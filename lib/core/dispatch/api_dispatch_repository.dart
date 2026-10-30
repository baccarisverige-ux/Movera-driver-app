import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/contracts/category_catalog.dart';
import 'package:movera/core/contracts/zone_settings.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/money/money.dart';

/// Contract v0.4.0 `Offer` → [RideOffer] (`openapi.yaml#Offer`).
abstract final class OfferWire {
  static const Map<String, String> _payments = {
    'cash': 'Cash',
    'card': 'Card',
    'apple_pay': 'Apple Pay',
    'google_pay': 'Google Pay',
    'wallet': 'Wallet',
  };

  /// Contract `PaymentMethod`, the v0.3 ids (`apple`, `google`) read as
  /// their v0.4 names like the config reader does. Unknown: Card.
  static String _payment(Object? id) {
    final key = id is String ? id.trim() : null;
    return _payments[ZoneDefaults.paymentMethodAliases[key] ?? key] ?? 'Card';
  }

  /// Throws [FormatException] when a required field is missing or wrong.
  static RideOffer parse(Map<String, dynamic> json) {
    String text(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Offer.$key missing', value);
      }
      return value;
    }

    int whole(String key) {
      final value = json[key];
      if (value is! num) throw FormatException('Offer.$key missing', value);
      return value.toInt();
    }

    Money? money(String key) {
      final value = json[key];
      return value is Map
          ? Money.fromJson(Map<String, dynamic>.from(value))
          : null;
    }

    Map<String, dynamic> place(Object? value) {
      if (value is! Map || value['lat'] is! num || value['lng'] is! num) {
        throw FormatException('Offer place missing', value);
      }
      return Map<String, dynamic>.from(value);
    }

    GeoPoint point(Map<String, dynamic> p) =>
        GeoPoint((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble());

    final pickup = place(json['pickup']);
    final dropoff = place(json['dropoff']);
    final stops = json['stops'];
    final rating = json['riderRating'];
    final scheduled = json['scheduledAt'];
    final at = scheduled is String
        ? DateTime.tryParse(scheduled)?.toLocal()
        : null;
    String two(int n) => n.toString().padLeft(2, '0');
    return RideOffer(
      id: text('offerId'),
      tripId: text('tripId'),
      version: whole('version'),
      category: CategoryCatalog.labelOf(text('categoryId')),
      fare:
          money('fare') ?? (throw const FormatException('Offer.fare missing')),
      driverBonus: money('driverBonus'),
      driverEarnings: money('driverEarnings'),
      pickupPay: money('pickupPay'),
      fareBoost: money('fareBoost'),
      priority: json['priority'] == true,
      source: OfferSource.fromWire(json['source']),
      groupId: json['groupId'] is String ? json['groupId'] as String : null,
      rating: rating is num ? rating.toStringAsFixed(2) : '—',
      riderTrips: (json['riderTrips'] as num?)?.toInt() ?? 0,
      pickupMinutes: (whole('pickupEtaSeconds') / 60).ceil(),
      pickupKm: whole('pickupMeters') / 1000,
      tripMinutes: (whole('tripSeconds') / 60).ceil(),
      tripKm: whole('tripMeters') / 1000,
      pickup: pickup['address'] as String? ?? '',
      dropoff: dropoff['address'] as String? ?? '',
      pickupPosition: point(pickup),
      dropoffPosition: point(dropoff),
      stops: [
        if (stops is List)
          for (final stop in stops)
            ReservationStop(
              address: place(stop)['address'] as String? ?? '',
              point: point(place(stop)),
            ),
      ],
      payment: _payment(json['paymentMethod']),
      kind: OfferKind.fromWire(json['kind']),
      expiresAt: json['expiresAt'] is String
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
      reasonCode: json['reasonCode'] is String
          ? json['reasonCode'] as String
          : null,
      reservationTime: json['kind'] == 'reservation' && at != null
          ? '${two(at.hour)}:${two(at.minute)}'
          : null,
      // The server already sent only what this driver may see.
      isNearby: true,
      followsDestination: true,
    );
  }
}

/// A driver offer feed event (`openapi.yaml#OfferEvent`). The feed also
/// tolerates an admin dispatch `assignment_locked` (§3.1) for a trip:
/// every offer of it is then gone, taken by another driver.
class OfferFeedEvent {
  const OfferFeedEvent._({
    required this.kind,
    required this.sequence,
    this.offerJson,
    this.tripId,
  });

  static OfferFeedEvent? tryParse(Map<String, dynamic> json) {
    final kind = json['kind'];
    final sequence = json['sequence'];
    if (kind is! String || sequence is! int || sequence < 1) return null;
    final offer = json['offer'];
    final trip = json['tripId'] ?? (offer is Map ? offer['tripId'] : null);
    return OfferFeedEvent._(
      kind: kind,
      sequence: sequence,
      offerJson: offer is Map ? Map<String, dynamic>.from(offer) : null,
      tripId: trip is String ? trip : null,
    );
  }

  final String kind;
  final int sequence;
  final Map<String, dynamic>? offerJson;
  final String? tripId;
}

/// Dispatch over the contract's driver offer endpoints:
/// `GET /driver/offers`, `GET /driver/offers/stream`,
/// `POST /offers/{offerId}/accept` and `POST /offers/{offerId}/decline`.
///
/// A live build (`MOVERA_AUTH_REQUIRED`) installs it through
/// `LiveDriverServices`; the demo builds use the in-process demo dispatch.
class ApiDispatchRepository implements DispatchRepository {
  ApiDispatchRepository({
    required http.Client client,
    required Uri baseUri,
    required Future<String?> Function() accessToken,
    String Function()? idempotencyKey,
    Duration Function(int attempt)? reconnectDelay,
    this.feedIdleTimeout = defaultFeedIdleTimeout,
    this.renewSession,
    this.onAccepted,
    DateTime Function()? now,
  }) : _client = client,
       _base = baseUri,
       _token = accessToken,
       _key = idempotencyKey ?? _randomKey,
       _reconnectDelay = reconnectDelay ?? _backoff,
       _now = now ?? DateTime.now;

  final http.Client _client;
  final Uri _base;
  final Future<String?> Function() _token;
  final String Function() _key;
  final Duration Function(int attempt) _reconnectDelay;
  final DateTime Function() _now;

  /// Owner, live test 2026-10-26 ("driver don't receive offers"): a feed
  /// that goes silent without closing (an iPhone that locked or changed
  /// network leaves the socket half open) is closed and opened again after
  /// this long with nothing on it. The server sends `: heartbeat` every
  /// 15 s, so a healthy feed is never this quiet.
  final Duration feedIdleTimeout;

  static const defaultFeedIdleTimeout = Duration(seconds: 45);

  /// Renews the access token after a `401` (the app's [ApiClient] refresh),
  /// so a command is sent once more and the feed reconnects with the new
  /// token. Null: a 401 is only an error.
  final Future<void> Function()? renewSession;

  /// The trip (`TripProjection`) an accepted offer answered with: its
  /// version is the trip's first `expectedVersion`.
  final void Function(Map<String, dynamic> trip)? onAccepted;

  /// The server took the driver offline (`OfferEvent.driverOffline`, the
  /// row of missed Exclusive offers). Set when a session attaches.
  void Function()? onDriverOffline;

  /// Driver group 3 live test (2026-10-30, "the first Go online after every
  /// start is undone a second later"): when the server answered the
  /// driver's latest Go online, on this phone's clock. A `driverOffline`
  /// that happened before it is history (an old auto-offline replayed by
  /// the feed), not a reason to go offline now.
  DateTime? _onlineSince;

  /// The server just answered Go online ([LivePresence.goOnline]): every
  /// `driverOffline` that happened before now is old news.
  void markOnline() => _onlineSince = _now();

  /// When [event] happened on this phone's clock: the server's own age of
  /// the event (`serverTime` − `occurredAt`) taken from now, so a phone
  /// clock that is off does not matter. Null without both times.
  DateTime? _happenedAt(Map<String, dynamic> event) {
    final occurred = event['occurredAt'];
    final server = event['serverTime'];
    if (occurred is! String || server is! String) return null;
    final at = DateTime.tryParse(occurred);
    final sent = DateTime.tryParse(server);
    if (at == null || sent == null) return null;
    return _now().subtract(sent.difference(at));
  }

  /// True when the event's `driverOffline` is older than the driver's
  /// latest Go online (a replay), so it must not set him offline again.
  bool _staleOffline(Map<String, dynamic> event) {
    final since = _onlineSince;
    if (since == null) return false;
    final at = _happenedAt(event);
    return at != null && at.isBefore(since);
  }

  final Map<String, RideOffer> _offers = <String, RideOffer>{};
  final Map<String, RideOffer> _nextTrips = <String, RideOffer>{};
  final StreamController<List<RideOffer>> _nearby =
      StreamController<List<RideOffer>>.broadcast();
  final StreamController<List<RideOffer>> _next =
      StreamController<List<RideOffer>>.broadcast();
  final StreamController<OfferWithdrawal> _withdrawals =
      StreamController<OfferWithdrawal>.broadcast();
  int _lastSequence = 0;
  StreamSubscription<String>? _feed;
  Timer? _feedIdle;
  final StreamController<bool> _live = StreamController<bool>.broadcast();
  bool _feedLive = false;
  int _reconnects = 0;
  Timer? _reconnect;
  bool _disposed = false;

  /// False after [disconnect]: a lost feed is not opened again.
  bool _wanted = true;

  /// Bumped by every [connect] and [disconnect]: an older answer that
  /// arrives late is not the feed.
  int _generation = 0;

  /// One Idempotency-Key per offer command (its route and body) until the
  /// server answers it: a retry after no answer, the app's or the
  /// driver's, is the same command (openapi `Unavailable`: "retry with
  /// the same Idempotency-Key"). A new body is a new command.
  final Map<String, String> _commandKeys = <String, String>{};

  static final math.Random _random = math.Random.secure();

  static String _randomKey() => List<String>.generate(
    32,
    (_) => _random.nextInt(16).toRadixString(16),
  ).join();

  /// The offer feed cursor, for `?after=` replay.
  int get lastSequence => _lastSequence;

  /// The longest any request waits for the server's answer (driver-r5-21):
  /// a stalled connection is then no answer, as when it drops, so a claim
  /// ends as a network error (same Idempotency-Key on a retry) instead of
  /// leaving Home "Matching" until the OS gives up on the socket.
  static const requestTimeout = Duration(seconds: 10);

  /// 1 s, 2 s, 4 s … up to 30 s between tries.
  static Duration _backoff(int attempt) =>
      Duration(seconds: math.min(30, 1 << math.min(attempt, 5)));

  /// True while the offer feed is open. When it is not, the offer list
  /// is the last one known and may be stale; it reconnects by itself.
  bool get feedLive => _feedLive;

  /// [feedLive] as it changes.
  Stream<bool> watchFeedLive() => _live.stream;

  void _setLive(bool live) {
    if (_feedLive == live) return;
    _feedLive = live;
    if (!_live.isClosed) _live.add(live);
  }

  Uri _uri(String path, [Map<String, String>? query]) => _base.replace(
    path: '${_base.path.replaceFirst(RegExp(r'/$'), '')}$path',
    queryParameters: query,
  );

  Future<Map<String, String>> _headers({String? idempotencyKey}) async {
    final token = await _token();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Api-Version': '0.5',
      if (token != null) 'Authorization': 'Bearer $token',
      if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
    };
  }

  /// POST [path] with [body] under the command's key. The key is dropped
  /// once the server answered (not on no answer or a 5xx).
  Future<http.Response> _command(String path, Map<String, Object?> body) async {
    final text = jsonEncode(body);
    final command = '$path $text';
    final key = _commandKeys.putIfAbsent(command, _key);
    var response = await _client
        .post(
          _uri(path),
          headers: await _headers(idempotencyKey: key),
          body: text,
        )
        .timeout(requestTimeout);
    final renew = renewSession;
    if (response.statusCode == 401 && renew != null) {
      // An expired access token: renewed once, then the same command.
      await renew();
      response = await _client
          .post(
            _uri(path),
            headers: await _headers(idempotencyKey: key),
            body: text,
          )
          .timeout(requestTimeout);
    }
    if (response.statusCode < 500) _commandKeys.remove(command);
    return response;
  }

  @override
  Stream<List<RideOffer>> watchNearbyOffers({
    bool destinationModeActive = false,
  }) => _withSnapshot(_nearby, () => _offers.values);

  @override
  Stream<List<RideOffer>> watchNextTripOffers() =>
      _withSnapshot(_next, () => _nextTrips.values);

  Stream<List<RideOffer>> _withSnapshot(
    StreamController<List<RideOffer>> source,
    Iterable<RideOffer> Function() now,
  ) => Stream<List<RideOffer>>.multi((sink) {
    final sub = source.stream.listen(sink.addSync, onDone: sink.closeSync);
    sink.onCancel = sub.cancel;
    sink.addSync(List<RideOffer>.unmodifiable(now()));
  }, isBroadcast: true);

  @override
  Stream<OfferWithdrawal> watchWithdrawals() => _withdrawals.stream;

  // Scheduled rides Movera assigns (Q29) are not mapped from the feed yet.
  @override
  Stream<ReservationRequestPreview> watchAssignments() =>
      const Stream<ReservationRequestPreview>.empty();

  /// The server puts a cancelled reservation back out itself.
  @override
  void releaseReservation(String reservationId) {}

  /// `GET /driver/offers?status=open`: the open offers replace the list.
  @override
  void refreshOffers() => unawaited(_load());

  Future<void> _load() async {
    try {
      final headers = await _headers();
      final response = await _client
          .get(
            _uri('/driver/offers', const {'status': 'open'}),
            headers: headers,
          )
          .timeout(requestTimeout);
      if (response.statusCode != 200) return;
      final body = jsonDecode(response.body);
      final items = body is Map ? body['items'] : null;
      if (items is! List) return;
      _offers.clear();
      _nextTrips.clear();
      for (final item in items) {
        if (item is Map) _upsert(Map<String, dynamic>.from(item));
      }
      _emit();
    } catch (_) {
      // Offline: the list stays as it was.
    }
  }

  /// Opens `GET /driver/offers/stream` (SSE) from [lastSequence]. An
  /// error answer, a dropped connection or a feed the server ends is
  /// retried with backoff from the last sequence; [feedLive] says when.
  Future<void> connect() async {
    _wanted = true;
    final generation = ++_generation;
    _reconnect?.cancel();
    _feedIdle?.cancel();
    await _feed?.cancel();
    _feed = null;
    if (_disposed || generation != _generation) return;
    final http.StreamedResponse response;
    try {
      final request =
          http.Request(
              'GET',
              _uri('/driver/offers/stream', {
                if (_lastSequence > 0) 'after': '$_lastSequence',
              }),
            )
            ..headers.addAll({
              ...await _headers(),
              'Accept': 'text/event-stream',
              if (_lastSequence > 0) 'Last-Event-ID': '$_lastSequence',
            });
      response = await _client.send(request).timeout(requestTimeout);
    } catch (_) {
      if (generation == _generation) _feedLost();
      return;
    }
    if (generation != _generation) {
      unawaited(response.stream.drain<void>().catchError((_) {}));
      return;
    }
    if (response.statusCode != 200) {
      // An error body is not the feed.
      unawaited(response.stream.drain<void>().catchError((_) {}));
      if (response.statusCode == 401) {
        try {
          await renewSession?.call();
        } catch (_) {
          // The next try asks again.
        }
      }
      _feedLost();
      return;
    }
    if (_disposed || !_wanted) {
      unawaited(response.stream.drain<void>().catchError((_) {}));
      return;
    }
    _reconnects = 0;
    _setLive(true);
    final data = StringBuffer();
    void quiet() {
      if (generation != _generation) return;
      unawaited(_feed?.cancel());
      _feed = null;
      _feedLost();
    }

    _feedIdle?.cancel();
    _feedIdle = Timer(feedIdleTimeout, quiet);
    int? blockId;
    _feed = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            // Any line, the heartbeat comment too, shows the feed is alive.
            _feedIdle?.cancel();
            _feedIdle = Timer(feedIdleTimeout, quiet);
            if (line.startsWith('data:')) {
              data.write(line.substring(5).trim());
            } else if (line.startsWith('id:')) {
              blockId = int.tryParse(line.substring(3).trim());
            } else if (line.isEmpty && data.isEmpty) {
              // An `id:` with no data is the feed's cursor (SSE): a feed
              // opened without one starts at the server's newest event,
              // and a reconnect goes on from there, not from 0.
              final id = blockId;
              blockId = null;
              if (id != null && id > _lastSequence) _lastSequence = id;
            } else if (line.isEmpty && data.isNotEmpty) {
              blockId = null;
              final raw = data.toString();
              data.clear();
              try {
                final event = jsonDecode(raw);
                if (event is Map) ingest(Map<String, dynamic>.from(event));
              } on FormatException {
                // A broken event is skipped; the next resync fixes the list.
              }
            }
          },
          onError: (_) => _feedLost(),
          onDone: _feedLost,
          cancelOnError: true,
        );
  }

  /// The feed is gone: not live, and it tries again after a while.
  void _feedLost() {
    _feedIdle?.cancel();
    _feedIdle = null;
    _setLive(false);
    if (_disposed || !_wanted) return;
    _reconnect?.cancel();
    _reconnect = Timer(
      _reconnectDelay(_reconnects++),
      () => unawaited(connect()),
    );
  }

  /// Closes the feed and forgets the offers (the driver went offline: the
  /// server withdraws them). [connect] opens it again from [lastSequence].
  Future<void> disconnect() async {
    _wanted = false;
    _generation++;
    _reconnect?.cancel();
    _reconnect = null;
    _feedIdle?.cancel();
    _feedIdle = null;
    final feed = _feed;
    _feed = null;
    _setLive(false);
    if (_offers.isNotEmpty || _nextTrips.isNotEmpty) {
      _offers.clear();
      _nextTrips.clear();
      _emit();
    }
    await feed?.cancel();
  }

  /// Applies one feed event (`offer_created`, `offer_updated`,
  /// `offer_withdrawn`, or a trip's `assignment_locked`). Replays and
  /// duplicates (sequence ≤ the last one) are ignored.
  void ingest(Map<String, dynamic> json) {
    final event = OfferFeedEvent.tryParse(json);
    if (event == null || event.sequence <= _lastSequence) return;
    _lastSequence = event.sequence;
    // Contract v0.8.0 §6.7: the server set the driver offline after the
    // row of missed Exclusive offers; the app goes offline too, unless it
    // happened before the driver's latest Go online (a replayed old one).
    if (json['driverOffline'] == true && !_staleOffline(json)) {
      onDriverOffline?.call();
    }
    final offer = event.offerJson;
    switch (event.kind) {
      case 'offer_created' || 'offer_updated' when offer != null:
        if (offer['status'] == null || offer['status'] == 'open') {
          _upsert(offer);
        } else {
          _withdraw(
            offer['offerId'],
            OfferGoneReason.fromWire(offer['status']),
          );
        }
      case 'offer_withdrawn' when offer != null:
        _withdraw(offer['offerId'], OfferGoneReason.fromWire(offer['status']));
      case 'assignment_locked' when event.tripId != null:
        for (final gone in [
          ..._offers.values,
          ..._nextTrips.values,
        ].where((item) => item.tripId == event.tripId)) {
          _withdraw(gone.id, OfferGoneReason.claimedElsewhere, emit: false);
        }
      default:
        return;
    }
    _emit();
  }

  void _upsert(Map<String, dynamic> json) {
    final RideOffer offer;
    try {
      offer = OfferWire.parse(json);
    } on FormatException {
      return;
    }
    (json['kind'] == 'next_trip' ? _nextTrips : _offers)[offer.id] = offer;
  }

  void _withdraw(Object? offerId, OfferGoneReason reason, {bool emit = false}) {
    if (offerId is! String) return;
    final gone = _offers.remove(offerId) ?? _nextTrips.remove(offerId);
    if (gone == null) return;
    if (!_withdrawals.isClosed) {
      _withdrawals.add(
        OfferWithdrawal(offerId: offerId, tripId: gone.tripId, reason: reason),
      );
    }
    if (emit) _emit();
  }

  void _emit() {
    if (!_nearby.isClosed) {
      _nearby.add(List<RideOffer>.unmodifiable(_offers.values));
    }
    if (!_next.isClosed) {
      _next.add(List<RideOffer>.unmodifiable(_nextTrips.values));
    }
  }

  RideOffer? _find(String offerId) => _offers[offerId] ?? _nextTrips[offerId];

  /// `POST /offers/{offerId}/accept` with the offer's version. A stale
  /// version is retried once with the server's.
  @override
  Future<ClaimResult> claimOffer(String offerId) async {
    final offer = _find(offerId);
    if (offer == null) return const ClaimResult.unavailable();
    var version = offer.version;
    for (var attempt = 0; attempt < 2; attempt++) {
      final http.Response response;
      try {
        response = await _command(
          '/offers/${Uri.encodeComponent(offerId)}/accept',
          {'expectedVersion': version},
        );
      } catch (_) {
        return const ClaimResult.networkError();
      }
      final body = _json(response.body);
      switch (response.statusCode) {
        case 200:
          // The body is the trip (TripProjection); the offer already
          // carries its tripId, so the trip opens under the server's id.
          if (body != null && body['tripId'] is String) {
            onAccepted?.call(body);
          }
          _offers.remove(offerId);
          _nextTrips.remove(offerId);
          _emit();
          return ClaimResult.success(offer);
        case 409:
          final current = body?['projection'];
          final status = current is Map ? current['status'] : null;
          if (body?['code'] == 'version_mismatch' &&
              status == 'open' &&
              current is Map &&
              current['version'] is int &&
              attempt == 0) {
            version = current['version'] as int;
            continue;
          }
          _withdraw(offerId, OfferGoneReason.fromWire(status), emit: true);
          return status == 'expired'
              ? const ClaimResult.expired()
              : status == 'claimed_elsewhere' || body?['code'] == 'conflict'
              ? const ClaimResult.alreadyClaimed()
              : const ClaimResult.unavailable();
        case 404:
          _withdraw(offerId, OfferGoneReason.withdrawn, emit: true);
          return const ClaimResult.unavailable();
        default:
          return const ClaimResult.networkError();
      }
    }
    return const ClaimResult.unavailable();
  }

  /// `POST /offers/{offerId}/decline` with the offer's version.
  @override
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async {
    final offer = _find(offerId);
    if (offer == null) return false;
    try {
      final response =
          await _command('/offers/${Uri.encodeComponent(offerId)}/decline', {
            'expectedVersion': offer.version,
            if (reasonCode != null) 'reasonCode': reasonCode,
          });
      if (response.statusCode != 200 && response.statusCode != 409) {
        return false;
      }
      _offers.remove(offerId);
      _nextTrips.remove(offerId);
      _emit();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Map<String, dynamic>? _json(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _reconnect?.cancel();
    _feedIdle?.cancel();
    await _feed?.cancel();
    await _live.close();
    await _nearby.close();
    await _next.close();
    await _withdrawals.close();
  }
}

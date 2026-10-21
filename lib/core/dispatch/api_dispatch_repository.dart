import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/contracts/category_catalog.dart';
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
  };

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
      return value is Map ? Money.fromJson(Map<String, dynamic>.from(value)) : null;
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
    final at = scheduled is String ? DateTime.tryParse(scheduled)?.toLocal() : null;
    String two(int n) => n.toString().padLeft(2, '0');
    return RideOffer(
      id: text('offerId'),
      tripId: text('tripId'),
      version: whole('version'),
      category: CategoryCatalog.labelOf(text('categoryId')),
      fare: money('fare') ?? (throw const FormatException('Offer.fare missing')),
      driverBonus: money('driverBonus'),
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
      payment: _payments[json['paymentMethod']] ?? 'Card',
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
/// No backend exists yet and nothing installs this class in the app; the
/// demo builds use the in-process demo dispatch.
class ApiDispatchRepository implements DispatchRepository {
  ApiDispatchRepository({
    required http.Client client,
    required Uri baseUri,
    required Future<String?> Function() accessToken,
    String Function()? idempotencyKey,
    Duration Function(int attempt)? reconnectDelay,
  }) : _client = client,
       _base = baseUri,
       _token = accessToken,
       _key = idempotencyKey ?? _randomKey,
       _reconnectDelay = reconnectDelay ?? _backoff;

  final http.Client _client;
  final Uri _base;
  final Future<String?> Function() _token;
  final String Function() _key;
  final Duration Function(int attempt) _reconnectDelay;

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
  final StreamController<bool> _live = StreamController<bool>.broadcast();
  bool _feedLive = false;
  int _reconnects = 0;
  Timer? _reconnect;
  bool _disposed = false;

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
      'X-Api-Version': '0.4',
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
    final response = await _client.post(
      _uri(path),
      headers: await _headers(idempotencyKey: key),
      body: text,
    );
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
      final response = await _client.get(
        _uri('/driver/offers', const {'status': 'open'}),
        headers: await _headers(),
      );
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
    _reconnect?.cancel();
    await _feed?.cancel();
    _feed = null;
    if (_disposed) return;
    final http.StreamedResponse response;
    try {
      final request = http.Request(
        'GET',
        _uri('/driver/offers/stream', {
          if (_lastSequence > 0) 'after': '$_lastSequence',
        }),
      )..headers.addAll({
          ...await _headers(),
          'Accept': 'text/event-stream',
          if (_lastSequence > 0) 'Last-Event-ID': '$_lastSequence',
        });
      response = await _client.send(request);
    } catch (_) {
      _feedLost();
      return;
    }
    if (response.statusCode != 200) {
      // An error body is not the feed.
      unawaited(response.stream.drain<void>().catchError((_) {}));
      _feedLost();
      return;
    }
    if (_disposed) {
      unawaited(response.stream.drain<void>().catchError((_) {}));
      return;
    }
    _reconnects = 0;
    _setLive(true);
    final data = StringBuffer();
    _feed = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          if (line.startsWith('data:')) {
            data.write(line.substring(5).trim());
          } else if (line.isEmpty && data.isNotEmpty) {
            final raw = data.toString();
            data.clear();
            try {
              final event = jsonDecode(raw);
              if (event is Map) ingest(Map<String, dynamic>.from(event));
            } on FormatException {
              // A broken event is skipped; the next resync fixes the list.
            }
          }
        }, onError: (_) => _feedLost(), onDone: _feedLost, cancelOnError: true);
  }

  /// The feed is gone: not live, and it tries again after a while.
  void _feedLost() {
    _setLive(false);
    if (_disposed) return;
    _reconnect?.cancel();
    _reconnect = Timer(_reconnectDelay(_reconnects++), () => unawaited(connect()));
  }

  /// Applies one feed event (`offer_created`, `offer_updated`,
  /// `offer_withdrawn`, or a trip's `assignment_locked`). Replays and
  /// duplicates (sequence ≤ the last one) are ignored.
  void ingest(Map<String, dynamic> json) {
    final event = OfferFeedEvent.tryParse(json);
    if (event == null || event.sequence <= _lastSequence) return;
    _lastSequence = event.sequence;
    final offer = event.offerJson;
    switch (event.kind) {
      case 'offer_created' || 'offer_updated' when offer != null:
        if (offer['status'] == null || offer['status'] == 'open') {
          _upsert(offer);
        } else {
          _withdraw(offer['offerId'], OfferGoneReason.fromWire(offer['status']));
        }
      case 'offer_withdrawn' when offer != null:
        _withdraw(offer['offerId'], OfferGoneReason.fromWire(offer['status']));
      case 'assignment_locked' when event.tripId != null:
        for (final gone in [..._offers.values, ..._nextTrips.values]
            .where((item) => item.tripId == event.tripId)) {
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
      _withdrawals.add(OfferWithdrawal(
        offerId: offerId,
        tripId: gone.tripId,
        reason: reason,
      ));
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
      final response = await _command(
        '/offers/${Uri.encodeComponent(offerId)}/decline',
        {
          'expectedVersion': offer.version,
          if (reasonCode != null) 'reasonCode': reasonCode,
        },
      );
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
    await _feed?.cancel();
    await _live.close();
    await _nearby.close();
    await _next.close();
    await _withdrawals.close();
  }
}

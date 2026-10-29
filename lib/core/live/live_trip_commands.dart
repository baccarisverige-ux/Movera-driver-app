import 'dart:async';
import 'dart:convert';

import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/live/live_error_message.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:movera/core/money/money.dart';

/// What the server said to one trip step: done, or a plain [message] for
/// the driver.
class LiveTripOutcome {
  const LiveTripOutcome.ok() : message = null, error = null;
  const LiveTripOutcome.failed(String this.message, {this.error});

  final String? message;
  final Object? error;
  bool get ok => message == null;
}

/// The server's final price before Collect cash (contract v0.17.3 §26):
/// [total] the rider's fare, [cashDue] what the driver takes in cash
/// (the fare less the wallet's part), [earlyEnd] when the driver is more
/// than 300 m from the drop-off (owner decision 28: priced by what was
/// driven, at least the category minimum).
class CompletePreview {
  const CompletePreview({
    this.previewId,
    required this.total,
    required this.cashDue,
    required this.earlyEnd,
    this.driverEarnings,
  });

  /// The answer's money, or null when it is not a `CompletePreview`.
  static CompletePreview? tryParse(Map<String, dynamic> json) {
    try {
      final total = json['total'];
      final cash = json['cashDue'];
      final early = json['earlyEnd'];
      final earnings = json['driverEarnings'];
      if (total is! Map || cash is! Map || early is! bool) return null;
      final id = json['previewId'];
      final parsed = CompletePreview(
        previewId: id is String && id.isNotEmpty ? id : null,
        total: Money.fromJson(Map<String, dynamic>.from(total)),
        cashDue: Money.fromJson(Map<String, dynamic>.from(cash)),
        earlyEnd: early,
        driverEarnings: earnings is Map
            ? Money.fromJson(Map<String, dynamic>.from(earnings))
            : null,
      );
      return parsed.cashDue.currency == parsed.total.currency ? parsed : null;
    } on FormatException {
      return null;
    }
  }

  /// The frozen price's id (2 minutes, contract v0.17.3 §26), sent back
  /// on complete; null from a server before the freeze.
  final String? previewId;
  final Money total;
  final Money cashDue;
  final bool earlyEnd;

  /// The driver's part of [total]; null from a server that leaves it out.
  final Money? driverEarnings;
}

/// A device fix as the contract's `GeoFix` (`{lat, lng, accuracy,
/// heading?, speedMps?, measuredAt}`).
typedef LiveFix = Map<String, Object?>;

/// The driver's trip commands on the server (contract §3, live builds):
/// `POST /trips/{tripId}/head-to-pickup | arrive | board | start | complete
/// | no-show | cancel`, each with the trip's `expectedVersion` and its own
/// `Idempotency-Key` (the same key again after no answer).
///
/// It keeps each trip's newest projection (from the accept answer, every
/// command answer, a `409` and the trip's live events) so the next command
/// sends the version the server has. The trip screen keeps its own stages;
/// this only asks the server first.
class LiveTripCommands {
  LiveTripCommands({
    required ApiClient api,
    LiveFix? Function()? lastFix,
    this.onEnded,
  }) : _api = api,
       _lastFix = lastFix ?? (() => null);

  final ApiClient _api;
  final LiveFix? Function() _lastFix;

  /// Told when a projection says the trip is over (contract.json
  /// `tripStatus.terminal`): the chat closes at drop-off (v0.13.0 §22).
  final void Function(String tripId)? onEnded;

  /// contract.json `tripStatus.terminal`.
  static const terminal = {
    'completed',
    'cancelled_by_rider',
    'cancelled_by_driver',
    'cancelled_by_admin',
    'cancelled_by_system',
    'no_show',
    'expired',
    'failed',
  };

  static const _base = '/api/v1/trips';

  /// The last final price shown per trip (contract v0.17.3 §26).
  final Map<String, CompletePreview> _previews = {};
  final Map<String, CompletePreview> _changed = {};
  final Set<String> _unsupported = {};

  /// True when the server has no complete-preview (`404` without
  /// `trip_not_found`: a server before contract v0.17.3). The app then
  /// keeps the old finish so a cash trip is never stuck.
  bool previewUnsupported(String tripId) => _unsupported.contains(tripId);

  /// The last [previewComplete] answer for [tripId]: its `cashDue` is the
  /// cash the driver was told to take, sent as `cashCollected`.
  CompletePreview? previewOf(String tripId) => _previews[tripId];

  /// Newest known projection per trip (`tripId`, `status`, `version`).
  final Map<String, Map<String, dynamic>> _trips = {};

  /// Statuses this phone's own commands lead to, per trip: their echo on
  /// the trip's event stream is not news for the screen.
  final Map<String, Set<String>> _own = {};

  /// One Idempotency-Key per command (path and body) until it is answered.
  final Map<String, String> _keys = {};

  /// The trip's last known status (wire name), or null when not known.
  String? statusOf(String tripId) => _trips[tripId]?['status'] as String?;

  /// The trip's last known version, or null when not known.
  int? versionOf(String tripId) =>
      (_trips[tripId]?['version'] as num?)?.toInt();

  /// The trip's newest known projection (the whole answer), or null.
  Map<String, dynamic>? projectionOf(String tripId) {
    final known = _trips[tripId];
    return known == null ? null : Map<String, dynamic>.unmodifiable(known);
  }

  /// Folds a projection in: kept when it is not older than the one known.
  void observe(Map<String, dynamic> projection) {
    final id = projection['tripId'];
    final version = projection['version'];
    if (id is! String || version is! num) return;
    final known = versionOf(id);
    if (known != null && version.toInt() < known) return;
    _trips[id] = {...?_trips[id], ...projection};
    if (terminal.contains(projection['status'])) onEnded?.call(id);
  }

  /// True when [status] is where one of this phone's own commands took
  /// [tripId] (its echo on the event stream).
  bool isOwnEcho(String tripId, String? status) =>
      status != null && (_own[tripId]?.contains(status) ?? false);

  /// Forgets a trip that is over for this phone.
  void forget(String tripId) {
    _trips.remove(tripId);
    _previews.remove(tripId);
    _changed.remove(tripId);
    _unsupported.remove(tripId);
    _own.remove(tripId);
  }

  /// The trip screen opened: an accepted trip is on its way to the pickup
  /// (`head-to-pickup`), so the rider sees the driver coming.
  Future<LiveTripOutcome> begin(String tripId) async {
    final current = await _current(tripId);
    if (current == null) return _unknown;
    if (current['status'] != 'accepted') return const LiveTripOutcome.ok();
    return _step(
      tripId,
      'head-to-pickup',
      done: const {'driver_to_pickup', 'arrived', ..._onboard},
      leadsTo: const {'driver_to_pickup'},
    );
  }

  /// Arrived at the pickup (`arrive`, with the latest fix): the server
  /// checks the driver is near it. An accepted trip heads to it first.
  Future<LiveTripOutcome> arrive(String tripId) async {
    final begun = await begin(tripId);
    if (!begun.ok) return begun;
    final fix = _lastFix();
    return _step(
      tripId,
      'arrive',
      body: {if (fix != null) 'location': fix},
      done: const {'arrived', ..._onboard},
      leadsTo: const {'arrived'},
    );
  }

  /// "Start trip": the app's one slide is the contract's `board` then
  /// `start` (`rider_onboard` → `in_trip`).
  Future<LiveTripOutcome> start(String tripId) async {
    final boarded = await _step(
      tripId,
      'board',
      done: _onboard,
      leadsTo: const {'rider_onboard'},
    );
    if (!boarded.ok) return boarded;
    return _step(
      tripId,
      'start',
      done: const {'in_trip', 'approaching_dropoff'},
      leadsTo: const {'in_trip'},
    );
  }

  /// Finish (`complete`). [preview] is the frozen price the driver was
  /// shown (contract v0.17.3 §26): its `previewId` and, on a [cash] trip,
  /// its `cashDue` as `cashCollected`. Without it the server counts the
  /// fare less what the rider's wallet paid. On `409 price_changed` the
  /// server's fresh price is kept ([takePriceChanged]) and the step fails:
  /// the app shows the sheet again and never resends the old amount.
  Future<LiveTripOutcome> complete(
    String tripId, {
    CompletePreview? preview,
    bool cash = false,
  }) async {
    final outcome = await _step(
      tripId,
      'complete',
      body: {
        if (preview?.previewId != null) 'previewId': preview!.previewId,
        if (cash && preview != null) 'cashCollected': preview.cashDue.toJson(),
      },
      done: const {'completed'},
      leadsTo: const {'completed'},
    );
    final error = outcome.error;
    if (error is ApiError && error.detail == 'price_changed') {
      final fresh = error.preview == null
          ? null
          : CompletePreview.tryParse(error.preview!);
      // The fresh frozen price replaces the shown one; it is what the next
      // complete sends.
      if (fresh == null) {
        _previews.remove(tripId);
      } else {
        _previews[tripId] = fresh;
        _changed[tripId] = fresh;
      }
    }
    return outcome;
  }

  /// The fresh price of a `409 price_changed`, once: the sheet shows it.
  CompletePreview? takePriceChanged(String tripId) => _changed.remove(tripId);

  /// The final price `complete` would set now, frozen for 2 minutes
  /// (contract v0.17.3 §26, `GET /driver/trips/{tripId}/complete-preview`):
  /// shown on Collect cash so the driver takes what the rider is charged
  /// (owner 2026-10-29, live bug A). Null when the server did not answer
  /// with one; see [previewUnsupported].
  Future<CompletePreview?> previewComplete(String tripId) async {
    _unsupported.remove(tripId);
    try {
      final answer = await _api.get(
        '/api/v1/driver/trips/${Uri.encodeComponent(tripId)}/complete-preview',
      );
      final preview = CompletePreview.tryParse(answer);
      if (preview == null) {
        _previews.remove(tripId);
      } else {
        _previews[tripId] = preview;
      }
      return preview;
    } on ApiError catch (error) {
      final projection = error.projection;
      if (projection != null) observe({'tripId': tripId, ...projection});
      _previews.remove(tripId);
      if (error.statusCode == 404 && error.reason != 'trip_not_found') {
        _unsupported.add(tripId);
      }
      DriverLog.warn('complete preview refused: ${error.detail}', name: 'live');
      return null;
    }
  }

  /// "Framme vid stoppet" (contract v0.7.1 §3.8): the paid wait at the
  /// middle stop [stopIndex] (0-based) starts now; there are no free
  /// minutes at a stop.
  Future<LiveTripOutcome> arriveAtStop(String tripId, int stopIndex) =>
      _stopStep(tripId, stopIndex, 'arrive');

  /// The trip goes on from the middle stop [stopIndex]: its paid wait ends.
  Future<LiveTripOutcome> leaveStop(String tripId, int stopIndex) =>
      _stopStep(tripId, stopIndex, 'leave');

  /// True when the projection already has the stop's tap (a retry after a
  /// lost answer).
  bool _stopDone(String tripId, int stopIndex, String verb) {
    final visits = _trips[tripId]?['stopVisits'];
    if (visits is! List) return false;
    for (final visit in visits) {
      if (visit is Map && visit['stopIndex'] == stopIndex) {
        return verb == 'arrive'
            ? visit['arrivedAt'] != null
            : visit['leftAt'] != null;
      }
    }
    return false;
  }

  Future<LiveTripOutcome> _stopStep(
    String tripId,
    int stopIndex,
    String verb,
  ) async {
    final path =
        '/api/v1/driver/trips/${Uri.encodeComponent(tripId)}/stops/$stopIndex/$verb';
    for (var attempt = 0; attempt < 2; attempt++) {
      final current = await _current(tripId);
      if (current == null) return _unknown;
      if (_stopDone(tripId, stopIndex, verb)) return const LiveTripOutcome.ok();
      final payload = {'expectedVersion': versionOf(tripId)};
      final signature = '$path ${jsonEncode(payload)}';
      final key = _keys.putIfAbsent(signature, ApiClient.randomKey);
      try {
        observe(await _api.post(path, body: payload, idempotencyKey: key));
        _keys.remove(signature);
        return const LiveTripOutcome.ok();
      } on ApiError catch (error) {
        if (!error.isRetryable) _keys.remove(signature);
        final projection = error.projection;
        if (projection != null) observe({'tripId': tripId, ...projection});
        // Already recorded (another screen, or a lost answer): nothing to do.
        if (error.reason == 'stop_already_arrived' && verb == 'arrive' ||
            error.reason == 'stop_already_left' && verb == 'leave') {
          return const LiveTripOutcome.ok();
        }
        if (error.code == 'version_mismatch' &&
            projection != null &&
            attempt == 0) {
          continue;
        }
        DriverLog.warn('stop $verb refused: ${error.detail}', name: 'live');
        return LiveTripOutcome.failed(
          liveTripErrorMessage(error),
          error: error,
        );
      }
    }
    return _unknown;
  }

  /// The rider did not come (`no-show`, after the zone's wait).
  Future<LiveTripOutcome> noShow(String tripId, {String? reasonCode}) => _step(
    tripId,
    'no-show',
    body: {if (reasonCode != null) 'reasonCode': reasonCode},
    done: const {'no_show'},
    leadsTo: const {'no_show'},
  );

  /// The driver's cancel (`cancel`, a reason of the driver's groups):
  /// before the rider is on board the trip goes back to dispatch, after
  /// it the trip ends as cancelled by the driver.
  Future<LiveTripOutcome> cancel(String tripId, {required String reasonCode}) =>
      _step(
        tripId,
        'cancel',
        body: {'reasonCode': reasonCode},
        done: const {'cancelled_by_driver'},
        leadsTo: const {'searching', 'requested', 'cancelled_by_driver'},
      );

  static const Set<String> _onboard = {
    'rider_onboard',
    'in_trip',
    'approaching_dropoff',
  };

  LiveTripOutcome get _unknown =>
      LiveTripOutcome.failed(liveTripErrorMessage(null));

  /// The projection known, else `GET /trips/{tripId}`.
  /// Reads the trip once when nothing is known yet (a screen restored
  /// after a restart), so a replay of its history is told from news.
  Future<void> ensureKnown(String tripId) async {
    if (versionOf(tripId) == null) await _current(tripId);
  }

  Future<Map<String, dynamic>?> _current(
    String tripId, {
    bool fresh = false,
  }) async {
    final known = _trips[tripId];
    if (known != null && !fresh) return known;
    try {
      observe(await _api.get('$_base/${Uri.encodeComponent(tripId)}'));
    } on ApiError catch (error) {
      DriverLog.warn('trip $tripId not read: ${error.code}', name: 'live');
      return known;
    }
    return _trips[tripId];
  }

  Future<LiveTripOutcome> _step(
    String tripId,
    String command, {
    Map<String, Object?> body = const {},
    required Set<String> done,
    required Set<String> leadsTo,
  }) async {
    final path = '$_base/${Uri.encodeComponent(tripId)}/$command';
    for (var attempt = 0; attempt < 2; attempt++) {
      final current = await _current(tripId);
      if (current == null) return _unknown;
      // Already there (a retry after a lost answer, or another screen).
      if (done.contains(current['status'])) return const LiveTripOutcome.ok();
      final payload = {...body, 'expectedVersion': versionOf(tripId)};
      final signature = '$path ${jsonEncode(payload)}';
      final key = _keys.putIfAbsent(signature, ApiClient.randomKey);
      final own = _own.putIfAbsent(tripId, () => <String>{});
      final added = leadsTo.difference(own);
      own.addAll(added);
      try {
        final answer = await _api.post(
          path,
          body: payload,
          idempotencyKey: key,
        );
        _keys.remove(signature);
        observe(answer);
        return const LiveTripOutcome.ok();
      } on ApiError catch (error) {
        if (!error.isRetryable) _keys.remove(signature);
        final projection = error.projection;
        if (projection != null) observe({'tripId': tripId, ...projection});
        if (!error.neverReachedServer) {
          // Refused: its echo will not come.
          own.removeAll(added);
        }
        if (error.code == 'version_mismatch' &&
            projection != null &&
            attempt == 0) {
          continue;
        }
        DriverLog.warn('trip $command refused: ${error.detail}', name: 'live');
        return LiveTripOutcome.failed(
          liveTripErrorMessage(error),
          error: error,
        );
      }
    }
    return _unknown;
  }
}

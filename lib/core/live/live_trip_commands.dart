import 'dart:async';
import 'dart:convert';

import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/live/live_error_message.dart';
import 'package:movera/core/logging/driver_log.dart';

/// What the server said to one trip step: done, or a plain [message] for
/// the driver.
class LiveTripOutcome {
  const LiveTripOutcome.ok() : message = null, error = null;
  const LiveTripOutcome.failed(String this.message, {this.error});

  final String? message;
  final Object? error;
  bool get ok => message == null;
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
  LiveTripCommands({required ApiClient api, LiveFix? Function()? lastFix})
    : _api = api,
      _lastFix = lastFix ?? (() => null);

  final ApiClient _api;
  final LiveFix? Function() _lastFix;

  static const _base = '/api/v1/trips';

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
  int? versionOf(String tripId) => (_trips[tripId]?['version'] as num?)?.toInt();

  /// Folds a projection in: kept when it is not older than the one known.
  void observe(Map<String, dynamic> projection) {
    final id = projection['tripId'];
    final version = projection['version'];
    if (id is! String || version is! num) return;
    final known = versionOf(id);
    if (known != null && version.toInt() < known) return;
    _trips[id] = {...?_trips[id], ...projection};
  }

  /// True when [status] is where one of this phone's own commands took
  /// [tripId] (its echo on the event stream).
  bool isOwnEcho(String tripId, String? status) =>
      status != null && (_own[tripId]?.contains(status) ?? false);

  /// Forgets a trip that is over for this phone.
  void forget(String tripId) {
    _trips.remove(tripId);
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

  /// Finish (`complete`). The server counts the cash taken: the fare,
  /// waiting included, less what the rider's wallet paid.
  Future<LiveTripOutcome> complete(String tripId) => _step(
    tripId,
    'complete',
    done: const {'completed'},
    leadsTo: const {'completed'},
  );

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
  Future<Map<String, dynamic>?> _current(String tripId, {bool fresh = false}) async {
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
        final answer = await _api.post(path, body: payload, idempotencyKey: key);
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
        if (error.code == 'version_mismatch' && projection != null && attempt == 0) {
          continue;
        }
        DriverLog.warn('trip $command refused: ${error.detail}', name: 'live');
        return LiveTripOutcome.failed(liveTripErrorMessage(error), error: error);
      }
    }
    return _unknown;
  }
}

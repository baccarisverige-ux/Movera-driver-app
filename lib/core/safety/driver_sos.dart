import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/live/live_trip_commands.dart' show LiveFix;
import 'package:movera/core/logging/driver_log.dart';
import 'package:movera/core/safety/pending_sos.dart';
import 'package:movera/core/safety/sos_contacts_sms.dart';

export 'package:movera/core/safety/pending_sos.dart';
export 'package:movera/core/safety/sos_contacts_sms.dart';

/// What the SOS to Movera came to.
enum DriverSosOutcome {
  /// Movera has it: the app shows "SOS sent" (and nothing later).
  sent,

  /// No live trip: the server takes an SOS only during one.
  noTrip,

  /// Every try failed: the driver is told to rely on the 112 call.
  failed,
}

/// The SOS outcome with what the server said about the SMS to the
/// driver's emergency contacts (v0.18.101 §92 `SosReceipt.contactsSms`;
/// null when the answer has none).
class DriverSosResult {
  const DriverSosResult(this.outcome, {this.contactsSms});

  final DriverSosOutcome outcome;
  final SosContactsSms? contactsSms;
}

/// Contract v0.7.0 §15 (owner safety part 1, 2026-10-27): the driver's SOS
/// alerts Movera with `POST /driver/trips/{tripId}/sos` while the phone opens
/// 112. The phone's GPS goes once; one Idempotency-Key per press, kept for
/// every retry, so Movera gets one SOS however often the network drops it.
class DriverSos {
  DriverSos({
    required ApiClient api,
    Future<void> Function(Duration)? sleep,
    DateTime Function()? now,
    PendingSosStore? pending,
  }) : _api = api,
       _sleep = sleep ?? Future<void>.delayed,
       _now = now ?? DateTime.now,
       _pending = pending ?? const PendingSosStore();

  final ApiClient _api;
  final PendingSosStore _pending;

  /// Audit 2026-11-20 item 1: the waits of the background retries of an
  /// SOS that is still not confirmed (the last one repeats, no end).
  static const backgroundDelays = [
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 20),
    Duration(seconds: 40),
    Duration(seconds: 60),
  ];

  /// The wait after the server refused the kept SOS because the trip is no
  /// longer live (409): it is kept and tried again at this pace.
  static const refusedDelay = Duration(minutes: 5);

  /// A kept SOS older than this (from its `at`) is not sent any more: a
  /// trip-less or refused SOS must never attach to a later trip. It is
  /// logged and dropped.
  static const maxAge = Duration(minutes: 30);

  /// Set by the app root: a kept SOS was given up on (too old, refused,
  /// another driver, sign-out) without reaching Movera; the driver is told.
  static void Function()? onExpired;

  /// Bumped by [signedOut]: what began before is never saved or posted.
  static int _generation = 0;

  /// The SOS whose POST is on its way, and whether sign-out dropped it.
  static String? _inFlightKey;
  static bool _inFlightDropped = false;

  /// One background retry loop per app run.
  static Future<void>? _retrying;

  /// The phone storage writes of the SOS, in order; the send never waits
  /// for them (the POST goes out at once).
  static Future<void> _writes = Future<void>.value();

  static void _store(Future<void> Function() write) {
    _writes = _writes.then((_) => write()).catchError((Object _) {});
  }

  @visibleForTesting
  static Future<void> get writesDone => _writes;

  @visibleForTesting
  static Future<void> resetForTesting() async {
    await _writes;
    await _retrying?.catchError((Object _) {});
    _retrying = null;
    _inFlightKey = null;
    _inFlightDropped = false;
  }

  final Future<void> Function(Duration) _sleep;
  final DateTime Function() _now;

  static const profilePath = '/api/v1/driver/profile';

  /// Waits between tries when the SOS did not get through.
  static const retryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  static String _key() => 'sos-${ApiClient.randomKey()}';

  /// The SOS body's position from a contract `GeoFix`; null without one.
  static Map<String, Object?>? positionOf(LiveFix? fix) {
    final lat = fix?['lat'];
    final lng = fix?['lng'];
    if (lat is! num || lng is! num) return null;
    final accuracy = fix?['accuracy'];
    final at = fix?['measuredAt'];
    return {
      'lat': lat,
      'lng': lng,
      if (accuracy is num && accuracy >= 0) 'accuracyM': accuracy,
      'at': at is String ? at : DateTime.now().toUtc().toIso8601String(),
    };
  }

  /// Sends the SOS for [tripId] (or the trip the server holds for this
  /// driver when null) with [fix], the phone's last GPS.
  Future<DriverSosOutcome> send({String? tripId, LiveFix? fix}) async =>
      (await sendWithReceipt(tripId: tripId, fix: fix)).outcome;

  /// [send], with the receipt's `contactsSms` (v0.18.101 §92).
  Future<DriverSosResult> sendWithReceipt({
    String? tripId,
    LiveFix? fix,
  }) async {
    const noTrip = DriverSosResult(DriverSosOutcome.noTrip);
    const failed = DriverSosResult(DriverSosOutcome.failed);
    final key = _key();
    final body = <String, Object?>{
      'at': _now().toUtc().toIso8601String(),
      if (positionOf(fix) case final position?) 'position': position,
    };
    var id = tripId;
    // Kept before the first try: an app killed or a network lost now
    // still sends it later (audit 2026-11-20 item 1). Tied to the driver
    // signed in at press time (read in the queued write, so the POST
    // never waits for it).
    String? driver;
    final generation = _generation;
    Future<void> keep(String? trip) async {
      // Signed out since the press: never saved again.
      if (generation != _generation) return;
      driver ??= await _pending.owner();
      if (generation != _generation) return;
      await _pending.save(
        PendingSos(key: key, tripId: trip, body: body, driverId: driver),
      );
    }

    _store(() => keep(id));
    for (var attempt = 0; ; attempt++) {
      try {
        if (id == null) {
          try {
            id = await _activeTripId();
          } on ApiError catch (error) {
            // Only a 404 means no trip; any other profile trouble (403,
            // 401, 5xx, network) keeps the SOS and tries again.
            if (error.statusCode == 404) {
              _store(() => _pending.clear(key));
              return noTrip;
            }
            if (attempt >= retryDelays.length || !_retryable(error)) {
              DriverLog.warn('sos trip unknown: ${error.code}', name: 'safety');
              _retryLater();
              return failed;
            }
            await _sleep(retryDelays[attempt]);
            continue;
          }
          if (id == null) {
            _store(() => _pending.clear(key));
            return noTrip;
          }
          // The trip it is for, kept: a later retry still finds it.
          final trip = id;
          _store(() => keep(trip));
        }
        // Signed out since the press: an SOS of before is never posted.
        if (generation != _generation) return failed;
        _inFlightKey = key;
        final Map<String, dynamic> receipt;
        try {
          receipt = await _api.post(
            '/api/v1/driver/trips/${Uri.encodeComponent(id)}/sos',
            body: body,
            idempotencyKey: key,
          );
        } finally {
          if (_inFlightKey == key) _inFlightKey = null;
          _inFlightDropped = false;
        }
        _store(() => _pending.clear(key));
        return DriverSosResult(
          DriverSosOutcome.sent,
          contactsSms: SosContactsSms.fromJson(receipt['contactsSms']),
        );
      } on ApiError catch (error) {
        if (error.statusCode == 404) {
          _store(() => _pending.clear(key));
          return noTrip;
        }
        if (error.statusCode == 409) {
          // The trip is no longer live (it ended before the SOS got
          // through): never dropped; kept, shown "not sent", tried again.
          // Today's server takes an SOS only during a live trip; it waits
          // for a server that takes it by press time (`at`).
          DriverLog.warn('sos refused: trip not live, kept', name: 'safety');
          _retryLater();
          return failed;
        }
        if (!_keepTrying(error)) {
          _store(() => _pending.clear(key));
          DriverLog.warn('sos not sent: ${error.code}', name: 'safety');
          return failed;
        }
        if (attempt >= retryDelays.length) {
          DriverLog.warn('sos not sent yet: ${error.code}', name: 'safety');
          _retryLater();
          return failed;
        }
      } catch (error) {
        if (attempt >= retryDelays.length) {
          DriverLog.warn(
            'sos not sent yet: ${error.runtimeType}',
            name: 'safety',
          );
          _retryLater();
          return failed;
        }
      }
      await _sleep(retryDelays[attempt]);
    }
  }

  void _retryLater() => unawaited(
    retryPending().catchError((Object error) {
      DriverLog.warn('sos retry stopped: ${error.runtimeType}', name: 'safety');
    }),
  );

  /// Sends the kept SOS again, with growing waits, until Movera confirms it
  /// (a 409 trip not live keeps it: never dropped). Called after a failed press and on app
  /// start; a second call while one runs joins it.
  Future<void> retryPending() =>
      _retrying ??= _retryLoop().whenComplete(() => _retrying = null);

  Future<void> _retryLoop() async {
    final generation = _generation;
    for (var attempt = 0; ; attempt++) {
      await _writes;
      // Signed out meanwhile: the SOS of before is gone, the loop stops.
      if (generation != _generation) return;
      final sos = await _pending.read();
      if (sos == null) return;
      final at = DateTime.tryParse('${sos.body['at']}');
      if (at == null || _now().difference(at) > maxAge) {
        await _giveUp(sos, 'kept sos too old, dropped');
        return;
      }
      // Whose phone it is now: an SOS of another driver (a sign-out and a
      // new sign-in) is never sent, also not to his trip.
      final me = await _pending.owner();
      if (sos.driverId != null && me != null && sos.driverId != me) {
        await _giveUp(sos, 'kept sos of another driver, dropped');
        return;
      }
      var id = sos.tripId;
      if (id == null) {
        // Only the driver who pressed it may look up his own trip; an SOS
        // of unknown driver waits for its age instead.
        if (sos.driverId == null || me != sos.driverId) {
          await _sleep(refusedDelay);
          continue;
        }
        try {
          id = _idOf((await _api.get(profilePath))['activeTripId']);
        } catch (_) {
          // A profile read that fails (network, 401, 403, 5xx) never drops
          // the SOS: tried again after the wait.
          id = null;
        }
        if (id == null) {
          await _sleep(refusedDelay);
          continue;
        }
      }
      if (generation != _generation) return;
      try {
        _inFlightKey = sos.key;
        try {
          await _api.post(
            '/api/v1/driver/trips/${Uri.encodeComponent(id)}/sos',
            body: sos.body,
            idempotencyKey: sos.key,
          );
        } catch (_) {
          // Dropped by a sign-out while it was on its way, and it did not
          // get through: now the driver is told.
          if (_inFlightDropped) onExpired?.call();
          if (generation != _generation) return;
          rethrow;
        } finally {
          _inFlightKey = null;
          _inFlightDropped = false;
        }
        await _pending.clear(sos.key);
        DriverLog.info('pending sos sent', name: 'safety');
        return;
      } on ApiError catch (error) {
        if (error.statusCode == 409) {
          // Trip not live: kept, tried again slowly until [maxAge].
          await _sleep(refusedDelay);
          continue;
        }
        if (error.statusCode == 404 || !_keepTrying(error)) {
          await _giveUp(sos, 'kept sos refused: ${error.code}');
          return;
        }
      } catch (_) {
        // Network or storage trouble: try again after the wait.
      }
      final last = backgroundDelays.length - 1;
      await _sleep(backgroundDelays[attempt < last ? attempt : last]);
    }
  }

  /// Owner 2026-11-20 "Show 'SOS not sent'": every kept SOS given up on
  /// is told to the driver (existing text safetySosNotSent).
  Future<void> _giveUp(PendingSos sos, String why) async {
    DriverLog.warn(why, name: 'safety');
    await _pending.clear(sos.key);
    onExpired?.call();
  }

  /// Sign-out (and before another driver signs in): a kept SOS is told to
  /// the driver as not sent and dropped from this phone.
  static Future<void> signedOut({PendingSosStore? store}) {
    _generation++;
    final pending = store ?? const PendingSosStore();
    // In the write queue: a save of a press still running lands first and
    // is then dropped too; nothing saves it again after.
    final done = Completer<void>();
    _store(() async {
      try {
        final sos = await pending.read();
        if (sos == null) return;
        DriverLog.warn('kept sos dropped at sign-out', name: 'safety');
        await pending.clear(sos.key);
        // On its way now: told only if it then fails (a success is not
        // "not sent").
        if (sos.key == _inFlightKey) {
          _inFlightDropped = true;
        } else {
          onExpired?.call();
        }
      } finally {
        done.complete();
      }
    });
    return done.future;
  }

  static String? _idOf(Object? id) =>
      id is String && id.trim().isNotEmpty ? id : null;

  /// Not given up on: a network or server trouble, or a sign-in to renew.
  static bool _keepTrying(ApiError error) =>
      _retryable(error) || error.statusCode == 401 || error.statusCode == 408;

  Future<String?> _activeTripId() async {
    final profile = await _api.get(profilePath);
    final id = profile['activeTripId'];
    return id is String && id.trim().isNotEmpty ? id : null;
  }

  static bool _retryable(ApiError error) =>
      error.code == ApiError.network ||
      error.code == ApiError.timeout ||
      error.code == 'rate_limited' ||
      error.code == 'unavailable' ||
      (error.statusCode != null && error.statusCode! >= 500);

  /// The SOS from the app: the live build sends it with the last fix the
  /// app reported (or a fresh one); the demo, which has no server, answers
  /// sent so it shows what drivers see.
  static Future<DriverSosOutcome> fromApp() async =>
      (await fromAppWithReceipt()).outcome;

  /// [fromApp] with the receipt's `contactsSms`; the demo has none (so
  /// "SOS sent" alone, as before).
  static Future<DriverSosResult> fromAppWithReceipt() async {
    final live = LiveDriverServices.instance;
    if (live == null) return const DriverSosResult(DriverSosOutcome.sent);
    final fix =
        live.reporter.lastFix ??
        await live.reporter.freshFix().timeout(
          const Duration(seconds: 3),
          onTimeout: () => null,
        );
    return DriverSos(api: live.api).sendWithReceipt(fix: fix);
  }
}

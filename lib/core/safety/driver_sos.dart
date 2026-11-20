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

  /// Set by the app root: a kept SOS passed [maxAge] without reaching
  /// Movera; the driver is told so.
  static void Function()? onExpired;

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
    // still sends it later (audit 2026-11-20 item 1).
    _store(() => _pending.save(PendingSos(key: key, tripId: id, body: body)));
    for (var attempt = 0; ; attempt++) {
      try {
        if (id == null) {
          id = await _activeTripId();
          if (id == null) {
            _store(() => _pending.clear(key));
            return noTrip;
          }
          // The trip it is for, kept: a later retry still finds it.
          _store(
            () => _pending.save(PendingSos(key: key, tripId: id, body: body)),
          );
        }
        final receipt = await _api.post(
          '/api/v1/driver/trips/${Uri.encodeComponent(id)}/sos',
          body: body,
          idempotencyKey: key,
        );
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
    for (var attempt = 0; ; attempt++) {
      await _writes;
      final sos = await _pending.read();
      if (sos == null) return;
      final at = DateTime.tryParse('${sos.body['at']}');
      if (at == null || _now().difference(at) > maxAge) {
        DriverLog.warn('kept sos too old, dropped', name: 'safety');
        await _pending.clear(sos.key);
        // Owner 2026-11-20 "Show 'SOS not sent'": the driver is told it
        // never reached Movera (existing text safetySosNotSent).
        onExpired?.call();
        return;
      }
      try {
        final id = sos.tripId ?? await _activeTripId();
        if (id == null) {
          // No trip known to send it to: kept, asked again later.
          await _sleep(refusedDelay);
          continue;
        }
        await _api.post(
          '/api/v1/driver/trips/${Uri.encodeComponent(id)}/sos',
          body: sos.body,
          idempotencyKey: sos.key,
        );
        await _pending.clear(sos.key);
        DriverLog.info('pending sos sent', name: 'safety');
        return;
      } on ApiError catch (error) {
        if (error.statusCode == 409) {
          // Trip not live: kept (never dropped), tried again slowly.
          await _sleep(refusedDelay);
          continue;
        }
        if (error.statusCode == 404 || !_keepTrying(error)) {
          await _pending.clear(sos.key);
          return;
        }
      } catch (_) {
        // Network or storage trouble: try again after the wait.
      }
      final last = backgroundDelays.length - 1;
      await _sleep(backgroundDelays[attempt < last ? attempt : last]);
    }
  }

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

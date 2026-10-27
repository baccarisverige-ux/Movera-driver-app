import 'dart:async';

import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/live/live_trip_commands.dart' show LiveFix;
import 'package:movera/core/logging/driver_log.dart';

/// What the SOS to Movera came to.
enum DriverSosOutcome {
  /// Movera has it: the app shows "SOS sent" (and nothing later).
  sent,

  /// No live trip: the server takes an SOS only during one.
  noTrip,

  /// Every try failed: the driver is told to rely on the 112 call.
  failed,
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
  }) : _api = api,
       _sleep = sleep ?? Future<void>.delayed,
       _now = now ?? DateTime.now;

  final ApiClient _api;
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
  Future<DriverSosOutcome> send({String? tripId, LiveFix? fix}) async {
    final key = _key();
    final body = <String, Object?>{
      'at': _now().toUtc().toIso8601String(),
      if (positionOf(fix) case final position?) 'position': position,
    };
    var id = tripId;
    for (var attempt = 0; ; attempt++) {
      try {
        id ??= await _activeTripId();
        if (id == null) return DriverSosOutcome.noTrip;
        await _api.post(
          '/api/v1/driver/trips/${Uri.encodeComponent(id)}/sos',
          body: body,
          idempotencyKey: key,
        );
        return DriverSosOutcome.sent;
      } on ApiError catch (error) {
        if (error.statusCode == 409 || error.statusCode == 404) {
          return DriverSosOutcome.noTrip;
        }
        if (!_retryable(error) || attempt >= retryDelays.length) {
          DriverLog.warn('sos not sent: ${error.code}', name: 'safety');
          return DriverSosOutcome.failed;
        }
      } catch (error) {
        if (attempt >= retryDelays.length) {
          DriverLog.warn('sos not sent: ${error.runtimeType}', name: 'safety');
          return DriverSosOutcome.failed;
        }
      }
      await _sleep(retryDelays[attempt]);
    }
  }

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
  static Future<DriverSosOutcome> fromApp() async {
    final live = LiveDriverServices.instance;
    if (live == null) return DriverSosOutcome.sent;
    final fix =
        live.reporter.lastFix ??
        await live.reporter.freshFix().timeout(
          const Duration(seconds: 3),
          onTimeout: () => null,
        );
    return DriverSos(api: live.api).send(fix: fix);
  }
}

import 'dart:async';

import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/live/live_trip_commands.dart' show LiveFix;
import 'package:movera/core/safety/driver_sos.dart';
import 'package:movera/core/safety/ride_check.dart';
import 'package:movera/core/safety/safety_alert_repository.dart';

/// The contract name of a trigger (v0.12.0 §22).
String rideCheckTriggerWire(RideCheckTrigger trigger) => switch (trigger) {
  RideCheckTrigger.droppedFar => 'dropped_far',
  RideCheckTrigger.longStop => 'long_stop',
  RideCheckTrigger.offRoute => 'off_route',
  RideCheckTrigger.possibleCrash => 'possible_crash',
};

/// Contract v0.12.0 §22 (owner safety part 2, 2026-10-28): the driver's Ride
/// check goes to `POST /driver/trips/{tripId}/ride-check`, once when the card
/// shows (no answer: Movera's 2-minute clock starts) and once with the
/// answer. "I'm OK" is only saved; a red row or Call 112 is "I need help",
/// the safety team's red alarm. One Idempotency-Key per report, kept for
/// every retry. Afterwards the card says only "Sent".
class LiveSafetyAlertRepository implements SafetyAlertRepository {
  LiveSafetyAlertRepository({
    required ApiClient api,
    LiveFix? Function()? fix,
    Future<void> Function(Duration)? sleep,
    DateTime Function()? now,
  }) : _api = api,
       _fix = fix ?? (() => null),
       _sleep = sleep ?? Future<void>.delayed,
       _now = now ?? DateTime.now;

  final ApiClient _api;
  final LiveFix? Function() _fix;
  final Future<void> Function(Duration) _sleep;
  final DateTime Function() _now;
  final Map<String, SafetyAlert> _alerts = <String, SafetyAlert>{};

  static const retryDelays = DriverSos.retryDelays;

  @override
  Future<void> shown({
    required String checkId,
    required String tripId,
    required RideCheckTrigger trigger,
    required DateTime at,
  }) => _report(tripId: tripId, checkId: checkId, trigger: trigger, at: at);

  @override
  Future<void> answeredOk({
    required String checkId,
    required String tripId,
    required RideCheckTrigger trigger,
  }) => _report(
    tripId: tripId,
    checkId: checkId,
    trigger: trigger,
    at: _now(),
    answer: 'ok',
  );

  @override
  Future<SafetyAlert> send({
    required SafetyAlertTrip trip,
    required RideCheckTrigger trigger,
    required String reason,
    required String topic,
    required List<RideCheckAnswer> answers,
    String? checkId,
  }) async {
    final at = _now();
    final id =
        checkId ?? 'ride-check-${trip.tripId}-${at.microsecondsSinceEpoch}';
    final receipt = await _report(
      tripId: trip.tripId,
      checkId: id,
      trigger: trigger,
      at: at,
      answer: 'need_help',
    );
    if (receipt == null) {
      throw StateError('The trip no longer takes Ride checks');
    }
    final incident = receipt['incidentId'];
    final alert = SafetyAlert(
      id: incident is String && incident.isNotEmpty ? incident : id,
      trip: trip,
      trigger: trigger,
      reason: reason,
      topic: topic,
      answers: List<RideCheckAnswer>.unmodifiable(answers),
      sentAt: at,
      updatedAt: at,
    );
    _alerts[alert.id] = alert;
    return alert;
  }

  /// Movera keeps "I need help" whatever follows; the follow-up answers stay
  /// on the phone's trip record.
  @override
  Future<SafetyAlert> update(String alertId, RideCheckAnswer answer) async {
    final current = _alerts[alertId];
    if (current == null) throw StateError('Unknown safety alert $alertId');
    return _alerts[alertId] = current.withAnswer(answer);
  }

  /// The receipt; null when the trip no longer takes checks (409).
  Future<Map<String, dynamic>?> _report({
    required String tripId,
    required String checkId,
    required RideCheckTrigger trigger,
    required DateTime at,
    String? answer,
  }) async {
    final key = 'ride-check-${ApiClient.randomKey()}';
    final position = DriverSos.positionOf(_fix());
    final body = <String, Object?>{
      'checkId': checkId,
      'trigger': rideCheckTriggerWire(trigger),
      'at': at.toUtc().toIso8601String(),
      if (answer != null) 'answer': answer,
      if (position != null) 'position': position,
    };
    final path =
        '/api/v1/driver/trips/${Uri.encodeComponent(tripId)}/ride-check';
    for (var attempt = 0; ; attempt++) {
      try {
        return await _api.post(path, body: body, idempotencyKey: key);
      } on ApiError catch (error) {
        if (error.statusCode == 409 || error.statusCode == 404) return null;
        if (!_retryable(error) || attempt >= retryDelays.length) rethrow;
      } catch (_) {
        if (attempt >= retryDelays.length) rethrow;
      }
      await _sleep(retryDelays[attempt]);
    }
  }

  static bool _retryable(ApiError error) =>
      error.code == ApiError.network ||
      error.code == ApiError.timeout ||
      error.code == 'rate_limited' ||
      error.code == 'unavailable' ||
      (error.statusCode != null && error.statusCode! >= 500);
}

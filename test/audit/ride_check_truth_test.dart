import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/safety/demo_safety_alert_repository.dart';
import 'package:movera/core/safety/ride_check.dart';
import 'package:movera/core/safety/ride_check_controller.dart';
import 'package:movera/core/safety/ride_check_detector.dart';
import 'package:movera/core/safety/ride_check_log.dart';
import 'package:movera/core/safety/ride_check_recorder.dart';
import 'package:movera/core/safety/ride_check_services.dart';
import 'package:movera/core/safety/safety_alert_repository.dart';

// D3.6 Ride check: what is saved and sent must match what happened.

const _trip = SafetyAlertTrip(
  tripId: 'trip-1',
  riderName: 'Angelica',
  riderRating: 4.9,
  pickup: 'Odlarvägen 22',
  dropoff: 'T-Centralen, Stockholm',
  fare: '126 kr',
  category: 'Comfort',
  driverName: 'Movera Driver',
  vehicle: 'Volvo XC60',
  plate: 'ABC 123',
);

/// A recorder whose start can be held open, like the native one awaiting
/// the documents folder and the plugin.
class _Recorder implements RideCheckRecorder {
  Completer<void>? holdStart;
  bool recording = false;
  int stops = 0, cancels = 0;
  @override
  bool get supported => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> start(String recordingId) async {
    await holdStart?.future;
    recording = true;
  }

  @override
  Future<String?> stop() async {
    stops++;
    final was = recording;
    recording = false;
    return was ? '/phone/ride_check_audio/$stops.m4a' : null;
  }

  @override
  Future<void> cancel() async {
    cancels++;
    recording = false;
  }
}

class _Kit {
  _Kit({bool dialOpens = true}) {
    controller = RideCheckController(
      services: RideCheckServices(
        alerts: alerts,
        log: log,
        now: () => now,
        recorder: () => recorder,
        launch: (_) async => dialOpens,
      ),
      tripId: 'trip-1',
      tripDetails: () => _trip,
    );
  }
  var now = DateTime(2026, 10, 15, 14, 30);
  final alerts = DemoSafetyAlertRepository();
  final log = MemoryRideCheckLog();
  final recorder = _Recorder();
  late final RideCheckController controller;

  RideCheckEvent event([RideCheckTrigger t = RideCheckTrigger.longStop]) =>
      RideCheckDetector().demo(t, now, destination: 'T-Centralen');

  void dispose() {
    controller.dispose();
    alerts.dispose();
  }
}

void main() {
  test('driver-u43: a dialer that does not open is not saved or sent as '
      '"Called 112"', () async {
    final kit = _Kit(dialOpens: false);
    addTearDown(kit.dispose);
    kit.controller.open(kit.event(), instant: true);
    await kit.controller.callEmergency();
    await kit.controller.settleAlerts();
    expect(kit.controller.dialFailed, isTrue);
    final answers = [for (final a in kit.log.rows.single.answers) a.answer];
    expect(answers, isNot(contains('Called 112')));
    expect(answers.last, 'Did not open');
    final alert = kit.alerts.alerts.single;
    expect(alert.topic, isNot('Called 112'));
    expect(alert.answers.last.answer, 'Did not open',
        reason: 'Movera must learn that the dialer did not open');
  });

  test('driver-u43: an opened dialer is recorded as opened, not as a call',
      () async {
    final kit = _Kit();
    addTearDown(kit.dispose);
    kit.controller.open(kit.event(), instant: true);
    await kit.controller.callEmergency();
    await kit.controller.settleAlerts();
    final answers = kit.log.rows.single.answers;
    expect(answers.first.answer, 'Call 112');
    expect(answers.last.question, '112 dialer');
    expect(answers.last.answer, 'Opened');
    expect(kit.alerts.alerts.single.topic, 'Call 112');
    expect(kit.alerts.alerts.single.answers.last.answer, 'Opened');
  });
}

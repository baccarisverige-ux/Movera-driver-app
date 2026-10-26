import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/safety/safety_audio_option.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/core/safety/demo_safety_alert_repository.dart';
import 'package:movera/core/safety/ride_check.dart';
import 'package:movera/core/safety/ride_check_controller.dart';
import 'package:movera/core/safety/ride_check_detector.dart';
import 'package:movera/core/safety/ride_check_log.dart';
import 'package:movera/core/safety/ride_check_recorder.dart';
import 'package:movera/core/safety/ride_check_services.dart';
import 'package:movera/core/safety/safety_alert_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

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
    expect(
      alert.answers.last.answer,
      'Did not open',
      reason: 'Movera must learn that the dialer did not open',
    );
  });

  test(
    'driver-u43: an opened dialer is recorded as opened, not as a call',
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
    },
  );

  test('driver-28: a recording still starting when the card closes does '
      'not keep the microphone on', () async {
    final kit = _Kit();
    addTearDown(kit.dispose);
    kit.recorder.holdStart = Completer<void>();
    kit.controller.open(kit.event(), instant: true);
    final starting = kit.controller.toggleRecording();
    await Future<void>.delayed(Duration.zero);
    expect(kit.controller.audio, RideCheckAudio.starting);
    await kit.controller.imOk();
    kit.recorder.holdStart!.complete();
    await starting;
    expect(
      kit.recorder.recording,
      isFalse,
      reason: 'no recording may run behind a closed card',
    );
    expect(kit.controller.audio, isNot(RideCheckAudio.recording));
  });

  test('driver-28: a later check and dispose still stop a recorder that '
      'is running', () async {
    final kit = _Kit();
    kit.recorder.holdStart = Completer<void>();
    kit.controller.open(kit.event(), instant: true);
    final starting = kit.controller.toggleRecording();
    await Future<void>.delayed(Duration.zero);
    await kit.controller.imOk();
    kit.recorder.holdStart!.complete();
    await starting;
    kit.controller.open(kit.event(RideCheckTrigger.offRoute), instant: true);
    kit.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(kit.recorder.recording, isFalse);
  });

  test('driver-u41: leaving the app stops the recording; the saved length '
      'is what was captured, not the time away', () async {
    final kit = _Kit();
    addTearDown(kit.dispose);
    final done = kit.controller.open(kit.event(), instant: true);
    await kit.controller.toggleRecording();
    kit.now = kit.now.add(const Duration(seconds: 12));
    await kit.controller.appBackgrounded();
    expect(
      kit.recorder.recording,
      isFalse,
      reason: 'the phone does not capture in the background',
    );
    expect(kit.controller.audio, RideCheckAudio.saved);
    expect(kit.controller.audioStoppedInBackground, isTrue);
    kit.now = kit.now.add(const Duration(minutes: 3));
    expect(kit.controller.audioSeconds, 12);
    await kit.controller.imOk();
    expect((await done).audioSeconds, 12);
  });

  testWidgets('driver-u41: the trip screen stops Ride-check audio when the '
      'app is hidden and says so', (tester) async {
    SafetyAudioOption.debugEnabled = true; // owner decision 10: offered again
    addTearDown(() => SafetyAudioOption.debugEnabled = null);
    SharedPreferences.setMockInitialValues({});
    CompletionJournal.resetForTesting();
    WaybillStore.reset();
    addTearDown(WaybillStore.reset);
    final maps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var now = DateTime.now();
    final recorder = _Recorder();
    final alerts = DemoSafetyAlertRepository();
    addTearDown(alerts.dispose);
    final services = RideCheckServices(
      alerts: alerts,
      log: MemoryRideCheckLog(),
      now: () => now,
      recorder: () => recorder,
      launch: (_) async => true,
    );
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: AcceptRide(
            tripId: 'audio-trip',
            initialStage: ActiveRideStage.onTrip,
            locationRepository: _Gps(),
            rideCheck: services,
          ),
        ),
      ),
    );
    await _frames(tester);
    await tester.longPress(find.byKey(const ValueKey('island-morph-shell')));
    await _frames(tester);
    final demo = find.byKey(const ValueKey('ride-check-demo-longStop'));
    await tester.ensureVisible(demo);
    await tester.tap(demo);
    await _frames(tester, 30);
    await tester.tap(find.byKey(const ValueKey('ride-check-record-audio')));
    await _frames(tester, 4);
    expect(recorder.recording, isTrue);
    now = now.add(const Duration(seconds: 9));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await _frames(tester, 2);
    expect(recorder.recording, isFalse);
    now = now.add(const Duration(minutes: 3));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _frames(tester, 4);
    expect(
      find.text(
        'Audio saved · 0:09 · stopped when Movera left the screen',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester);
  });
}

class _Gps implements DriverLocationRepository {
  final _fixes = StreamController<DriverLocation>.broadcast();
  @override
  Future<DriverLocation> getCurrentPosition() async => DriverLocation(
    point: const GeoPoint(59.3416, 18.0649),
    measuredAt: DateTime.now(),
    accuracyMeters: 5,
  );
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      _fixes.stream;
}

Future<void> _frames(WidgetTester tester, [int count = 12]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

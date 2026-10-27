// Owner decision 10 (2026-10-22): "Hide for the moment the audio recording
// option, only hide the option". One switch, SafetyAudioOption.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/safety/demo_safety_alert_repository.dart';
import 'package:movera/core/safety/ride_check.dart';
import 'package:movera/core/safety/ride_check_controller.dart';
import 'package:movera/core/safety/ride_check_detector.dart';
import 'package:movera/core/safety/ride_check_log.dart';
import 'package:movera/core/safety/ride_check_recorder.dart';
import 'package:movera/core/safety/ride_check_services.dart';
import 'package:movera/core/safety/safety_alert_repository.dart';
import 'package:movera/core/safety/safety_audio_option.dart';
import 'package:movera/presentation/driver/accept%20ride/ride_check_card.dart';
import 'package:movera/presentation/driver/safety%20toolkits/safety_toolkits.dart';

class _Recorder implements RideCheckRecorder {
  @override
  bool get supported => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> start(String recordingId) async {}
  @override
  Future<String?> stop() async => '/phone/ride_check_audio/1.m4a';
  @override
  Future<void> cancel() async {}
}

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

final _record = find.byKey(const ValueKey('ride-check-record-audio'));

Future<RideCheckController> _rideCheck(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final c = RideCheckController(
    services: RideCheckServices(
      alerts: DemoSafetyAlertRepository(),
      log: MemoryRideCheckLog(),
      recorder: _Recorder.new,
      launch: (_) async => true,
    ),
    tripId: 'trip-1',
    tripDetails: () => _trip,
  );
  await tester.pumpWidget(
    MaterialApp(
      // Reduced motion, as the other Ride check tests: the card's pulse
      // never settles otherwise.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Scaffold(
        body: ListenableBuilder(
          listenable: c,
          builder: (_, _) => c.active
              ? RideCheckLayer(controller: c, top: 10, maxHeight: 820)
              : const SizedBox.shrink(),
        ),
      ),
    ),
  );
  unawaited(
    c.open(
      RideCheckDetector().demo(
        RideCheckTrigger.longStop,
        DateTime.now(),
        destination: 'T-Centralen, Stockholm',
      ),
      instant: true,
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

Future<void> _end(WidgetTester tester, RideCheckController c) async {
  await tester.pumpWidget(const SizedBox.shrink());
  c.dispose();
}

Future<void> _toolkit(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: SafetyToolKits())),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() {
    SafetyAudioOption.debugEnabled = null;
    DriverAppTexts.language = 'en';
  });

  test('the switch is off: the option is hidden by default', () {
    expect(safetyAudioRecordingEnabled, isFalse);
    expect(SafetyAudioOption.enabled, isFalse);
  });

  testWidgets('Ride check hides Record audio; a running recording keeps Stop', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final c = await _rideCheck(tester);
    expect(_record, findsNothing);
    expect(
      find.textContaining('Record audio', findRichText: true),
      findsNothing,
    );
    expect(find.bySemanticsLabel(RegExp('Record audio')), findsNothing);
    // No gap: the 112 / I'm OK buttons sit 24 px above the prompt.
    final buttons = tester.getBottomLeft(
      find.byKey(const ValueKey('ride-check-ok')),
    );
    final prompt = tester.getTopLeft(find.text(tr.orTellUsWhatSHappening));
    expect(prompt.dy - buttons.dy, lessThan(30));

    // A recording already under way (started before the switch) stays
    // stoppable.
    unawaited(c.toggleRecording());
    await tester.pump();
    expect(c.audio, RideCheckAudio.recording);
    expect(_record, findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);
    await tester.tap(_record);
    await tester.pump();
    expect(c.audio, RideCheckAudio.saved);
    expect(_record, findsNothing);
    expect(tester.takeException(), isNull);
    await _end(tester, c);
    semantics.dispose();
  });

  testWidgets('the Safety toolkit hides Record audio, no gap', (tester) async {
    final semantics = tester.ensureSemantics();
    await _toolkit(tester);
    expect(find.text('Record audio'), findsNothing);
    expect(find.byIcon(Icons.mic_outlined), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Record audio')), findsNothing);
    // Owner 2026-10-27: no Contact 112 (SOS opens 112).
    final sos = tester.getRect(find.byKey(const ValueKey('safety-sos')));
    final share = tester.getRect(
      find
          .ancestor(of: find.text('Share trip'), matching: find.byType(InkWell))
          .first,
    );
    expect(find.text('Contact 112'), findsNothing);
    expect(share.left, moreOrLessEquals(sos.left, epsilon: 1));
    // Design option B: Share trip and Safety preferences share the row
    // in two equal tiles, edge to edge under the SOS card.
    final prefs = tester.getRect(
      find
          .ancestor(
            of: find.text('Safety preferences'),
            matching: find.byType(InkWell),
          )
          .first,
    );
    expect(prefs.right, moreOrLessEquals(sos.right, epsilon: 1));
    expect(share.width, moreOrLessEquals(prefs.width, epsilon: 1));
    semantics.dispose();
  });

  test('the Safety toolkit subtitle reads without "record audio"', () {
    const hidden = {
      'en': 'Share trip, get help',
      'fr': 'Partager la course, obtenir de l’aide',
      'sv': 'Dela resan, få hjälp',
    };
    for (final MapEntry(key: code, value: text) in hidden.entries) {
      DriverAppTexts.language = code;
      expect(SafetyAudioOption.toolkitSubtitle, text, reason: code);
    }
  });

  group('with the switch on, everything is as before', () {
    setUp(() => SafetyAudioOption.debugEnabled = true);

    testWidgets('Ride check offers Record audio', (tester) async {
      final c = await _rideCheck(tester);
      expect(
        find.text(
          'Record audio · saved only on this phone',
          findRichText: true,
        ),
        findsOneWidget,
      );
      await _end(tester, c);
    });

    testWidgets('the Safety toolkit offers Record audio', (tester) async {
      await _toolkit(tester);
      await tester.tap(find.text('Record audio'));
      await tester.pump();
      expect(
        find.text('Audio recording is unavailable in this demo.'),
        findsOneWidget,
      );
    });

    test('the subtitle names audio again', () {
      const shown = {
        'en': 'Share trip, record audio, get help',
        'fr': 'Partager la course, enregistrer l’audio, obtenir de l’aide',
        'sv': 'Dela resan, spela in ljud, få hjälp',
      };
      for (final MapEntry(key: code, value: text) in shown.entries) {
        DriverAppTexts.language = code;
        expect(SafetyAudioOption.toolkitSubtitle, text, reason: code);
      }
    });
  });
}

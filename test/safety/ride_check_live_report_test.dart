// Safety part 2 (contract v0.12.0 §22, owner decisions 2026-10-28): a live
// build reports the driver's Ride check to POST /driver/trips/{tripId}/
// ride-check once when the card shows (no answer) and once with the answer;
// "I'm OK" is ok, a red row or Call 112 is need_help, and the card then says
// only "Sent".
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/core/safety/driver_sos.dart';
import 'package:movera/core/safety/live_safety_alert_repository.dart';
import 'package:movera/core/safety/ride_check.dart';
import 'package:movera/core/safety/ride_check_controller.dart';
import 'package:movera/core/safety/ride_check_detector.dart';
import 'package:movera/core/safety/ride_check_log.dart';
import 'package:movera/core/safety/ride_check_services.dart';
import 'package:movera/core/safety/safety_alert_repository.dart';
import 'package:movera/presentation/driver/accept%20ride/ride_check_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late List<http.Request> sent;
  late List<int> statuses;

  ApiClient api() => ApiClient(
    client: MockClient((request) async {
      sent.add(request);
      final asked = jsonDecode(request.body) as Map<String, dynamic>;
      final status = statuses.isEmpty ? 200 : statuses.removeAt(0);
      return http.Response(
        jsonEncode(
          status == 200
              ? {
                  'checkId': asked['checkId'],
                  'tripId': 'trp_1',
                  if (asked['answer'] != null) 'answer': asked['answer'],
                  'receivedAt': '2026-10-28T10:00:01Z',
                  if (asked['answer'] == 'need_help') 'incidentId': 'inc_7',
                }
              : {
                  'code': status == 409
                      ? 'invalid_transition'
                      : status == 400
                      ? 'validation_failed'
                      : 'unavailable',
                  'message': 'x',
                  'requestId': 'r',
                  'retryable': status != 409,
                },
        ),
        status,
      );
    }),
    baseUri: Uri.parse('https://api.example.test'),
    tokens: MemoryTokenStore(),
  );
  const fix = <String, Object?>{
    'lat': 59.3331,
    'lng': 18.0651,
    'accuracy': 6.0,
    'measuredAt': '2026-10-28T10:00:00.000Z',
  };
  Map<String, dynamic> body(http.Request r) =>
      jsonDecode(r.body) as Map<String, dynamic>;
  LiveSafetyAlertRepository repo() => LiveSafetyAlertRepository(
    api: api(),
    fix: () => fix,
    sleep: (_) async {},
  );
  const trip = SafetyAlertTrip(
    tripId: 'trp_1',
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

  setUp(() {
    sent = [];
    statuses = [];
  });

  test('wire names of every trigger', () {
    expect(RideCheckTrigger.values.map(rideCheckTriggerWire), [
      'dropped_far',
      'long_stop',
      'off_route',
      'possible_crash',
    ]);
  });

  test('shown, ok and need_help reports with the GPS', () async {
    final r = repo();
    await r.shown(
      checkId: 'rc_1',
      tripId: 'trp_1',
      trigger: RideCheckTrigger.offRoute,
      at: DateTime.utc(2026, 10, 28, 10),
    );
    expect(sent.single.url.path, '/api/v1/driver/trips/trp_1/ride-check');
    expect(body(sent.single), {
      'checkId': 'rc_1',
      'trigger': 'off_route',
      'at': '2026-10-28T10:00:00.000Z',
      'position': {
        'lat': 59.3331,
        'lng': 18.0651,
        'accuracyM': 6.0,
        'at': '2026-10-28T10:00:00.000Z',
      },
    });
    await r.answeredOk(
      checkId: 'rc_1',
      tripId: 'trp_1',
      trigger: RideCheckTrigger.offRoute,
    );
    expect(body(sent.last)['answer'], 'ok');
    final alert = await r.send(
      trip: trip,
      trigger: RideCheckTrigger.offRoute,
      reason: 'Off the route',
      topic: 'I feel unsafe',
      answers: const [],
      checkId: 'rc_2',
    );
    expect(body(sent.last)['answer'], 'need_help');
    expect(alert.id, 'inc_7');
    final count = sent.length;
    final updated = await r.update(
      alert.id,
      RideCheckAnswer(question: 'q', answer: 'Yes', at: DateTime.utc(2026)),
    );
    expect(updated.updates, 1);
    expect(sent, hasLength(count), reason: 'follow-ups stay on the phone');
    expect(
      () => r.update(
        'nope',
        RideCheckAnswer(question: 'q', answer: 'Yes', at: DateTime.utc(2026)),
      ),
      throwsStateError,
    );
  });

  test('retries with one Idempotency-Key; 409 means no case', () async {
    statuses = [503, 503];
    await repo().shown(
      checkId: 'rc_3',
      tripId: 'trp_1',
      trigger: RideCheckTrigger.longStop,
      at: DateTime.utc(2026, 10, 28, 10),
    );
    expect(sent, hasLength(3));
    expect(sent.map((r) => r.headers['Idempotency-Key']).toSet(), hasLength(1));
    statuses = [409];
    await expectLater(
      repo().send(
        trip: trip,
        trigger: RideCheckTrigger.longStop,
        reason: 'Long stop',
        topic: 'Accident',
        answers: const [],
      ),
      throwsStateError,
    );
    statuses = [503, 503, 503, 503];
    await expectLater(
      repo().answeredOk(
        checkId: 'rc_4',
        tripId: 'trp_1',
        trigger: RideCheckTrigger.longStop,
      ),
      throwsA(anything),
    );
    statuses = [400];
    await expectLater(
      repo().answeredOk(
        checkId: 'rc_5',
        tripId: 'trp_1',
        trigger: RideCheckTrigger.longStop,
      ),
      throwsA(anything),
    );
  });

  Future<RideCheckController> pumpCard(
    WidgetTester tester, {
    GlobalKey? boundary,
  }) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = RideCheckController(
      services: RideCheckServices(
        alerts: repo(),
        log: MemoryRideCheckLog(),
        launch: (_) async => true,
        sos: () async => DriverSosOutcome.sent,
      ),
      tripId: 'trp_1',
      tripDetails: () => trip,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: Stack(
              children: [
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF8FA3B0), Color(0xFFDDE3E6)],
                      ),
                    ),
                  ),
                ),
                ListenableBuilder(
                  listenable: controller,
                  builder: (_, _) => controller.active
                      ? RideCheckLayer(
                          controller: controller,
                          top: 54,
                          maxHeight: 780,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    unawaited(
      controller.open(
        RideCheckDetector().demo(
          RideCheckTrigger.longStop,
          DateTime.utc(2026, 10, 28, 10),
          destination: 'T-Centralen, Stockholm',
        ),
        instant: true,
      ),
    );
    await tester.runAsync(controller.settleAlerts);
    await tester.pump();
    return controller;
  }

  testWidgets('I\'m OK: shown then ok, no case', (tester) async {
    final controller = await pumpCard(tester);
    await tester.tap(find.byKey(const ValueKey('ride-check-ok')));
    await tester.pump();
    await tester.runAsync(controller.settleAlerts);
    expect([for (final r in sent) body(r)['answer']], [null, 'ok']);
    expect(body(sent.first).containsKey('answer'), isFalse);
    expect(
      sent.map((r) => body(r)['checkId']).toSet(),
      hasLength(1),
      reason: 'both reports are one check',
    );
  });

  testWidgets('a non-red row and Done is ok for Movera', (tester) async {
    final controller = await pumpCard(tester);
    final row = find.byKey(const ValueKey('ride-check-row-traffic'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pump();
    final done = find.byKey(const ValueKey('ride-check-done'));
    await tester.ensureVisible(done);
    await tester.tap(done);
    await tester.pump();
    await tester.runAsync(controller.settleAlerts);
    expect([for (final r in sent) body(r)['answer']], [null, 'ok']);
  });

  testWidgets('I need help: shown then need_help, the card says only "Sent"', (
    tester,
  ) async {
    final shot = Platform.environment['MOVERA_SHOT'];
    if (shot != null) {
      await tester.runAsync(_loadFonts);
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() => DriverLanguage.choose('sv'));
      addTearDown(DriverLanguage.resetForTest);
    }
    final boundary = GlobalKey();
    final controller = await pumpCard(tester, boundary: boundary);
    final row = find.byKey(const ValueKey('ride-check-row-unsafe'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pump();
    await tester.runAsync(controller.settleAlerts);
    await tester.pump();
    expect([for (final r in sent) body(r)['answer']], [null, 'need_help']);
    final note = find.byKey(const ValueKey('ride-check-alert-sent'));
    expect(note, findsOneWidget);
    final text = tester.widget<Text>(
      find.descendant(of: note, matching: find.byType(Text)),
    );
    expect(text.textSpan!.toPlainText(), shot != null ? 'Skickat' : 'Sent');
    if (shot != null) {
      await tester.pump(const Duration(milliseconds: 300));
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 2);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File(shot)
          ..createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      });
    }
  });
}

/// Screenshots only: real glyphs instead of the test font.
Future<void> _loadFonts() async {
  ByteData bytes(String path) =>
      ByteData.sublistView(File(path).readAsBytesSync());
  const dejavu = '/usr/share/fonts/truetype/dejavu';
  await (FontLoader('Roboto')
        ..addFont(Future.value(bytes('$dejavu/DejaVuSans.ttf')))
        ..addFont(Future.value(bytes('$dejavu/DejaVuSans-Bold.ttf'))))
      .load();
  await (FontLoader('Urbanist')
        ..addFont(Future.value(bytes('assets/fonts/urbanist/Urbanist-500.ttf')))
        ..addFont(Future.value(bytes('assets/fonts/urbanist/Urbanist-600.ttf')))
        ..addFont(
          Future.value(bytes('assets/fonts/urbanist/Urbanist-800.ttf')),
        ))
      .load();
}

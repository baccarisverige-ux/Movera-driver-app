import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/live/live_trip_commands.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

/// Contract v0.7.1 (owner Pricing decisions 2026-10-27): the driver app
/// reports "Framme vid stoppet" and leaving each middle stop to the server
/// (no free minutes at a stop). v0.7.2: the surge notice on Home is gone
/// (test/pricing/surge_map_test.dart).
void main() {
  final origin = Uri.parse('https://api.test.movera.se');
  late List<http.Request> requests;
  late List<FutureOr<http.Response> Function(http.Request)> answers;

  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  ApiClient api() => ApiClient(
    client: MockClient((request) async {
      requests.add(request);
      if (answers.isEmpty) {
        return json(500, {
          'code': 'internal',
          'message': 'x',
          'requestId': 'r',
          'retryable': false,
        });
      }
      return answers.removeAt(0)(request);
    }),
    baseUri: origin,
    tokens: MemoryTokenStore()..save(access: 'a1', refresh: 'r1'),
  );

  setUp(() {
    requests = [];
    answers = [];
  });

  group('middle stops', () {
    Map<String, dynamic> trip(int version, [List<Object> visits = const []]) =>
        {
          'tripId': 't1',
          'status': 'in_trip',
          'version': version,
          if (visits.isNotEmpty) 'stopVisits': visits,
        };

    test('arrive and leave go to the stop with the trip version', () async {
      final trips = LiveTripCommands(api: api())..observe(trip(7));
      answers
        ..add(
          (_) => json(
            200,
            trip(8, [
              {'stopIndex': 0, 'arrivedAt': '2026-10-27T10:00:00Z'},
            ]),
          ),
        )
        ..add(
          (_) => json(
            200,
            trip(9, [
              {
                'stopIndex': 0,
                'arrivedAt': '2026-10-27T10:00:00Z',
                'leftAt': '2026-10-27T10:04:00Z',
              },
            ]),
          ),
        );
      expect((await trips.arriveAtStop('t1', 0)).ok, isTrue);
      expect((await trips.leaveStop('t1', 0)).ok, isTrue);
      expect(requests.map((r) => r.url.path), [
        '/api/v1/driver/trips/t1/stops/0/arrive',
        '/api/v1/driver/trips/t1/stops/0/leave',
      ]);
      expect(jsonDecode(requests[0].body), {'expectedVersion': 7});
      expect(jsonDecode(requests[1].body), {'expectedVersion': 8});
      expect(requests[0].headers['Idempotency-Key'], isNotEmpty);
      // Already recorded: nothing is sent again.
      expect((await trips.leaveStop('t1', 0)).ok, isTrue);
      expect(requests, hasLength(2));
    });

    test('a refusal is shown; a stop the server already has is fine', () async {
      final trips = LiveTripCommands(api: api())..observe(trip(3));
      answers
        ..add(
          (_) => json(409, {
            'code': 'invalid_transition',
            'message': 'Tap arrived at this stop first.',
            'requestId': 'r',
            'retryable': false,
            'reason': 'stop_not_arrived',
          }),
        )
        ..add(
          (_) => json(409, {
            'code': 'invalid_transition',
            'message': 'You already arrived at this stop.',
            'requestId': 'r',
            'retryable': false,
            'reason': 'stop_already_arrived',
          }),
        );
      final refused = await trips.leaveStop('t1', 1);
      expect(refused.ok, isFalse);
      expect(refused.message, isNotEmpty);
      expect((await trips.arriveAtStop('t1', 1)).ok, isTrue);
    });
  });

  testWidgets(
    'on the way to a middle stop the arrival button says Framme vid stoppet',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      DriverAppTexts.language = 'sv';
      addTearDown(DriverAppTexts.reset);
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => MaterialApp(
            home: AcceptRide(
              tripId: 'stop-label-trip',
              fare: '245 kr',
              matchedVia: 'Radar',
              stopAddresses: const ['Odenplan'],
              initialStage: ActiveRideStage.waitingForRider,
              activeRideRepository: MemoryActiveRideRepository(),
              waybillRepository: InMemoryWaybillRepository.instance,
            ),
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final slide = find.byKey(const ValueKey('active-ride-primary-action'));
      if (slide.evaluate().isEmpty) {
        tester
            .widgetList<SlidingUpPanel>(find.byType(SlidingUpPanel))
            .last
            .controller!
            .animatePanelToSnapPoint();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 820));
      }
      await tester.drag(slide, const Offset(320, 0));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final button = find.byKey(
        const ValueKey<String>('active-ride-arrived-button'),
      );
      expect(button, findsOneWidget);
      expect(
        find.descendant(of: button, matching: find.text('Framme vid stoppet')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    },
  );
}

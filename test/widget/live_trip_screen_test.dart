import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

/// A live build: the trip screen's Arrived is the server's `arrive` first.
/// A refusal is said plainly and the trip stays on its way to the pickup;
/// once the server takes it, the screen moves on.
void main() {
  late List<http.Request> commands;
  late List<http.Response Function()> arriveAnswers;
  late LiveDriverServices live;

  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    commands = [];
    arriveAnswers = [];
    final tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/events')) {
        // No live stream in this test: it keeps retrying quietly.
        return http.Response('', 503);
      }
      if (request.method == 'GET' && path == '/api/v1/trips/live-trip') {
        return json(200, {
          'tripId': 'live-trip',
          'status': 'driver_to_pickup',
          'version': 4,
        });
      }
      if (request.method == 'POST' &&
          path == '/api/v1/trips/live-trip/arrive') {
        commands.add(request);
        return arriveAnswers.removeAt(0)();
      }
      return json(404, {'code': 'not_found', 'message': 'No.'});
    });
    final api = ApiClient(
      client: client,
      baseUri: Uri.parse('https://api.test.movera.se'),
      tokens: tokens,
    );
    live = LiveDriverServices(
      client: client,
      origin: Uri.parse('https://api.test.movera.se'),
      tokens: tokens,
      api: api,
      location: _NoGps(),
    );
    LiveDriverServices.instance = live;
  });

  tearDown(() async {
    LiveDriverServices.instance = null;
    await live.dispose();
  });

  Future<void> frames(WidgetTester tester, [int count = 12]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('Arrived waits for the server; its refusal is shown and the '
      'trip stays where it was', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, __) => MaterialApp(
          home: AcceptRide(
            tripId: 'live-trip',
            locationRepository: _NoGps(),
            activeRideRepository: MemoryActiveRideRepository(),
          ),
        ),
      ),
    );
    await frames(tester);
    tester
        .widget<SlidingUpPanel>(find.byType(SlidingUpPanel))
        .controller!
        .animatePanelToSnapPoint();
    await frames(tester, 16);
    ScaffoldMessenger.of(
      tester.element(find.byType(AcceptRide)),
    ).clearSnackBars();
    await frames(tester);

    const waiting = ValueKey<String>('active-ride-panel-waitingForRider');
    final arrive = find.byKey(
      const ValueKey<String>('active-ride-arrived-button'),
    );

    arriveAnswers.add(
      () => json(409, {
        'code': 'invalid_transition',
        'reason': 'not_at_pickup',
        'message': 'You are not at the pickup yet.',
        'projection': {
          'tripId': 'live-trip',
          'status': 'driver_to_pickup',
          'version': 4,
        },
      }),
    );
    await tester.ensureVisible(arrive);
    await tester.tap(arrive);
    await frames(tester);
    expect(commands, hasLength(1));
    expect(jsonDecode(commands.single.body)['expectedVersion'], 4);
    expect(find.text(tr.liveTripNotAtPickup), findsOneWidget);
    expect(find.byKey(waiting), findsNothing);

    ScaffoldMessenger.of(
      tester.element(find.byType(AcceptRide)),
    ).clearSnackBars();
    await frames(tester);
    arriveAnswers.add(
      () =>
          json(200, {'tripId': 'live-trip', 'status': 'arrived', 'version': 5}),
    );
    await tester.ensureVisible(arrive);
    await tester.tap(arrive);
    await frames(tester);
    expect(commands, hasLength(2));
    expect(find.byKey(waiting), findsOneWidget);
    expect(live.trips.statusOf('live-trip'), 'arrived');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}

class _NoGps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() =>
      Completer<DriverLocation>().future;
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream.empty();
}

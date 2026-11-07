import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/ride%20completed/ride_completed.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

/// Finder A4 (2026-11-07): while a live trip step waits for the server
/// (Arrived, Collect cash's price, the cash Complete) the button looked
/// alive and more taps were silently ignored; after a successful complete
/// the summary waited for 2 more requests (`openNextTripAfter`: GET
/// /driver/profile, then GET /trips/{id}), up to 2×15 s on a weak network.
void main() {
  late List<String> requests;
  late MemoryDriverRealtime realtime;
  late LiveDriverServices live;
  Completer<void>? arriveGate, previewGate, completeGate, profileGate;
  var completed = false;
  Map<String, dynamic> money(int minor) => {
    'amountMinor': minor,
    'currency': 'SEK',
  };
  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
  Map<String, dynamic> trip(String status, int version) => {
    'tripId': 'live-trip',
    'status': status,
    'version': version,
    'paymentMethod': 'cash',
    'fare': money(20800),
    'driverEarnings': money(15136),
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    InMemoryWaybillRepository.instance.reset();
    requests = [];
    realtime = MemoryDriverRealtime();
    arriveGate = previewGate = completeGate = profileGate = null;
    completed = false;
    final tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
    final client = MockClient((request) async {
      final path = request.url.path;
      requests.add('${request.method} $path');
      if (path.endsWith('/events')) return http.Response('', 503);
      if (request.method == 'GET' && path == '/api/v1/trips/live-trip') {
        return json(200, trip('driver_to_pickup', 8));
      }
      if (request.method == 'POST' &&
          path == '/api/v1/trips/live-trip/arrive') {
        await arriveGate?.future;
        return json(200, trip('arrived', 9));
      }
      if (request.method == 'GET' &&
          path == '/api/v1/driver/trips/live-trip/complete-preview') {
        await previewGate?.future;
        return json(200, {
          'previewId': 'cpv_1',
          'tripId': 'live-trip',
          'total': money(20800),
          'cashDue': money(20800),
          'driverEarnings': money(15136),
          'earlyEnd': false,
        });
      }
      if (request.method == 'POST' &&
          path == '/api/v1/trips/live-trip/complete') {
        await completeGate?.future;
        completed = true;
        return json(200, {
          ...trip('completed', 10),
          'finish': {'ratingAllowed': true},
        });
      }
      if (request.method == 'GET' && path == '/api/v1/driver/profile') {
        // The next-trip look-up after the finish.
        if (completed) await profileGate?.future;
        return json(200, {
          'driverId': 'drv_1',
          'accountStatus': 'active',
          'version': 4,
        });
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
    for (final gate in [arriveGate, previewGate, completeGate, profileGate]) {
      if (gate != null && !gate.isCompleted) gate.complete();
    }
    realtime.dispose();
    LiveDriverServices.instance = null;
    await live.dispose();
  });

  Future<void> frames(WidgetTester tester, [int count = 12]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> open(WidgetTester tester, ActiveRideStage stage) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = DriverSessionController(initialOnline: true);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      DriverRuntimeScope(
        session: session,
        homeBuilder: () => const SizedBox(),
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => MaterialApp(
            home: AcceptRide(
              tripId: 'live-trip',
              initialStage: stage,
              riderName: 'Passenger',
              fare: '151,36 kr',
              riderFare: '208,00 kr',
              paidByCash: true,
              cashToCollect: '208,00 kr',
              category: 'Economy',
              matchedVia: WaybillRecord.demoRadarSource,
              pickupAddress: 'Sergels torg',
              pickupArea: '',
              pickupPosition: const LatLng(59.3326, 18.0649),
              dropoffAddress: 'Odenplan',
              dropoffPosition: const LatLng(59.3429, 18.0498),
              locationRepository: _NoGps(),
              activeRideRepository: MemoryActiveRideRepository(),
              sessionController: session,
              waybillRepository: InMemoryWaybillRepository.instance,
              realtime: realtime,
            ),
          ),
        ),
      ),
    );
    await frames(tester, 20);
    tester
        .widget<SlidingUpPanel>(find.byType(SlidingUpPanel))
        .controller!
        .animatePanelToSnapPoint();
    await frames(tester, 16);
  }

  Finder inButton(String key, Finder child) =>
      find.descendant(of: find.byKey(ValueKey<String>(key)), matching: child);

  void expectBusy(WidgetTester tester, String key, {required bool busy}) {
    final button = tester.widget<FilledButton>(
      find.byKey(ValueKey<String>(key)),
    );
    expect(button.onPressed == null, busy, reason: '$key disabled: $busy');
    expect(
      inButton(key, find.byType(CircularProgressIndicator)),
      busy ? findsOneWidget : findsNothing,
      reason: '$key spinner: $busy',
    );
  }

  Future<void> close(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('Arrived: disabled with a spinner while arrive runs', (
    tester,
  ) async {
    arriveGate = Completer<void>();
    await open(tester, ActiveRideStage.headingToPickup);
    const key = 'active-ride-arrived-button';
    expectBusy(tester, key, busy: false);
    await tester.ensureVisible(find.byKey(const ValueKey<String>(key)));
    await tester.tap(find.byKey(const ValueKey<String>(key)));
    await frames(tester, 6);
    expect(requests, contains('POST /api/v1/trips/live-trip/arrive'));
    expectBusy(tester, key, busy: true);
    arriveGate!.complete();
    await frames(tester, 20);
    expect(find.byKey(const ValueKey<String>(key)), findsNothing);
    await close(tester);
  });

  Future<void> finishCash(WidgetTester tester, {required bool busy}) async {
    previewGate = Completer<void>();
    completeGate = Completer<void>();
    profileGate = Completer<void>();
    await open(tester, ActiveRideStage.onTrip);
    const key = 'active-ride-collect-cash';
    if (busy) expectBusy(tester, key, busy: false);
    await tester.ensureVisible(find.byKey(const ValueKey<String>(key)));
    await tester.tap(find.byKey(const ValueKey<String>(key)));
    await frames(tester, 6);
    expect(
      requests,
      contains('GET /api/v1/driver/trips/live-trip/complete-preview'),
    );
    if (busy) expectBusy(tester, key, busy: true);
    previewGate!.complete();
    await frames(tester, 16);
    expect(
      find.byKey(const ValueKey<String>('cash-collect-sheet')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey<String>('cash-complete-ride')));
    await frames(tester, 16);
    expect(requests, contains('POST /api/v1/trips/live-trip/complete'));
    // The sheet closed on Complete; the button under it waits for the
    // server.
    if (busy) expectBusy(tester, key, busy: true);
    completeGate!.complete();
    await frames(tester, 40);
  }

  testWidgets('Collect cash: busy while the price and then the complete '
      'run', (tester) async {
    await finishCash(tester, busy: true);
    profileGate!.complete();
    await frames(tester, 10);
    await close(tester);
  });

  testWidgets('after complete the summary shows at once; the next-trip '
      'look-up runs behind it', (tester) async {
    await finishCash(tester, busy: false);
    // The next-trip look-up (GET /driver/profile) has not answered yet.
    expect(requests.last, 'GET /api/v1/driver/profile');
    expect(profileGate!.isCompleted, isFalse);
    expect(find.byType(DriverRideCompleted), findsOneWidget);
    profileGate!.complete();
    await frames(tester, 10);
    await close(tester);
  });
}

class _NoGps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() =>
      Completer<DriverLocation>().future;

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream<DriverLocation>.empty();
}

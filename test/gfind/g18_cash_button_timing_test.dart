// G18 (BrowserStack 2026-11-12 run 1 + run 2, plan/JOBS-2026-11-11-G.md):
// on a cash trip "Encaisser les espèces" (Collect cash) shows right after
// the start, kilometres from the drop-off. This test pins TODAY's
// behaviour on main as the proof (Rule 36) that the finding is still
// present. It is by design (the cash button is the finish action, and an
// early end is priced by the server: test/g8/g8_driver_early_end_test.dart);
// the wording far from the drop-off waits for the owner's answer
// (Rules audits/impact/driver-g18-g19-history.md). When the owner answers,
// flip the expectation below to the chosen behaviour (failing test first).
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
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

const _pickup = GeoPoint(59.3326, 18.0649); // Sergels torg
const _dropoff = GeoPoint(59.3429, 18.0498); // Odenplan, ~1.4 km away

/// The car stands at the pickup: the trip has just started.
class _AtPickup implements DriverLocationRepository {
  DriverLocation get fix => DriverLocation(
    point: _pickup,
    measuredAt: DateTime.now(),
    accuracyMeters: 5,
  );
  @override
  Future<DriverLocation> getCurrentPosition() async => fix;
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      Stream<DriverLocation>.value(fix);
}

void main() {
  late MemoryDriverRealtime realtime;
  late LiveDriverServices live;
  Map<String, dynamic> money(int minor) => {
    'amountMinor': minor,
    'currency': 'SEK',
  };
  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    InMemoryWaybillRepository.instance.reset();
    realtime = MemoryDriverRealtime();
    final tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/events')) return http.Response('', 503);
      if (request.method == 'GET' && path == '/api/v1/trips/g18-trip') {
        return json(200, {
          'tripId': 'g18-trip',
          'status': 'in_trip',
          'version': 8,
          'paymentMethod': 'cash',
          'fare': money(20800),
          'driverEarnings': money(15136),
        });
      }
      if (request.method == 'GET' && path == '/api/v1/driver/profile') {
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
      location: _AtPickup(),
    );
    LiveDriverServices.instance = live;
  });
  tearDown(() async {
    realtime.dispose();
    LiveDriverServices.instance = null;
    await live.dispose();
  });

  Future<void> frames(WidgetTester tester, [int count = 12]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('G18 proof: Collect cash is the main button right after the '
      'start of a cash trip, ~1.4 km from the drop-off (still present on '
      'main; the wording waits for the owner)', (tester) async {
    expect(_pickup.distanceMetersTo(_dropoff), greaterThan(1000));
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
              tripId: 'g18-trip',
              initialStage: ActiveRideStage.onTrip,
              riderName: 'Passenger',
              fare: '151,36 kr',
              riderFare: '208,00 kr',
              paidByCash: true,
              cashToCollect: '208,00 kr',
              category: 'Economy',
              matchedVia: WaybillRecord.demoRadarSource,
              pickupAddress: 'Sergels torg',
              pickupArea: '',
              pickupPosition: LatLng(_pickup.latitude, _pickup.longitude),
              dropoffAddress: 'Odenplan',
              dropoffPosition: LatLng(_dropoff.latitude, _dropoff.longitude),
              locationRepository: _AtPickup(),
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

    // Today on main: the cash button is there at once, with no distance
    // gate (`_collectsCashNow`, accept_ride_state_getters.dart:285),
    // labelled "Collect cash" / "Encaisser les espèces".
    const key = ValueKey<String>('active-ride-collect-cash');
    expect(find.byKey(key), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(key), matching: find.text('Collect cash')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('active-ride-slide-action')),
      findsNothing,
      reason: 'no neutral "finish" step comes before it',
    );

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}

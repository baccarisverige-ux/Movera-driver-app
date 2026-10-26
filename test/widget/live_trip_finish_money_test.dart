import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/ride%20completed/ride_completed.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

/// Owner, live test 2026-10-26, on a live cash trip finished 1.2 km in
/// and 5.8 km from the drop-off (the local server's own numbers):
/// - N9: the finish screen, the waybill, history and the cash balance
///   take the server's final money (40,00 kr earnings, 54,00 kr cash),
///   not the 151,36 kr / 208,00 kr booked at accept.
/// - N11: the waybill names the signed-in driver and their car, the
///   pickup's address is looked up when the offer carried only its
///   coordinates, and the rider's fare is on it.
void main() {
  late List<http.Request> requests;
  late LiveDriverServices live;
  late DriverAccountSession account;
  Map<String, dynamic> money(int minor) => {
    'amountMinor': minor,
    'currency': 'SEK',
  };
  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
  final completed = <String, dynamic>{
    'tripId': 'live-trip',
    'status': 'completed',
    'version': 10,
    'fare': money(5400),
    'quote': {'quoteId': 'q', 'total': money(20800)},
    'fareLines': [
      {'code': 'base', 'amount': money(2900)},
      {'code': 'distance', 'amount': money(1735)},
      {'code': 'time', 'amount': money(32)},
      {'code': 'minimum_adjust', 'amount': money(233)},
      {'code': 'app_fee', 'amount': money(490)},
      {'code': 'rounding', 'amount': money(10)},
    ],
    'driverEarnings': money(3920),
    'commission': money(1400),
    'pickupPay': money(80),
    'paymentMethod': 'cash',
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    InMemoryWaybillRepository.instance.reset();
    requests = [];
    final tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
    final client = MockClient((request) async {
      final path = request.url.path;
      requests.add(request);
      if (path.endsWith('/events')) return http.Response('', 503);
      if (request.method == 'GET' && path == '/api/v1/trips/live-trip') {
        return json(200, {
          'tripId': 'live-trip',
          'status': 'in_trip',
          'version': 8,
        });
      }
      if (request.method == 'POST' &&
          path == '/api/v1/trips/live-trip/complete') {
        return json(200, completed);
      }
      if (request.method == 'GET' && path == '/api/v1/driver/profile') {
        return json(200, {
          'driverId': 'drv_1',
          'accountStatus': 'active',
          'version': 4,
          'firstName': 'Test',
          'lastName': 'Åkare',
          'vehicleId': 'veh_1',
        });
      }
      if (request.method == 'GET' && path == '/api/v1/driver/vehicles') {
        return json(200, {
          'items': [
            {
              'vehicleId': 'veh_0',
              'make': 'Toyota',
              'model': 'Corolla',
              'year': 2022,
              'color': 'White',
              'plate': 'TST 002',
              'seats': 4,
              'status': 'approved',
            },
            {
              'vehicleId': 'veh_1',
              'make': 'Volvo',
              'model': 'V60',
              'year': 2021,
              'color': 'Black',
              'plate': 'TST 001',
              'seats': 4,
              'status': 'approved',
            },
          ],
        });
      }
      if (request.method == 'POST' &&
          path == '/api/v1/locations/reverse-geocode') {
        final body = jsonDecode(request.body) as Map;
        expect(body['latitude'], 59.195885);
        expect(body['longitude'], 17.597423);
        return json(200, {
          'address': 'Klockarvägen 37, 151 62 Södertälje',
          'latitude': 59.195885,
          'longitude': 17.597423,
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
    account = DriverAccountSession(repository: DriverAccountRepository(api));
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

  testWidgets('an early finish shows the server\'s final money; the waybill '
      'names the driver, the car, the pickup and the rider\'s fare', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = DriverSessionController(initialOnline: true);
    addTearDown(session.dispose);
    final rides = MemoryActiveRideRepository();
    await tester.pumpWidget(
      DriverRuntimeScope(
        session: session,
        homeBuilder: () => const SizedBox(),
        account: account,
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, __) => MaterialApp(
            home: AcceptRide(
              tripId: 'live-trip',
              initialStage: ActiveRideStage.onTrip,
              riderName: 'Passenger',
              fare: '151,36 kr',
              riderFare: '208,00 kr',
              paidByCash: true,
              cashToCollect: '208,00 kr',
              category: 'Economy',
              matchedVia: WaybillRecord.moveraRadarSource,
              // The rider app named the pickup by its coordinates only.
              pickupAddress: '59.195885, 17.597423',
              pickupArea: '',
              pickupPosition: const LatLng(59.195885, 17.597423),
              dropoffAddress: 'Klockarvägen 37, Södertälje',
              dropoffPosition: const LatLng(59.2411, 17.6031),
              locationRepository: _NoGps(),
              activeRideRepository: rides,
              sessionController: session,
              waybillRepository: InMemoryWaybillRepository.instance,
            ),
          ),
        ),
      ),
    );
    await frames(tester, 20);

    // N11: the waybill as the server knows the driver and the car.
    final current = InMemoryWaybillRepository.instance.current!;
    expect(current.driverName, 'Test Åkare');
    expect(current.vehicle, 'Volvo V60 2021');
    expect(current.licensePlate, 'TST 001');
    expect(current.pickup, 'Klockarvägen 37, 151 62 Södertälje');
    expect(current.riderFare, '208,00 kr');
    expect(current.fare, '151,36 kr');
    // The save keeps the looked-up address for a restart.
    expect(
      (await rides.read())!.pickupAddress,
      'Klockarvägen 37, 151 62 Södertälje',
    );
    expect((await rides.read())!.riderFare, '208,00 kr');

    // The driver collects the cash and finishes, 5.8 km from the drop-off.
    tester
        .widget<SlidingUpPanel>(find.byType(SlidingUpPanel))
        .controller!
        .animatePanelToSnapPoint();
    await frames(tester, 16);
    final collect = find.byKey(
      const ValueKey<String>('active-ride-collect-cash'),
    );
    await tester.ensureVisible(collect);
    await tester.tap(collect);
    await frames(tester, 10);
    await tester.tap(find.byKey(const ValueKey<String>('cash-complete-ride')));
    for (
      var i = 0;
      i < 80 && find.byType(DriverRideCompleted).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 25));
    }
    expect(find.byType(DriverRideCompleted), findsOneWidget);
    // The trip screen slides out under the finish screen.
    await tester.pump(const Duration(milliseconds: 1200));
    final complete = requests
        .where((r) => r.url.path.endsWith('/complete'))
        .single;
    expect(jsonDecode(complete.body), {
      'expectedVersion': 8,
    }, reason: 'no fare of its own: the server prices the finish');

    // N9: the server's final money everywhere after the finish.
    final summary = tester.widget<Text>(
      find.byKey(const ValueKey<String>('ride-completed-fare')),
    );
    expect(summary.textSpan!.toPlainText(), '40,00 kr');
    expect(find.textContaining('151,36', findRichText: true), findsNothing);
    final last = InMemoryWaybillRepository.instance.last!;
    expect(last.fare, '40,00 kr');
    expect(last.riderFare, '54,00 kr');
    expect(last.waitingFee, isNull);
    expect(last.driverName, 'Test Åkare');
    await CompletionJournal.settle();
    final history = await PrefsTripHistoryRepository().list();
    expect(history.single.fare, '40,00 kr');
    expect(history.single.cashCollected, '54,00 kr');
    expect(history.single.cashBalance!.balance.minorUnits, 4000 - 5400);
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
      const Stream<DriverLocation>.empty();
}

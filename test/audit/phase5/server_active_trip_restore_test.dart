import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/live/live_active_trip.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../integration_test/headless_map_platform.dart';

/// D-3 (audit Phase 5, S2): a driver signing in on a new browser while the
/// server holds their accepted trip saw "searching"; the app only restored
/// trips saved on the device. Home now asks the server (`activeTripId`).
void main() {
  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  Map<String, Object?> projection(String status) => {
    'tripId': 'srv-trip-9',
    'status': status,
    'version': 4,
    'categoryId': 'economy',
    'paymentMethod': 'card',
    'acceptedAt': '2026-10-26T10:00:00Z',
    'pickup': {'lat': 59.3326, 'lng': 18.0649, 'address': 'Drottninggatan 1'},
    'dropoff': {'lat': 59.35, 'lng': 18.07, 'address': 'Odenplan'},
    'fare': {'amountMinor': 15000, 'currency': 'SEK'},
    'driverEarnings': {'amountMinor': 12000, 'currency': 'SEK'},
    'pickupPay': {'amountMinor': 155, 'currency': 'SEK'},
  };

  group('snapshotOf', () {
    test('maps statuses the trip screen runs, and nothing else', () {
      expect(
        LiveActiveTrip.stageOf('accepted'),
        ActiveRideStage.headingToPickup,
      );
      expect(
        LiveActiveTrip.stageOf('arrived'),
        ActiveRideStage.waitingForRider,
      );
      expect(LiveActiveTrip.stageOf('in_trip'), ActiveRideStage.onTrip);
      expect(LiveActiveTrip.stageOf('searching'), isNull);
      expect(LiveActiveTrip.stageOf('completed'), isNull);
    });

    test('a projection becomes a restorable snapshot', () {
      final ride = LiveActiveTrip.snapshotOf(projection('accepted'))!;
      expect(ride.tripId, 'srv-trip-9');
      expect(ride.stage, ActiveRideStage.headingToPickup);
      expect(ride.hasVerifiedEndpoints, isTrue);
      expect(ride.pickupAddress, 'Drottninggatan 1');
      expect(ride.dropoffAddress, 'Odenplan');
      expect(ride.paidByCash, isFalse);
      // The driver's own pay: earnings plus pickup pay.
      expect(ride.fare, contains('121,55'));
    });

    test('no coordinates: nothing to restore', () {
      final trip = projection('accepted')..remove('pickup');
      expect(LiveActiveTrip.snapshotOf(trip), isNull);
    });
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    ScheduledRideStore.reset();
  });
  tearDown(() => LiveDriverServices.instance = null);

  Future<LiveDriverServices> pumpHome(
    WidgetTester tester, {
    required Object? activeTripId,
    String status = 'accepted',
  }) async {
    final tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
    final client = MockClient((request) async {
      return switch (request.url.path) {
        '/api/v1/driver/profile' => json(200, {
          'driverId': 'd1',
          'onlineStatus': activeTripId == null ? 'offline' : 'on_trip',
          'version': 3,
          'activeTripId': ?activeTripId,
        }),
        '/api/v1/trips/srv-trip-9' => json(200, projection(status)),
        _ => http.Response('', 503),
      };
    });
    final live = LiveDriverServices(
      client: client,
      origin: Uri.parse('https://api.test.movera.se'),
      tokens: tokens,
      api: ApiClient(
        client: client,
        baseUri: Uri.parse('https://api.test.movera.se'),
        tokens: tokens,
      ),
      location: _Gps(),
      locationEvery: const Duration(hours: 1),
    );
    LiveDriverServices.instance = live;
    final maps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      LayoutViewport(
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          minTextAdapt: true,
          splitScreenMode: true,
          useInheritedMediaQuery: true,
          builder: (_, __) => MaterialApp(
            home: DriverHome(
              sessionController: DriverSessionController(),
              dispatchRepository: live.dispatch,
              locationRepository: _Gps(),
              activeRideRepository: MemoryActiveRideRepository(),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return live;
  }

  Future<void> leave(WidgetTester tester, LiveDriverServices live) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await live.dispose();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('nothing saved on the device: the server\'s trip opens', (
    tester,
  ) async {
    final live = await pumpHome(tester, activeTripId: 'srv-trip-9');
    expect(find.byType(AcceptRide), findsOneWidget);
    expect(
      tester.widget<AcceptRide>(find.byType(AcceptRide)).tripId,
      'srv-trip-9',
    );
    expect(live.trips.versionOf('srv-trip-9'), 4);
    await leave(tester, live);
  });

  testWidgets('no activeTripId: Home stays as it was', (tester) async {
    final live = await pumpHome(tester, activeTripId: null);
    expect(find.byType(AcceptRide), findsNothing);
    await leave(tester, live);
  });

  testWidgets('a trip the screen cannot run (searching) is not opened', (
    tester,
  ) async {
    final live = await pumpHome(
      tester,
      activeTripId: 'srv-trip-9',
      status: 'searching',
    );
    expect(find.byType(AcceptRide), findsNothing);
    await leave(tester, live);
  });
}

class _Gps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() async => DriverLocation(
    point: const GeoPoint(59.3326, 18.0649),
    accuracyMeters: 5,
    measuredAt: DateTime.now(),
  );

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream<DriverLocation>.empty();
}

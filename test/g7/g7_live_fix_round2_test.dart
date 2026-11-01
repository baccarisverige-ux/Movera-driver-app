import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
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

import '../../integration_test/headless_map_platform.dart';

class _Gps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() async => DriverLocation(
    point: const GeoPoint(59.3429, 18.0498),
    accuracyMeters: 5,
    measuredAt: DateTime.now(),
  );
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream.empty();
}

/// G7 live re-check 2026-11-01, item 3: after reopening the app at a stop
/// the driver saw "Kör till stopp 1 / Framme vid stoppet" again although
/// the server trip had `stops[0].arrivedAt`. The restore's server read was
/// applied, then replaced by the saved "driving to the stop". Through the
/// real reopen path: Home asks the server for the active trip.
void main() {
  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  final arrivedAt = DateTime.now().toUtc().subtract(
    const Duration(seconds: 90),
  );

  Map<String, Object?> projection(List<Map<String, Object?>> stops) => {
    'tripId': 'srv-stop-1',
    'status': 'in_trip',
    'version': 9,
    'categoryId': 'economy',
    'paymentMethod': 'card',
    'acceptedAt': '2026-11-01T22:00:00Z',
    'startedAt': '2026-11-01T22:05:00Z',
    'pickup': {'lat': 59.3326, 'lng': 18.0649, 'address': 'Drottninggatan 1'},
    'dropoff': {'lat': 59.35, 'lng': 18.07, 'address': 'Hornsgatan 2'},
    'stops': stops,
    'fare': {'amountMinor': 15000, 'currency': 'SEK'},
    'driverEarnings': {'amountMinor': 12000, 'currency': 'SEK'},
    'terms': {
      'currency': 'SEK',
      'freeWaitMin': 3,
      'waitPerMin': {'amountMinor': 500, 'currency': 'SEK'},
      'noShowAfterMin': 5,
      'noShowFee': {'amountMinor': 5000, 'currency': 'SEK'},
      'stopFreeWaitMin': 0,
      'stopWaitPerMin': {'amountMinor': 500, 'currency': 'SEK'},
    },
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    ScheduledRideStore.reset();
  });
  tearDown(() {
    LiveDriverServices.instance = null;
    DriverAppTexts.reset();
  });

  Future<LiveDriverServices> reopen(
    WidgetTester tester,
    Map<String, Object?> trip, {
    PersistedActiveRide? saved,
  }) async {
    final tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
    final client = MockClient((request) async {
      return switch (request.url.path) {
        '/api/v1/driver/profile' => json(200, {
          'driverId': 'd1',
          'onlineStatus': 'on_trip',
          'version': 3,
          'activeTripId': 'srv-stop-1',
        }),
        '/api/v1/trips/srv-stop-1' => json(200, trip),
        _ => http.Response('', 503),
      };
    });
    final origin = Uri.parse('https://api.test.movera.se');
    final live = LiveDriverServices(
      client: client,
      origin: origin,
      tokens: tokens,
      api: ApiClient(client: client, baseUri: origin, tokens: tokens),
      location: _Gps(),
      locationEvery: const Duration(hours: 1),
    );
    LiveDriverServices.instance = live;
    final repository = MemoryActiveRideRepository();
    if (saved != null) await repository.save(saved);
    final maps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      LayoutViewport(
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          minTextAdapt: true,
          splitScreenMode: true,
          useInheritedMediaQuery: true,
          builder: (_, _) => MaterialApp(
            home: DriverHome(
              sessionController: DriverSessionController(),
              dispatchRepository: live.dispatch,
              locationRepository: _Gps(),
              activeRideRepository: repository,
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 30; i++) {
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

  final atStop = [
    {
      'lat': 59.3429,
      'lng': 18.0498,
      'address': 'Odenplan',
      'arrivedAt': arrivedAt.toIso8601String(),
    },
  ];

  for (final language in ['sv', 'fr', 'en']) {
    testWidgets('reopened at stop 1: the stop wait, not "drive to stop 1" '
        '($language)', (tester) async {
      DriverAppTexts.language = language;
      final live = await reopen(tester, projection(atStop));
      expect(find.byType(AcceptRide), findsOneWidget);
      expect(find.text(tr.waitingAtStopNumber(1)), findsWidgets);
      expect(find.text(tr.driveToStopNumber(1)), findsNothing);
      expect(find.text(tr.tripArriveAtStop), findsNothing);
      await leave(tester, live);
    });
  }

  testWidgets('a saved "driving to stop 1" loses to the server arrival', (
    tester,
  ) async {
    DriverAppTexts.language = 'sv';
    final live = await reopen(
      tester,
      projection(atStop),
      saved: PersistedActiveRide(
        tripId: 'srv-stop-1',
        stage: ActiveRideStage.onTrip,
        stopIndex: 0,
        paidStopWait: false,
        savedAt: DateTime.now(),
        pickupAddress: 'Drottninggatan 1',
        dropoffAddress: 'Hornsgatan 2',
        stopAddresses: const ['Odenplan'],
        stopPoints: const [GeoPoint(59.3429, 18.0498)],
        pickupLat: 59.3326,
        pickupLng: 18.0649,
        dropoffLat: 59.35,
        dropoffLng: 18.07,
      ),
    );
    expect(find.text(tr.waitingAtStopNumber(1)), findsWidgets);
    expect(find.text(tr.driveToStopNumber(1)), findsNothing);
    expect(find.text(tr.tripArriveAtStop), findsNothing);
    await leave(tester, live);
  });

  testWidgets('no arrival on the server: still "Framme vid stoppet"', (
    tester,
  ) async {
    DriverAppTexts.language = 'sv';
    final live = await reopen(
      tester,
      projection([
        {'lat': 59.3429, 'lng': 18.0498, 'address': 'Odenplan'},
      ]),
    );
    expect(find.text(tr.waitingAtStopNumber(1)), findsNothing);
    expect(find.text(tr.driveToStopNumber(1)), findsWidgets);
    await leave(tester, live);
  });
}

import 'dart:async';
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
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_route_observer.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:movera/widgets/navigation_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

/// A live build: Home's switch is the server's availability. A refusal is
/// said plainly and Home stays offline; once online, the server's offers
/// are the only ones (no demo offers).
void main() {
  late List<http.Request> seen;
  late http.Response Function(http.Request) availability;
  var openOffers = <Map<String, Object?>>[];

  /// The trip the server's profile names (`activeTripId`), and its answer.
  String? serverTripId;
  Map<String, Object?>? serverTrip;
  late LiveDriverServices live;

  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  setUp(() {
    serverTripId = null;
    serverTrip = null;
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    ScheduledRideStore.reset();
  });

  tearDown(() => LiveDriverServices.instance = null);

  /// Made inside the test: its futures must run on the test's clock.
  void makeLive() {
    seen = [];
    final tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
    final client = MockClient((request) async {
      seen.add(request);
      final path = request.url.path;
      return switch (path) {
        '/api/v1/driver/profile' => json(200, {
          'driverId': 'd1',
          'onlineStatus': 'offline',
          'version': 1,
          'activeTripId': ?serverTripId,
        }),
        final trip
            when serverTrip != null &&
                trip == '/api/v1/trips/${serverTrip!['tripId']}' =>
          json(200, serverTrip!),
        '/api/v1/driver/availability' => availability(request),
        '/api/v1/driver/location' => json(200, {'accepted': 1}),
        '/api/v1/driver/offers' => json(200, {
          'items': openOffers,
          'nextCursor': null,
        }),
        // The live feed stays closed here; the list above is what is open.
        _ => http.Response('', 503),
      };
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
      location: _Gps(),
      locationEvery: const Duration(hours: 1),
    );
    LiveDriverServices.instance = live;
  }

  Future<void> frames(WidgetTester tester, Duration total) async {
    const step = Duration(milliseconds: 100);
    for (var t = Duration.zero; t < total; t += step) {
      await tester.pump(step);
    }
  }

  Future<DriverSessionController> goOnline(
    WidgetTester tester, {
    ActiveRideRepository? rides,
  }) async {
    makeLive();
    final maps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = DriverSessionController();
    live.attach(session);
    await tester.pumpWidget(
      LayoutViewport(
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          minTextAdapt: true,
          splitScreenMode: true,
          useInheritedMediaQuery: true,
          builder: (_, __) => MaterialApp(
            navigatorObservers: [driverRouteObserver],
            home: DriverHome(
              sessionController: session,
              dispatchRepository: live.dispatch,
              locationRepository: _Gps(),
              activeRideRepository: rides,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    tester
        .widget<GestureDetector>(
          find.byKey(const ValueKey<String>('trip-radar-touch-target')),
        )
        .onTap!
        .call();
    await frames(tester, const Duration(milliseconds: 2000));
    return session;
  }

  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await live.dispose();
    await frames(tester, const Duration(seconds: 2));
  }

  testWidgets('a refusal is shown and Home stays offline', (tester) async {
    openOffers = [];
    availability = (_) => json(409, {
      'code': 'invalid_transition',
      'reason': 'no_vehicle',
      'message': 'Choose an approved car first.',
    });
    final session = await goOnline(tester);
    expect(
      seen.where((r) => r.url.path == '/api/v1/driver/availability'),
      hasLength(1),
    );
    expect(find.text(tr.liveOnlineNoVehicle), findsOneWidget);
    expect(session.status, DriverOnlineStatus.offline);
    expect(live.presence.serverOnline, isFalse);
    await leave(tester);
  });

  testWidgets('online: only the server\'s offer comes up, no demo offers', (
    tester,
  ) async {
    availability = (request) =>
        json(200, {'driverId': 'd1', 'onlineStatus': 'online', 'version': 2});
    openOffers = [_exclusiveOffer()];
    final session = await goOnline(tester);
    expect(session.status, DriverOnlineStatus.online);
    expect(live.presence.serverOnline, isTrue);
    final sent =
        jsonDecode(
              seen
                  .firstWhere(
                    (r) => r.url.path == '/api/v1/driver/availability',
                  )
                  .body,
            )
            as Map;
    expect(sent['expectedVersion'], 1);
    expect(sent['onlineStatus'], 'online');
    expect(seen.any((r) => r.url.path == '/api/v1/driver/location'), isTrue);
    await frames(tester, const Duration(seconds: 3));
    expect(
      find.byKey(const ValueKey<String>('exclusive-offer-card-srv-offer-1')),
      findsOneWidget,
    );
    // The demo's own Exclusive offers never come up in a live build.
    await frames(tester, const Duration(seconds: 25));
    expect(
      find.byWidgetPredicate((widget) {
        final key = widget.key;
        return key is ValueKey<String> &&
            key.value.startsWith('exclusive-offer-card-') &&
            key.value != 'exclusive-offer-card-srv-offer-1';
      }),
      findsNothing,
    );
    await leave(tester);
  });

  testWidgets('deep-1 H-3: an Exclusive offer arriving while a menu page '
      'covers Home brings Home back and shows the offer', (tester) async {
    availability = (request) =>
        json(200, {'driverId': 'd1', 'onlineStatus': 'online', 'version': 2});
    openOffers = [];
    final session = await goOnline(tester);
    expect(session.status, DriverOnlineStatus.online);
    final home = tester.element(find.byType(DriverHome));
    unawaited(
      Navigator.of(home).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(
            body: Text('History page', key: ValueKey<String>('menu-page')),
          ),
        ),
      ),
    );
    await frames(tester, const Duration(seconds: 1));
    expect(find.byKey(const ValueKey<String>('menu-page')), findsOneWidget);
    // The server sends an Exclusive offer while History is open.
    openOffers = [_exclusiveOffer()];
    live.dispatch.refreshOffers();
    await frames(tester, const Duration(seconds: 4));
    expect(find.byKey(const ValueKey<String>('menu-page')), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('exclusive-offer-card-srv-offer-1')),
      findsOneWidget,
    );
    await leave(tester);
  });

  testWidgets('audit B1: after an accepted trip, its summary is not closed '
      'by a new Exclusive offer', (tester) async {
    availability = (request) =>
        json(200, {'driverId': 'd1', 'onlineStatus': 'online', 'version': 2});
    openOffers = [];
    final session = await goOnline(tester);
    expect(session.status, DriverOnlineStatus.online);
    final home = tester.element(find.byType(DriverHome));
    // Accept pushes the trip screen before its trip is begun (post-frame).
    unawaited(
      Navigator.of(home).push(
        ActiveRideTransition(
          const Scaffold(
            body: Text('Trip', key: ValueKey<String>('trip-page')),
          ),
        ),
      ),
    );
    await frames(tester, const Duration(seconds: 1));
    expect(find.byKey(const ValueKey<String>('trip-page')), findsOneWidget);
    // The trip ends: its summary replaces it, the driver is free again.
    unawaited(
      Navigator.of(
        tester.element(find.byKey(const ValueKey('trip-page'))),
      ).pushReplacement(
        BottomToTopTransition(
          const Scaffold(
            body: Text('Summary', key: ValueKey<String>('summary-page')),
          ),
        ),
      ),
    );
    await frames(tester, const Duration(seconds: 1));
    expect(find.byKey(const ValueKey<String>('summary-page')), findsOneWidget);
    openOffers = [_exclusiveOffer()];
    live.dispatch.refreshOffers();
    await frames(tester, const Duration(seconds: 4));
    expect(find.byKey(const ValueKey<String>('summary-page')), findsOneWidget);
    await leave(tester);
  });

  testWidgets('audit B2: a saved trip already over is not re-opened when a '
      'page over Home closes, and its snapshot is cleared', (tester) async {
    availability = (request) =>
        json(200, {'driverId': 'd1', 'onlineStatus': 'online', 'version': 2});
    openOffers = [];
    final rides = MemoryActiveRideRepository();
    await goOnline(tester, rides: rides);
    // The trip was completed on this phone; its snapshot is still there.
    await rides.save(_savedTrip('srv-trip-9'));
    live.trips.observe({
      'tripId': 'srv-trip-9',
      'status': 'completed',
      'version': 4,
    });
    await _coverAndUncover(tester, frames);
    expect(find.byType(AcceptRide), findsNothing);
    expect(await rides.read(), isNull);
    await leave(tester);
  });

  testWidgets('audit B2: the server\'s active trip, already over on this '
      'phone, is not re-opened when a page over Home closes', (tester) async {
    availability = (request) =>
        json(200, {'driverId': 'd1', 'onlineStatus': 'online', 'version': 2});
    openOffers = [];
    await goOnline(tester, rides: MemoryActiveRideRepository());
    // The server is slower than this phone: it still says in_trip.
    serverTripId = 'srv-trip-9';
    serverTrip = _serverTrip('srv-trip-9', status: 'in_trip', version: 3);
    live.trips.observe({
      'tripId': 'srv-trip-9',
      'status': 'completed',
      'version': 4,
    });
    await _coverAndUncover(tester, frames);
    expect(find.byType(AcceptRide), findsNothing);
    await leave(tester);
  });
}

Map<String, Object?> _exclusiveOffer() => {
  'offerId': 'srv-offer-1',
  'tripId': 'srv-trip-1',
  'kind': 'exclusive',
  'status': 'open',
  'version': 1,
  'expiresAt': DateTime.now()
      .toUtc()
      .add(const Duration(minutes: 5))
      .toIso8601String(),
  'fare': {'amountMinor': 6800, 'currency': 'SEK'},
  'driverEarnings': {'amountMinor': 5400, 'currency': 'SEK'},
  'priority': false,
  'source': 'system',
  'pickup': {'lat': 59.332, 'lng': 18.066, 'address': 'Vasagatan 1, Stockholm'},
  'dropoff': {
    'lat': 59.34,
    'lng': 18.08,
    'address': 'Kungsgatan 40, Stockholm',
  },
  'stops': <Object>[],
  'categoryId': 'economy',
  'paymentMethod': 'cash',
  'pickupEtaSeconds': 180,
  'pickupMeters': 900,
  'tripSeconds': 420,
  'tripMeters': 2100,
};

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

/// A menu page covers Home, then closes (Home's `_pageUncovered`).
Future<void> _coverAndUncover(
  WidgetTester tester,
  Future<void> Function(WidgetTester, Duration) frames,
) async {
  final home = tester.element(find.byType(DriverHome));
  unawaited(
    Navigator.of(home).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(
          body: Text('Settings', key: ValueKey<String>('menu-page')),
        ),
      ),
    ),
  );
  await frames(tester, const Duration(seconds: 1));
  expect(find.byKey(const ValueKey<String>('menu-page')), findsOneWidget);
  Navigator.of(tester.element(find.byKey(const ValueKey('menu-page')))).pop();
  await frames(tester, const Duration(seconds: 3));
}

PersistedActiveRide _savedTrip(String tripId) => PersistedActiveRide(
  tripId: tripId,
  stage: ActiveRideStage.onTrip,
  savedAt: DateTime.now(),
  pickupLat: 59.332,
  pickupLng: 18.066,
  dropoffLat: 59.34,
  dropoffLng: 18.08,
  pickupAddress: 'Vasagatan 1, Stockholm',
  dropoffAddress: 'Kungsgatan 40, Stockholm',
);

Map<String, Object?> _serverTrip(
  String tripId, {
  required String status,
  required int version,
}) => {
  'tripId': tripId,
  'status': status,
  'version': version,
  'pickup': {'lat': 59.332, 'lng': 18.066, 'address': 'Vasagatan 1, Stockholm'},
  'dropoff': {
    'lat': 59.34,
    'lng': 18.08,
    'address': 'Kungsgatan 40, Stockholm',
  },
  'fare': {'amountMinor': 6800, 'currency': 'SEK'},
  'driverEarnings': {'amountMinor': 5400, 'currency': 'SEK'},
  'paymentMethod': 'card',
  'categoryId': 'economy',
};

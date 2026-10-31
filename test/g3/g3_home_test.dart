import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/driver/driver_home_notices.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/location/driver_location_service.dart';
import 'package:movera/core/location/driver_start_position.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/home/components/destination_set_panel.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/custom_google_map.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:movera/widgets/movera_radar_orb.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../../integration_test/headless_map_platform.dart';

/// Driver group 3 "Home & going online" on Home (owner decisions 1–3,
/// G3-R1, R2, R5; contract v0.18.4 §29), at 390 x 844.
void main() {
  final previous = DriverRuntimeConfig.current;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DriverStartPosition.clearMemory();
    IslandMessages.reset();
    ScheduledRideStore.reset();
    DriverAreaWatch.instance.reset();
    DriverSetOfflineNotice.instance.clear();
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      simulatedArrival: false,
      externalRouting: false,
      skipAccountActivation: true,
      liveMapTicker: false,
      reservationPopup: false,
      islandHint: false,
    );
  });
  tearDown(() {
    DriverRuntimeConfig.current = previous;
    LiveDriverServices.instance = null;
  });

  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  Future<void> frames(WidgetTester tester, [int count = 20]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Home at 390 x 844; [answer] plays movera-server (null: the demo).
  Future<({DriverSessionController session, LiveDriverServices? live})>
  pumpHome(
    WidgetTester tester, {
    DriverLocationRepository? location,
    Future<http.Response> Function(http.Request request)? answer,
    bool initialOnline = false,
    DriverAccountSession? account,
  }) async {
    LiveDriverServices? live;
    if (answer != null) {
      final tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
      final client = MockClient(answer);
      final origin = Uri.parse('https://api.test.movera.se');
      live = LiveDriverServices.instance = LiveDriverServices(
        client: client,
        origin: origin,
        tokens: tokens,
        api: ApiClient(client: client, baseUri: origin, tokens: tokens),
        location: _Gps(),
        locationEvery: const Duration(hours: 1),
      );
    }
    final maps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = DriverSessionController(initialOnline: initialOnline);
    final Widget home = DriverHome(
      sessionController: session,
      dispatchRepository: live?.dispatch,
      initialOnline: initialOnline,
      locationRepository: location ?? _Gps(),
      activeRideRepository: MemoryActiveRideRepository(),
    );
    await tester.pumpWidget(
      LayoutViewport(
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          minTextAdapt: true,
          splitScreenMode: true,
          useInheritedMediaQuery: true,
          builder: (_, _) => MaterialApp(
            // A signed-in (live) account, as the app root provides it.
            home: account == null
                ? home
                : DriverRuntimeScope(
                    session: session,
                    homeBuilder: () => const SizedBox(),
                    account: account,
                    child: home,
                  ),
          ),
        ),
      ),
    );
    await frames(tester);
    return (session: session, live: live);
  }

  Future<void> leave(WidgetTester tester, LiveDriverServices? live) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await live?.dispose();
    await frames(tester);
  }

  Finder radar() => find.byType(MoveraRadarOrb).last;

  testWidgets('decision 2: location off blocks Go online: "Turn on location '
      'to go online" with Open Settings, above the radar', (tester) async {
    final home = await pumpHome(tester, location: _LocationOff());
    await tester.tap(radar());
    await frames(tester, 5);
    expect(home.session.isGoingOnline, isFalse);
    expect(home.session.isOnline, isFalse);
    expect(find.text('Turn on location to go online'), findsOneWidget);
    expect(find.text('Open Settings'), findsOneWidget);
    final card = tester.getRect(
      find.byKey(const ValueKey<String>('home-reason-location-required')),
    );
    expect(card.bottom, lessThanOrEqualTo(tester.getRect(radar()).top));
    await leave(tester, null);
  });

  testWidgets('03c: the location card sits above the bell, never over it', (
    tester,
  ) async {
    // The bell shows for a signed-in (live) account only.
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      simulatedArrival: false,
      externalRouting: false,
      skipAccountActivation: true,
      liveMapTicker: false,
      reservationPopup: false,
      islandHint: false,
      authRequired: true,
    );
    final client = MockClient((_) async => json(200, {}));
    final account =
        DriverAccountSession(
          repository: DriverAccountRepository(
            ApiClient(
              client: client,
              baseUri: Uri.parse('https://api.test.movera.se'),
              tokens: MemoryTokenStore()..save(access: 'a1', refresh: 'r1'),
            ),
          ),
        )..replace(
          DriverAccount.fromJson(const {
            'driverId': 'd1',
            'accountStatus': 'active',
            'firstName': 'Amira',
            'version': 3,
            'country': 'SE',
          }),
        );
    await pumpHome(tester, location: _LocationOff(), account: account);
    await tester.tap(radar());
    await frames(tester, 5);
    final card = tester.getRect(
      find.byKey(const ValueKey<String>('home-reason-location-required')),
    );
    // The real bell, measured where it is drawn (not from layout constants).
    final bellFinder = find.byKey(
      const ValueKey<String>('home-notifications-bell'),
    );
    expect(bellFinder, findsOneWidget);
    final bell = tester.getRect(bellFinder);
    expect(card.overlaps(bell), isFalse, reason: 'card $card, bell $bell');
    expect(card.bottom, lessThanOrEqualTo(bell.top));
    expect(card.bottom, lessThanOrEqualTo(tester.getRect(radar()).top));
    await leave(tester, null);
  });

  testWidgets('item 4: the location message never covers Go online', (
    tester,
  ) async {
    await pumpHome(tester, location: _NotAllowed());
    final message = find.text(
      "Movera can't see your location, so trips can't reach you.",
    );
    expect(message, findsOneWidget);
    final radarRect = tester.getRect(radar());
    // The whole card (not only its text) stays above the radar.
    final card = find.ancestor(of: message, matching: find.byType(Material));
    expect(tester.getRect(card.first).bottom, lessThanOrEqualTo(radarRect.top));
    await leave(tester, null);
  });

  testWidgets('a refusal from the server stays on the card (no 6 s '
      'snackbar)', (tester) async {
    final home = await pumpHome(
      tester,
      answer: (request) async => switch ((request.method, request.url.path)) {
        ('GET', '/api/v1/driver/profile') => json(200, {
          'driverId': 'd1',
          'onlineStatus': 'offline',
          'version': 3,
        }),
        ('POST', '/api/v1/driver/availability') => json(409, {
          'code': 'invalid_transition',
          'message': 'no car',
          'requestId': 'r',
          'retryable': false,
          'reason': 'no_vehicle',
          'projection': {'onlineStatus': 'offline', 'version': 3},
        }),
        _ => http.Response('', 503),
      },
    );
    await tester.tap(radar());
    await frames(tester, 30);
    expect(home.session.isOnline, isFalse);
    final reason = find.byKey(
      const ValueKey<String>('home-reason-server-refusal'),
    );
    expect(reason, findsOneWidget);
    await frames(tester, 100);
    expect(reason, findsOneWidget, reason: 'still there after 10 s');
    expect(
      tester.getRect(reason).bottom,
      lessThanOrEqualTo(tester.getRect(radar()).top),
    );
    await leave(tester, home.live);
  });

  testWidgets('409 location_required: the card has Open Settings', (
    tester,
  ) async {
    final home = await pumpHome(
      tester,
      answer: (request) async => switch ((request.method, request.url.path)) {
        ('GET', '/api/v1/driver/profile') => json(200, {
          'driverId': 'd1',
          'onlineStatus': 'offline',
          'version': 3,
        }),
        ('POST', '/api/v1/driver/availability') => json(409, {
          'code': 'invalid_transition',
          'message': 'no position',
          'requestId': 'r',
          'retryable': false,
          'reason': 'location_required',
          'projection': {'onlineStatus': 'offline', 'version': 3},
        }),
        _ => http.Response('', 503),
      },
    );
    await tester.tap(radar());
    await frames(tester, 30);
    expect(find.text('Turn on location to go online'), findsOneWidget);
    expect(find.text('Open Settings'), findsOneWidget);
    await leave(tester, home.live);
  });

  testWidgets('auth.slowStart: "Starting the server…" after 5 s while going '
      'online waits', (tester) async {
    final home = await pumpHome(
      tester,
      answer: (request) async {
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/driver/profile') {
          return json(200, {
            'driverId': 'd1',
            'onlineStatus': 'offline',
            'version': 3,
          });
        }
        if (request.url.path == '/api/v1/driver/availability') {
          await Future<void>.delayed(const Duration(seconds: 20));
          return json(409, {
            'code': 'invalid_transition',
            'message': 'no car',
            'requestId': 'r',
            'retryable': false,
            'reason': 'no_vehicle',
          });
        }
        return http.Response('', 503);
      },
    );
    await tester.tap(radar());
    await frames(tester, 30);
    expect(find.text('Starting the server…'), findsNothing);
    await frames(tester, 30);
    expect(find.text('Starting the server…'), findsOneWidget);
    expect(home.session.isGoingOnline, isTrue);
    await frames(tester, 160);
    expect(find.text('Starting the server…'), findsNothing);
    await leave(tester, home.live);
  });

  testWidgets('decision 3 (owner 2026-10-31: the line became the "You\'re '
      'offline" card): its radar reads Go online and goes online', (
    tester,
  ) async {
    final home = await pumpHome(tester);
    DriverSetOfflineNotice.instance.show(
      reason: DriverOfflineReason.appRestart,
    );
    await frames(tester, 3);
    final card = find.byKey(const ValueKey<String>('home-offline-card'));
    expect(card, findsOneWidget);
    expect(
      find.text('You were set offline – tap to go online again'),
      findsNothing,
    );
    await tester.tap(find.byType(MoveraRadarOrb).last);
    await frames(tester, 3);
    expect(home.session.isGoingOnline || home.session.isOnline, isTrue);
    expect(card, findsNothing);
    await frames(tester, 30);
    await leave(tester, null);
  });

  testWidgets('G3-R2: "You are not eligible to drive in this area" with his '
      'zones', (tester) async {
    await pumpHome(tester, initialOnline: true);
    DriverAreaWatch.instance.observe({
      'outsideArea': true,
      'areaZones': [
        {'zoneId': 'z1', 'name': 'Stockholm'},
      ],
    });
    await frames(tester, 5);
    expect(find.text('You are not eligible to drive in this area'), findsOne);
    expect(
      find.text('You get no trips here. Drive back to Stockholm to get trips.'),
      findsOneWidget,
    );
    await tester.tap(find.text('OK'));
    await frames(tester, 5);
    DriverAreaWatch.instance.observe({'outsideArea': true});
    await frames(tester, 5);
    expect(
      find.text('You are not eligible to drive in this area'),
      findsNothing,
    );
    await leave(tester, null);
  });

  testWidgets('item 8: a laptop\'s rough position (300 m) still opens the '
      'map on the driver, not on the Stockholm fallback', (tester) async {
    final rough = _Rough();
    await pumpHome(tester, location: rough);
    final map = tester.widget<CustomGoogleMap>(find.byType(CustomGoogleMap));
    final car = map.markers!.firstWhere(
      (m) => m.markerId.value == 'driver_location',
    );
    expect(car.position.latitude, closeTo(48.8566, 1e-6));
    expect(car.position.longitude, closeTo(2.3522, 1e-6));
    await leave(tester, null);
  });

  testWidgets('item 11: surge colours are hidden during a trip', (
    tester,
  ) async {
    final home = await pumpHome(tester, initialOnline: true);
    Set<Polygon> polygons() =>
        tester.widget<CustomGoogleMap>(find.byType(CustomGoogleMap)).polygons ??
        const {};
    await frames(tester, 10);
    expect(polygons(), isNotEmpty, reason: 'the demo zones while online');
    home.session.beginTrip('trip-g3');
    await frames(tester, 5);
    expect(home.session.activeTripId, 'trip-g3');
    expect(polygons(), isEmpty);
    home.session.endTrip();
    await frames(tester, 5);
    await leave(tester, null);
  });

  testWidgets('destination mode shows the picked destination, not "1141 '
      'central park, DHA"', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          home: Scaffold(
            body: DestinationSetPanel(
              onClose: () {},
              controller: PanelController(),
              address: 'Vasagatan 10, Stockholm',
              body: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1141 central park, DHA'), findsNothing);
    expect(find.text('Vasagatan 10, Stockholm'), findsWidgets);
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

class _LocationOff implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() async =>
      throw const DriverLocationException('Location services are turned off.');

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream<DriverLocation>.empty();
}

class _NotAllowed implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() async =>
      throw const LocationPermissionDeniedException();

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream<DriverLocation>.empty();
}

class _Rough implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() async => DriverLocation(
    point: const GeoPoint(48.8566, 2.3522),
    accuracyMeters: 300,
    measuredAt: DateTime.now(),
  );

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream<DriverLocation>.empty();
}

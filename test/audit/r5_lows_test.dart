// Audit round 5, the low bugs (Wave 6b).
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/dispatch/destination_mode_session.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/location/driver_start_position.dart';
import 'package:movera/core/privacy/local_data.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_route_observer.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/core/storage/local_write_session.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/main.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/components/destination_island.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/widgets/route_mark_pins.dart';
import 'package:movera/widgets/web_map_bitmap.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../../integration_test/headless_map_platform.dart';

Future<void> _frames(WidgetTester tester, int count, [int ms = 50]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _app(Widget home, {GlobalKey<NavigatorState>? navigator}) =>
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, _) => MaterialApp(navigatorKey: navigator, home: home),
    );

/// No GPS fix ever (Home stays on its start position).
class _NoGps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() =>
      Completer<DriverLocation>().future;
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream.empty();
}

/// GPS the test feeds by hand.
class _Gps implements DriverLocationRepository {
  final updates = StreamController<DriverLocation>.broadcast();
  @override
  Future<DriverLocation> getCurrentPosition() async => fix();
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      updates.stream;
  DriverLocation fix() => DriverLocation(
        point: const GeoPoint(59.3300, 18.0600),
        measuredAt: DateTime.now(),
        accuracyMeters: 5,
      );
}

/// Road routing that answers once (10 km, 10 min), then fails.
class _OnceRoutes implements RouteRepository {
  var calls = 0;
  @override
  Future<RoadRoute> drivingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async {
    if (calls++ > 0) throw StateError('routing offline');
    return RoadRoute(
        points: [origin, destination], distanceMeters: 10000,
        durationSeconds: 600);
  }
}

/// Home's test setup: a headless map and the demo's quiet runtime.
void _homeSetUp(WidgetTester tester) {
  _phone(tester);
  SharedPreferences.setMockInitialValues({});
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
  final config = DriverRuntimeConfig.current;
  DriverRuntimeConfig.current = const DriverRuntimeConfig(
    externalRouting: false,
    liveMapTicker: false,
    reservationPopup: false,
    islandHint: false,
    radarSound: false,
    simulatedArrival: true,
    skipAccountActivation: true,
  );
  addTearDown(() => DriverRuntimeConfig.current = config);
}

Future<GlobalKey<NavigatorState>> _pumpHome(
    WidgetTester tester, Widget home) async {
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (_, _) => MaterialApp(
      navigatorKey: navigator,
      navigatorObservers: [driverRouteObserver],
      home: home,
    ),
  ));
  await _frames(tester, 20);
  return navigator;
}

/// Slides the trip's primary action, opening its panel first.
Future<void> _slide(WidgetTester tester) async {
  final action = find.byKey(const ValueKey('active-ride-primary-action'));
  if (action.evaluate().isEmpty) {
    tester.widgetList<SlidingUpPanel>(find.byType(SlidingUpPanel)).last
        .controller!.animatePanelToSnapPoint();
    await _frames(tester, 20);
  }
  await tester.ensureVisible(action);
  await tester.drag(action, const Offset(320, 0));
  await _frames(tester, 8, 30);
}

/// Every trip save, in order.
class _Saves extends MemoryActiveRideRepository {
  final saved = <PersistedActiveRide>[];
  @override
  Future<void> save(PersistedActiveRide ride) {
    saved.add(ride);
    return super.save(ride);
  }
}

void main() {
  test('driver-r5-8: admin\'s scheduled-rides "until" is a local time', () {
    final access = ScheduledRidesDriverAccess.fromJson(
        {'on': false, 'until': '2026-10-23T22:30:00Z'});
    expect(access.until!.isUtc, isFalse,
        reason: 'the notice formats its date: a UTC date can be a day early');
    expect(access.until!.isAtSameMomentAs(DateTime.utc(2026, 10, 23, 22, 30)),
        isTrue);
  });

  testWidgets('driver-r5-21: a stalled accept ends as a network error',
      (tester) async {
    final stalled = Completer<http.Response>();
    final repo = ApiDispatchRepository(
      client: MockClient((request) async => request.method == 'GET'
          ? http.Response(jsonEncode({'items': [_wireOffer], 'nextCursor': null}),
              200, headers: {'content-type': 'application/json'})
          : stalled.future),
      baseUri: Uri.parse('https://api.dev.movera.invalid/api/v1'),
      accessToken: () async => 'token',
    );
    final listed = repo.watchNearbyOffers().skip(1).first;
    repo.refreshOffers();
    await tester.runAsync(() => listed);
    ClaimResult? result;
    unawaited(repo.claimOffer('o1').then((r) => result = r));
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(result?.outcome, ClaimOutcome.networkError,
        reason: 'before: the claim waited for the socket forever');
  });

  test('driver-r5-40: a GPS fix during logout cleanup is not saved',
      () async {
    SharedPreferences.setMockInitialValues({});
    DriverStartPosition.clearMemory();
    // Logout has begun and cleared the position; a Home fix lands now.
    LocalWriteSession.beginCleanup();
    DriverStartPosition.clearMemory();
    await DriverStartPosition.save(const GeoPoint(59.33, 18.06));
    LocalWriteSession.endCleanup();
    expect(DriverStartPosition.cached, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(DriverStartPosition.key), isNull,
        reason: 'before: the departing driver\'s position was written back');
  });

  test('driver-r5-18: logout removes a settings section another tab wrote',
      () async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();
    // Another tab writes to the shared store; this tab's cache never sees it.
    const key = '${SettingsRepository.sectionPrefix}contacts';
    await SharedPreferencesStorePlatform.instance
        .setValue('String', 'flutter.$key', '{"phones":["+46700000000"]}');
    await clearLocalUserData();
    final stored = await SharedPreferencesStorePlatform.instance.getAll();
    expect(stored.keys, isNot(contains('flutter.$key')),
        reason: 'before: only keys in this tab\'s cache were removed');
  });

  test('driver-r5-17: each trip reuses the route pins and their web URLs',
      () async {
    var urls = 0;
    WebMapBitmaps.debugCreateUrl = (_) => 'blob:test/${urls++}';
    addTearDown(() => WebMapBitmaps.debugCreateUrl = null);
    // Two trips ask for the same three pins, as AcceptRide does on mount.
    for (var trip = 0; trip < 2; trip++) {
      for (final kind in RouteMarkKind.values) {
        await RouteMarkPins.pin(kind);
      }
    }
    expect(urls, RouteMarkKind.values.length,
        reason: 'before: a new PNG and Blob URL per pin per trip');
  });

  testWidgets('driver-r5-39: the Start-trip save holds the pickup\'s paid '
      'wait and the start time', (tester) async {
    _phone(tester);
    SharedPreferences.setMockInitialValues({});
    final saves = _Saves();
    await tester.pumpWidget(_app(AcceptRide(
      tripId: 'start-save',
      initialStage: ActiveRideStage.waitingForRider,
      initialWaitSeconds: 6 * 60 + 30,
      waitNow: () => DateTime(2026, 10, 20, 12),
      activeRideRepository: saves,
    )));
    await _frames(tester, 8);
    await _slide(tester);
    final first = saves.saved
        .firstWhere((ride) => ride.stage == ActiveRideStage.onTrip);
    expect([first.paidWaitSeconds, first.startedAt != null], [90, true],
        reason: 'before: the first onTrip save had 0 paid seconds and no '
            'start, and a kill then lost the waiting fee');
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester, 10, 100);
  });

  testWidgets('driver-r5-33: a next-trip offer does not run out under the '
      'trip\'s side menu', (tester) async {
    _phone(tester);
    SharedPreferences.setMockInitialValues({});
    ExclusiveAnswers.instance.reset();
    DriverOfferRules.current = const DriverOfferRules(autoOffline: false);
    addTearDown(() => DriverOfferRules.current = const DriverOfferRules());
    await tester.pumpWidget(_app(AcceptRide(
      initialStage: ActiveRideStage.onTrip,
      waitNow: () => tester.binding.clock.now(),
    )));
    await _frames(tester, 10);
    await tester.pump(const Duration(milliseconds: 2600));
    const card = ValueKey<String>('on-trip-radar-offer-button');
    expect(find.byKey(card), findsOneWidget);
    // The island's menu opens the drawer over the offer.
    tester.state<ScaffoldState>(find.byWidgetPredicate(
        (w) => w is Scaffold && w.drawer != null)).openDrawer();
    final limit = DriverOfferRules.current.exclusiveAcceptTime +
        const Duration(seconds: 4);
    await _frames(tester, limit.inMilliseconds ~/ 250, 250);
    expect(ExclusiveAnswers.instance.missedInRow, 0,
        reason: 'before: it ran out under the menu and counted as missed');
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester, 10, 100);
  });

  testWidgets('driver-r5-27: logout drops the island messages waiting for '
      'Home', (tester) async {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MoveraApp());
    await tester.pump(const Duration(milliseconds: 120));
    // Profile covers Home; a notice posted now waits in the queue.
    final home = tester.element(find.byType(DriverHome));
    unawaited(Navigator.of(home).push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Profile')))));
    await _frames(tester, 10);
    IslandMessages.show(
        const IslandMessage(title: 'Insurance expires in 7 days'));
    final runtime = DriverRuntimeScope.maybeOf(home)!;
    await tester.runAsync(() => runtime.logout!());
    expect(IslandMessages.hasPending, isFalse,
        reason: 'before: the next driver\'s Home showed it, with a tap '
            'bound to the old Home');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('driver-r5-9: back from a sleep past the destination limit, '
      'Home ends destination mode', (tester) async {
    _homeSetUp(tester);
    var wall = DateTime(2026, 10, 22, 9);
    final before = DestinationModeSession.instance;
    DestinationModeSession.instance = DestinationModeSession(now: () => wall);
    addTearDown(() => DestinationModeSession.instance = before);
    final navigator = await _pumpHome(tester, DriverHome(locationRepository: _NoGps()));
    // A destination set on the trip (2 h limit) is Home's once it closes.
    unawaited(navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('trip')))));
    await _frames(tester, 10);
    DestinationModeSession.instance.started(
        address: 'Solna', position: const GeoPoint(59.36, 18.00));
    navigator.currentState!.pop();
    await _frames(tester, 10);
    expect(DestinationModeSession.instance.activeAddress, 'Solna');
    // The phone sleeps 3 h: the wall clock moves, the Timer's does not.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    wall = wall.add(const Duration(hours: 3));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _frames(tester, 4);
    expect(DestinationModeSession.instance.activeAddress, isNull,
        reason: 'before: it kept filtering offers until the late Timer');
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester, 10, 100);
  });

  testWidgets('driver-r5-20: a lost GPS fix keeps the last live destination '
      'figures', (tester) async {
    _homeSetUp(tester);
    final before = DestinationModeSession.instance;
    DestinationModeSession.instance = DestinationModeSession();
    addTearDown(() => DestinationModeSession.instance = before);
    final gps = _Gps(), routes = _OnceRoutes();
    addTearDown(gps.updates.close);
    final navigator = await _pumpHome(tester,
        DriverHome(locationRepository: gps, routeRepository: routes));
    unawaited(navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('trip')))));
    await _frames(tester, 10);
    DestinationModeSession.instance.started(
        address: 'Solna', position: const GeoPoint(59.36, 18.00));
    navigator.currentState!.pop();
    await _frames(tester, 10);
    gps.updates.add(gps.fix());
    await _frames(tester, 10);
    final face = find.byType(DigitalDestinationFace);
    for (var i = 0; i < 100 && face.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.widget<DigitalDestinationFace>(face).eta, '10 min');
    // A fix that is not usable (no time or accuracy): Home drops the live
    // route as when GPS is lost.
    gps.updates.add(const DriverLocation(point: GeoPoint(59.3301, 18.0600)));
    await _frames(tester, 10);
    expect(tester.widget<DigitalDestinationFace>(face).eta, '10 min',
        reason: 'before: it fell back to the confirm-time figures');
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester, 10, 100);
  });
}

/// Contract `Offer` (openapi.yaml#Offer).
const _wireOffer = {
  'offerId': 'o1',
  'tripId': 'trip-o1',
  'kind': 'radar',
  'status': 'open',
  'version': 1,
  'expiresAt': '2026-10-20T12:00:15Z',
  'fare': {'amountMinor': 8810, 'currency': 'SEK'},
  'source': 'system',
  'pickup': {'address': 'Tegnérgatan, Stockholm', 'lat': 59.3335, 'lng': 18.0610},
  'dropoff': {'address': 'Odengatan, Stockholm', 'lat': 59.3428, 'lng': 18.0475},
  'categoryId': 'comfort',
  'paymentMethod': 'card',
  'pickupEtaSeconds': 180,
  'pickupMeters': 900,
  'tripSeconds': 720,
  'tripMeters': 5200,
};

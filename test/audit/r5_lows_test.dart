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
import 'package:movera/core/history/trip_history.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/location/driver_start_position.dart';
import 'package:movera/core/privacy/local_data.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_route_observer.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/core/storage/local_write_session.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';
import 'package:movera/main.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/components/destination_island.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/ride%20history/history%20detail/history_detail.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
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

RideOffer _radarTrip(String id) => RideOffer(
      id: id,
      category: 'Comfort',
      fare: Money(minorUnits: 10000),
      rating: '4.9',
      pickupMinutes: 2,
      pickupKm: 1,
      tripMinutes: 10,
      tripKm: 5,
      pickup: 'Pickup, Stockholm',
      dropoff: 'Dropoff, Stockholm',
      pickupPosition: const GeoPoint(59.3279, 18.0615),
      dropoffPosition: const GeoPoint(59.3326, 18.0649),
      isNearby: true,
      followsDestination: true,
    );

/// Dispatch with two Radar trips; each Match waits for the test's answer.
class _RadarDispatch implements DispatchRepository {
  final claims = <Completer<ClaimResult>>[];
  List<RideOffer> offers = [_radarTrip('first'), _radarTrip('second')];
  final updates = StreamController<List<RideOffer>>.broadcast();
  void publish(List<RideOffer> next) => updates.add(offers = next);
  @override
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async =>
      false;
  @override
  Stream<OfferWithdrawal> watchWithdrawals() => const Stream.empty();
  @override
  Stream<List<RideOffer>> watchNearbyOffers({
    bool destinationModeActive = false,
  }) =>
      Stream.multi((sink) {
        sink.addSync(offers);
        final sub = updates.stream.listen(sink.addSync);
        sink.onCancel = sub.cancel;
      }, isBroadcast: true);
  @override
  Stream<List<RideOffer>> watchNextTripOffers() => const Stream.empty();
  @override
  void refreshOffers() {}
  @override
  void releaseReservation(String reservationId) {}
  @override
  Stream<ReservationRequestPreview> watchAssignments() => const Stream.empty();
  @override
  Future<ClaimResult> claimOffer(String offerId) {
    claims.add(Completer<ClaimResult>());
    return claims.last.future;
  }
}

/// Waits (in test time) until [finder] shows, up to [limit].
Future<void> _until(WidgetTester tester, Finder finder,
    [Duration limit = const Duration(seconds: 10)]) async {
  for (var t = Duration.zero; t < limit && finder.evaluate().isEmpty;
      t += const Duration(milliseconds: 100)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Trip storage that is blocked: every read fails.
class _BlockedStorage extends MemoryActiveRideRepository {
  var reads = 0;
  @override
  Future<PersistedActiveRide?> read() async {
    reads++;
    throw ActiveRideStorageUnavailable('blocked');
  }
}

/// A reservation picked up tomorrow at [hour]:00, or [at].
ReservationRequestPreview _reservation(int hour, {DateTime? at}) {
  final now = DateTime.now();
  return ReservationRequestPreview(
    category: 'Comfort',
    fare: '210,00 kr',
    rating: '4.80',
    riderName: 'Eva',
    riderTrips: 12,
    pickupLabel: 'Tomorrow at $hour:00',
    pickupAddress: 'Kungsholmen, Stockholm',
    dropoffAddress: 'Arlanda Airport',
    pickupTime: '$hour:00',
    pickupDay: 'Tomorrow',
    tripMinutes: 35,
    tripKm: 40,
    pickup: const GeoPoint(59.3326, 18.0300),
    dropoff: const GeoPoint(59.6498, 17.9238),
  ).scheduledFor(at ?? DateTime(now.year, now.month, now.day + 1, hour));
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

  testWidgets('driver-r5-32: after a lost Match in the full Radar list, '
      'trips that left dispatch leave Home\'s deck', (tester) async {
    _homeSetUp(tester);
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      externalRouting: false,
      liveMapTicker: false,
      reservationPopup: false,
      islandHint: false,
      radarSound: false,
      simulatedArrival: false,
      skipAccountActivation: false,
    );
    final dispatch = _RadarDispatch();
    await _pumpHome(tester, DriverHome(
      locationRepository: _NoGps(),
      dispatchRepository: dispatch,
      sessionController: DriverSessionController(),
    ));
    await tester.tap(find.text('OFF'));
    const second = ValueKey<String>('radar-offer-card-second');
    await _until(tester, find.byKey(second), const Duration(seconds: 24));
    await tester.tap(find.byKey(const ValueKey<String>('radar-home-all-offers')));
    await _frames(tester, 12);
    await tester.tap(find.byKey(const ValueKey<String>('radar-match-first')));
    await tester.pump();
    // Both trips leave dispatch (no withdrawal event); the Match is lost.
    dispatch.publish([]);
    await tester.pump();
    dispatch.claims.single.complete(const ClaimResult.alreadyClaimed());
    await _frames(tester, 12, 250); // the lost Match's notice clears
    await tester.tap(find.byTooltip('Back'));
    await _frames(tester, 4);
    final match = find.byKey(const ValueKey<String>('radar-match-second'));
    expect(
        match.evaluate().isEmpty ||
            tester.widget<FilledButton>(match).onPressed == null,
        isTrue,
        reason: 'before: it stayed on the deck with Match enabled');
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester, 10, 100);
  });

  testWidgets('driver-r5-2: an Exclusive offer past its server expiresAt is '
      'not shown', (tester) async {
    _homeSetUp(tester);
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      externalRouting: false,
      liveMapTicker: false,
      reservationPopup: false,
      islandHint: false,
      radarSound: false,
      simulatedArrival: false,
      skipAccountActivation: false,
    );
    final dispatch = _RadarDispatch()
      ..offers = [
        OfferWire.parse({
          ..._wireOffer,
          'kind': 'assigned',
          'expiresAt': DateTime.now()
              .subtract(const Duration(seconds: 2)).toUtc().toIso8601String(),
        }),
      ];
    await _pumpHome(tester, DriverHome(
      locationRepository: _NoGps(),
      dispatchRepository: dispatch,
      sessionController: DriverSessionController(),
    ));
    await tester.tap(find.text('OFF'));
    const card = ValueKey<String>('exclusive-offer-card-o1');
    await _until(tester, find.byKey(card), const Duration(seconds: 6));
    expect(find.byKey(card), findsNothing,
        reason: 'before: it got a fresh full countdown');
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester, 10, 100);
  });

  testWidgets('driver-r5-37: the storage Retry bar goes by itself and does '
      'not re-read during a trip', (tester) async {
    _homeSetUp(tester);
    final storage = _BlockedStorage();
    final session = DriverSessionController();
    await _pumpHome(tester, DriverHome(locationRepository: _NoGps(),
        activeRideRepository: storage, sessionController: session));
    final bar = find.byType(SnackBar);
    expect(bar, findsOneWidget);
    expect(tester.widget<SnackBar>(bar).persist, isFalse,
        reason: 'before: with its action it stayed until swiped away');
    session.beginTrip('live-trip');
    final reads = storage.reads;
    await tester.tap(find.text('Retry'));
    await _frames(tester, 4);
    expect(storage.reads, reads,
        reason: 'before: Retry re-ran the restore over the live trip');
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester, 10, 100);
  });

  testWidgets('driver-r5-38: a restored trip\'s waybill names the driver as '
      'a live trip does', (tester) async {
    _homeSetUp(tester);
    final saved = MemoryActiveRideRepository();
    await tester.pumpWidget(_app(AcceptRide(tripId: 'restored-trip',
        initialStage: ActiveRideStage.onTrip, locationRepository: _NoGps(),
        activeRideRepository: saved)));
    await _frames(tester, 8);
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester, 10, 100);
    // The app was killed; Home restores the trip.
    final waybills = InMemoryWaybillRepository.instance..reset();
    addTearDown(waybills.reset);
    await _pumpHome(tester, DriverHome(locationRepository: _NoGps(),
        activeRideRepository: saved, waybillRepository: waybills));
    await _until(tester, find.byType(AcceptRide));
    expect(waybills.current?.tripId, 'restored-trip');
    expect(waybills.current?.driverName, WaybillRecord.moveraDriverName,
        reason: 'before: "Demo driver — identity unavailable"');
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester, 10, 100);
  });

  testWidgets('driver-r5-34: a zero cash balance after Movera\'s fee does '
      'not say the cash matched the fare', (tester) async {
    _homeSetUp(tester);
    // 200 kr fare, 25 % fee: the rider paid 150 kr, the driver's earnings.
    await tester.pumpWidget(_app(DriverRideHistoryDetail(
      record: const TripHistoryRecord(
        tripId: 'cash-trip',
        riderName: 'Karin',
        whenLabel: '15/10/2026, 07:59',
        pickup: 'Gamla vägen',
        dropoff: 'Solna centrum',
        fare: '200,00 kr',
        category: 'Comfort',
        paymentMethod: 'Cash',
        cashCollected: '150,00 kr',
      ),
      loadRideChecks: (_) async => const [],
    )));
    await _frames(tester, 10);
    final note = find.byKey(const ValueKey<String>('history-owed-note'));
    await tester.ensureVisible(note);
    expect(tester.widget<Text>(note).data,
        'Cash matched your earnings: nothing to settle',
        reason: 'before: "Cash matched your fare" although 50 kr less');
  });

  testWidgets('driver-r5-49: the Accepted tab lists rides by pickup time',
      (tester) async {
    _phone(tester);
    SharedPreferences.setMockInitialValues({});
    ScheduledRideStore.reset();
    addTearDown(ScheduledRideStore.reset);
    // The seed's 08:15 ride is accepted; an 18:00 one is accepted after it.
    ScheduledRideStore.acceptAssigned(_reservation(18));
    await tester.pumpWidget(_app(const ScheduledRidesScreen()));
    await _frames(tester, 6);
    await tester.tap(find.text('Accepted'));
    await _frames(tester, 6);
    final early = tester.getTopLeft(find.textContaining('08:15').first).dy;
    final late = tester.getTopLeft(find.textContaining('18:00').first).dy;
    expect(early, lessThan(late),
        reason: 'before: the newest acceptance was on top');
  });

  test('driver-r5-47: the backup-driver note does not stay for days', () {
    var wall = DateTime.now();
    final real = ScheduledClock.realNow;
    ScheduledClock.realNow = () => wall;
    addTearDown(() => ScheduledClock.realNow = real);
    ScheduledRideStore.reset();
    addTearDown(ScheduledRideStore.reset);
    final ride = _reservation(18);
    ScheduledRideStore.acceptAssigned(ride);
    ScheduledRideStore.giveToBackup(ride);
    expect(ScheduledRideStore.backupNote.value, contains('18:00'));
    wall = wall.add(const Duration(days: 2));
    expect(ScheduledRideStore.backupNote.value, isNull,
        reason: 'before: it stayed above later 18:00 rides until logout');
  });

  testWidgets('driver-r5-46: the cancel confirmation turns late when the '
      'free cancel ends while it is open', (tester) async {
    _phone(tester);
    final real = ScheduledClock.realNow, clock = ScheduledClock.instance;
    ScheduledClock.realNow = () => tester.binding.clock.now();
    ScheduledClock.instance = ScheduledClock();
    addTearDown(() {
      ScheduledClock.realNow = real;
      ScheduledClock.instance = clock;
    });
    ScheduledRideStore.reset();
    addTearDown(ScheduledRideStore.reset);
    // Free cancel ends 30 s from now (1 h before pickup).
    ScheduledRideStore.acceptAssigned(_reservation(0, at: tester.binding.clock
        .now().add(const Duration(hours: 1, seconds: 30))));
    await tester.pumpWidget(_app(const ScheduledRidesScreen()));
    await _frames(tester, 6);
    await tester.tap(find.text('Accepted'));
    await _frames(tester, 6);
    await tester.tap(find.text('Kungsholmen, Stockholm').first);
    await _frames(tester, 12);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel reservation'));
    await _frames(tester, 12);
    await tester.ensureVisible(find.text('Personal emergency'));
    await tester.tap(find.text('Personal emergency'));
    await _frames(tester, 6);
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await _frames(tester, 12);
    const warning = ValueKey<String>('scheduled-late-cancel');
    expect(find.byKey(warning), findsNothing);
    await tester.pump(const Duration(seconds: 31));
    await tester.pump();
    expect(find.byKey(warning), findsOneWidget,
        reason: 'before: it still read as free, and Confirm counted late');
  });

  testWidgets('driver-r5-45: a reservation claim out from Scheduled rides '
      'shows as Matching in a reopened screen', (tester) async {
    _phone(tester);
    SharedPreferences.setMockInitialValues({});
    ScheduledRideStore.reset();
    addTearDown(ScheduledRideStore.reset);
    final dispatch = _RadarDispatch();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_app(const SizedBox(), navigator: navigator));
    Future<void> open() async {
      unawaited(navigator.currentState!.push(MaterialPageRoute<void>(
          builder: (_) => ScheduledRidesScreen(dispatchRepository: dispatch))));
      await _frames(tester, 12);
    }

    await open();
    await tester.tap(find.text('Gamla vägen, Stockholm').first);
    await _frames(tester, 12);
    final accept = find.textContaining('Accept  •');
    await tester.ensureVisible(accept);
    await tester.tap(accept);
    await _frames(tester, 12);
    expect(dispatch.claims, hasLength(1));
    // Back while it says Matching, then Scheduled rides again.
    navigator.currentState!.pop();
    await _frames(tester, 12);
    await open();
    expect(find.byKey(const ValueKey<String>('scheduled-ride-matching')),
        findsOneWidget,
        reason: 'before: it showed as open, and Accept claimed it again');
    dispatch.claims.single.complete(const ClaimResult.unavailable());
    await _frames(tester, 6);
  });

  testWidgets('driver-r5-3: a Radar card\'s Match ends at the server\'s '
      'expiresAt', (tester) async {
    _homeSetUp(tester);
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      externalRouting: false,
      liveMapTicker: false,
      reservationPopup: false,
      islandHint: false,
      radarSound: false,
      simulatedArrival: false,
      skipAccountActivation: false,
    );
    // The server lets it go in 8 s; the app's own window is 15 s.
    final expires = DateTime.now().add(const Duration(seconds: 8));
    final dispatch = _RadarDispatch()
      ..offers = [
        OfferWire.parse(
            {..._wireOffer, 'expiresAt': expires.toUtc().toIso8601String()}),
      ];
    await _pumpHome(tester, DriverHome(
      locationRepository: _NoGps(),
      dispatchRepository: dispatch,
      sessionController: DriverSessionController(),
    ));
    await tester.tap(find.text('OFF'));
    final match = find.byKey(const ValueKey<String>('radar-match-o1'));
    await _until(tester, match, const Duration(seconds: 24));
    expect(tester.widget<FilledButton>(match).onPressed, isNotNull);
    await _frames(tester, 36, 250);
    expect(tester.widget<FilledButton>(match).onPressed, isNull,
        reason: 'before: Match stayed on for the app\'s full 15 s');
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

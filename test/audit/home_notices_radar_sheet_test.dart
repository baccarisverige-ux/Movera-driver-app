import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/admin/trip_rules_admin_config.dart';
import 'package:movera/core/dispatch/destination_mode_session.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/next_trip_gate.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/location/driver_start_position.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';
import 'package:movera/core/session/driver_route_observer.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/session/driving_time_clock.dart';
import 'package:movera/presentation/driver/home/components/home_island_notices.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/trip_island.dart';
import 'package:movera/presentation/driver/destination%20mode/destination_picker.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/ride%20requests/ride_requests.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/custom_google_map.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:movera/widgets/offer_route_line.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../../integration_test/headless_map_platform.dart';

// Wave 3 (D3.2, part a): Home's island notices, Radar, map sheet.
// - driver-u110 / driver-u126: a notice posted while a screen covers
//   Home waits for Home instead of playing on its hidden island.
// - driver-65: the app inactive but on screen (a call banner, Control
//   Center, a system dialog) keeps Home's online face and its offers.
// - driver-u113: system Back on "Unresolved trip" keeps the dialog and
//   the saved trip; only "Close trip" closes it.
// - driver-u117: trips the Radar list had when it closed that then leave
//   dispatch no longer keep Home on "Trip found".
// - driver-u118: the driving limit closes the Radar list, and the list
//   never claims a trip for an offline driver.
// - driver-u121: with no known position, Destination mode does not measure
//   from the city-centre placeholder.
// - driver-u122: Home's time limit for its destination does not end a
//   destination the driver set later on a trip.
// - driver-u124: online and waiting, a screen reader's tap on the island
//   brings Menu and Search destination back, as a touch does.
// - driver-u125: the island's TODAY face shows today's recorded earnings,
//   not a sample figure; LAST TRIP shows none before the first trip.

/// Dispatch with no trips unless the test publishes some.
class _Dispatch implements DispatchRepository {
  final _nearby = StreamController<List<RideOffer>>.broadcast();
  List<RideOffer> offers = const [];
  final claims = <Completer<ClaimResult>>[];

  void publish(List<RideOffer> next) {
    offers = List<RideOffer>.unmodifiable(next);
    _nearby.add(offers);
  }

  @override
  Stream<List<RideOffer>> watchNearbyOffers({
    bool destinationModeActive = false,
  }) => Stream<List<RideOffer>>.multi((sink) {
    final sub = _nearby.stream.listen(sink.addSync);
    sink.onCancel = sub.cancel;
    sink.addSync(offers);
  }, isBroadcast: true);

  @override
  Stream<List<RideOffer>> watchNextTripOffers() =>
      Stream.value(const <RideOffer>[]);

  @override
  void refreshOffers() {}

  @override
  void releaseReservation(String reservationId) {}

  @override
  Stream<ReservationRequestPreview> watchAssignments() =>
      const Stream<ReservationRequestPreview>.empty();

  @override
  Future<ClaimResult> claimOffer(String offerId) {
    final claim = Completer<ClaimResult>();
    claims.add(claim);
    return claim.future;
  }

  @override
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async =>
      false;

  @override
  Stream<OfferWithdrawal> watchWithdrawals() =>
      const Stream<OfferWithdrawal>.empty();
}

/// Location blocked: no fix ever comes.
class _NoGps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() async =>
      throw StateError('location denied');

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream<DriverLocation>.empty();
}

/// Roads that arrive when the test lets them.
class _HeldRoads implements RouteRepository {
  final held = <(GeoPoint, GeoPoint, Completer<RoadRoute>)>[];

  @override
  Future<RoadRoute> drivingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) {
    final road = Completer<RoadRoute>();
    held.add((origin, destination, road));
    return road.future;
  }

  void release() {
    for (final (from, to, road) in held) {
      if (!road.isCompleted) {
        road.complete(RoadRoute(
            points: [from, to], distanceMeters: 900, durationSeconds: 120));
      }
    }
  }
}

/// A short Radar trip near the driver.
RideOffer _trip(String id) => RideOffer(
  id: id,
  category: 'Comfort',
  fare: Money(minorUnits: 8810),
  rating: '4.92',
  riderName: 'Sara',
  pickupMinutes: 2,
  pickupKm: 0.8,
  tripMinutes: 6,
  tripKm: 3.1,
  pickup: 'Tegnérgatan, Stockholm',
  dropoff: 'Odengatan, Stockholm',
  pickupPosition: const GeoPoint(59.3335, 18.0610),
  dropoffPosition: const GeoPoint(59.3380, 18.0700),
  isNearby: true,
  followsDestination: false,
);

typedef _Home = ({_Dispatch dispatch, DriverSessionController session});

Future<void> _frames(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

/// Home with the app's route observer, so a screen pushed over Home
/// covers it as in the app; with [online], the Radar is on.
Future<_Home> _pumpHome(
  WidgetTester tester, {
  bool online = true,
  ActiveRideRepository? activeRides,
  DriverLocationRepository? location,
  RouteRepository? routes,
}) async {
  final dispatch = _Dispatch();
  final session = DriverSessionController();
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
          navigatorObservers: [driverRouteObserver],
          home: DriverHome(
            sessionController: session,
            dispatchRepository: dispatch,
            activeRideRepository: activeRides,
            locationRepository: location,
            routeRepository: routes,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
  if (online) {
    tester
        .widget<GestureDetector>(
          find.byKey(const ValueKey<String>('trip-radar-touch-target')),
        )
        .onTap!
        .call();
    await _frames(tester, const Duration(milliseconds: 1500));
  }
  return (dispatch: dispatch, session: session);
}

/// Pushes a screen over Home, as a trip or a menu item does.
Future<NavigatorState> _cover(WidgetTester tester) async {
  final navigator = Navigator.of(tester.element(find.byType(DriverHome)));
  unawaited(navigator.push(MaterialPageRoute<void>(
    builder: (_) => const Scaffold(body: Text('cover')),
  )));
  await _frames(tester, const Duration(milliseconds: 600));
  expect(find.text('cover'), findsOneWidget);
  return navigator;
}

Future<void> _end(WidgetTester tester) async {
  tester.takeException();
  await tester.pumpWidget(const SizedBox());
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DriverStartPosition.clearMemory();
    IslandMessages.reset();
    ScheduledRideStore.reset();
    ExclusiveAnswers.instance.reset();
  });
  tearDown(() {
    DriverOfferRules.current = const DriverOfferRules();
    DrivingTimeClock.instance.load(worked: Duration.zero);
    DestinationModeRules.current = const DestinationModeRules();
    DestinationModeSession.instance = DestinationModeSession();
  });

  group('driver-u110: a notice posted while a screen covers Home', () {
    testWidgets('waits and shows once Home is back on top', (tester) async {
      await _pumpHome(tester);
      // "Radar online" and the launch messages pass first.
      await _frames(tester, const Duration(seconds: 6));
      final navigator = await _cover(tester);
      final missed = HomeIslandNotices.offlineAfterMissed(5);
      IslandMessages.show(missed);
      // Longer than the message's own time on the island.
      await _frames(tester, const Duration(seconds: 6));
      expect(IslandMessages.hasPending, isTrue,
          reason: 'Home is covered: nobody has seen it yet');
      navigator.pop();
      await _frames(tester, const Duration(milliseconds: 800));
      expect(find.text(missed.title), findsOneWidget);
      await _end(tester);
    });
  });

  group('driver-u126: the driving-limit warning during a covering screen', () {
    testWidgets('the 30 min warning shows once Home is back', (tester) async {
      final rule = DrivingTimeClock.instance.rule;
      // 30 min left in 3 s.
      DrivingTimeClock.instance.load(
        worked: rule.work - const Duration(minutes: 30, seconds: 3),
        offlineSince: ScheduledClock.realNow(),
      );
      await _pumpHome(tester);
      await _frames(tester, const Duration(milliseconds: 500));
      final navigator = await _cover(tester);
      await _frames(tester, const Duration(seconds: 8));
      final warning = HomeIslandNotices.drivingLeft(30);
      expect(IslandMessages.posted.map((m) => m.title),
          contains(warning.title));
      navigator.pop();
      await _frames(tester, const Duration(milliseconds: 800));
      expect(find.text(warning.title), findsOneWidget);
      await _end(tester);
    });
  });

  group('driver-65: the app inactive but still on screen', () {
    testWidgets('Home keeps the online Radar, not "OFF · Tap to scan"', (
      tester,
    ) async {
      final home = await _pumpHome(tester);
      expect(home.session.availableForOffers, isTrue);
      expect(find.text('Tap to scan'), findsNothing);
      // An incoming call banner: the app stays visible behind it.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await _frames(tester, const Duration(seconds: 2));
      expect(find.text('Tap to scan'), findsNothing,
          reason: 'the driver is still online');
      expect(find.text('Scanning'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _frames(tester, const Duration(milliseconds: 300));
      await _end(tester);
    });

    testWidgets('a trip published meanwhile still reaches Home', (
      tester,
    ) async {
      final home = await _pumpHome(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await _frames(tester, const Duration(milliseconds: 300));
      home.dispatch.publish([_trip('call')]);
      await _frames(tester, const Duration(seconds: 20));
      expect(find.byKey(const ValueKey<String>('radar-offer-card-call')),
          findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _frames(tester, const Duration(milliseconds: 300));
      await _end(tester);
    });
  });

  group('driver-r4-31: a sheet or dialog over Home', () {
    testWidgets('leaves Home online; only a screen covers it', (tester) async {
      await _pumpHome(tester);
      final context = tester.element(find.byType(DriverHome));
      unawaited(showModalBottomSheet<void>(
        context: context,
        builder: (_) => const SizedBox(height: 200, child: Text('sheet')),
      ));
      await _frames(tester, const Duration(seconds: 1));
      expect(find.text('sheet'), findsOneWidget);
      expect(find.text('Tap to scan'), findsNothing,
          reason: 'Home is still visible and the driver online');
      expect(find.text('Scanning'), findsOneWidget);
      Navigator.of(context).pop();
      await _frames(tester, const Duration(seconds: 1));
      await _cover(tester);
      expect(find.text('Tap to scan', skipOffstage: false), findsOneWidget,
          reason: 'a full screen still pauses Home');
      await _end(tester);
    });
  });

  group('driver-u113: system Back on the "Unresolved trip" dialog', () {
    testWidgets('keeps the dialog and the saved trip', (tester) async {
      final rides = MemoryActiveRideRepository();
      // A trip saved 7 h ago: older than the 6 h window, still resumable.
      await rides.save(PersistedActiveRide(
        tripId: 'stale-trip',
        stage: ActiveRideStage.onTrip,
        savedAt: DateTime.now().subtract(const Duration(hours: 7)),
        pickupLat: 59.3335,
        pickupLng: 18.0610,
        dropoffLat: 59.3380,
        dropoffLng: 18.0700,
      ));
      await _pumpHome(tester, online: false, activeRides: rides);
      await _frames(tester, const Duration(milliseconds: 500));
      expect(find.text('Unresolved trip'), findsOneWidget);
      // Android Back.
      await tester.binding.handlePopRoute();
      await _frames(tester, const Duration(milliseconds: 500));
      expect(find.text('Unresolved trip'), findsOneWidget,
          reason: 'Back is not "Close trip"');
      expect(await rides.read(), isNotNull,
          reason: 'the saved trip is kept');
      await tester.tap(find.text('Close trip'));
      await _frames(tester, const Duration(milliseconds: 500));
      expect(find.text('Unresolved trip'), findsNothing);
      expect(await rides.read(), isNull);
      await _end(tester);
    });
  });

  group('driver-u117: the Radar list closed with trips that then leave', () {
    testWidgets('Home goes back to scanning and "Finding trips"', (
      tester,
    ) async {
      final home = await _pumpHome(tester);
      home.dispatch.publish([_trip('a')]);
      // The demo Exclusive passes, then "a" comes onto the Home deck.
      await _frames(tester, const Duration(seconds: 26));
      expect(find.byKey(const ValueKey<String>('radar-offer-card-a')),
          findsOneWidget);
      // "b" is on Radar only; the driver opens the full list.
      home.dispatch.publish([_trip('a'), _trip('b')]);
      await _frames(tester, const Duration(milliseconds: 300));
      tester
          .widget<GestureDetector>(
            find.byKey(const ValueKey<String>('radar-home-all-offers')),
          )
          .onTap!
          .call();
      await _frames(tester, const Duration(seconds: 1));
      expect(find.byType(RideRequests), findsOneWidget);
      expect(home.dispatch.claims, isEmpty);
      // "a" is taken by someone else and leaves the Home deck.
      home.dispatch.publish([_trip('b')]);
      await _frames(tester, const Duration(seconds: 4));
      // The driver closes the list with "b" still in it.
      tester.widget<RideRequests>(find.byType(RideRequests)).onCloseRides!(true);
      await _frames(tester, const Duration(seconds: 1));
      expect(find.text('Tap for all'), findsOneWidget);
      // "b" leaves dispatch too: nothing is left to take.
      home.dispatch.publish(const []);
      await _frames(tester, const Duration(seconds: 3));
      expect(find.text('Trip found'), findsNothing);
      expect(find.text('Tap for all'), findsNothing);
      expect(find.text('Scanning'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('island-finding')),
          findsOneWidget);
      await _end(tester);
    });
  });

  group('driver-u118: the driving limit with the Radar list open', () {
    testWidgets('the list closes and the driver is offline', (tester) async {
      final rule = DrivingTimeClock.instance.rule;
      // The limit lands 32 s after going online.
      DrivingTimeClock.instance.load(
        worked: rule.work - const Duration(seconds: 32),
        offlineSince: ScheduledClock.realNow(),
      );
      final home = await _pumpHome(tester);
      home.dispatch.publish([_trip('a'), _trip('b')]);
      await _frames(tester, const Duration(seconds: 20));
      tester
          .widget<GestureDetector>(
            find.byKey(const ValueKey<String>('radar-home-all-offers')),
          )
          .onTap!
          .call();
      await _frames(tester, const Duration(seconds: 1));
      expect(find.byType(RideRequests), findsOneWidget);
      await _frames(tester, const Duration(seconds: 13));
      expect(IslandMessages.posted.map((m) => m.title),
          contains(startsWith('Rest until')));
      expect(home.session.availableForOffers, isFalse);
      expect(find.byType(RideRequests), findsNothing,
          reason: 'no Match buttons left for a driver who must rest');
      expect(home.dispatch.claims, isEmpty);
      await _end(tester);
    });

    testWidgets('Match in the list claims nothing while offline', (
      tester,
    ) async {
      final dispatch = _Dispatch()..publish([_trip('a')]);
      final session = DriverSessionController();
      expect(session.availableForOffers, isFalse);
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: RideRequests(
          dispatchRepository: dispatch,
          sessionController: session,
          onCloseRides: (_) {},
        ),
      ));
      await _frames(tester, const Duration(seconds: 1));
      final match = find.byKey(const ValueKey<String>('radar-match-a'));
      await tester.ensureVisible(match);
      await tester.tap(match);
      await _frames(tester, const Duration(seconds: 1));
      expect(dispatch.claims, isEmpty);
      await _end(tester);
    });
  });

  group('driver-u121: Destination mode with no known position', () {
    testWidgets('the picker gets no origin to measure from', (tester) async {
      await _pumpHome(tester, online: false, location: _NoGps());
      // The map opens without a car once GPS has failed.
      await _frames(tester, const Duration(seconds: 9));
      tester
          .widget<InkWell>(
            find.byKey(const ValueKey<String>('destination-mode-open')),
          )
          .onTap!
          .call();
      await _frames(tester, const Duration(seconds: 1));
      final picker = tester.widget<DriverDestinationPicker>(
        find.byType(DriverDestinationPicker),
      );
      expect(picker.origin, isNull,
          reason: 'no figures from the Stockholm placeholder');
      await _end(tester);
    });
  });

  group('driver-u122: a destination set on the trip after Home\'s', () {
    testWidgets('Home\'s old time limit does not end it', (tester) async {
      var now = DateTime(2026, 10, 21, 10);
      DestinationModeSession.instance = DestinationModeSession(now: () => now);
      Future<void> pass(Duration total) async {
        for (var t = Duration.zero; t < total; t += const Duration(seconds: 1)) {
          now = now.add(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
        }
      }

      await _pumpHome(tester, online: false, location: _NoGps());
      await _frames(tester, const Duration(seconds: 9));
      // The admin's time limit: 1 min here (2 h in the app).
      DestinationModeRules.current =
          const DestinationModeRules(timeLimitHours: 1 / 60);
      // 10:00: a destination on Home.
      tester
          .widget<InkWell>(
            find.byKey(const ValueKey<String>('destination-mode-open')),
          )
          .onTap!
          .call();
      await _frames(tester, const Duration(seconds: 1));
      await tester.tap(
          find.byKey(const ValueKey<String>('destination-result-solna')));
      await _frames(tester, const Duration(seconds: 1));
      expect(DestinationModeSession.instance.timeLeft(), isNotNull);
      // A trip covers Home; 40 s later the driver sets a new destination
      // there, which has its own minute.
      await _cover(tester);
      await pass(const Duration(seconds: 38));
      OnTripDestination.started();
      // Past Home's first minute.
      await pass(const Duration(seconds: 25));
      final session = DestinationModeSession.instance;
      expect(session.expired(), isFalse,
          reason: 'the trip\'s destination has about 35 s left');
      expect(session.timeLeft()!.inSeconds, inInclusiveRange(30, 40));
      // Its own minute ends it.
      await pass(const Duration(seconds: 40));
      expect(session.expired(), isTrue);
      await _end(tester);
    });
  });

  group('driver-r4-38: Destination mode ends under an Exclusive offer', () {
    testWidgets('the offer keeps its route preview', (tester) async {
      DestinationModeRules.current =
          const DestinationModeRules(timeLimitHours: 8 / 3600);
      final roads = _HeldRoads();
      await _pumpHome(tester, online: false, routes: roads);
      await _frames(tester, const Duration(seconds: 9));
      tester
          .widget<InkWell>(
            find.byKey(const ValueKey<String>('destination-mode-open')),
          )
          .onTap!
          .call();
      await _frames(tester, const Duration(seconds: 1));
      await tester.tap(
          find.byKey(const ValueKey<String>('destination-result-solna')));
      roads.release();
      // Online toward Solna; an Exclusive rises, its road still coming.
      await _frames(tester, const Duration(seconds: 6));
      expect(find.byKey(const ValueKey<String>('exclusive-radar-touch-target')),
          findsOneWidget);
      // The 8 s limit ends Destination mode; then the road comes in.
      await _frames(tester, const Duration(seconds: 3));
      expect(IslandMessages.posted.map((m) => m.title),
          contains(HomeIslandNotices.destinationEnded.title));
      roads.release();
      await _frames(tester, const Duration(seconds: 1));
      final map = tester.widget<CustomGoogleMap>(find.byType(CustomGoogleMap));
      expect(map.polylines!.map((l) => l.polylineId.value),
          contains(OfferRouteLine.coreId));
      expect(find.byKey(const ValueKey<String>('exclusive-radar-touch-target')),
          findsOneWidget);
      await _end(tester);
    });
  });

  group('driver-r4-37: a flick on the Home sheet', () {
    testWidgets('a short fast flick up opens it', (tester) async {
      await _pumpHome(tester, online: false);
      await _frames(tester, const Duration(seconds: 9));
      final panel = tester
          .widget<SlidingUpPanel>(find.byType(SlidingUpPanel).first)
          .controller!;
      expect(panel.panelPosition, lessThan(0.02));
      // 15 px (under the 3 % rule) at 1500 px/s, from the dock's left end.
      await tester.flingFrom(const Offset(30, 790), const Offset(0, -15), 1500);
      await _frames(tester, const Duration(seconds: 1));
      expect(panel.panelPosition, greaterThan(0.98));
      await _end(tester);
    });
  });

  group('driver-u124: Menu and Search with a screen reader while waiting', () {
    testWidgets('a semantic tap on "Finding trips" brings them back', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpHome(tester);
      bool side(SemanticsNode node) =>
          node.tooltip == 'Menu' || node.tooltip == 'Search destination';
      // The demo Exclusive offer passes first.
      await _frames(tester, const Duration(seconds: 20));
      expect(find.byKey(const ValueKey<String>('island-finding')),
          findsOneWidget);
      expect(find.semantics.byPredicate(side), findsNothing,
          reason: 'tucked behind "Finding trips"');
      tester.semantics.tap(find.semantics.byLabel(RegExp('Finding')));
      await _frames(tester, const Duration(milliseconds: 600));
      expect(find.semantics.byPredicate(side), findsExactly(2));
      handle.dispose();
      await _end(tester);
    });
  });

  group('driver-u125: the island\'s money faces', () {
    WaybillRecord receipt(String id, String fare) => WaybillRecord(
      tripId: id,
      statusLabel: 'Completed',
      issuedAt: DateTime.now(),
      fare: fare,
      service: 'Comfort',
      riderName: 'Sara',
      pickup: 'Tegnérgatan',
      dropoff: 'Odengatan',
      source: 'Movera Radar',
      driverName: 'Driver',
      vehicle: 'Car',
      licensePlate: 'ABC 123',
      passengerCapacity: 4,
    );

    /// Two trips today (261,00 kr) and one yesterday.
    Future<void> record() async {
      final history = PrefsTripHistoryRepository();
      await history.archive(receipt('t1', '104,80 kr'));
      await history.archive(receipt('t2', '156,20 kr'));
      await history.archive(receipt('y1', '99,00 kr'),
          completedAt: DateTime.now().subtract(const Duration(days: 1)));
    }

    testWidgets('Home: TODAY is today\'s recorded total', (tester) async {
      await record();
      await _pumpHome(tester, online: false);
      await _frames(tester, const Duration(seconds: 3));
      final launcher = find.byKey(const ValueKey<String>('last-trip-launcher'));
      tester.widget<InkWell>(launcher).onTap!.call();
      await _frames(tester, const Duration(milliseconds: 600));
      expect(find.text('LAST TRIP'), findsOneWidget);
      expect(find.text('126 kr'), findsNothing, reason: 'no sample figure');
      tester.widget<InkWell>(launcher).onTap!.call();
      await _frames(tester, const Duration(milliseconds: 600));
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('183.25 kr'), findsNothing);
      expect(find.text('261,00 kr'), findsOneWidget);
      await _end(tester);
    });

    testWidgets('trip screen: TODAY is today\'s recorded total', (
      tester,
    ) async {
      await record();
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: TripIsland(lastTripLabel: '104,80 kr'),
          ),
        ),
      ));
      final middle = find.byKey(const ValueKey<String>('trip-island-middle'));
      await tester.tap(middle);
      await _frames(tester, const Duration(milliseconds: 600));
      await tester.tap(middle);
      await _frames(tester, const Duration(milliseconds: 600));
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('183.25 kr'), findsNothing);
      expect(find.text('261,00 kr'), findsOneWidget);
      await _end(tester);
    });
  });
}

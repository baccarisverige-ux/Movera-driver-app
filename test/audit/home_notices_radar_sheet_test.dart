import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';
import 'package:movera/core/session/driver_route_observer.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/session/driving_time_clock.dart';
import 'package:movera/presentation/driver/home/components/home_island_notices.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

// Wave 3 (D3.2, part a): Home's island notices, Radar, map sheet.
// - driver-u110 / driver-u126: a notice posted while a screen covers
//   Home waits for Home instead of playing on its hidden island.
// - driver-65: the app inactive but on screen (a call banner, Control
//   Center, a system dialog) keeps Home's online face and its offers.
// - driver-u113: system Back on "Unresolved trip" keeps the dialog and
//   the saved trip; only "Close trip" closes it.

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
    IslandMessages.reset();
    ScheduledRideStore.reset();
    ExclusiveAnswers.instance.reset();
  });
  tearDown(() {
    DriverOfferRules.current = const DriverOfferRules();
    DrivingTimeClock.instance.load(worked: Duration.zero);
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
}

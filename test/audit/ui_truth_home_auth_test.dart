// Wave 5 D5.2 (UI truth), part b: Home, onboarding and profile show only
// what really happened.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/admin/trip_rules_admin_config.dart';
import 'package:movera/core/dispatch/destination_mode_session.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/prefs_active_ride_repository.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/auth/additional%20detail/screens/upload%20document/take%20id%20photo/take_id_photo.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/profile/profile.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:movera/widgets/led_count_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

/// [first] as the app's first route, inside the app's runtime scope, with
/// [push] opened on top of it.
Future<void> _app(WidgetTester tester, Widget first, [Widget? push]) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(DriverRuntimeScope(
    session: DriverSessionController(),
    homeBuilder: () => const Scaffold(body: Text('Driver home')),
    child: ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => MaterialApp(navigatorKey: navigator, home: first),
    ),
  ));
  if (push != null) {
    navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => push));
  }
  await tester.pumpAndSettle();
}

RideOffer _offer(String id, {OfferSource source = OfferSource.system}) =>
    RideOffer(
      id: id,
      category: 'Comfort',
      fare: Money(minorUnits: 8810),
      rating: '4.92',
      riderName: 'Sara',
      pickupMinutes: 3,
      pickupKm: 0.9,
      tripMinutes: 12,
      tripKm: 5.2,
      pickup: 'Tegnérgatan, Stockholm',
      dropoff: 'Odengatan, Stockholm',
      pickupPosition: const GeoPoint(59.3335, 18.0610),
      dropoffPosition: const GeoPoint(59.3428, 18.0475),
      isNearby: true,
      followsDestination: true,
      source: source,
    );

/// Dispatch with a fixed feed and nothing else.
class _Dispatch implements DispatchRepository {
  _Dispatch(this.offers);
  final List<RideOffer> offers;
  @override
  Stream<List<RideOffer>> watchNearbyOffers({
    bool destinationModeActive = false,
  }) => Stream<List<RideOffer>>.multi((sink) => sink.addSync(offers),
      isBroadcast: true);
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
  Future<ClaimResult> claimOffer(String offerId) async =>
      const ClaimResult.unavailable();
  @override
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async =>
      false;
  @override
  Stream<OfferWithdrawal> watchWithdrawals() => const Stream.empty();
}

Future<void> _frames(WidgetTester tester, [int count = 12]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Home on a phone with [activeRides] as its saved-trip storage.
Future<void> _home(WidgetTester tester, ActiveRideRepository? activeRides,
    {WaybillRepository? waybills, DispatchRepository? dispatch}) async {
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
  await tester.binding.setSurfaceSize(const Size(375, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(LayoutViewport(
    child: ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      useInheritedMediaQuery: true,
      builder: (_, __) => MaterialApp(
        home: DriverHome(
          sessionController: DriverSessionController(),
          activeRideRepository: activeRides,
          waybillRepository: waybills,
          dispatchRepository: dispatch,
        ),
      ),
    ),
  ));
  await _frames(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('driver-r3-10: "Return to home" at the end of onboarding opens '
      'Home, not the Sign-in screen it started from', (tester) async {
    await _app(tester, const Scaffold(body: Text('Sign in')),
        const TakeIdPhoto());
    await tester.tap(find.byKey(const ValueKey('id-preview-return')));
    await tester.pumpAndSettle();
    expect(find.text('Driver home'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('driver-81: Profile does not flash "Vehicle data unavailable" '
      'while the vehicle is being read', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: DriverProfile()));
    expect(find.text('Vehicle data unavailable'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('Vehicle data unavailable'), findsNothing);
    expect(find.text('Mercedes-Benz E 220'), findsOneWidget);
  });

  testWidgets('driver-u112: blocked storage does not report a saved trip and '
      'the driver can still go online', (tester) async {
    await _home(tester, PrefsActiveRideRepository(
        load: () => Future.error(StateError('SecurityError: storage blocked'))));
    expect(find.text('The saved trip could not be opened.'), findsNothing);
    expect(find.textContaining('could not be opened, so no saved trip'),
        findsOneWidget);
    tester
        .widget<GestureDetector>(
            find.byKey(const ValueKey<String>('trip-radar-touch-target')))
        .onTap!
        .call();
    await _frames(tester);
    expect(find.text('Finish or close the saved trip before going online.'),
        findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets("driver-u114: a restored trip's waybill is issued when the "
      'trip was accepted, not at the last background save', (tester) async {
    final now = DateTime.now();
    final accepted = now.subtract(const Duration(minutes: 38));
    final waybills = InMemoryWaybillRepository.instance..reset();
    addTearDown(waybills.reset);
    final store = MemoryActiveRideRepository();
    await store.save(PersistedActiveRide(
      tripId: 'restored-1',
      stage: ActiveRideStage.headingToPickup,
      riderName: 'Angelica',
      pickupLat: 59.3326, pickupLng: 18.0649,
      dropoffLat: 59.3428, dropoffLng: 18.0475,
      acceptedAt: accepted,
      savedAt: now.subtract(const Duration(minutes: 2)),
    ));
    await _home(tester, store, waybills: waybills);
    expect(waybills.current?.tripId, 'restored-1');
    expect(waybills.current?.issuedAt, accepted);
    await tester.pumpWidget(const SizedBox());
    await _frames(tester, 2);
  });

  test('driver-u123: "Destination mode until" is when the time limit ends '
      'the mode, not the arrival time; no limit, no end time', () {
    final confirmed = DateTime(2026, 10, 21, 10);
    final session = DestinationModeSession(now: () => confirmed)
      ..started(address: 'Kista centrum');
    expect(session.endsAt(), DateTime(2026, 10, 21, 12));
    expect(
        session.endsAt(
            rules: const DestinationModeRules(timeLimitHours: .25)),
        DateTime(2026, 10, 21, 10, 15));
    expect(
        session.endsAt(rules: const DestinationModeRules(timeLimitOn: false)),
        isNull);
  });

  testWidgets("driver-u134: the deck's 'All offers' count leaves out the "
      'admin direct assign, like the Radar list', (tester) async {
    IslandMessages.reset();
    ScheduledRideStore.reset();
    // The demo reservation's own Exclusive offer stays out of it.
    ScheduledRideStore.answer('Gamla vägen, Stockholm', accepted: false);
    await _home(tester, null, dispatch: _Dispatch([
      _offer('radar-a'),
      _offer('radar-b'),
      _offer('admin-assign', source: OfferSource.admin),
    ]));
    tester
        .widget<GestureDetector>(
            find.byKey(const ValueKey<String>('trip-radar-touch-target')))
        .onTap!
        .call();
    // Radar trips are dealt 3 s + the Exclusive accept time after Radar
    // is live.
    await _frames(tester, 220);
    final badge = find.descendant(
        of: find.byKey(const ValueKey<String>('radar-home-all-offers')),
        matching: find.byType(LedCountBadge));
    expect(tester.widget<LedCountBadge>(badge).count, 2);
    await tester.pumpWidget(const SizedBox());
  });
}

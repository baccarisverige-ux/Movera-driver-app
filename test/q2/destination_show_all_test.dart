// Q2 (owner 2026-11-07): "Show all offres with badge on your way for offres
// that is on the destination set by driver". Destination mode never hides an
// offer; an offer whose drop-off is on the way gets the badge
// « Sur votre chemin » (DriverTexts.offerOnYourWay). Finding A6
// (plan/finders-2026-11-07/A.md): an off-route Exclusive was hidden on Home
// (home_offer_radar.dart `!_directOfferFollowsDestination(offer) ||`), the
// server still counted it, and it expired as missed.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/dispatch/demo_dispatch_repository.dart';
import 'package:movera/core/dispatch/destination_mode_session.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/session/driver_route_observer.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/home/components/destination_island.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

class _Dispatch implements DispatchRepository {
  final _nearby = StreamController<List<RideOffer>>.broadcast();
  List<RideOffer> offers = const [];
  final List<String> declines = <String>[];

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
  Future<ClaimResult> claimOffer(String offerId) async =>
      const ClaimResult.unavailable();

  @override
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async {
    declines.add(offerId);
    return true;
  }

  @override
  Stream<OfferWithdrawal> watchWithdrawals() =>
      const Stream<OfferWithdrawal>.empty();
}

Future<void> _frames(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

// Solna, north of the driver (Home starts at 59.3293, 18.0686).
const _destination = GeoPoint(59.3600, 18.0000);

// The island shows the destination ("Solna Torg · …") while it is on.
bool _homeHasDestination(WidgetTester tester) =>
    find.byType(DigitalDestinationFace).evaluate().isNotEmpty;

/// Home online with destination mode on (taken over from the session, as
/// after a trip screen set it, driver-u65).
Future<_Dispatch> _onlineWithDestination(WidgetTester tester) async {
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
  await tester.binding.setSurfaceSize(const Size(375, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final dispatch = _Dispatch();
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    LayoutViewport(
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        useInheritedMediaQuery: true,
        builder: (_, __) => MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [driverRouteObserver],
          home: DriverHome(
            sessionController: DriverSessionController(),
            dispatchRepository: dispatch,
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
  await _frames(tester, const Duration(milliseconds: 1500));

  DestinationModeSession.instance.started(
    address: 'Solna Torg, Solna',
    position: _destination,
  );
  unawaited(
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
    ),
  );
  await _frames(tester, const Duration(milliseconds: 600));
  navigator.currentState!.pop();
  await _frames(tester, const Duration(milliseconds: 1500));
  expect(_homeHasDestination(tester), isTrue, reason: 'destination mode on');
  return dispatch;
}

Future<bool> _shows(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 120 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return finder.evaluate().isNotEmpty;
}

Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await _frames(tester, const Duration(seconds: 2));
}

// Drop-off in Hammarby sjöstad: south-east, away from Solna.
const RideOffer _offRoute = DemoAdminOffers.directAssign;

// Drop-off next to Solna Torg: on the driver's way.
const RideOffer _onRoute = RideOffer(
  id: 'admin-assign-solna',
  riderName: 'Karim',
  riderTrips: 64,
  category: 'Movera',
  fare: Money(minorUnits: 12860, currency: 'SEK'),
  source: OfferSource.admin,
  rating: '4.88',
  pickupMinutes: 3,
  pickupKm: 0.8,
  tripMinutes: 14,
  tripKm: 7.9,
  pickup: 'Tegnérgatan 8, Stockholm',
  dropoff: 'Solna Torg, Solna',
  pickupPosition: GeoPoint(59.3378, 18.0570),
  dropoffPosition: GeoPoint(59.3590, 18.0010),
  isNearby: true,
  followsDestination: true,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    ScheduledRideStore.reset();
    ExclusiveAnswers.instance.reset();
    DestinationModeSession.instance = DestinationModeSession();
  });

  testWidgets('Q2: an Exclusive whose drop-off is NOT on the way still shows '
      'in destination mode, without the "On your way" badge', (tester) async {
    final dispatch = await _onlineWithDestination(tester);
    dispatch.publish([_offRoute]);
    final card = find.byKey(
      const ValueKey<String>('exclusive-offer-card-admin-assign-1'),
    );
    expect(
      await _shows(tester, card),
      isTrue,
      reason: 'destination mode must not hide an Exclusive offer',
    );
    expect(find.text('On your way'), findsNothing);
    tester.takeException();
    await _leave(tester);
  });

  testWidgets('Q2: an Exclusive whose drop-off is on the way shows with the '
      '"On your way" badge', (tester) async {
    final dispatch = await _onlineWithDestination(tester);
    dispatch.publish([_onRoute]);
    final card = find.byKey(
      const ValueKey<String>('exclusive-offer-card-admin-assign-solna'),
    );
    expect(await _shows(tester, card), isTrue);
    expect(find.text('On your way'), findsOneWidget);
    tester.takeException();
    await _leave(tester);
  });
}

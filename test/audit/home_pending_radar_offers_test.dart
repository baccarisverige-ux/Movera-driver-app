import 'package:movera/core/money/money.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/safety/ride_check_gate.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:movera/widgets/movera_radar_orb.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

// Wave 3 (D3.1): a Radar trip that waits off screen (pending) behind a
// Ride check, and leaves dispatch before the check is answered.
// - driver-u129: gone from the feed, with Home paused during its 2.8 s
//   removal, it must not land on the deck as a "Taken" card for good.
// - driver-u132: withdrawn, it must not leave "Trip found / NEW" on the
//   radar with no trip, which also held later Exclusive offers back.

RideOffer _trip(String id) => RideOffer(
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
);

class _Dispatch implements DispatchRepository {
  final _nearby = StreamController<List<RideOffer>>.broadcast();
  final _withdrawals = StreamController<OfferWithdrawal>.broadcast();
  List<RideOffer> offers = const [];

  void publish(List<RideOffer> next) {
    offers = List<RideOffer>.unmodifiable(next);
    _nearby.add(offers);
  }

  /// Contract `offer_withdrawn`: first the reason, then the list without it.
  void withdraw(String id, OfferGoneReason reason) {
    _withdrawals.add(OfferWithdrawal(offerId: id, reason: reason));
    publish([
      for (final offer in offers)
        if (offer.id != id) offer,
    ]);
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
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async =>
      false;

  @override
  Stream<OfferWithdrawal> watchWithdrawals() => _withdrawals.stream;
}

Future<void> _frames(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

/// The Home radar orb (not an Exclusive or reservation orb).
MoveraRadarOrb _orb(WidgetTester tester) => tester
    .widgetList<MoveraRadarOrb>(find.byType(MoveraRadarOrb))
    .where(
      (orb) =>
          orb.touchKey == const ValueKey<String>('trip-radar-touch-target'),
    )
    .single;

const _card = ValueKey<String>('radar-offer-card-waiting');
const _deck = ValueKey<String>('radar-home-deck');

/// Online with one Radar trip in dispatch, parked as pending behind a
/// Ride check opened just before the demo deals it onto the deck.
Future<_Dispatch> _pumpPending(WidgetTester tester) async {
  // The demo reservation's own Exclusive offer (40 s in) stays out of it.
  ScheduledRideStore.answer('Gamla vägen, Stockholm', accepted: false);
  final dispatch = _Dispatch()..offers = [_trip('waiting')];
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
  // Radar trips are dealt 3 s + the Exclusive accept time after Radar is
  // live (about 19.6 s in): the Ride check opens just before.
  await _frames(tester, const Duration(milliseconds: 19000));
  RideCheckGate.set(true);
  await _frames(tester, const Duration(milliseconds: 1500));
  expect(find.byKey(_card), findsNothing, reason: 'held behind the check');
  expect(_orb(tester).offer, isTrue, reason: 'one trip waits');
  return dispatch;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    ScheduledRideStore.reset();
    RideCheckGate.set(false);
  });
  tearDown(() => RideCheckGate.set(false));

  testWidgets('driver-u132: a withdrawn waiting trip leaves no "Trip found" '
      'behind, and a later Exclusive offer still comes', (tester) async {
    final dispatch = await _pumpPending(tester);
    dispatch.withdraw('waiting', OfferGoneReason.claimedElsewhere);
    await _frames(tester, const Duration(milliseconds: 300));
    RideCheckGate.set(false);
    await _frames(tester, const Duration(seconds: 1));
    final orb = _orb(tester);
    expect(orb.offer, isFalse, reason: 'no trip waits: ${orb.title}');
    expect(find.byKey(_deck), findsNothing);
    // The demo's second Exclusive offer comes 50 s after Radar went live
    // unless Home thinks Radar trips are waiting.
    await _frames(tester, const Duration(seconds: 32));
    expect(
      find.byKey(
        const ValueKey<String>('exclusive-offer-card-home-direct-expanded'),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('driver-u129: a waiting trip that left dispatch while Home '
      'was paused never becomes a "Taken" card', (tester) async {
    final dispatch = await _pumpPending(tester);
    // Dispatch drops it from the feed; the driver opens another screen
    // for a moment within the 2.8 s it would take to leave.
    dispatch.publish(const <RideOffer>[]);
    await _frames(tester, const Duration(milliseconds: 500));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await _frames(tester, const Duration(milliseconds: 300));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _frames(tester, const Duration(milliseconds: 300));
    // The Ride check is answered.
    RideCheckGate.set(false);
    await _frames(tester, const Duration(seconds: 3));
    expect(find.byKey(_card), findsNothing);
    expect(find.byKey(_deck), findsNothing);
    expect(_orb(tester).offer, isFalse, reason: 'dispatch has no trips');
    await _frames(tester, const Duration(seconds: 25));
    expect(find.byKey(_card), findsNothing, reason: 'nor later');
    expect(find.byKey(_deck), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}

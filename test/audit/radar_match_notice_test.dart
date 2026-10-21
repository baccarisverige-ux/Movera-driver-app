import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/ride%20requests/ride_requests.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

// The Radar list's match banner.
// driver-u161: the "Could not match" banner after a network error clears
// by itself, like the other banners, so Back and Refresh under it work.
// driver-89: another trip withdrawn while a won Match is opening its trip
// does not cancel the opening: the won trip opens.

RideOffer _offer(String id, double km) => RideOffer(
  id: id,
  category: 'Comfort',
  fare: const Money(minorUnits: 10000),
  rating: '4.9',
  pickupMinutes: 2,
  pickupKm: km,
  tripMinutes: 10,
  tripKm: 5,
  pickup: 'Pickup $id, Stockholm',
  dropoff: 'Dropoff, Stockholm',
  pickupPosition: const GeoPoint(59.3279, 18.0615),
  dropoffPosition: const GeoPoint(59.3326, 18.0649),
  isNearby: true,
  followsDestination: true,
);

/// Dispatch whose claims and withdrawals the test sends.
class _Dispatch implements DispatchRepository {
  final withdrawals = StreamController<OfferWithdrawal>.broadcast();
  final claims = <Completer<ClaimResult>>[];
  final offers = [_offer('a', 1), _offer('b', 2)];

  @override
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async =>
      false;

  @override
  Stream<OfferWithdrawal> watchWithdrawals() => withdrawals.stream;

  @override
  Stream<List<RideOffer>> watchNearbyOffers({
    bool destinationModeActive = false,
  }) => Stream.value(offers);

  @override
  Stream<List<RideOffer>> watchNextTripOffers() => const Stream.empty();

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
}

Future<void> _mount(
  WidgetTester tester,
  _Dispatch dispatch, {
  void Function(bool)? onClose,
}) async {
  SharedPreferences.setMockInitialValues({});
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
  await tester.binding.setSurfaceSize(const Size(375, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => MaterialApp(
        home: RideRequests(
          dispatchRepository: dispatch,
          onCloseRides: onClose,
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _tapMatch(WidgetTester tester, String id) async {
  final match = find.byKey(ValueKey<String>('radar-match-$id'));
  await tester.ensureVisible(match);
  await tester.tap(match);
  await tester.pump();
}

const _notice = ValueKey<String>('radar-match-notice');

void main() {
  testWidgets('driver-u161: the network error banner clears and Back works', (
    tester,
  ) async {
    final dispatch = _Dispatch();
    var closes = 0;
    await _mount(tester, dispatch, onClose: (_) => closes++);
    await _tapMatch(tester, 'a');
    dispatch.claims.single.complete(const ClaimResult.networkError());
    await tester.pump();
    expect(find.text('Could not match trip. Try again.'), findsOneWidget);
    expect(find.byKey(_notice), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(_notice), findsNothing);
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    expect(closes, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('driver-89: another trip withdrawn while the won trip opens', (
    tester,
  ) async {
    final dispatch = _Dispatch();
    await _mount(tester, dispatch);
    await _tapMatch(tester, 'a');
    dispatch.claims.single.complete(ClaimResult.success(dispatch.offers[0]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Trip matched'), findsOneWidget);

    dispatch.withdrawals.add(const OfferWithdrawal(
      offerId: 'b',
      reason: OfferGoneReason.claimedElsewhere,
    ));
    await tester.pump(const Duration(milliseconds: 100));
    // The won Match keeps its banner.
    expect(find.text('Trip matched'), findsOneWidget);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    tester.takeException();
    expect(find.byType(AcceptRide, skipOffstage: false), findsOneWidget);
    expect(find.byType(AcceptRide, skipOffstage: false).evaluate().single
        .widget, isA<AcceptRide>().having((t) => t.offerId, 'offerId', 'a'));
    tester.takeException();
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    tester.takeException();
  });
}

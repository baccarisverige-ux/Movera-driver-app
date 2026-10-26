import 'package:movera/core/money/money.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/demo_dispatch_repository.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/ride%20requests/ride_requests.dart';

const _offer = RideOffer(
  id: 'controlled-offer',
  category: 'Comfort',
  fare: Money(minorUnits: 10000),
  rating: '4.9',
  pickupMinutes: 2,
  pickupKm: 1,
  tripMinutes: 10,
  tripKm: 5,
  pickup: 'Pickup, Stockholm',
  dropoff: 'Dropoff, Stockholm',
  pickupPosition: GeoPoint(59.3279, 18.0615),
  dropoffPosition: GeoPoint(59.3326, 18.0649),
  isNearby: true,
  followsDestination: true,
);

class _ControlledDispatch implements DispatchRepository {
  @override
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async =>
      false;

  @override
  Stream<OfferWithdrawal> watchWithdrawals() =>
      const Stream<OfferWithdrawal>.empty();

  final requests = <Completer<ClaimResult>>[];
  @override
  Stream<List<RideOffer>> watchNearbyOffers({
    bool destinationModeActive = false,
  }) => Stream.value(const [_offer]);
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
    final response = Completer<ClaimResult>();
    requests.add(response);
    return response.future;
  }
}

Future<void> _mount(WidgetTester tester, _ControlledDispatch dispatch) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(home: RideRequests(dispatchRepository: dispatch)),
  );
  await tester.pump();
}

Future<void> _tapMatch(WidgetTester tester) async {
  final match = find.byKey(
    const ValueKey<String>('radar-match-controlled-offer'),
  );
  await tester.ensureVisible(match);
  await tester.tap(match);
  await tester.pump();
}

void main() {
  testWidgets('claim from the previous session cannot consume a reset offer', (
    tester,
  ) async {
    final dispatch = DemoDispatchRepository(
      claimDelay: const Duration(seconds: 1),
    );
    final oldClaim = dispatch.claimOffer('nearby-1');
    dispatch.reset();
    await tester.pump(const Duration(seconds: 1));
    expect((await oldClaim).outcome, ClaimOutcome.unavailable);
    final freshClaim = dispatch.claimOffer('nearby-1');
    await tester.pump(const Duration(seconds: 1));
    expect((await freshClaim).outcome, ClaimOutcome.success);
    dispatch.dispose();
  });

  testWidgets('disposed dispatch rejects a pending claim', (tester) async {
    final dispatch = DemoDispatchRepository(
      claimDelay: const Duration(seconds: 1),
    );
    final claim = dispatch.claimOffer('nearby-1');
    dispatch.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect((await claim).outcome, ClaimOutcome.unavailable);
  });

  testWidgets('two simultaneous claims produce one winner', (tester) async {
    final dispatch = DemoDispatchRepository(
      claimDelay: const Duration(seconds: 1),
    );
    final claims = [
      dispatch.claimOffer('nearby-1'),
      dispatch.claimOffer('nearby-1'),
    ];
    await tester.pump(const Duration(seconds: 1));
    final results = await Future.wait(claims);
    expect(results.where((r) => r.isSuccess), hasLength(1));
    expect(
      results.where((r) => r.outcome == ClaimOutcome.unavailable),
      hasLength(1),
    );
    dispatch.dispose();
  });

  testWidgets('a thrown claim error releases Matching for retry', (
    tester,
  ) async {
    final dispatch = _ControlledDispatch();
    await _mount(tester, dispatch);
    await _tapMatch(tester);
    dispatch.requests.single.completeError(
      StateError('Transport disconnected'),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Matching trip'), findsNothing);
    expect(find.text('Could not match trip. Try again.'), findsOneWidget);
    await _tapMatch(tester);
    expect(dispatch.requests, hasLength(2));
    dispatch.requests.last.complete(const ClaimResult.unavailable());
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final result in [
    const ClaimResult.expired(),
    const ClaimResult.unavailable(),
  ]) {
    testWidgets(
      '${result.outcome.name} during matching never opens an active trip',
      (tester) async {
        final dispatch = _ControlledDispatch();
        await _mount(tester, dispatch);
        await _tapMatch(tester);
        // A second tap must not dispatch another claim while the first is pending.
        await tester.tap(
          find.byKey(const ValueKey<String>('radar-match-controlled-offer')),
          warnIfMissed: false,
        );
        await tester.pump();
        expect(dispatch.requests, hasLength(1));
        dispatch.requests.single.complete(result);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(AcceptRide), findsNothing);
        expect(find.text('No longer available'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

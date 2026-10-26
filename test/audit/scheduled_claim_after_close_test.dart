import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';

// driver-94: a reservation claim that dispatch answers after the driver
// left Scheduled rides still moves the ride to Accepted. It is not left
// under Requests, to be reported "No longer available" on the next Accept.

/// Dispatch whose claims the test answers.
class _Dispatch implements DispatchRepository {
  final claims = <String, Completer<ClaimResult>>{};

  @override
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async =>
      false;

  @override
  Stream<OfferWithdrawal> watchWithdrawals() =>
      const Stream<OfferWithdrawal>.empty();

  @override
  Stream<List<RideOffer>> watchNearbyOffers({
    bool destinationModeActive = false,
  }) => const Stream<List<RideOffer>>.empty();

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
  Future<ClaimResult> claimOffer(String offerId) =>
      (claims[offerId] = Completer<ClaimResult>()).future;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Opens Scheduled rides from a host screen, accepts Gamla vägen and goes
/// Back while dispatch has the claim.
Future<void> _acceptThenLeave(WidgetTester tester, _Dispatch dispatch) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  ScheduledRidesScreen(dispatchRepository: dispatch),
            ),
          ),
          child: const Text('Open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Gamla vägen, Stockholm').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Accept  •  95,06 kr'));
  // The card spins while dispatch has the claim.
  await _settle(tester);
  expect(dispatch.claims.keys, [demoReservationId]);
  await tester.tap(find.byTooltip('Back'));
  await _settle(tester);
  expect(find.byType(ScheduledRidesScreen), findsNothing);
}

void main() {
  setUp(() {
    ScheduledRideStore.reset();
    IslandMessages.reset();
  });
  tearDown(ScheduledRideStore.reset);

  testWidgets('a claim won after the list closed moves the ride to Accepted', (
    tester,
  ) async {
    final dispatch = _Dispatch();
    await _acceptThenLeave(tester, dispatch);
    dispatch.claims[demoReservationId]!.complete(
      ClaimResult.success(RideOffer.reservation(demoReservationRequest)),
    );
    await tester.pumpAndSettle();
    expect(ScheduledRideStore.isOpen(demoReservationId), isFalse);
    expect(
      ScheduledRideStore.upcoming.map((ride) => ride.pickupAddress),
      contains('Gamla vägen, Stockholm'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a claim lost after the list closed leaves the requests', (
    tester,
  ) async {
    final dispatch = _Dispatch();
    await _acceptThenLeave(tester, dispatch);
    dispatch.claims[demoReservationId]!.complete(
      const ClaimResult.alreadyClaimed(),
    );
    await tester.pumpAndSettle();
    expect(ScheduledRideStore.isOpen(demoReservationId), isFalse);
    expect(
      ScheduledRideStore.upcoming.map((ride) => ride.pickupAddress),
      isNot(contains('Gamla vägen, Stockholm')),
    );
    expect(tester.takeException(), isNull);
  });
}

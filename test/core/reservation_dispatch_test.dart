import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/demo_dispatch_repository.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';

DemoDispatchRepository _dispatch({
  String losingOfferId = 'nearby-2',
  Duration reservationRadarDelay = const Duration(days: 1),
}) {
  final dispatch = DemoDispatchRepository(
    claimDelay: Duration.zero,
    newOfferDelay: const Duration(days: 1),
    externalClaimDelay: const Duration(days: 1),
    losingOfferId: losingOfferId,
    reservationRadarDelay: reservationRadarDelay,
  );
  addTearDown(dispatch.dispose);
  return dispatch;
}

void main() {
  test('the demo reservation has its timings in one place', () {
    expect(demoReservationRequest.id, demoReservationId);
    expect(ReservationDemoTimings.homePopupAfter, isNot(Duration.zero));
    expect(
      ReservationDemoTimings.nearPickupAfter,
      greaterThan(ReservationDemoTimings.homePopupAfter),
    );
  });

  test('a reservation goes to the first claim; later claims lose', () async {
    final dispatch = _dispatch();
    final first = await dispatch.claimOffer(demoReservationId);
    expect(first.outcome, ClaimOutcome.success);
    expect(first.offer?.id, demoReservationId);
    expect(first.offer?.isReservation, isTrue);

    final second = await dispatch.claimOffer(demoReservationId);
    expect(second.outcome, ClaimOutcome.unavailable);
  });

  test('another driver can win the reservation (simultaneous claim)', () async {
    final dispatch = _dispatch(losingOfferId: demoReservationId);
    final result = await dispatch.claimOffer(demoReservationId);
    expect(result.outcome, ClaimOutcome.alreadyClaimed);
    // Decided once: nobody can claim it after that.
    expect(
      (await dispatch.claimOffer(demoReservationId)).outcome,
      ClaimOutcome.unavailable,
    );
  });

  test('close to pickup an untaken reservation joins the Radar trips', () async {
    final dispatch = _dispatch(
      reservationRadarDelay: const Duration(milliseconds: 5),
    );
    final events = <List<RideOffer>>[];
    final sub = dispatch.watchNearbyOffers().listen(events.add);
    addTearDown(sub.cancel);
    await Future<void>.delayed(const Duration(milliseconds: 1));
    expect(events.last.any((offer) => offer.isReservation), isFalse);

    await Future<void>.delayed(const Duration(milliseconds: 20));
    final reservation = events.last.singleWhere((o) => o.id == demoReservationId);
    expect(reservation.isReservation, isTrue);
    expect(reservation.reservationTime, '07:40');
    expect(reservation.isNearby, isTrue);
    expect(reservation.fare, '126,75 kr');

    // Taken from Radar: it leaves Radar at once.
    expect(
      (await dispatch.claimOffer(demoReservationId)).outcome,
      ClaimOutcome.success,
    );
    await Future<void>.delayed(Duration.zero);
    expect(events.last.any((o) => o.id == demoReservationId), isFalse);
  });

  test('a reservation taken before pickup never joins Radar', () async {
    final dispatch = _dispatch(
      reservationRadarDelay: const Duration(milliseconds: 5),
    );
    await dispatch.claimOffer(demoReservationId);
    final events = <List<RideOffer>>[];
    final sub = dispatch.watchNearbyOffers().listen(events.add);
    addTearDown(sub.cancel);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
      events.expand((offers) => offers).any((o) => o.isReservation),
      isFalse,
    );
  });

  test('a cancelled reservation can be claimed again', () async {
    final dispatch = _dispatch();
    expect(
      (await dispatch.claimOffer(demoReservationId)).outcome,
      ClaimOutcome.success,
    );
    dispatch.releaseReservation(demoReservationId);
    expect(
      (await dispatch.claimOffer(demoReservationId)).outcome,
      ClaimOutcome.success,
    );
    // Unknown ids stay unknown.
    dispatch.releaseReservation('nope');
    expect(
      (await dispatch.claimOffer('nope')).outcome,
      ClaimOutcome.unavailable,
    );
  });
}

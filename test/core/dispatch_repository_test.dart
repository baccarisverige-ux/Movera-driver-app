import 'package:movera/core/money/money.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/demo_dispatch_repository.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';

void main() {
  test('demo dispatch wins nearby-1 and loses nearby-2', () async {
    final dispatch = DemoDispatchRepository(claimDelay: Duration.zero);
    addTearDown(dispatch.dispose);

    final won = await dispatch.claimOffer('nearby-1');
    expect(won.outcome, ClaimOutcome.success);
    expect(won.offer?.id, 'nearby-1');

    final lost = await dispatch.claimOffer('nearby-2');
    expect(lost.outcome, ClaimOutcome.alreadyClaimed);
    expect(lost.offer, isNull);

    final missing = await dispatch.claimOffer('does-not-exist');
    expect(missing.outcome, ClaimOutcome.unavailable);
  });

  test(
    'demo dispatch snapshot starts with nearby-1..3 and queues 4-7',
    () async {
      final dispatch = DemoDispatchRepository(
        claimDelay: Duration.zero,
        newOfferDelay: const Duration(days: 1),
        externalClaimDelay: const Duration(days: 1),
      );
      addTearDown(dispatch.dispose);

      final first = await dispatch.watchNearbyOffers().first;
      expect(first.map((offer) => offer.id), [
        'nearby-1',
        'nearby-2',
        'nearby-3',
      ]);
    },
  );

  test(
    'demo dispatch later releases queued offers and drops nearby-3',
    () async {
      final dispatch = DemoDispatchRepository(
        claimDelay: Duration.zero,
        newOfferDelay: const Duration(milliseconds: 5),
        externalClaimDelay: const Duration(milliseconds: 10),
      );
      addTearDown(dispatch.dispose);

      final events = <List<String>>[];
      final sub = dispatch.watchNearbyOffers().listen((offers) {
        events.add(offers.map((offer) => offer.id).toList());
      });
      addTearDown(sub.cancel);

      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(events, isNotEmpty);
      expect(events.first, ['nearby-1', 'nearby-2', 'nearby-3']);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(events.last, [
        'nearby-1',
        'nearby-2',
        'nearby-4',
        'nearby-5',
        'nearby-6',
        'nearby-7',
        'nearby-8',
        'nearby-9',
        'nearby-10',
        'ridecheck-demo-far-dropoff',
        'ridecheck-demo-long-stop',
      ]);
    },
  );

  test('R9: a cash reservation keeps its cash to collect as a trip', () {
    final plan = DemoReservations.plan;
    addTearDown(() {
      DemoReservations.plan = plan;
      DemoReservations.reset();
    });
    DemoReservations.plan = DemoReservationPlan.app;
    DemoReservations.reset();
    final airport = DemoReservations.airport!;
    expect(airport.paidByCash, isTrue);
    final offer = RideOffer.reservation(airport);
    expect(offer.payment, 'Cash');
    expect(offer.fare, const Money(minorUnits: 24840));
    expect(offer.fareLabel, '248,40 kr');
    expect(offer.cashToCollectLabel, '300,00 kr');
    // A card reservation has none.
    expect(RideOffer.reservation(DemoReservations.main).cashToCollect, isNull);
  });
}

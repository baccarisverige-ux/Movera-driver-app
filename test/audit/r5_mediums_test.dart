import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/notifications/driver_notifications.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/core/admin/pickup_pay_config.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/dispatch/pickup_pay.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/widgets/radar_offer_card.dart';

// Round-5 medium audit bugs (FIX_PLAN Wave 6b), one group per bug.

Map<String, dynamic> _wireOffer() => {
  'offerId': 'o1',
  'tripId': 'trip-o1',
  'kind': 'radar',
  'status': 'open',
  'version': 1,
  'expiresAt': '2026-10-20T12:00:15Z',
  'fare': {'amountMinor': 20000, 'currency': 'SEK'},
  'driverEarnings': {'amountMinor': 17000, 'currency': 'SEK'},
  'pickupPay': {'amountMinor': 900, 'currency': 'SEK'},
  'source': 'system',
  'pickup': {'address': 'Tegnérgatan, Stockholm', 'lat': 59.3335, 'lng': 18.0610},
  'dropoff': {'address': 'Odengatan, Stockholm', 'lat': 59.3428, 'lng': 18.0475},
  'categoryId': 'comfort',
  'paymentMethod': 'card',
  'pickupEtaSeconds': 180,
  'pickupMeters': 900,
  'tripSeconds': 720,
  'tripMeters': 5200,
};

void main() {
  group('driver-r5-1', () {
    test("an API offer's card shows the server's driverEarnings and "
        'pickupPay', () {
      final offer = OfferWire.parse(_wireOffer());
      expect(offer.driverEarnings, Money.ore(17000));
      expect(offer.pickupPay, Money.ore(900));
      // The server's pickup pay, even where the local rules have none.
      final quote = PickupPayCalculator.quote(
        category: offer.category,
        kind: PickupPayOfferKind.radar,
        leg: const PickupLeg(km: 0.2, minutes: 1),
        serverPay: offer.pickupPay,
      );
      expect(quote.pay, Money.ore(900));
      final view = RadarOfferView(
        id: offer.id,
        category: offer.category,
        payment: offer.payment,
        rating: offer.rating,
        fare: offer.fareLabel,
        pickupMinutes: offer.pickupMinutes,
        pickupKm: offer.pickupKm,
        tripMinutes: offer.tripMinutes,
        tripKm: offer.tripKm,
        pickup: offer.pickup,
        dropoff: offer.dropoff,
        driverEarnings: offer.driverEarnings?.formatted,
      );
      // Net-fare card: 'Your share' is the server's 170 kr, not 75 % of 200.
      expect(view.shownFare(const OfferCardDetails(netFare: true)),
          '170,00 kr');
      expect(view.shownFare(const OfferCardDetails()), '200,00 kr');
    });
  });

  group('driver-r5-14', () {
    test('a cash rider with pickup pay still pays the fare without the '
        'Movera bonus', () {
      final quote = PickupPayQuote(
        pay: Money.ore(1300),
        leg: const PickupLeg(km: 4, minutes: 6),
      );
      final terms = quote.termsOf(
        fare: '152,40 kr',
        driverBonus: Money.ore(4000),
        paidByCash: true,
      );
      expect(terms.fare, '165,40 kr');
      expect(terms.driverBonus, Money.ore(5300));
      // 152,40 kr includes Movera's 40 kr bonus: the rider pays 112,40 kr.
      expect(terms.cashToCollect, '112,40 kr');
      // A server cash amount still wins.
      expect(
        quote
            .termsOf(
              fare: '152,40 kr',
              driverBonus: Money.ore(4000),
              cashToCollect: '120,00 kr',
              paidByCash: true,
            )
            .cashToCollect,
        '120,00 kr',
      );
    });
  });

  group('driver-r5-41', () {
    setUp(ScheduledRideStore.reset);
    tearDown(ScheduledRideStore.reset);

    testWidgets("while admin has Scheduled rides on, a late cancel at the "
        'limit neither warns nor notifies a pause', (tester) async {
      final now = ScheduledClock.instance.now();
      ScheduledRideStore.driverAccess = ScheduledRidesDriverAccess.fromJson({
        'on': true,
        'until': now.add(const Duration(days: 3)).toUtc().toIso8601String(),
      });
      ScheduledRideStore.addLateCancel(now.subtract(const Duration(days: 2)));
      ScheduledRideStore.answer('Gamla vägen, Stockholm', accepted: true);
      final paused = DriverNotificationFeed.instance.items
          .where((n) => n.kind == DriverNoticeKind.scheduledPaused)
          .length;
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: ScheduledRidesScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accepted'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Gamla vägen, Stockholm').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gamla vägen, Stockholm').first);
      await tester.pumpAndSettle();
      await tester
          .tap(find.widgetWithText(OutlinedButton, 'Cancel reservation'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Personal emergency'));
      await tester.tap(find.text('Personal emergency'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      final warning = tester.widget<Text>(
          find.byKey(const ValueKey<String>('scheduled-late-cancel')));
      expect(warning.data, isNot(contains('pause')));
      final confirm = find.widgetWithText(FilledButton, 'Cancel reservation');
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(ScheduledRideStore.block(), isNull);
      expect(
        DriverNotificationFeed.instance.items
            .where((n) => n.kind == DriverNoticeKind.scheduledPaused)
            .length,
        paused,
      );
    });
  });

  group('driver-r5-42', () {
    setUp(ScheduledRideStore.reset);
    tearDown(ScheduledRideStore.reset);

    test('at Leave now, requests that clash with the trip being driven stay '
        'hidden', () {
      ScheduledRideStore.answer('Gamla vägen, Stockholm', accepted: true);
      expect(ScheduledRideStore.openRequests.value, 0);
      final ride = ScheduledRideStore.upcoming.firstWhere(
          (r) => r.pickupAddress == 'Gamla vägen, Stockholm');
      expect(ScheduledRideStore.start(ride), isTrue);
      // The Lidingö request clashes with the 07:40 trip now on the road.
      expect(ScheduledRideStore.openRequests.value, 0);
      // After a logout nothing is held back any more.
      ScheduledRideStore.reset();
      expect(ScheduledRideStore.openRequests.value, 2);
    });
  });
}

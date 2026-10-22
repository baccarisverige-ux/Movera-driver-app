import 'package:flutter_test/flutter_test.dart';
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
}

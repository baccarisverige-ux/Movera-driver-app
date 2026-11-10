// IN-DL.9 #524 (b), global plan step 73: an offer the server sends without
// `driverEarnings` shows "—", never a phone-computed share (owner decision
// 2026-11-10: never show made-up earnings).
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';

/// Recorded shape of `Offer` (as `test/g4/g4_offers_test.dart` sends it),
/// with `driverEarnings` left out.
Map<String, dynamic> _offerWithoutEarnings() => {
  'offerId': 'off-1',
  'tripId': 'trip-off-1',
  'kind': 'exclusive',
  'status': 'open',
  'version': 1,
  'expiresAt': DateTime.now()
      .add(const Duration(seconds: 15))
      .toUtc()
      .toIso8601String(),
  'fare': {'amountMinor': 20800, 'currency': 'SEK'},
  'source': 'system',
  'pickup': {
    'address': 'Tegnérgatan, Stockholm',
    'lat': 59.3335,
    'lng': 18.0610,
  },
  'dropoff': {
    'address': 'Odengatan, Stockholm',
    'lat': 59.3428,
    'lng': 18.0475,
  },
  'categoryId': 'comfort',
  'paymentMethod': 'card',
  'pickupEtaSeconds': 180,
  'pickupMeters': 900,
  'tripSeconds': 720,
  'tripMeters': 5200,
};

void main() {
  setUp(() => DriverOfferRules.current = const DriverOfferRules());
  tearDown(() => DriverOfferRules.current = const DriverOfferRules());

  test('no driverEarnings from the server: the card shows "—"', () {
    final offer = OfferWire.parse(_offerWithoutEarnings());
    expect(offer.driverEarnings, isNull);

    final shown = const OfferCardDetails().fare(
      offer.fareLabel,
      earnings: offer.driverEarnings?.formatted,
    );
    expect(
      shown,
      '—',
      reason:
          'the server sent no driverEarnings; the card made up a share '
          'from the phone commission rate '
          '${DriverOfferRules.current.commissionRate}',
    );
  });

  test('no driverEarnings from the server: the trip pay is not made up', () {
    final offer = OfferWire.parse(_offerWithoutEarnings());
    expect(
      offer.driverPayLabel,
      '—',
      reason: 'driverPay fell back to WaybillPayment.shareOf on the phone',
    );
  });
}

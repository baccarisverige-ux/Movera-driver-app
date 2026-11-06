import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';

/// Same-address fix (contract v0.18.42 §67, contract.json#sameAddress.label):
/// the trip's address is the label the rider chose ("Solna Centrum, …"), and
/// the driver's offer card and trip screens show that text as it comes, never
/// a street address looked up again. Driver app: no code change, this test
/// guards that the offer keeps the rider's place name.
void main() {
  test('the offer keeps the place name the rider chose', () {
    final offer = OfferWire.parse({
      'offerId': 'o1',
      'tripId': 'trip-o1',
      'kind': 'radar',
      'status': 'open',
      'version': 1,
      'expiresAt': '2026-11-06T12:00:15Z',
      'fare': {'amountMinor': 8100, 'currency': 'SEK'},
      'source': 'system',
      'pickup': {
        'address': 'Solnavägen 13, 171 45 Solna, Sverige',
        'lat': 59.36,
        'lng': 18.0,
      },
      'dropoff': {
        'address': 'Mall of Scandinavia, Stjärntorget, Solna, Sverige',
        'lat': 59.3703,
        'lng': 18.0045,
      },
      'categoryId': 'comfort',
      'paymentMethod': 'card',
      'pickupEtaSeconds': 180,
      'pickupMeters': 900,
      'tripSeconds': 300,
      'tripMeters': 1300,
    });
    expect(offer.dropoff, 'Mall of Scandinavia, Stjärntorget, Solna, Sverige');
    expect(offer.pickup, 'Solnavägen 13, 171 45 Solna, Sverige');
  });
}

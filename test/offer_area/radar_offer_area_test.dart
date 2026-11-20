import 'package:flutter_test/flutter_test.dart';
import 'package:movera/widgets/radar_offer_card.dart';

// Store screenshot 2026-11-20: with the admin's "drop-off area only" the
// offer showed "Sverige": the area was the last part of Google's address,
// which is the country.
void main() {
  test('area of a Google address is the town, not the country', () {
    expect(
      RadarOfferView.area('Klarabergsgatan 16, 111 21 Stockholm, Sverige'),
      'Stockholm',
    );
    expect(RadarOfferView.area('Solna Centrum, Solna, Sweden'), 'Solna');
    expect(
      RadarOfferView.area('12 Rue de Rivoli, 75004 Paris, France'),
      'Paris',
    );
    expect(
      RadarOfferView.area('Av. Habib Bourguiba, Tunis 1000, Tunisie'),
      'Tunis',
    );
  });

  test('area keeps the old answers', () {
    expect(RadarOfferView.area('Hantverkargatan 4, Stockholm'), 'Stockholm');
    expect(
      RadarOfferView.area('Klockarvägen 37, Geneta, Södertälje'),
      'Södertälje',
    );
    expect(RadarOfferView.area('Stockholm'), 'Stockholm');
    expect(RadarOfferView.area('Sverige'), 'Sverige');
  });
}

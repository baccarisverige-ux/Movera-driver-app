import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/geo/compact_address.dart';

/// The rider app's compactAddress rules (destination_search), in the
/// driver app.
void main() {
  test('compactAddress drops the country, postal code and region', () {
    expect(
      compactAddress('Klockarvägen 35, 123 45 Stockholm, Sweden'),
      'Klockarvägen 35, 123 45 Stockholm',
    );
    expect(compactAddress('Vasagatan 1, Stockholm'), 'Vasagatan 1, Stockholm');
    expect(
      compactAddress('Rue de Rivoli 10, 75001 Paris, France'),
      'Rue de Rivoli 10, 75001 Paris',
    );
    expect(
      compactAddress('Storgatan 2, Södertälje kommun, Sverige'),
      'Storgatan 2',
    );
    expect(compactAddress('Sergels torg'), 'Sergels torg');
  });
}

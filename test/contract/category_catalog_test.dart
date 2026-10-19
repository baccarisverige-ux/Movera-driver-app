import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/category_catalog.dart';
import 'package:movera/core/vehicle/ride_categories.dart';

void main() {
  final categories = (jsonDecode(File('contracts/contract.json')
          .readAsStringSync()) as Map<String, dynamic>)['categories']
      as Map<String, dynamic>;

  test('seed ids, alias and pattern = contract.json#categories', () {
    expect(CategoryCatalog.seed, categories['seed']);
    expect(CategoryCatalog.aliases, categories['aliases']);
    expect(CategoryCatalog.pattern.pattern, categories['pattern']);
    expect(CategoryCatalog.driverLabels.keys.toList(), categories['seed']);
  });

  test('ids: alias on read, unknown well-formed ids pass, bad ids fail', () {
    expect(CategoryCatalog.canonicalId('movera'), 'economy');
    expect(CategoryCatalog.canonicalId('xl'), 'xl');
    expect(CategoryCatalog.canonicalId('van_8'), 'van_8');
    expect(CategoryCatalog.canonicalId('Movera XL'), isNull);
    expect(CategoryCatalog.labelOf('movera'), 'Movera');
    expect(CategoryCatalog.labelOf('van_8'), 'van_8');
  });

  test('every driver display name maps to a seed id or is an extra', () {
    final ids = {
      for (final name in DriverCategoryAccess.all)
        name: CategoryCatalog.idForLabel(name),
    };
    expect(ids, {
      'Movera': 'economy',
      'Comfort': 'comfort',
      'Premium': 'premium',
      'Priority': 'priority',
      'Movera XL': 'xl',
      'Electric': 'electric',
      'Movera Pet': 'pet',
      'Booster Seat': null,
    });
    expect(CategoryCatalog.idForLabel('XL'), 'xl');
  });
}

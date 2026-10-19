import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/money/money.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File('contracts/$path').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  final fixtures = _json('fixtures/money.json');

  test('currency exponents = contract.json#currencies', () {
    final currencies = _json('contract.json')['currencies'] as Map;
    expect(Money.exponents, {
      for (final e in currencies.entries) e.key: (e.value as Map)['exponent'],
    });
    expect(Money.symbols, {
      for (final e in currencies.entries) e.key: (e.value as Map)['symbol'],
    });
  });

  test('replays fixtures/money.json valid cases', () {
    final cases = (fixtures['cases'] as List).cast<Map<String, dynamic>>();
    expect(cases, isNotEmpty);
    for (final c in cases) {
      final wire = Map<String, dynamic>.from(c['money'] as Map);
      final money = Money.fromJson(wire);
      expect(money.majorString, c['major'], reason: '$wire');
      expect(money.toJson(), wire);
      expect(Money.fromJson(jsonDecode(jsonEncode(money.toJson()))), money);
    }
  });

  test('rejects fixtures/money.json invalid cases on the wire', () {
    for (final raw in (fixtures['invalid'] as List).cast<Map>()) {
      expect(() => Money.fromJson(Map<String, dynamic>.from(raw)),
          throwsFormatException, reason: '$raw');
    }
  });

  test('local storage may still hold legacy minorUnits', () {
    expect(Money.fromStoredJson({'minorUnits': 100, 'currency': 'SEK'}),
        const Money(minorUnits: 100));
    expect(Money.fromStoredJson({'amountMinor': 335, 'currency': 'EUR'}),
        const Money(minorUnits: 335, currency: 'EUR'));
    expect(() => Money.fromStoredJson({'minorUnits': 1.5, 'currency': 'SEK'}),
        throwsFormatException);
  });

  test('local formatting per currency', () {
    expect(const Money(minorUnits: 12675).formatted, '126,75 kr');
    expect(const Money(minorUnits: 299480).formatted, '2 994,80 kr');
    expect(const Money(minorUnits: -2000).formatted, '−20,00 kr');
    expect(const Money(minorUnits: 12500, currency: 'TND').formatted,
        '12,500 DT');
    expect(const Money(minorUnits: 4000).formattedShort, '40 kr');
    expect(const Money(minorUnits: 4050).formattedShort, '40,50 kr');
  });
}

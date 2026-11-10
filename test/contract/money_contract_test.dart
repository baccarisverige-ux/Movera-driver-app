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
      expect(
        () => Money.fromJson(Map<String, dynamic>.from(raw)),
        throwsFormatException,
        reason: '$raw',
      );
    }
  });

  test('local storage may still hold legacy minorUnits', () {
    expect(
      Money.fromStoredJson({'minorUnits': 100, 'currency': 'SEK'}),
      const Money(minorUnits: 100, currency: 'SEK'),
    );
    expect(
      Money.fromStoredJson({'amountMinor': 335, 'currency': 'EUR'}),
      const Money(minorUnits: 335, currency: 'EUR'),
    );
    expect(
      () => Money.fromStoredJson({'minorUnits': 1.5, 'currency': 'SEK'}),
      throwsFormatException,
    );
  });

  test('local formatting per currency', () {
    expect(
      const Money(minorUnits: 12675, currency: 'SEK').formatted,
      '126,75 kr',
    );
    expect(
      const Money(minorUnits: 299480, currency: 'SEK').formatted,
      '2 994,80 kr',
    );
    expect(
      const Money(minorUnits: -2000, currency: 'SEK').formatted,
      '−20,00 kr',
    );
    expect(
      const Money(minorUnits: 12500, currency: 'TND').formatted,
      '12.500 DT',
    );
    expect(
      const Money(minorUnits: 4000, currency: 'SEK').formattedShort,
      '40 kr',
    );
    expect(
      const Money(minorUnits: 4050, currency: 'SEK').formattedShort,
      '40,50 kr',
    );
  });

  // Contract v0.18.59 §81 (owner 2026-11-10): the dinar is written with a
  // dot, 3 decimals, a space between thousands; SEK and EUR keep the comma.
  test('TND with a dot: 12.350 DT, 1 250.000 DT', () {
    expect(
      const Money(minorUnits: 12350, currency: 'TND').formatted,
      '12.350 DT',
    );
    expect(
      const Money(minorUnits: 1250000, currency: 'TND').formatted,
      '1 250.000 DT',
    );
    expect(
      const Money(minorUnits: 2000, currency: 'TND').formattedShort,
      '2 DT',
    );
    expect(
      const Money(minorUnits: 12350, currency: 'TND').formattedShort,
      '12.350 DT',
    );
    expect(Money.parseLabel('12.350 DT')?.amountMinor, 12350);
    expect(
      const Money(minorUnits: 12675, currency: 'SEK').formatted,
      '126,75 kr',
    );
    expect(const Money(minorUnits: 741, currency: 'EUR').formatted, '7,41 €');
  });
}

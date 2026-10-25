import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/driver_onboarding_rules.dart';

/// `DriverOnboardingRules` is a copy of `contract.json#driverOnboarding`
/// (v0.5.3 §14); this keeps the copy honest after a contract sync.
void main() {
  final onboarding =
      (jsonDecode(File('contracts/contract.json').readAsStringSync())
              as Map<String, dynamic>)['driverOnboarding']
          as Map<String, dynamic>;

  test('account types, minimum age and countries', () {
    expect(DriverOnboardingRules.accountTypes, onboarding['accountTypes']);
    expect(DriverOnboardingRules.minAge, onboarding['minAge']);
    final countries = onboarding['countries'] as Map<String, dynamic>;
    expect(
      DriverOnboardingRules.countries.keys.toSet(),
      countries.keys.toSet(),
    );
    for (final MapEntry(key: code, value: row) in countries.entries) {
      final country = DriverOnboardingRules.countries[code]!;
      expect(country.open, row['open'], reason: code);
      final cities = (row['cities'] as List).cast<Map<String, dynamic>>();
      expect(country.cities.length, cities.length, reason: code);
      for (var i = 0; i < cities.length; i++) {
        expect(country.cities[i].cityId, cities[i]['cityId']);
        expect(country.cities[i].name, cities[i]['name']);
        expect(country.cities[i].zoneId, cities[i]['zoneId']);
      }
    }
  });

  test('fleet code shape and upload limits', () {
    final code = onboarding['fleetCode'] as Map<String, dynamic>;
    expect(DriverOnboardingRules.fleetCodePrefix, code['prefix']);
    expect(DriverOnboardingRules.fleetCodeLength, code['length']);
    expect(DriverOnboardingRules.fleetCodeAlphabet, code['alphabet']);
    expect(
      DriverOnboardingRules.joinAttemptsPerHour,
      code['joinAttemptsPerHour'],
    );
    final upload = (onboarding['documents'] as Map)['upload'] as Map;
    expect(DriverOnboardingRules.uploadMaxBytes, upload['maxBytes']);
    expect(DriverOnboardingRules.uploadMediaTypes, upload['mediaTypes']);
  });

  test('every document type, kind and name in en, sv and fr', () {
    final types =
        (onboarding['documents'] as Map)['types'] as Map<String, dynamic>;
    expect(
      DriverOnboardingRules.documentTypes.keys.toSet(),
      types.keys.toSet(),
    );
    for (final MapEntry(key: type, value: row) in types.entries) {
      final info = DriverOnboardingRules.documentTypes[type]!;
      expect(info.owner, row['owner'], reason: type);
      final kind = switch (info.kind) {
        DocumentKind.file => 'file',
        DocumentKind.acceptance => 'acceptance',
        DocumentKind.adminCheck => 'admin_check',
      };
      expect(kind, row['kind'], reason: type);
      final names = row['name'] as Map<String, dynamic>;
      expect(info.en, names['en'], reason: type);
      expect(info.sv, names['sv'], reason: type);
      expect(info.fr, names['fr'], reason: type);
      expect(DriverOnboardingRules.documentName(type, 'sv'), names['sv']);
    }
    expect(DriverOnboardingRules.documentName('unknown_x', 'en'), 'unknown_x');
  });

  test('the required lists only name known types', () {
    final required =
        (onboarding['documents'] as Map)['required'] as Map<String, dynamic>;
    for (final country in required.values) {
      for (final list in (country as Map).values) {
        for (final type in list as List) {
          expect(DriverOnboardingRules.documentTypes, contains(type));
        }
      }
    }
  });

  test('fleet codes are normalised like the server does', () {
    expect(DriverOnboardingRules.normalizeFleetCode('mv-7k3q9'), 'MV-7K3Q9');
    expect(DriverOnboardingRules.normalizeFleetCode(' 7K3 Q9 '), 'MV-7K3Q9');
    expect(DriverOnboardingRules.normalizeFleetCode('MV7K3Q9'), 'MV-7K3Q9');
  });

  test('age counts whole years', () {
    final now = DateTime.utc(2026, 10, 25);
    expect(DriverOnboardingRules.ageAt(DateTime.utc(2005, 10, 25), now), 21);
    expect(DriverOnboardingRules.ageAt(DateTime.utc(2005, 10, 26), now), 20);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/admin/trip_rules_admin_config.dart';
import 'package:movera/core/contracts/category_catalog.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/ride/waiting_rules.dart';

/// Audit D4 regressions: X10 (TND no-show share), X12 (waiting rules by
/// category id), X13 (default zone id).
void main() {
  test('X10: the driver\'s no-show share keeps the fee\'s currency', () {
    const terms = WaitingTerms(
      freeMinutes: 2,
      perMinute: Money(minorUnits: 3700, currency: 'TND'),
      noShowAfterMinutes: 5,
      noShowFee: Money(minorUnits: 19500, currency: 'TND'),
      driverShareNoShowPercent: 80,
    );
    final fee = terms.driverNoShowFee;
    expect(fee, const Money(minorUnits: 15600, currency: 'TND'));
    expect(fee.exponent, 3);
    expect(fee.formatted, '15,600 DT');
  });

  test('X12: category waiting rules apply by id and by driver label', () {
    const rules = WaitingRules();
    for (final category in ['xl', CategoryCatalog.labelOf('xl'), 'XL']) {
      expect(
        rules.termsFor(category: category).freeMinutes,
        3,
        reason: category,
      );
    }
    for (final category in ['premium', 'Premium']) {
      expect(
        rules.termsFor(category: category).perMinute.formatted,
        '16,90 kr',
        reason: category,
      );
    }
    expect(rules.termsFor(category: 'economy').rule, '');
    expect(rules.termsFor(category: 'Booster Seat').rule, '');
  });

  group('X13: default zone id', () {
    test('is the admin and contract id', () {
      expect(DriverHomeAdminContentService.defaultZoneId, 'Z001');
      expect(const DriverHomeAdminContentService().zoneId, 'Z001');
    });

    test('reads Z001 from the admin rules file', () {
      final export = <String, dynamic>{
        'driverApp': {
          'destinationMode': {
            'Z001': {'destinationsPerDay': 7},
            'Z002': {'destinationsPerDay': 4},
          },
        },
      };
      final config = DriverHomeAdminContentService(rulesExport: export).load();
      expect(config.destinationMode!.destinationsPerDay, 7);
    });

    test('still reads an export or caller that uses svc-stockholm', () {
      final legacy = <String, dynamic>{
        'driverApp': {
          'destinationMode': {
            'svc-stockholm': {'destinationsPerDay': 5},
          },
        },
      };
      expect(
        DriverHomeAdminContentService(
          rulesExport: legacy,
        ).load().destinationMode!.destinationsPerDay,
        5,
      );
      final current = <String, dynamic>{
        'destinationMode': {
          'Z001': {'destinationsPerDay': 6},
          'svc-stockholm': {'destinationsPerDay': 5},
        },
      };
      expect(
        DriverTripRulesExport.forZone(
          current,
          'svc-stockholm',
        ).$1.destinationsPerDay,
        6,
      );
    });
  });
}

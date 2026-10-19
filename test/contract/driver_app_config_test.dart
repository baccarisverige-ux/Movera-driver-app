import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/admin/trip_rules_admin_config.dart';
import 'package:movera/core/contracts/driver_app_config.dart';
import 'package:movera/core/ride/waiting_rules.dart';

/// X1: the driver app reads the admin app's `DriverAppConfig` (contract §6).
/// `test/fixtures/config/driver_app_config.<zone>.json` are copies of the
/// admin exporter's fixtures (admin `webapp/src/config/__fixtures__`).
Object? _read(String path) => jsonDecode(File(path).readAsStringSync());

DriverAppConfig _admin(String zone) => DriverAppConfig.fromJson(
  _read('test/fixtures/config/driver_app_config.$zone.json'),
);

void main() {
  test('the contract fixture parses', () {
    final config = DriverAppConfig.fromJson(
      _read('contracts/fixtures/config/driver_app_config.json'),
    );
    expect(config.version, 7);
    expect(config.zoneId, 'Z001');
    expect(config.currency, 'SEK');
    expect(config.categoryIds, ['economy', 'comfort']);
    expect(config.feature('scheduledRides'), isTrue);
    expect(config.waiting.base.perMinute.formatted, '5,00 kr');
    expect(config.waiting.base.noShowFee.formatted, '50,00 kr');
    expect(config.waiting.base.driverShareNoShowPercent, 80);
    expect(config.cancelReasons['noShow'], ['rider_no_show']);
    expect(config.latestVersion, '1.2.0');
  });

  group('admin export fixtures', () {
    test('Z001 (SEK)', () {
      final config = _admin('Z001');
      expect(config.version, 8);
      expect(config.zoneId, 'Z001');
      expect(config.timeZone, 'Europe/Stockholm');
      expect(config.publishedAt, DateTime.utc(2026, 10, 19, 8));
      expect(config.categoryIds, contains('child_seat'));
      expect(config.categories.firstWhere((c) => c.id == 'xl').seats, 6);
      final waiting = config.waiting;
      expect(waiting.base.freeMinutes, 2);
      expect(waiting.base.perMinute.formatted, '12,26 kr');
      expect(waiting.base.noShowFee.formatted, '65,00 kr');
      expect(waiting.base.driverNoShowFee.formatted, '52,00 kr');
      // Category rules only where they differ from the zone's terms.
      expect(waiting.categories.keys, unorderedEquals(['premium', 'xl']));
      expect(waiting.termsFor(category: 'Movera XL').freeMinutes, 3);
      expect(waiting.termsFor(category: 'premium').perMinute.formatted,
          '16,90 kr');
      expect(waiting.termsFor(pickupKm: 7).noShowFee.formatted, '85,00 kr');
      expect(
        waiting.termsFor(type: WaitingRideType.airport).noShowAfterMinutes,
        20,
      );
      expect(config.destinationMode.destinationsPerDay, 2);
      expect(config.nextTrips.withinMinutesOfDropoff, 10);
      expect(config.cancelReasons['driverBeforeTrip'], hasLength(6));
    });

    test('FR-PC (EUR)', () {
      final config = _admin('FR-PC');
      expect(config.zoneId, 'FR-PC');
      expect(config.currency, 'EUR');
      expect(config.timeZone, 'Europe/Paris');
      expect(config.waiting.base.perMinute.formatted, '1,15 €');
      expect(config.waiting.base.driverNoShowFee.formatted, '4,92 €');
      expect(config.waiting.termsFor(category: 'xl').freeMinutes, 3);
    });

    test('TN-TC (TND, 3 decimals)', () {
      final config = _admin('TN-TC');
      expect(config.currency, 'TND');
      expect(config.timeZone, 'Africa/Tunis');
      final terms = config.waiting.termsFor(category: 'Movera');
      expect(terms.noShowFee.formatted, '19,500 DT');
      expect(terms.driverNoShowFee.formatted, '15,600 DT');
      expect(terms.driverNoShowFee.currency, 'TND');
      final premium = config.waiting.termsFor(category: 'Premium');
      expect(premium.perMinute.formatted, '5,100 DT');
      expect(premium.freeMinutes, 5);
      expect(config.waiting.termsFor(pickupKm: 9).noShowFee.formatted,
          '25,500 DT');
    });

    test('apply() puts the zone rules in use', () {
      addTearDown(() => WaitingRules.current = const WaitingRules());
      _admin('TN-TC').apply();
      expect(WaitingRules.current.base.noShowFee.currency, 'TND');
    });

    test('Home reads destination mode from the document', () {
      final json = _read('test/fixtures/config/driver_app_config.Z001.json')
          as Map<String, dynamic>;
      (json['destinationMode'] as Map)['destinationsPerDay'] = 7;
      final home = DriverHomeAdminContentService(
        appConfig: DriverAppConfig.fromJson(json),
      ).load();
      expect(home.destinationMode!.destinationsPerDay, 7);
    });
  });

  group('never crashes; missing or broken values are the seed', () {
    for (final input in <Object?>[null, 'x', 3, <dynamic>[], <String, dynamic>{}]) {
      test('input $input', () {
        final config = DriverAppConfig.fromJson(input);
        expect(config.zoneId, DriverZones.defaultId);
        expect(config.currency, 'SEK');
        expect(config.waiting.base.noShowFee.formatted, '65,00 kr');
        expect(config.waiting.termsFor(category: 'xl').freeMinutes, 3);
        expect(config.categoryIds, isNotEmpty);
      });
    }

    test('wrong types everywhere', () {
      final config = DriverAppConfig.fromJson({
        'version': 'nine',
        'publishedAt': 12,
        'zoneId': 42,
        'currency': 'XYZ',
        'timeZone': false,
        'catalog': {
          'categories': [1, {'id': 'Not An Id'}, {'id': 'xl', 'seats': 'six'}],
        },
        'features': {'performance': 'yes', 'scheduledRides': false},
        'waiting': {
          'freeWaitMin': -3,
          'perMin': 'abc',
          'noShowFee': {'amountMinor': 1.5, 'currency': 'SEK'},
          'driverSharePct': 400,
          'farPickup': 'far',
          'rideTypes': {'airport': {'on': false}, 'event': 7},
          'byCategory': {'xl': 'three', 'BAD KEY': {}, 'pet': {'freeWaitMin': 4}},
        },
        'destinationMode': 'on',
        'nextTrips': [],
        'cancelReasons': {'noShow': 'rider_no_show', 'scheduled': [1, 'scheduled_other']},
        'appUpdate': {'latestVersion': 2},
        'somethingNew': {'a': 1},
      });
      expect(config.version, 0);
      expect(config.zoneId, 'Z001');
      expect(config.currency, 'SEK');
      expect(config.categoryIds, ['xl']);
      expect(config.categories.single.seats, isNull);
      expect(config.feature('performance', fallback: true), isTrue);
      expect(config.feature('scheduledRides', fallback: true), isFalse);
      final waiting = config.waiting;
      expect(waiting.base.freeMinutes, 2);
      expect(waiting.base.perMinute.formatted, '12,26 kr');
      expect(waiting.base.noShowFee.formatted, '65,00 kr');
      expect(waiting.base.driverShareNoShowPercent, 80);
      expect(waiting.rideTypes.containsKey(WaitingRideType.airport), isFalse);
      expect(waiting.termsFor(category: 'pet').freeMinutes, 4);
      expect(waiting.termsFor(category: 'xl').freeMinutes, 2);
      expect(config.cancelReasons['scheduled'], ['scheduled_other']);
      expect(config.cancelReasons.containsKey('noShow'), isFalse);
      expect(config.latestVersion, '1.0.0');
    });

    test('a TND document never takes SEK seed amounts', () {
      final config = DriverAppConfig.fromJson({
        'currency': 'TND',
        'waiting': {
          'perMin': {'amountMinor': 500, 'currency': 'SEK'},
        },
      });
      final terms = config.waiting.termsFor(category: 'Premium', pickupKm: 9);
      expect(terms.perMinute.currency, 'TND');
      expect(terms.noShowFee.currency, 'TND');
      expect(terms.driverNoShowFee.currency, 'TND');
      final none = DriverAppConfig.fromJson({'currency': 'TND'});
      expect(none.waiting.termsFor(category: 'Premium').perMinute.currency,
          'TND');
    });

    test('the old zone id is read as Z001', () {
      expect(DriverAppConfig.fromJson({'zoneId': 'svc-stockholm'}).zoneId,
          'Z001');
    });
  });
}

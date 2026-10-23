import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/admin/trip_rules_admin_config.dart';
import 'package:movera/core/contracts/driver_app_config.dart';
import 'package:movera/core/contracts/zone_settings.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/ride/waiting_rules.dart';
import 'package:movera/core/scheduled/scheduled_ride_rules.dart';

/// X1: the driver app reads the admin app's `DriverAppConfig` (contract §6).
/// `test/fixtures/config/driver_app_config.<zone>.json` are copies of the
/// admin exporter's fixtures (admin `webapp/src/config/__fixtures__`).
Object? _read(String path) => jsonDecode(File(path).readAsStringSync());

/// [rules] in the contract's `reservations` names.
Map<String, Object?> _reservations(ScheduledRideRules rules) => {
  'on': rules.enabled,
  'lateWarn': rules.lateWarning,
  'offlineBackupAfterMin': rules.backupAfterMinutes,
  'homePopupAfterMin': rules.homePopupAfterMinutes,
  'exclusiveBeforeMin': rules.exclusiveBeforeMinutes,
  'radarBeforeMin': rules.radarBeforeMinutes,
  'onDriverCancel': rules.onDriverCancel.name,
  'hideClashing': rules.removeClashing,
  'towardPickup': rules.towardPickupBeforeRide,
  'towardPickupBeforeMin': rules.towardPickupBeforeMinutes,
  'longTripKm': rules.longTripKm,
  'driverLateCancelHours': rules.driverLateCancelHours,
  'lateCancelLimit': rules.lateCancelLimit,
  'lateCancelPeriodDays': rules.lateCancelPeriodDays,
  'pauseDays': rules.pauseDays,
  'assignAcceptSeconds': rules.assignAcceptTime.inSeconds,
  'rideTypes': {
    for (final kind in ScheduledRideKind.values)
      kind.name: {
        'onlineBeforeMin': rules.ruleFor(kind).onlineBeforeMinutes,
        'spareMin': rules.ruleFor(kind).spareMinutes,
        'reminderMin': rules.ruleFor(kind).reminderMinutes,
      },
  },
  'lateEta': {
    'on': rules.lateEta.on,
    'toleranceMin': rules.lateEta.toleranceMinutes,
    'checkEverySeconds': rules.lateEta.checkEverySeconds,
    'reassignTo': rules.lateEta.reassignTo.name,
  },
};

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
      expect(config.version, 9);
      expect(config.zoneId, 'Z001');
      expect(config.timeZone, 'Europe/Stockholm');
      expect(config.publishedAt, DateTime.utc(2026, 10, 19, 8));
      expect(config.categoryIds, contains('child_seat'));
      expect(config.categories.firstWhere((c) => c.id == 'xl').seats, 6);
      final waiting = config.waiting;
      // Owner Q41: free wait 5 min (XL 3), and the no-show comes with it.
      expect(waiting.base.freeMinutes, 5);
      expect(waiting.base.noShowAfterMinutes, 5);
      expect(waiting.base.perMinute.formatted, '12,26 kr');
      expect(waiting.base.noShowFee.formatted, '65,00 kr');
      expect(waiting.base.driverNoShowFee.formatted, '52,00 kr');
      // Category rules only where they differ from the zone's terms.
      expect(waiting.categories.keys, unorderedEquals(['premium', 'xl']));
      expect(waiting.termsFor(category: 'Movera XL').freeMinutes, 3);
      expect(waiting.termsFor(category: 'Movera XL').noShowAfterMinutes, 3);
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
      expect(waiting.base.freeMinutes, 5);
      expect(waiting.base.perMinute.formatted, '12,26 kr');
      expect(waiting.base.noShowFee.formatted, '65,00 kr');
      expect(waiting.base.driverShareNoShowPercent, 80);
      expect(waiting.rideTypes.containsKey(WaitingRideType.airport), isFalse);
      expect(waiting.termsFor(category: 'pet').freeMinutes, 4);
      expect(waiting.termsFor(category: 'xl').freeMinutes, 5);
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

  group('contract v0.4.0 per-zone fields', () {
    test('ZoneDefaults equal contract.json#configDefaults', () {
      final contract = _read('contracts/contract.json') as Map<String, dynamic>;
      final defaults = contract['configDefaults'] as Map<String, dynamic>;
      expect(contract['version'], '0.5.0');
      expect(ZoneDefaults.paymentMethods, contract['zonePaymentMethods']['values']);
      expect(ZoneDefaults.languages, contract['languages']['values']);
      expect(ZoneDefaults.maxStops, defaults['maxStops']);
      expect(ZoneDefaults.maxPickupMoveMeters, defaults['maxPickupMoveMeters']);
      expect(ZoneDefaults.missedExclusiveBeforeOffline,
          defaults['missedExclusiveBeforeOffline']);
      expect(ZoneDefaults.waitingDriverSharePct, defaults['waitingDriverSharePct']);
      expect(ZoneDefaults.noShowDriverSharePct, defaults['noShowDriverSharePct']);
      for (final MapEntry(key: country, value: row)
          in (defaults['countries'] as Map<String, dynamic>).entries) {
        final currency = row['currency'] as String;
        expect(ZoneDefaults.countryOf(currency), country);
        expect(ZoneDefaults.languageOf(country), row['defaultLanguage']);
        final bonus = DriverBonusLimits.defaultsIn(currency);
        expect(bonus.defaultLimit,
            Money.fromJson(Map<String, dynamic>.from(row['driverBonus']['defaultLimit'])));
        expect(bonus.hardMax,
            Money.fromJson(Map<String, dynamic>.from(row['driverBonus']['hardMax'])));
      }
    });

    for (final (zone, country, lang, limit, max) in const [
      ('Z001', 'SE', 'sv', '200,00 kr', '1 000,00 kr'),
      ('FR-PC', 'FR', 'fr', '20,00 €', '95,00 €'),
      ('TN-TC', 'TN', 'fr', '60,000 DT', '300,000 DT'),
    ]) {
      test('$zone admin export', () {
        final config = _admin(zone);
        expect(config.country, country);
        expect(config.languages.available, ['en', 'fr', 'sv']);
        expect([config.languages.rider, config.languages.driver, config.languages.admin],
            [lang, lang, lang]);
        expect(config.paymentMethods, ['cash', 'card', 'apple_pay', 'google_pay']);
        expect(config.maxStops, 3);
        expect(config.maxPickupMoveMeters, 500);
        expect(config.autoOffline, isTrue);
        expect(config.missedExclusiveBeforeOffline, 3);
        expect(config.driverBonus, isNotNull);
        expect(config.driverBonusLimits.defaultLimit.currency, config.currency);
        String digits(String text) => text.replaceAll(RegExp(r'\s'), '');
        expect(digits(config.driverBonusLimits.defaultLimit.formatted), digits(limit));
        expect(digits(config.driverBonusLimits.hardMax.formatted), digits(max));
        expect(config.waiting.base.driverShareWaitPercent, 100);
        expect(config.waiting.base.driverShareNoShowPercent, 80);
      });
    }

    test('the contract sample', () {
      final config = DriverAppConfig.fromJson(
        _read('contracts/fixtures/config/driver_app_config.json'),
      );
      expect(config.country, 'SE');
      expect(config.missedExclusiveBeforeOffline, 3);
      expect(config.driverBonusLimits.defaultLimit, Money(minorUnits: 20000));
      expect(config.waiting.base.freeMinutes, 5);
      expect(config.waiting.termsFor(category: 'comfort').noShowAfterMinutes, 5);
      expect(config.waiting.base.driverShareWaitPercent, 100);
    });

    test('missing: the defaults of the currency', () {
      final config = DriverAppConfig.fromJson({'currency': 'EUR'});
      expect(config.country, 'FR');
      expect(config.languages.driver, 'fr');
      expect(config.paymentMethods, ZoneDefaults.paymentMethods);
      expect(config.maxStops, 3);
      expect(config.maxPickupMoveMeters, 500);
      expect(config.missedExclusiveBeforeOffline, 3);
      expect(config.driverBonus, isNull);
      expect(config.driverBonusLimits.defaultLimit,
          Money(minorUnits: 2000, currency: 'EUR'));
      expect(config.driverBonusLimits.hardMax,
          Money(minorUnits: 9500, currency: 'EUR'));
    });

    test('invalid values never crash and fall back', () {
      final config = DriverAppConfig.fromJson({
        'currency': 'TND',
        'country': 'Tunisia',
        'languages': {
          'available': ['ar', 'en', 'en'],
          'default': {'driver': 'ar', 'rider': 3},
        },
        'paymentMethods': ['swish', 'apple', 'd17', 'wallet', 'cash', 'cash'],
        'booking': {'maxStops': 11, 'maxPickupMoveMeters': 2.5},
        'offers': {
          'autoOffline': {'on': 'yes', 'missedExclusive': 0},
        },
        'driverBonus': {
          'defaultLimit': {'amountMinor': 500000, 'currency': 'TND'},
          'hardMax': {'amountMinor': 300000, 'currency': 'TND'},
        },
      });
      expect(config.country, 'TN');
      expect(config.languages.available, ['en']);
      expect(config.languages.driver, 'en');
      expect(config.languages.rider, 'en');
      expect(config.paymentMethods, ['apple_pay', 'cash']);
      expect(config.maxStops, 3);
      expect(config.maxPickupMoveMeters, 500);
      expect(config.autoOffline, isTrue);
      expect(config.missedExclusiveBeforeOffline, 3);
      expect(config.driverBonus, isNull, reason: 'limit above the hard max');
      expect(config.driverBonusLimits.defaultLimit,
          Money(minorUnits: 60000, currency: 'TND'));
      final other = DriverAppConfig.fromJson({
        'currency': 'SEK',
        'paymentMethods': 'card',
        'driverBonus': {
          'defaultLimit': {'amountMinor': 2000, 'currency': 'EUR'},
          'hardMax': {'amountMinor': 9500, 'currency': 'EUR'},
        },
        'languages': 'sv',
      });
      expect(other.paymentMethods, ZoneDefaults.paymentMethods);
      expect(other.driverBonus, isNull, reason: 'another currency');
      expect(other.languages.driver, 'sv');
    });
  });

  group('contract v0.4.2 reservations', () {
    test('ScheduledRideRules defaults equal contract.json#configDefaults', () {
      final contract = _read('contracts/contract.json') as Map<String, dynamic>;
      final defaults = Map<String, dynamic>.from(
        contract['configDefaults']['reservations'] as Map,
      )..remove('note');
      expect(_reservations(const ScheduledRideRules()), defaults);
      // Read back from the contract's own defaults: the same rules.
      expect(
        _reservations(ScheduledRideRules.fromJson(defaults)),
        defaults,
      );
    });

    // Owner decision 2: reservations on/off for the zone (either switch)
    // and for one driver (`Driver.scheduledRides`) reach Home.
    test('the zone switch and Driver.scheduledRides reach Home', () {
      ScheduledRidesAdminConfig rides({
        Map<String, Object?> config = const {},
        Map<String, dynamic>? profile,
      }) => DriverHomeAdminContentService(
        appConfig: DriverAppConfig.fromJson(config),
        driverProfile: profile,
      ).load().scheduledRides;
      expect(rides().enabled, isTrue);
      expect(rides(config: {'reservations': {'on': false}}).enabled, isFalse);
      expect(rides(config: {'features': {'scheduledRides': false}}).enabled,
          isFalse);
      final now = DateTime.utc(2026, 10, 21, 12);
      expect(rides().driverAccess.offAt(now), isFalse);
      expect(
        rides(profile: {'scheduledRides': {'on': false, 'until': null}})
            .driverAccess
            .offAt(now),
        isTrue,
      );
      final on = rides(profile: {
        'scheduledRides': {'on': true, 'until': '2026-10-24T12:00:00.000Z'},
      }).driverAccess;
      expect([on.onAt(now), on.onAt(DateTime.utc(2026, 10, 25))],
          [true, false]);
      expect(rides(profile: {'scheduledRides': 'broken'}).driverAccess.onAt(now),
          isFalse);
    });

    test('the contract fixture\'s reservations are read as sent', () {
      final json = _read('contracts/fixtures/config/driver_app_config.json')
          as Map<String, dynamic>;
      final config = DriverAppConfig.fromJson(json);
      expect(_reservations(config.reservations), json['reservations']);
    });
  });
}

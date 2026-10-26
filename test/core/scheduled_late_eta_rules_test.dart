import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/driver_app_config.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/scheduled/scheduled_ride_rules.dart';
import 'package:movera/core/scheduled/smart_gap.dart';

// Owner rule (late ETA) and `DriverAppConfig.reservations`.

final _pickup = DateTime(2026, 10, 21, 7, 40);

bool _late({
  required DateTime now,
  required Duration eta,
  ScheduledRideRules rules = const ScheduledRideRules(),
}) => SmartGap.wouldBeLate(now: now, pickupAt: _pickup, eta: eta, rules: rules);

void main() {
  group('SmartGap.wouldBeLate', () {
    final now = DateTime(2026, 10, 21, 7, 20);

    test('late only past pickup + tolerance (default 3 min)', () {
      // Arrives 07:42: inside the tolerance.
      expect(_late(now: now, eta: const Duration(minutes: 22)), isFalse);
      // Exactly 07:43: still on time.
      expect(_late(now: now, eta: const Duration(minutes: 23)), isFalse);
      // One second past it: late.
      expect(
        _late(now: now, eta: const Duration(minutes: 23, seconds: 1)),
        isTrue,
      );
      expect(_late(now: now, eta: const Duration(minutes: 40)), isTrue);
    });

    test('early arrival and zero ETA are on time', () {
      expect(_late(now: now, eta: Duration.zero), isFalse);
      expect(_late(now: now, eta: const Duration(minutes: 5)), isFalse);
    });

    test('tolerance 0: any second past the pickup time is late', () {
      const strict = ScheduledRideRules(
        lateEta: LateEtaRule(toleranceMinutes: 0),
      );
      expect(
        _late(now: now, eta: const Duration(minutes: 20), rules: strict),
        isFalse,
      );
      expect(
        _late(
          now: now,
          eta: const Duration(minutes: 20, seconds: 1),
          rules: strict,
        ),
        isTrue,
      );
    });

    test('a pickup time already past with any ETA is late', () {
      expect(
        _late(now: DateTime(2026, 10, 21, 7, 50), eta: Duration.zero),
        isTrue,
      );
    });

    test('the off switch: never late', () {
      const off = ScheduledRideRules(lateEta: LateEtaRule(on: false));
      expect(
        _late(now: now, eta: const Duration(hours: 3), rules: off),
        isFalse,
      );
    });
  });

  group('ScheduledRideRules.fromJson', () {
    test('defaults are the agreed schema defaults', () {
      for (final rules in [
        const ScheduledRideRules(),
        ScheduledRideRules.fromJson(null),
        ScheduledRideRules.fromJson(const <String, Object>{}),
        ScheduledRideRules.fromJson('broken'),
      ]) {
        expect(rules.enabled, isTrue);
        expect(rules.lateWarning, isTrue);
        expect(rules.backupAfterMinutes, 5);
        expect(rules.homePopupAfterMinutes, 10);
        expect(rules.exclusiveBeforeMinutes, 20);
        expect(rules.radarBeforeMinutes, 15);
        expect(rules.onDriverCancel, ReservationCancelReturn.byTime);
        expect(rules.removeClashing, isTrue);
        expect(rules.towardPickupBeforeRide, isTrue);
        expect(rules.towardPickupBeforeMinutes, 60);
        expect(rules.longTripKm, 50);
        expect(rules.driverLateCancelHours, 1);
        expect(rules.lateCancelLimit, 2);
        expect(rules.lateCancelPeriodDays, 7);
        expect(rules.pauseDays, 7);
        expect(rules.assignAcceptTime, const Duration(seconds: 30));
        expect(rules.includedWaitingMinutes, 5);
        expect(rules.lateEta.on, isTrue);
        expect(rules.lateEta.toleranceMinutes, 3);
        expect(rules.lateEta.checkEverySeconds, 60);
        expect(rules.lateEta.reassignTo, LateEtaReassignTo.exclusive);
        final online = {
          for (final kind in ScheduledRideKind.values)
            kind.name: rules.ruleFor(kind).onlineBeforeMinutes,
        };
        expect(online, {
          'normal': 30,
          'airport': 60,
          'longTrip': 60,
          'comfortPremium': 45,
          'event': 45,
        });
        for (final kind in ScheduledRideKind.values) {
          expect(rules.ruleFor(kind).spareMinutes, 15);
          expect(rules.ruleFor(kind).reminderMinutes, [60, 15]);
        }
      }
    });

    test('reads every field and maps the admin names', () {
      final rules = ScheduledRideRules.fromJson({
        'on': false,
        'leaveNow': false,
        'lateWarn': false,
        'offlineBackupAfterMin': 8,
        'homePopupAfterMin': 12,
        'exclusiveBeforeMin': 25,
        'radarBeforeMin': 10,
        'onDriverCancel': 'exclusive',
        'hideClashing': false,
        'towardPickup': false,
        'towardPickupBeforeMin': 90,
        'longTripKm': 70.5,
        'driverLateCancelHours': 2,
        'lateCancelLimit': 3,
        'lateCancelPeriodDays': 14,
        'pauseDays': 3,
        'assignAcceptSeconds': 45,
        'rideTypes': {
          'normal': {'onlineBeforeMin': 20},
          'airport': {
            'onlineBeforeMin': 90,
            'spareMin': 25,
            'reminderMin': [15, 120, 15],
          },
          'longTrip': {'spareMin': 30},
          'comfortPremium': {'reminderMin': <int>[]},
          'event': {'onlineBeforeMin': 50},
        },
        'lateEta': {
          'on': false,
          'toleranceMin': 5,
          'checkEverySeconds': 30,
          'reassignTo': 'radar',
        },
      });
      expect(rules.enabled, isFalse);
      expect(rules.lateWarning, isFalse);
      expect(rules.backupAfterMinutes, 8);
      expect(rules.homePopupAfterMinutes, 12);
      expect(rules.exclusiveBeforeMinutes, 25);
      expect(rules.radarBeforeMinutes, 10);
      expect(rules.onDriverCancel, ReservationCancelReturn.exclusive);
      expect(rules.removeClashing, isFalse);
      expect(rules.towardPickupBeforeRide, isFalse);
      expect(rules.towardPickupBeforeMinutes, 90);
      expect(rules.longTripKm, 70.5);
      expect(rules.driverLateCancelHours, 2);
      expect(rules.lateCancelLimit, 3);
      expect(rules.lateCancelPeriodDays, 14);
      expect(rules.pauseDays, 3);
      expect(rules.assignAcceptTime, const Duration(seconds: 45));
      final normal = rules.ruleFor(ScheduledRideKind.normal);
      expect(normal.onlineBeforeMinutes, 20);
      expect(normal.spareMinutes, 15);
      expect(normal.reminderMinutes, [60, 15]);
      final airport = rules.ruleFor(ScheduledRideKind.airport);
      expect(airport.onlineBeforeMinutes, 90);
      expect(airport.spareMinutes, 25);
      // Each reminder once, the earliest first.
      expect(airport.reminderMinutes, [120, 15]);
      expect(rules.ruleFor(ScheduledRideKind.longTrip).spareMinutes, 30);
      expect(rules.ruleFor(ScheduledRideKind.longTrip).onlineBeforeMinutes, 60);
      expect(
        rules.ruleFor(ScheduledRideKind.comfortPremium).reminderMinutes,
        isEmpty,
      );
      expect(rules.ruleFor(ScheduledRideKind.event).onlineBeforeMinutes, 50);
      expect(rules.lateEta.on, isFalse);
      expect(rules.lateEta.toleranceMinutes, 5);
      expect(rules.lateEta.checkEverySeconds, 30);
      expect(rules.lateEta.reassignTo, LateEtaReassignTo.radar);
    });

    test('numbers out of the schema ranges keep the defaults', () {
      // driver-r4-7 / CONTRACT.md §6.1: an invalid field keeps the
      // default; it is not clamped.
      for (final json in [
        {
          'offlineBackupAfterMin': 0,
          'lateEta': {'toleranceMin': -4, 'checkEverySeconds': 1},
        },
        {
          'offlineBackupAfterMin': 600,
          'lateEta': {'toleranceMin': 45, 'checkEverySeconds': 3600},
        },
        // Not a whole number.
        {
          'offlineBackupAfterMin': 7.6,
          'lateEta': {'toleranceMin': 2.5, 'checkEverySeconds': 30.5},
        },
      ]) {
        final rules = ScheduledRideRules.fromJson(json);
        expect(rules.backupAfterMinutes, 5);
        expect(rules.lateEta.toleranceMinutes, 3);
        expect(rules.lateEta.checkEverySeconds, 60);
      }
    });

    test('wrong types and unknown choices keep the defaults', () {
      final rules = ScheduledRideRules.fromJson({
        'offlineBackupAfterMin': '9',
        'onDriverCancel': 'somewhere',
        'longTripKm': double.nan,
        'rideTypes': {
          'premium': {'onlineBeforeMin': 5},
          'airport': 'broken',
        },
        'lateEta': {'on': 1, 'reassignTo': 'teleport', 'toleranceMin': null},
      });
      expect(rules.backupAfterMinutes, 5);
      expect(rules.onDriverCancel, ReservationCancelReturn.byTime);
      expect(rules.longTripKm, 50);
      // Only the contract keys; admin's "premium" id is mapped by admin.
      expect(
        rules.ruleFor(ScheduledRideKind.comfortPremium).onlineBeforeMinutes,
        45,
      );
      expect(rules.ruleFor(ScheduledRideKind.airport).onlineBeforeMinutes, 60);
      expect(rules.lateEta.on, isTrue);
      expect(rules.lateEta.reassignTo, LateEtaReassignTo.exclusive);
      expect(rules.lateEta.toleranceMinutes, 3);
      for (final to in LateEtaReassignTo.values) {
        expect(LateEtaRule.fromJson({'reassignTo': to.name}).reassignTo, to);
      }
    });
  });

  group('DriverAppConfig.reservations', () {
    tearDown(() => ScheduledRideRules.current = const ScheduledRideRules());

    test('read from the config and put in use by apply()', () {
      final config = DriverAppConfig.fromJson({
        'reservations': {
          'offlineBackupAfterMin': 9,
          'lateEta': {'toleranceMin': 6, 'reassignTo': 'dispatch'},
        },
      });
      expect(config.reservations.backupAfterMinutes, 9);
      expect(config.reservations.lateEta.toleranceMinutes, 6);
      config.apply();
      expect(ScheduledRideRules.current.backupAfterMinutes, 9);
      expect(
        ScheduledRideRules.current.lateEta.reassignTo,
        LateEtaReassignTo.dispatch,
      );
    });

    test('a config without reservations keeps the defaults', () {
      final config = DriverAppConfig.fromJson(const {'version': 1});
      expect(config.reservations.backupAfterMinutes, 5);
      expect(config.reservations.lateEta.on, isTrue);
    });
  });

  group('active-ride snapshot', () {
    test('keeps a scheduled trip\'s pickup time and reservation', () {
      final ride = PersistedActiveRide(
        tripId: 'trip-1',
        stage: ActiveRideStage.headingToPickup,
        scheduledPickupAt: _pickup,
        scheduledRideId: 'res-1',
      );
      final json = ride.toJson();
      expect(json['scheduledPickupAt'], _pickup.toUtc().toIso8601String());
      final back = PersistedActiveRide.fromJson(json)!;
      expect(back.scheduledPickupAt, _pickup);
      expect(back.scheduledRideId, 'res-1');
      expect(back.stamped().scheduledPickupAt, _pickup);
    });

    test('any other trip has none, and a broken time is refused', () {
      const ride = PersistedActiveRide(
        tripId: 'trip-2',
        stage: ActiveRideStage.headingToPickup,
      );
      expect(ride.toJson().containsKey('scheduledPickupAt'), isFalse);
      expect(
        PersistedActiveRide.fromJson(ride.toJson())!.scheduledPickupAt,
        isNull,
      );
      expect(
        PersistedActiveRide.fromJson({
          ...ride.toJson(),
          'scheduledPickupAt': 'soon',
        }),
        isNull,
      );
    });
  });
}

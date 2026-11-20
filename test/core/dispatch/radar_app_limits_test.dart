import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/dispatch/radar_app_limits.dart';

void main() {
  group('RadarAppLimits (contract §3.3, offers.radarApp)', () {
    test('defaults are the contract defaults', () {
      const limits = RadarAppLimits();
      expect(limits.full, 8);
      expect(limits.popup, 2);
      expect(limits.listOpen(moving: false), isTrue);
      expect(limits.listOpen(moving: true), isFalse);
      expect(limits.cardLimit(moving: true), 2);
    });

    test('the admin numbers reach the app through withOffers', () {
      final rules = const DriverOfferRules().withOffers({
        'radarApp': {
          'fullOn': true,
          'full': 5,
          'fullLockWhileDriving': false,
          'popupOn': true,
          'popup': 3,
          'popupSplitByDriving': true,
          'popupWhileDriving': 1,
        },
      });
      final limits = rules.radarApp;
      expect(limits.listLimit, 5);
      expect(limits.listOpen(moving: true), isTrue);
      expect(limits.cardLimit(moving: false), 3);
      expect(limits.cardLimit(moving: true), 1);
    });

    test('a whole number sent as 3.0 counts', () {
      expect(RadarAppLimits.fromJson({'popup': 3.0}).popup, 3);
      expect(RadarAppLimits.fromJson({'popup': 2.5}).popup, 2);
    });

    test('switched off: no list, no cards', () {
      final limits = RadarAppLimits.fromJson({
        'fullOn': false,
        'popupOn': false,
      });
      expect(limits.listOpen(moving: false), isFalse);
      expect(limits.listLimit, 0);
      expect(limits.cardLimit(moving: false), 0);
    });

    test('bad values keep what is in use', () {
      final limits = RadarAppLimits.fromJson({
        'full': 99,
        'popup': 0,
        'popupWhileDriving': 'x',
      });
      expect(limits.full, 8);
      expect(limits.popup, 2);
      expect(limits.popupWhileDriving, 1);
    });

    test('auto-offline change keeps the radar limits', () {
      final rules = const DriverOfferRules()
          .withOffers({
            'radarApp': {'full': 3},
          })
          .withAutoOffline(on: true, after: 5);
      expect(rules.radarApp.full, 3);
    });
  });

  group('DriverMotion (contract.json#driverMotion: 1 m/s for 10 s)', () {
    final t0 = DateTime.utc(2026, 11, 20, 12);
    test('moving only after 10 s at 1 m/s or more', () {
      final motion = DriverMotion();
      motion.update(speedMps: 5, at: t0);
      expect(motion.moving, isFalse);
      motion.update(speedMps: 5, at: t0.add(const Duration(seconds: 9)));
      expect(motion.moving, isFalse);
      motion.update(speedMps: 5, at: t0.add(const Duration(seconds: 10)));
      expect(motion.moving, isTrue);
    });

    test('a short stop at a light does not flip it back', () {
      final motion = DriverMotion();
      motion.update(speedMps: 5, at: t0);
      motion.update(speedMps: 5, at: t0.add(const Duration(seconds: 10)));
      motion.update(speedMps: 0, at: t0.add(const Duration(seconds: 12)));
      motion.update(speedMps: 0, at: t0.add(const Duration(seconds: 20)));
      expect(motion.moving, isTrue);
      motion.update(speedMps: 0, at: t0.add(const Duration(seconds: 22)));
      expect(motion.moving, isFalse);
    });

    test('offline resets to stopped', () {
      final motion = DriverMotion();
      motion.update(speedMps: 5, at: t0);
      motion.update(speedMps: 5, at: t0.add(const Duration(seconds: 10)));
      motion.reset();
      expect(motion.moving, isFalse);
    });

    test('no speed keeps the state', () {
      final motion = DriverMotion();
      motion.update(speedMps: null, at: t0);
      expect(motion.moving, isFalse);
    });
  });

  group('splitRadarDeck (Home deck refresh, §3.3)', () {
    String id(String s) => s;
    test('refresh keeps the overflow trips as held', () {
      final r = splitRadarDeck(['a', 'b', 'c', 'd'], limit: 2, id: id);
      expect(r.shown, ['a', 'b']);
      expect(r.held, ['c', 'd']);
    });
    test('driving lowers the limit: cards move back to held, then return', () {
      final driving = splitRadarDeck(['a', 'b', 'c'], limit: 1, id: id);
      expect(driving.shown, ['a']);
      expect(driving.held, ['b', 'c']);
      final stopped = splitRadarDeck(
        [...driving.shown, ...driving.held],
        limit: 3,
        id: id,
      );
      expect(stopped.shown, ['a', 'b', 'c']);
      expect(stopped.held, isEmpty);
    });
    test('duplicates count once; run-out held trips leave', () {
      final r = splitRadarDeck(
        ['a', 'a', 'b', 'c'],
        limit: 1,
        id: id,
        gone: (s) => s == 'c',
      );
      expect(r.shown, ['a']);
      expect(r.held, ['b']);
    });
    test('the list locks once driving and closes on the change', () {
      const limits = RadarAppLimits();
      final motion = DriverMotion();
      final t0 = DateTime.utc(2026, 11, 20);
      motion.update(speedMps: 8, at: t0);
      final changed = motion.update(
        speedMps: 8,
        at: t0.add(const Duration(seconds: 10)),
      );
      expect(changed, isTrue);
      expect(limits.listOpen(moving: motion.moving), isFalse);
    });
  });
}

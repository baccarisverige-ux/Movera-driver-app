import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/account/driver_account_rules.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/notifications/driver_notifications.dart';
import 'package:movera/core/vehicle/ride_categories.dart';

void main() {
  group('Q25/Q26: admin defaults', () {
    test('12 h work, 6 h rest, warnings at 30 and 10 min', () {
      const rules = DriverAccountRules();
      expect(rules.rest.work, const Duration(hours: 12));
      expect(rules.rest.rest, const Duration(hours: 6));
      expect(rules.rest.warnMinutesLeft, [30, 10]);
      expect(rules.rest.blockAtLimit, isTrue);
    });
  });

  // Q26 now follows the server (contract v0.17.0 §25): the admin's warning
  // days and block at expiry, test/core/onboarding_test.dart.

  group('Q27: categories', () {
    test('admin allows the car\'s categories; the driver turns some off', () {
      final access = DriverCategoryAccess.current;
      expect(access.allows('Comfort'), isTrue);
      expect(access.allows('Electric'), isFalse);
      expect(access.allows('XL'), isFalse);
      // Not a ride category: never filtered.
      expect(access.allows('Event'), isTrue);

      expect(DriverCategoryChoice.takes('Comfort'), isTrue);
      DriverCategoryChoice.off.value = {'Comfort'};
      expect(DriverCategoryChoice.takes('Comfort'), isFalse);
      expect(DriverCategoryChoice.takes('Premium'), isTrue);
      DriverCategoryChoice.reset();
      expect(DriverCategoryChoice.takes('Comfort'), isTrue);
    });
  });

  group('Q30: driver app texts', () {
    tearDown(DriverAppTexts.reset);

    test('admin text per language; empty or missing is the app text', () {
      DriverAppTexts.overrides = const DriverAppTextOverrides({
        'en': {'island.online': '', 'offer.accept': 'Take ride'},
        'sv': {'island.online': 'Radar på'},
      });
      expect(driverText(DriverTexts.islandOnline), 'Radar online');
      expect(driverText(DriverTexts.offerAccept), 'Take ride');
      DriverAppTexts.language = 'sv';
      expect(driverText(DriverTexts.islandOnline), 'Radar på');
      // Round 4: no admin text in Swedish is the app's own Swedish text.
      expect(driverText(DriverTexts.offerAccept), 'Acceptera');
      DriverAppTexts.language = 'fr';
      expect(driverText(DriverTexts.islandOnline), 'Radar en ligne');
    });

    test('values fill the braces, also in admin texts', () {
      expect(
        driverText(DriverTexts.islandRestUntil, {'time': '04:30'}),
        'Rest until 04:30',
      );
      DriverAppTexts.overrides = const DriverAppTextOverrides({
        'en': {'island.restUntil': 'Back online at {time}'},
      });
      expect(
        driverText(DriverTexts.islandRestUntil, {'time': '04:30'}),
        'Back online at 04:30',
      );
    });

    test('every key is listed once, in its area', () {
      final ids = DriverTexts.all.map((k) => k.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      for (final key in DriverTexts.all) {
        expect(key.id.startsWith('${key.area.name}.'), isTrue, reason: key.id);
        expect(key.english.trim(), isNotEmpty);
      }
    });
  });

  group('Q31: notifications', () {
    tearDown(() => DriverNoticeRules.current = const DriverNoticeRules());

    test('new ones pop up once; admin can turn a kind off', () {
      final now = DateTime(2026, 10, 15, 9);
      final feed = DriverNotificationFeed(now: () => now)..load(const []);
      expect(feed.add(DriverNotices.highDemand(now)), isTrue);
      expect(feed.add(DriverNotices.restOver(now), popup: false), isTrue);
      expect(feed.unread, 2);
      expect(feed.takePopups().map((n) => n.island), ['High demand · City']);
      expect(feed.takePopups(), isEmpty);
      expect(feed.items.first.kind, DriverNoticeKind.restOver);

      DriverNoticeRules.current = const DriverNoticeRules(
        off: {DriverNoticeKind.highDemand},
      );
      expect(feed.add(DriverNotices.highDemand(now)), isFalse);
      expect(feed.items, hasLength(2));
      feed.markAllRead();
      expect(feed.unread, 0);
    });

    test('N1–N3 kinds are in their groups', () {
      expect(
        DriverNoticeKind.newScheduledRide.group,
        DriverNoticeGroup.rideAlerts,
      );
      expect(DriverNoticeKind.leaveNow.group, DriverNoticeGroup.rideAlerts);
      expect(DriverNoticeKind.event.group, DriverNoticeGroup.demand);
      expect(DriverNoticeKind.payoutSent.group, DriverNoticeGroup.account);
      expect(DriverNoticeKind.bonusProgress.group, DriverNoticeGroup.account);
      final demo = DriverNotices.demoReceived(DateTime(2026, 10, 15));
      expect(demo.first.body, 'Tomorrow 07:40 · 126 kr · Tap to view');
    });
  });
}

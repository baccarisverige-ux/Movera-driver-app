import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/account/driver_account_rules.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/documents/document_expiry.dart';
import 'package:movera/core/notifications/driver_notifications.dart';
import 'package:movera/core/vehicle/ride_categories.dart';

TrackedDocument _doc(String id, DateTime expiresOn) => TrackedDocument(
  id: id,
  title: 'Insurance letter',
  shortTitle: 'Insurance',
  expiresOn: expiresOn,
);

void main() {
  group('Q25/Q26: admin defaults', () {
    test('12 h work, 6 h rest, warnings at 30 and 10 min', () {
      const rules = DriverAccountRules();
      expect(rules.rest.work, const Duration(hours: 12));
      expect(rules.rest.rest, const Duration(hours: 6));
      expect(rules.rest.warnMinutesLeft, [30, 10]);
      expect(rules.rest.blockAtLimit, isTrue);
      expect(rules.documents.warnDaysBefore, [30, 7, 1]);
      expect(rules.documents.blockOnExpiry, isTrue);
    });

    test('each day left falls in one warning step', () {
      const rule = DocumentExpiryRule();
      expect(rule.warningFor(45), isNull);
      expect(rule.warningFor(30), 30);
      expect(rule.warningFor(12), 30);
      expect(rule.warningFor(7), 7);
      expect(rule.warningFor(2), 7);
      expect(rule.warningFor(1), 1);
      expect(rule.warningFor(0), isNull);
    });
  });

  group('Q26: documents that run out', () {
    test('warns once per step, blocks on the expiry day until approved', () {
      var now = DateTime(2026, 10, 15, 9);
      final store = DocumentExpiryStore(
        now: () => now,
        seed: [_doc('INS', DateTime(2026, 11, 10))],
      );
      expect(store.takeWarnings().single.step, 30);
      expect(store.takeWarnings(), isEmpty);
      now = DateTime(2026, 11, 4, 9);
      final seven = store.takeWarnings().single;
      expect((seven.step, seven.daysLeft), (7, 6));
      expect(store.blocking, isNull);

      now = DateTime(2026, 11, 10, 6);
      expect(store.takeWarnings(), isEmpty);
      expect(store.blocking?.id, 'INS');
      store.uploadNew('INS');
      expect(store.blocking?.inReview, isTrue);
      store.approve('INS');
      expect(store.blocking, isNull);
      expect(store.byId('INS')!.expiresOn, DateTime(2027, 11, 10));
    });

    test('a new one in review needs no more warnings', () {
      final now = DateTime(2026, 10, 15);
      final store = DocumentExpiryStore(
        now: () => now,
        seed: [_doc('INS', DateTime(2026, 10, 16))],
      )..uploadNew('INS');
      expect(store.takeWarnings(), isEmpty);
      expect(expiresInLabel(1), 'tomorrow');
      expect(expiresInLabel(7), 'in 7 days');
    });

    test('the demo insurance letter ends in 7 days', () {
      final now = DateTime(2026, 10, 15, 12);
      final insurance = DocumentExpiryStore.demo(now).first;
      expect(insurance.title, 'Insurance letter');
      expect(insurance.daysLeft(now), 7);
    });
  });

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

    test('admin text per language; empty or missing is the default', () {
      DriverAppTexts.overrides = const DriverAppTextOverrides({
        'en': {'island.online': '', 'offer.accept': 'Take ride'},
        'sv': {'island.online': 'Radar på'},
      });
      expect(driverText(DriverTexts.islandOnline), 'Radar online');
      expect(driverText(DriverTexts.offerAccept), 'Take ride');
      DriverAppTexts.language = 'sv';
      expect(driverText(DriverTexts.islandOnline), 'Radar på');
      expect(driverText(DriverTexts.offerAccept), 'Accept');
      DriverAppTexts.language = 'fr';
      expect(driverText(DriverTexts.islandOnline), 'Radar online');
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
      expect(DriverNoticeKind.newScheduledRide.group, DriverNoticeGroup.rideAlerts);
      expect(DriverNoticeKind.leaveNow.group, DriverNoticeGroup.rideAlerts);
      expect(DriverNoticeKind.event.group, DriverNoticeGroup.demand);
      expect(DriverNoticeKind.payoutSent.group, DriverNoticeGroup.account);
      expect(DriverNoticeKind.bonusProgress.group, DriverNoticeGroup.account);
      final demo = DriverNotices.demoReceived(DateTime(2026, 10, 15));
      expect(demo.first.body, 'Tomorrow 07:40 · 126 kr · Tap to view');
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/documents/document_expiry.dart';
import 'package:movera/core/notifications/driver_notifications.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';
import 'package:movera/core/vehicle/ride_categories.dart';
import 'package:movera/presentation/driver/documents/document_renewal.dart';
import 'package:movera/presentation/driver/documents/documents.dart';
import 'package:movera/presentation/driver/home/components/reservation_request_sheet.dart';
import 'package:movera/presentation/driver/notifications/driver_notifications_screen.dart';
import 'package:movera/presentation/driver/preferences/preferences.dart';
import 'package:movera/presentation/driver/side%20menu/side_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Round 3 (D3) screens: Ride preferences with the categories admin allows
// (Q27), Documents with "Upload new" (Q26), Notifications (Q31), and the
// Home reservation popup on narrow phones.

Future<void> _show(
  WidgetTester tester,
  Widget page, {
  double width = 375,
  double height = 812,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pumpAndSettle();
}

TrackedDocument _insurance(int daysLeft) {
  final now = ScheduledClock.realNow();
  return TrackedDocument(
    id: 'DOC-INS-418',
    title: 'Insurance letter',
    shortTitle: 'Insurance',
    expiresOn: DateTime(now.year, now.month, now.day + daysLeft),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Q27: Ride preferences', () {
    testWidgets('only the categories admin allows; offers follow', (
      tester,
    ) async {
      await _show(tester, const Preferences());
      expect(find.text('6 of 6 active'), findsOneWidget);
      expect(find.text('Movera XL'), findsNothing);
      expect(find.text('Electric'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('preferences-categories-note')),
        findsOneWidget,
      );
      await tester.tap(find.text('Comfort'));
      await tester.pumpAndSettle();
      expect(find.text('5 of 6 active'), findsOneWidget);
      expect(DriverCategoryChoice.off.value, {'Comfort'});
      expect(DriverCategoryChoice.takes('Comfort'), isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('Q26: Documents', () {
    testWidgets('a document running out shows Upload new, then review', (
      tester,
    ) async {
      DocumentExpiryStore.instance.load([_insurance(7)]);
      await _show(tester, const DriverDocuments());
      final card = find.byKey(const ValueKey<String>('document-expiry-DOC-INS-418'));
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.textContaining('Expires in 7 days')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey<String>('document-upload-DOC-INS-418')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('document-upload-send')));
      await tester.pumpAndSettle();
      expect(find.text('New document in review'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('document-approve-DOC-INS-418')));
      await tester.pumpAndSettle();
      expect(card, findsNothing);
      expect(
        DriverNotificationFeed.instance.items.first.kind,
        DriverNoticeKind.documentApproved,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('nothing running out: the onboarding list only', (tester) async {
      await _show(tester, const DriverDocuments());
      expect(find.byType(DocumentExpiryList, skipOffstage: false), findsOneWidget);
      expect(find.textContaining('Expires'), findsNothing);
      expect(find.text('0 of 11 approved'), findsOneWidget);
    });
  });

  group('Q31: Notifications', () {
    testWidgets('N1–N3 in one list, with filters, a map and Upload new', (
      tester,
    ) async {
      DocumentExpiryStore.instance.load([_insurance(7)]);
      final feed = DriverNotificationFeed.instance..reset();
      final now = feed.now;
      feed
        ..add(DriverNotices.highDemand(now))
        ..add(DriverNotices.documentExpiring(
          now,
          documentId: 'DOC-INS-418',
          title: 'Insurance letter',
          shortTitle: 'Insurance',
          when: 'in 7 days',
        ));
      expect(feed.unread, 5);
      await _show(tester, const DriverNotificationsScreen(), height: 1400);
      expect(feed.unread, 0);
      expect(find.text('Insurance letter expires in 7 days'), findsOneWidget);
      expect(find.text('High demand in Stockholm City'), findsOneWidget);
      expect(find.byType(DemandAreaMap), findsOneWidget);
      expect(find.text('Payout sent'), findsOneWidget);
      expect(find.text('Bonus progress'), findsOneWidget);
      expect(find.text('New scheduled ride'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('notifications-filter-demand')));
      await tester.pumpAndSettle();
      expect(find.text('Payout sent'), findsNothing);
      expect(find.text('High demand in Stockholm City'), findsOneWidget);
      final account = find.byKey(const ValueKey<String>('notifications-filter-account'));
      await tester.ensureVisible(account);
      await tester.pumpAndSettle();
      await tester.tap(account);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upload new'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('document-upload-sheet')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the menu shows how many are new', (tester) async {
      DriverNotificationFeed.instance.reset();
      await _show(tester, const Scaffold(body: DriverSideMenu()));
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('Home reservation popup on narrow phones', () {
    for (final width in [320.0, 334.0, 347.0]) {
      testWidgets('fits at $width px', (tester) async {
        await _show(
          tester,
          Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ReservationRequestSheet(
                request: demoReservationRequest,
                mapBuilder: (_) => const ColoredBox(color: Color(0xFFE6EAED)),
                clock: () => DateTime(2026, 10, 15, 7),
              ),
            ),
          ),
          width: width,
        );
        expect(find.text('Today, 07:40'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

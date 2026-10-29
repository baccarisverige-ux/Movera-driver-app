import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/notifications/driver_notifications.dart';
import 'package:movera/core/vehicle/ride_categories.dart';
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

  group('Q26: Documents (demo)', () {
    testWidgets('the sample list only; no made-up end dates (group 2)', (
      tester,
    ) async {
      await _show(tester, const DriverDocuments());
      expect(find.textContaining('Expires'), findsNothing);
      expect(find.text('0 of 11 approved'), findsOneWidget);
      // A row opens its upload guide (owner item 4).
      await tester.tap(find.text('Driver’s license'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('upload-guide')), findsOneWidget);
      expect(find.text('Tips for a good photo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Q31: Notifications', () {
    testWidgets('N1–N3 in one list, with filters, a map and Upload new', (
      tester,
    ) async {
      final feed = DriverNotificationFeed.instance..reset();
      final now = feed.now;
      feed
        ..add(DriverNotices.highDemand(now))
        ..add(
          DriverNotices.documentExpiring(
            now,
            documentId: 'DOC-INS-418',
            title: () => 'Insurance letter',
            shortTitle: () => 'Insurance',
            when: () => 'in 7 days',
          ),
        );
      expect(feed.unread, 5);
      await _show(tester, const DriverNotificationsScreen(), height: 1400);
      expect(feed.unread, 0);
      expect(find.text('Insurance letter expires in 7 days'), findsOneWidget);
      expect(find.text('High demand in Stockholm City'), findsOneWidget);
      expect(find.byType(DemandAreaMap), findsOneWidget);
      expect(find.text('Payout sent'), findsOneWidget);
      expect(find.text('Bonus progress'), findsOneWidget);
      expect(find.text('New scheduled ride'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('notifications-filter-demand')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Payout sent'), findsNothing);
      expect(find.text('High demand in Stockholm City'), findsOneWidget);
      final account = find.byKey(
        const ValueKey<String>('notifications-filter-account'),
      );
      await tester.ensureVisible(account);
      await tester.pumpAndSettle();
      await tester.tap(account);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upload new'));
      await tester.pumpAndSettle();
      // Contract v0.17.0: the documents with their upload guides.
      expect(find.byType(DriverDocuments), findsOneWidget);
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
                // 40 min before its pickup, on the date the demo booked it
                // for (driver-u141: a fixed date no longer moves it).
                clock: () => demoReservationRequest.scheduledAt!.subtract(
                  const Duration(minutes: 40),
                ),
              ),
            ),
          ),
          width: width,
        );
        expect(find.text('In 40 min'), findsOneWidget);
        expect(find.text('07:40'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

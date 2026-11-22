import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/history/trip_history.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/presentation/driver/accept%20ride/cash_collect_sheet.dart';
import 'package:movera/presentation/driver/ride%20history/history%20detail/history_detail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

/// Owner 2026-11-21 14:55: the collect cash screen shows ONLY the final
/// price and the collect button. The earnings card (Din andel, Kontant
/// från resenären, what is owed to or by Movera) is not on it; the same
/// lines stay reachable on the finished trip in the ride history.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  tearDown(DriverAppTexts.reset);

  for (final language in ['sv', 'en', 'fr']) {
    testWidgets('collect screen: the total and the button, no earnings card '
        '($language)', (tester) async {
      DriverAppTexts.language = language;
      _phone(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CashCollectSheet(
              fare: '150,00 kr',
              cash: '250,00 kr',
              riderName: 'Anna',
              live: true,
              owedToMovera: Money(minorUnits: 9000, currency: 'SEK'),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('cash-collect-amount')))
            .data,
        '250,00 kr',
      );
      expect(find.byKey(const ValueKey('cash-complete-ride')), findsOneWidget);
      expect(find.byKey(const ValueKey('cash-collect-balance')), findsNothing);
      expect(find.text(tr.g8YourShare), findsNothing);
      expect(find.text(tr.cashFromRider), findsNothing);
      expect(find.text(tr.cashYouOweMovera), findsNothing);
      expect(find.text('150,00 kr'), findsNothing);
      expect(find.text('−90,00 kr'), findsNothing);
      // One amount only on the whole screen.
      expect(find.text('250,00 kr'), findsOneWidget);
    });
  }

  testWidgets('the same lines stay on the finished trip in the ride history', (
    tester,
  ) async {
    _phone(tester);
    SharedPreferences.setMockInitialValues({});
    final maps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          home: DriverRideHistoryDetail(
            record: const TripHistoryRecord(
              tripId: 'cash-trip',
              riderName: 'Anna',
              whenLabel: '21/11/2026, 15:00',
              pickup: 'A',
              dropoff: 'B',
              fare: '150,00 kr',
              category: 'Comfort',
              paymentMethod: 'Cash',
              cashCollected: '250,00 kr',
              owedToMovera: '90,00 kr',
            ),
            loadRideChecks: (_) async => const [],
          ),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final balance = find.byKey(const ValueKey('history-cash-balance'));
    await tester.ensureVisible(balance);
    expect(find.text(tr.yourEarnings), findsOneWidget);
    expect(find.text('150,00 kr'), findsWidgets);
    expect(find.text(tr.cashCollected), findsOneWidget);
    expect(find.text('250,00 kr'), findsOneWidget);
    expect(
      find.descendant(of: balance, matching: find.text(tr.cashYouOweMovera)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: balance, matching: find.text('−90,00 kr')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

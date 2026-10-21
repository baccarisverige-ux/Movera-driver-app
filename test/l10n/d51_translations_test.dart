import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/geo/driver_distance.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/driver/accept%20ride/cash_collect_sheet.dart';
import 'package:movera/presentation/driver/analytics/cancelation%20rate/cancelation_rate.dart';

/// Wave 5 D5.1 (parts a and b): texts that stayed in English, or in the
/// language a trip opened in, now follow the driver's language.
void speak(String code) => DriverAppTexts.language = code;

/// [home] in [code] on a roomy phone.
Future<void> show(WidgetTester tester, String code, Widget home) async {
  speak(code);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 1200);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (_, __) => MaterialApp(
      locale: Locale(code),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    ),
  ));
  await tester.pump();
}

/// [text] on screen, also inside rich text.
Finder words(String text) => find.textContaining(text, findRichText: true);

/// The languages each screen is checked in.
const languages = ['fr', 'sv'];

void main() {
  test('driver-33: French plurals take the singular for 0 and 1', () {
    speak('fr');
    expect(tr.tripsCount(0), '0 course');
    expect(tr.tripsCount(1), '1 course');
    expect(tr.tripsCount(2), '2 courses');
    expect(tr.stopsCount(0), '0 arrêt');
    expect(tr.riderBags(0), 'Le passager a 0 bagage');
    expect(tr.inDaysCount(0), 'dans 0 jour');
    expect(tr.schedRidesHidden(0), '0 course masquée');
    expect(tr.ratingAndRides('4,9', 0), '4,9 ★ · 0 course');
    speak('sv');
    expect(tr.tripsCount(0), '0 resor');
    expect(tr.tripsCount(1), '1 resa');
  });

  for (final code in languages) {
    testWidgets('driver-14: cash direction in $code', (tester) async {
      await show(tester, code, const Scaffold(
        body: CashCollectSheet(
          fare: '248,40 kr', cash: '300,00 kr', riderName: 'Nils'),
      ));
      expect(words(tr.cashYouOweMovera), findsWidgets);
      expect(words('You owe Movera'), findsNothing);
    });
  }

  for (final code in languages) {
    testWidgets('driver-15: decimals take the comma in $code', (tester) async {
      await show(tester, code, const CancelationRate());
      expect(words('2,4%'), findsWidgets);
      expect(words('2.4%'), findsNothing);
      expect(driverDistanceMeters(4200), '4,2 km');
      expect(driverDistanceAndMinutes(4.2, 9), '4,2 km · 9 min');
    });
  }
}

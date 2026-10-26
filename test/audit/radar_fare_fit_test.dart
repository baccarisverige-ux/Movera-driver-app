import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/zone_settings.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/widgets/radar_offer_card.dart';

/// driver-u182: the big Radar fare is one line in an Expanded next to the
/// PICKUP column. At 130 % text on a 320-360 px phone in fr/sv it wrapped
/// and only line 1 was painted ("104," for 104,80 kr). The whole fare must
/// show on the Home deck (viewport − 28 wide, with the corner close).
RadarOfferView _offer(String fare) => RadarOfferView(
  id: 'o1',
  category: 'Comfort',
  payment: 'Cash',
  rating: '4.96',
  riderTrips: 128,
  // The card shows the driver's money (owner decision 2026-10-26): the
  // label under test is given as the server's earnings.
  fare: fare,
  driverEarnings: fare,
  pickupMinutes: 2,
  pickupKm: 0.65,
  tripMinutes: 9,
  tripKm: 4.2,
  pickup: 'Kungsgatan 42, Stockholm',
  dropoff: 'Hornstull, Stockholm',
);

void main() {
  for (final (language, country) in [('fr', 'FR'), ('sv', 'SE')]) {
    for (final width in [320.0, 360.0]) {
      for (final fare in ['104,80 kr', '1 234,50 kr']) {
        testWidgets('$language $width px ×1.3: "$fare" is shown whole', (tester) async {
          DriverLanguage.applyZone(AppLanguages.forCountry(country));
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 800);
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpWidget(MaterialApp(
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width - 28,
                  child: RadarOfferCard(offer: _offer(fare), onMatch: () {}, onClose: () {}),
                ),
              ),
            ),
          ));
          await tester.pump();
          final price = find.byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText() == fare,
          );
          expect(price, findsOneWidget);
          final paragraph = tester.renderObject<RenderParagraph>(price);
          expect(paragraph.didExceedMaxLines, isFalse, reason: 'the fare was cut');
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}

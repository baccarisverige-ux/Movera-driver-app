// driver-u92: the Ride check emergency button never loses its number.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/zone_settings.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/core/safety/demo_safety_alert_repository.dart';
import 'package:movera/core/safety/ride_check.dart';
import 'package:movera/core/safety/ride_check_controller.dart';
import 'package:movera/core/safety/ride_check_detector.dart';
import 'package:movera/core/safety/ride_check_log.dart';
import 'package:movera/core/safety/ride_check_services.dart';
import 'package:movera/core/safety/safety_alert_repository.dart';
import 'package:movera/presentation/driver/accept%20ride/ride_check_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _trip = SafetyAlertTrip(
  tripId: 'trip-1',
  riderName: 'Angelica',
  riderRating: 4.9,
  pickup: 'Odlarvägen 22',
  dropoff: 'T-Centralen, Stockholm',
  fare: '126 kr',
  category: 'Comfort',
  driverName: 'Movera Driver',
  vehicle: 'Volvo XC60',
  plate: 'ABC 123',
);

/// The label of the button with [key], as laid out.
RenderParagraph _label(WidgetTester tester, Key key, String text) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(of: find.byKey(key), matching: find.text(text)),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final width in [320.0, 375.0]) {
    testWidgets('French, text x1.3, $width px: "Appeler le 112" is whole', (
      tester,
    ) async {
      DriverLanguage.applyZone(AppLanguages.forCountry('FR'));
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final alerts = DemoSafetyAlertRepository();
      addTearDown(alerts.dispose);
      final controller = RideCheckController(
        services: RideCheckServices(
          alerts: alerts,
          log: MemoryRideCheckLog(),
          launch: (_) async => true,
        ),
        tripId: 'trip-1',
        tripDetails: () => _trip,
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: ListenableBuilder(
              listenable: controller,
              builder: (_, _) => controller.active
                  ? RideCheckLayer(
                      controller: controller,
                      top: 10,
                      maxHeight: 680,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      );
      unawaited(
        controller.open(
          RideCheckDetector().demo(
            RideCheckTrigger.longStop,
            DateTime.now(),
            destination: 'T-Centralen, Stockholm',
          ),
          instant: true,
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(tr.call112, 'Appeler le 112');
      final call = _label(
        tester,
        const ValueKey('ride-check-call-112'),
        'Appeler le 112',
      );
      expect(
        call.didExceedMaxLines,
        isFalse,
        reason: 'the emergency number is never cut off',
      );
      final ok = _label(tester, const ValueKey('ride-check-ok'), tr.iMOk);
      expect(ok.didExceedMaxLines, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
  }
}

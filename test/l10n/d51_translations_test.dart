import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/geo/driver_distance.dart';
import 'package:movera/core/island/trip_island_controller.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/accept%20ride/cash_collect_sheet.dart';
import 'package:movera/presentation/driver/analytics/cancelation%20rate/cancelation_rate.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

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

/// A phone in Paris, far from the demo pickup.
class FarAway implements DriverLocationRepository {
  DriverLocation get _fix => DriverLocation(
    point: const GeoPoint(48.8566, 2.3522),
    measuredAt: DateTime.now(),
    accuracyMeters: 5,
  );

  @override
  Future<DriverLocation> getCurrentPosition() async => _fix;

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      Stream<DriverLocation>.value(_fix);
}

Future<void> frames(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// What the island strip says for [inputs], in order.
Future<List<String>> stripSays(
  WidgetTester tester,
  List<TripStripInput> inputs,
) async {
  final strip = TripStripController(clock: () => DateTime(2026, 1, 1, 6));
  addTearDown(strip.dispose);
  final seen = <String>[];
  strip.addListener(() {
    if (strip.current.kind == TripStripKind.message) {
      seen.add(strip.current.text);
    }
  });
  for (final input in inputs) {
    strip.update(input);
    await tester.pump(TripStripController.messageTime);
  }
  return seen;
}

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

  for (final (code, said) in [('fr', 'Ensuite : Arrêt 1'), ('sv', 'Härnäst: Stopp 1')]) {
    testWidgets('driver-17: the next stop in $code', (tester) async {
      speak(code);
      final seen = await stripSays(tester, [
        TripStripInput(leg: TripLeg.stop, stopLabel: tr.stopNumber(1)),
      ]);
      expect(seen, [said]);
    });
  }

  for (final (code, said) in [
    ('fr', 'Prise en charge côté gauche'),
    ('sv', 'Upphämtning på vänster sida'),
  ]) {
    testWidgets('driver-u87: the pickup side in $code', (tester) async {
      speak(code);
      final seen = await stripSays(tester, [
        const TripStripInput(leg: TripLeg.pickup, pickupSide: 'left'),
      ]);
      expect(seen, [said]);
    });
  }

  for (final code in languages) {
    testWidgets('driver-41: arriving too far from the pickup in $code',
        (tester) async {
      final previous = DriverRuntimeConfig.current;
      addTearDown(() => DriverRuntimeConfig.current = previous);
      DriverRuntimeConfig.current = const DriverRuntimeConfig(
        simulatedArrival: false,
        externalRouting: false,
        skipAccountActivation: false,
        liveMapTicker: false,
      );
      await show(tester, code, AcceptRide(locationRepository: FarAway()));
      await frames(tester, 10);
      tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel))
          .controller!.animatePanelToSnapPoint();
      await frames(tester, 14);
      final button = find.byKey(const ValueKey('active-ride-arrived-button'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await frames(tester, 6);
      expect(find.text(tr.moveWithin100MOfPickup), findsOneWidget);
      expect(words('(pickup)'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

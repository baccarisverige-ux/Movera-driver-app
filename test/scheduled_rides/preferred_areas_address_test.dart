import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/presentation/driver/scheduled rides/preferred_areas.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'preferred_areas_fakes.dart';

/// v0.18.172 (owner 2026-11-28 "Yes, both ways"): an address becomes the
/// AREA that holds it (/driver/areas/at); the address text and the point are
/// never saved on the phone and never sent in PUT /driver/preferred-areas.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    DriverAppTexts.language = 'sv';
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => DriverAppTexts.language = 'en');

  Future<void> pickKlockarvagen(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const ValueKey('preferred-areas-search')),
      'Klockarvägen 37',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('preferred-address-g1')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Klockarvägen 37 → Södertälje added, toast; PUT holds area ids only; nothing stored',
    (tester) async {
      final api = FakeAreasApi(saved: const [sodermalm], at: sodertalje);
      final addresses = FakeAddresses();
      await tester.pumpWidget(
        MaterialApp(
          home: PreferredAreasScreen(api: api, addresses: addresses),
        ),
      );
      await tester.pumpAndSettle();
      await pickKlockarvagen(tester);
      expect(addresses.resolves, [
        'g1',
      ], reason: 'the suggestion had no position: geocode once');
      expect(api.points.single, [59.1960, 17.6260]);
      expect(
        find.text(
          'Klockarvägen 37 ligger i Södertälje, Stockholms län - tillagd',
        ),
        findsOneWidget,
      );
      expect(find.text('Spara (2)'), findsOneWidget);
      // The toast floats over the button; press it as the finger would after it.
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('preferred-areas-save')),
          )
          .onPressed!();
      await tester.pumpAndSettle();
      expect(api.puts.single, ['SE-SDO-SODERMALM', 'SE-K-0181']);
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getKeys().map((k) => '$k=${prefs.get(k)}').join(';');
      expect(stored, isNot(contains('Klockar')));
      expect(stored, isNot(contains('59.19')));
    },
  );

  testWidgets('a district answer (Södermalm) is added, not its kommun', (
    tester,
  ) async {
    final api = FakeAreasApi(saved: const [solna], at: sodermalm);
    await tester.pumpWidget(
      MaterialApp(
        home: PreferredAreasScreen(api: api, addresses: FakeAddresses()),
      ),
    );
    await tester.pumpAndSettle();
    await pickKlockarvagen(tester);
    expect(find.text('Spara (2)'), findsOneWidget);
    // The toast floats over the button; press it as the finger would after it.
    tester
        .widget<FilledButton>(
          find.byKey(const ValueKey('preferred-areas-save')),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    expect(api.puts.single, ['SE-K-0184', 'SE-SDO-SODERMALM']);
  });

  testWidgets('no area for the address: the message, nothing added', (
    tester,
  ) async {
    final api = FakeAreasApi(saved: const [sodermalm]);
    await tester.pumpWidget(
      MaterialApp(
        home: PreferredAreasScreen(api: api, addresses: FakeAddresses()),
      ),
    );
    await tester.pumpAndSettle();
    await pickKlockarvagen(tester);
    expect(
      find.text(
        'Den här adressen ligger utanför dina zoners områden. Välj en adress i din zon.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('preferred-areas-save')), findsNothing);
  });

  testWidgets(
    'the address service finds no position: "Adressen hittades inte"',
    (tester) async {
      final api = FakeAreasApi(saved: const [sodermalm], at: sodertalje);
      await tester.pumpWidget(
        MaterialApp(
          home: PreferredAreasScreen(
            api: api,
            addresses: FakeAddresses(located: null),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await pickKlockarvagen(tester);
      expect(find.text('Adressen hittades inte. Försök igen.'), findsOneWidget);
      expect(api.points, isEmpty);
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/presentation/driver/scheduled rides/preferred_areas.dart';

import 'preferred_areas_fakes.dart';

/// v0.18.172: area names come from /driver/areas/search; the address
/// service is asked only from 3 characters, at most once per debounced
/// search (each address search costs one Google autocomplete call on the
/// server); areas are listed before addresses.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => DriverAppTexts.language = 'sv');
  tearDown(() => DriverAppTexts.language = 'en');

  testWidgets(
    'typing "Klock" fast is ONE address call; under 3 characters none',
    (tester) async {
      final api = FakeAreasApi(saved: const [sodermalm]);
      final addresses = FakeAddresses();
      await tester.pumpWidget(
        MaterialApp(
          home: PreferredAreasScreen(api: api, addresses: addresses),
        ),
      );
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('preferred-areas-search'));
      await tester.enterText(field, 'Sö');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(addresses.searches, isEmpty, reason: '2 characters: areas only');
      expect(api.searches.last, 'Sö');
      expect(find.text('OMRÅDEN'), findsOneWidget);
      for (final text in ['K', 'Kl', 'Klo', 'Kloc', 'Klock']) {
        await tester.enterText(field, text);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(addresses.searches, ['Klock']);
      expect(find.text('ADRESSER'), findsOneWidget);
      expect(find.text('Klockarvägen 37'), findsOneWidget);
      expect(addresses.resolves, isEmpty, reason: 'geocode only after a tap');
    },
  );

  testWidgets('areas first, then addresses', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PreferredAreasScreen(
          api: FakeAreasApi(saved: const [sodermalm]),
          addresses: FakeAddresses(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('preferred-areas-search')),
      'Klock',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('OMRÅDEN'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('preferred-areas-search')),
      'Sol',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    final areasY = tester.getTopLeft(find.text('OMRÅDEN')).dy;
    expect(find.text('Solna'), findsOneWidget);
    expect(find.text('ADRESSER'), findsNothing);
    expect(areasY, greaterThan(0));
  });
}

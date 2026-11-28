import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/scheduled/preferred_areas.dart';
import 'package:movera/presentation/driver/scheduled rides/preferred_areas.dart';

import 'preferred_areas_fakes.dart';

/// v0.18.172 (mockup v4 row B): multi-select, "Spara (n)" only when changed,
/// "Rensa", the empty state ("Du får bokade resor i hela zonen").
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => DriverAppTexts.language = 'sv');
  tearDown(() => DriverAppTexts.language = 'en');

  Future<FakeAreasApi> open(
    WidgetTester tester, {
    List<PreferredArea> saved = const [],
  }) async {
    final api = FakeAreasApi(saved: saved);
    await tester.pumpWidget(
      MaterialApp(
        home: PreferredAreasScreen(api: api, addresses: FakeAddresses()),
      ),
    );
    await tester.pumpAndSettle();
    return api;
  }

  testWidgets(
    'several areas, Spara (n) only when changed, saves area ids only',
    (tester) async {
      final api = await open(tester, saved: const [sodermalm]);
      expect(find.text('Föredragna områden'), findsOneWidget);
      expect(find.text('FÖRSLAG'), findsOneWidget);
      expect(find.byKey(const ValueKey('preferred-areas-save')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('preferred-area-SE-K-0184')));
      await tester.pump();
      expect(find.text('Spara (2)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('preferred-area-SE-K-0184')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('preferred-areas-save')),
        findsNothing,
        reason: 'back to the saved list',
      );
      await tester.tap(find.byKey(const ValueKey('preferred-area-SE-K-0184')));
      await tester.tap(find.byKey(const ValueKey('preferred-area-SE-K-0181')));
      await tester.pump();
      await tester.tap(find.text('Spara (3)'));
      await tester.pumpAndSettle();
      expect(api.puts.single, ['SE-SDO-SODERMALM', 'SE-K-0184', 'SE-K-0181']);
      expect(PreferredAreasStore.saved.value.length, 3);
    },
  );

  testWidgets('Rensa unselects everything; saving it sends []', (tester) async {
    final api = await open(tester, saved: const [sodermalm, solna]);
    await tester.tap(find.byKey(const ValueKey('preferred-areas-clear')));
    await tester.pump();
    expect(find.text('Spara (0)'), findsOneWidget);
    await tester.tap(find.text('Spara (0)'));
    await tester.pumpAndSettle();
    expect(api.puts.single, isEmpty);
  });

  testWidgets(
    'no areas chosen: the empty state, then Välj områden opens the list',
    (tester) async {
      await open(tester);
      expect(find.text('Inga valda områden'), findsOneWidget);
      expect(find.text('Du får bokade resor i hela zonen'), findsOneWidget);
      await tester.tap(find.text('Välj områden'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('preferred-areas-search')),
        findsOneWidget,
      );
      expect(find.text('Sök område eller adress'), findsOneWidget);
      expect(
        find.text('Vi sparar bara området, aldrig gatan eller numret.'),
        findsOneWidget,
      );
    },
  );
}

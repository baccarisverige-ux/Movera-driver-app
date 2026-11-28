import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/live/live_reservations.dart';
import 'package:movera/core/scheduled/preferred_areas.dart';
import 'package:movera/presentation/driver/scheduled rides/preferred_areas.dart';

import 'preferred_areas_fakes.dart';

/// v0.18.172 (reviewer 2026-11-28): a refused save tells the real reason
/// (never "No connection" unless it is the network), and an area Movera
/// switched off leaves the selection with a note so the driver can save
/// the rest (never blocked).
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => DriverAppTexts.language = 'sv');
  tearDown(() => DriverAppTexts.language = 'en');

  void press(WidgetTester tester) => tester
      .widget<FilledButton>(find.byKey(const ValueKey('preferred-areas-save')))
      .onPressed!();

  testWidgets('over the max: the max is told, not "no connection"', (
    tester,
  ) async {
    final api = FakeAreasApi(saved: const [sodermalm])
      ..refusals.add(
        const PreferredAreasRefusal(PreferredAreasRefusalKind.tooMany, max: 2),
      );
    await tester.pumpWidget(
      MaterialApp(
        home: PreferredAreasScreen(api: api, addresses: FakeAddresses()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('preferred-area-SE-K-0184')));
    await tester.tap(find.byKey(const ValueKey('preferred-area-SE-K-0181')));
    await tester.pump();
    press(tester);
    await tester.pumpAndSettle();
    expect(
      find.text('Du kan välja högst 2 områden. Ta bort ett och spara igen.'),
      findsOneWidget,
    );
    expect(find.text('Ingen anslutning'), findsNothing);
    expect(
      find.byKey(const ValueKey('preferred-areas-save')),
      findsOneWidget,
      reason: 'he can fix it and save',
    );
  });

  testWidgets(
    'an area Movera switched off: dropped with a note, the rest saves',
    (tester) async {
      final api = FakeAreasApi(saved: const [sodermalm, solna])
        ..refusals.add(
          const PreferredAreasRefusal(
            PreferredAreasRefusalKind.gone,
            goneIds: ['SE-SDO-SODERMALM'],
          ),
        );
      await tester.pumpWidget(
        MaterialApp(
          home: PreferredAreasScreen(api: api, addresses: FakeAddresses()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('preferred-area-SE-K-0181')));
      await tester.pump();
      press(tester);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Södermalm erbjuds inte längre av Movera och togs bort. Tryck Spara för att behålla de andra.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('preferred-area-SE-SDO-SODERMALM')),
        findsNothing,
      );
      press(tester);
      await tester.pumpAndSettle();
      expect(api.puts.last, ['SE-K-0184', 'SE-K-0181']);
      expect(PreferredAreasStore.saved.value.map((a) => a.areaId), [
        'SE-K-0184',
        'SE-K-0181',
      ]);
    },
  );

  testWidgets(
    'a saved area switched off, nothing else changed: he can still save without it',
    (tester) async {
      final api = FakeAreasApi(saved: const [sodermalm, solna]);
      await tester.pumpWidget(
        MaterialApp(
          home: PreferredAreasScreen(api: api, addresses: FakeAddresses()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('preferred-area-SE-SDO-SODERMALM')),
      );
      await tester.pump();
      press(tester);
      await tester.pumpAndSettle();
      expect(api.puts.last, ['SE-K-0184']);
    },
  );

  test(
    'live: 400 too_many_areas / area_not_found become reasons; only network is "network"',
    () async {
      var answer = http.Response('{}', 200);
      final live = LiveReservations(
        api: ApiClient(
          client: MockClient((_) async => answer),
          baseUri: Uri.parse('https://api.example.test'),
          tokens: MemoryTokenStore()..save(access: 'a1', refresh: 'r1'),
        ),
      );
      http.Response err(String reason, List<String> details) => http.Response(
        jsonEncode({
          'code': 'invalid_request',
          'message': 'x',
          'requestId': 'r',
          'retryable': false,
          'reason': reason,
          'details': details,
        }),
        400,
        headers: {'content-type': 'application/json'},
      );
      answer = err('too_many_areas', ['max:10']);
      var r = (await live.setPreferredAreas(['A1-X'])).refusal!;
      expect([r.kind, r.max], [PreferredAreasRefusalKind.tooMany, 10]);
      answer = err('area_not_found', ['areaId:SE-SDO-SODERMALM']);
      r = (await live.setPreferredAreas(['SE-SDO-SODERMALM'])).refusal!;
      expect(
        [r.kind, r.goneIds],
        [
          PreferredAreasRefusalKind.gone,
          ['SE-SDO-SODERMALM'],
        ],
      );
      answer = err('something_else', []);
      expect(
        (await live.setPreferredAreas(['X1-X'])).refusal!.kind,
        PreferredAreasRefusalKind.other,
      );
    },
  );
}

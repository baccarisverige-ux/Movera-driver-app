import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/live/live_earnings.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/presentation/driver/my%20wallet/wallet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// BQ-M22 driver part (contract v0.18.92 priceDisplay.payoutSummary; owner
/// 2026-11-14 "U show how much driver get and how much movera get thats all
/// no details"): the payout card shows the server's two lines
/// `Payout.summary { driverGets, moveraGets }` (his view), amounts only;
/// absent (an older server) → the card shows Payout.amount only. The app
/// never adds or subtracts. The contract copy here is older than 0.18.92
/// (not merged yet), so the field is read as optional.
void main() {
  Map<String, dynamic> money(int minor, String c) => {
    'amountMinor': minor,
    'currency': c,
  };
  Map<String, dynamic> payout(String c, {Map<String, dynamic>? summary}) => {
    'payoutId': 'PY1',
    'driverId': 'D1',
    'amount': money(c == 'TND' ? 10000 : 33500, c),
    'status': 'pending',
    'periodStart': '2026-11-02T00:00:00Z',
    'periodEnd': '2026-11-09T00:00:00Z',
    'createdAt': '2026-11-09T01:00:00Z',
    'source': 'weekly',
    'tripCount': 3,
    'lines': [],
    'summary': ?summary,
  };

  group('DriverPayout.summary parse', () {
    test('SEK: the two numbers, formatted with decimals', () {
      final p = DriverPayout.tryParse(
        payout(
          'SEK',
          summary: {
            'driverGets': money(43500, 'SEK'),
            'moveraGets': money(9850, 'SEK'),
          },
        ),
      )!;
      expect(p.summary, isNotNull);
      expect(p.summary!.driverGets.formatted, '435,00 kr');
      expect(p.summary!.moveraGets.formatted, '98,50 kr');
      // Payout.amount stays what it was (not touched by the summary).
      expect(p.amount.formatted, '335,00 kr');
    });

    test('EUR and TND (3 decimals)', () {
      final eur = DriverPayout.tryParse(
        payout(
          'EUR',
          summary: {
            'driverGets': money(4550, 'EUR'),
            'moveraGets': money(1200, 'EUR'),
          },
        ),
      )!;
      expect(eur.summary!.driverGets.formatted, '45,50 €');
      expect(eur.summary!.moveraGets.formatted, '12,00 €');
      final tnd = DriverPayout.tryParse(
        payout(
          'TND',
          summary: {
            'driverGets': money(16000, 'TND'),
            'moveraGets': money(6000, 'TND'),
          },
        ),
      )!;
      expect(tnd.summary!.driverGets.minorUnits, 16000);
      expect(tnd.summary!.driverGets.formatted, contains('16'));
      expect(tnd.summary!.driverGets.formatted, contains('000'));
      expect(tnd.summary!.moveraGets.minorUnits, 6000);
    });

    test('absent or broken summary → null, the payout still parses', () {
      expect(DriverPayout.tryParse(payout('SEK'))!.summary, isNull);
      final half = DriverPayout.tryParse(
        payout('SEK', summary: {'driverGets': money(100, 'SEK')}),
      )!;
      expect(half.summary, isNull);
      final bad = DriverPayout.tryParse(
        payout(
          'SEK',
          summary: {
            'driverGets': {'amountMinor': 'x', 'currency': 'SEK'},
            'moveraGets': money(1, 'SEK'),
          },
        ),
      )!;
      expect(bad.summary, isNull);
    });
  });

  group('wallet payout card', () {
    late LiveDriverServices live;

    void serve(List<Map<String, dynamic>> items) {
      final tokens = MemoryTokenStore()..save(access: 'a', refresh: 'r');
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/driver/payouts')) {
          return http.Response(
            jsonEncode({'items': items, 'nextCursor': null}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/driver/earnings')) {
          return http.Response(
            jsonEncode({
              'currency': 'SEK',
              'currencies': ['SEK'],
              'periods': [],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({'items': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = ApiClient(
        client: client,
        baseUri: Uri.parse('https://api.test.movera.se'),
        tokens: tokens,
      );
      live = LiveDriverServices(
        client: client,
        origin: Uri.parse('https://api.test.movera.se'),
        tokens: tokens,
        api: api,
        location: _NoGps(),
      );
      LiveDriverServices.instance = live;
    }

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      Money.zoneCurrency = 'SEK';
    });
    tearDown(() async {
      LiveDriverServices.instance = null;
      Money.forgetZone();
      await live.dispose();
    });

    Future<GlobalKey> open(WidgetTester tester) async {
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(key: boundary, child: const WalletScreen()),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      return boundary;
    }

    String textOf(WidgetTester tester, String key) {
      final f = find.byKey(ValueKey<String>(key));
      expect(f, findsOneWidget, reason: key);
      return tester
          .widgetList<Text>(find.descendant(of: f, matching: find.byType(Text)))
          .map((t) => t.data ?? t.textSpan!.toPlainText())
          .join(' ');
    }

    testWidgets('summary sent: 2 lines Driver gets / Movera gets, no amount', (
      tester,
    ) async {
      serve([
        payout(
          'SEK',
          summary: {
            'driverGets': money(43500, 'SEK'),
            'moveraGets': money(9850, 'SEK'),
          },
        ),
      ]);
      await open(tester);
      expect(
        textOf(tester, 'wallet-payout-driver-gets'),
        'Driver gets 435,00 kr',
      );
      expect(
        textOf(tester, 'wallet-payout-movera-gets'),
        'Movera gets 98,50 kr',
      );
      expect(find.text('335,00 kr'), findsNothing);
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('no summary (older server): Payout.amount only', (
      tester,
    ) async {
      serve([payout('SEK')]);
      await open(tester);
      expect(find.text('335,00 kr'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('wallet-payout-driver-gets')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('wallet-payout-movera-gets')),
        findsNothing,
      );
    });

    for (final lang in const ['en', 'sv', 'fr']) {
      testWidgets('$lang texts as the contract', (tester) async {
        final shot = Platform.environment['MOVERA_SHOT_DIR'];
        if (shot != null) await tester.runAsync(_loadFonts);
        await tester.runAsync(() => DriverLanguage.choose(lang));
        addTearDown(DriverLanguage.resetForTest);
        serve([
          payout(
            'SEK',
            summary: {
              'driverGets': money(43500, 'SEK'),
              'moveraGets': money(9850, 'SEK'),
            },
          ),
        ]);
        tester.view.devicePixelRatio = 2;
        tester.view.physicalSize = const Size(390 * 2, 1400 * 2);
        addTearDown(tester.view.reset);
        final boundary = await open(tester);
        final want = {
          'en': ['Driver gets', 'Movera gets'],
          'sv': ['Föraren får', 'Movera får'],
          'fr': ['Le chauffeur reçoit', 'Movera reçoit'],
        }[lang]!;
        expect(
          textOf(tester, 'wallet-payout-driver-gets'),
          startsWith(want[0]),
        );
        expect(
          textOf(tester, 'wallet-payout-movera-gets'),
          startsWith(want[1]),
        );
        if (shot != null && lang != 'fr') {
          await tester.ensureVisible(
            find.byKey(const ValueKey<String>('wallet-payout-movera-gets')),
          );
          await tester.pump(const Duration(milliseconds: 300));
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await render.toImage(pixelRatio: 2);
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            File('$shot/driver-payout-card-$lang.png')
              ..createSync(recursive: true)
              ..writeAsBytesSync(png!.buffer.asUint8List());
          });
        }
      });
    }
  });
}

class _NoGps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() =>
      Completer<DriverLocation>().future;

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream<DriverLocation>.empty();
}

/// Screenshots only: real glyphs instead of the test font.
Future<void> _loadFonts() async {
  ByteData bytes(String path) =>
      ByteData.sublistView(File(path).readAsBytesSync());
  const dejavu = '/usr/share/fonts/truetype/dejavu';
  await (FontLoader('Roboto')
        ..addFont(Future.value(bytes('$dejavu/DejaVuSans.ttf')))
        ..addFont(Future.value(bytes('$dejavu/DejaVuSans-Bold.ttf'))))
      .load();
  await (FontLoader('Urbanist')
        ..addFont(Future.value(bytes('assets/fonts/urbanist/Urbanist-500.ttf')))
        ..addFont(Future.value(bytes('assets/fonts/urbanist/Urbanist-600.ttf')))
        ..addFont(
          Future.value(bytes('assets/fonts/urbanist/Urbanist-800.ttf')),
        ))
      .load();
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/presentation/driver/my%20wallet/wallet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owner 2026-11-10: the wallet opens on the tab of the driver's own zone
/// currency (Tunis → DT, Stockholm → kr); other currency tabs stay.
void main() {
  late List<Uri> asked;
  late LiveDriverServices live;

  void serve(List<String> currencies) {
    asked = [];
    final tokens = MemoryTokenStore()..save(access: 'a', refresh: 'r');
    final client = MockClient((request) async {
      asked.add(request.url);
      if (request.url.path.endsWith('/driver/earnings')) {
        // The server's default is the driver's first zone: kr here, as on
        // the real phone of a Tunis driver.
        final c = request.url.queryParameters['currency'] ?? 'SEK';
        return http.Response(
          jsonEncode({
            'currency': c,
            'currencies': currencies,
            'periods': [
              {
                'periodStart': '2026-11-09T00:00:00Z',
                'periodEnd': '2099-11-16T00:00:00Z',
                'net': {'amountMinor': 12500, 'currency': c},
              },
            ],
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

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() async {
    LiveDriverServices.instance = null;
    Money.forgetZone();
    await live.dispose();
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: WalletScreen()));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  ChoiceChip chip(WidgetTester tester, String c) =>
      tester.widget<ChoiceChip>(find.byKey(ValueKey('wallet-currency-$c')));

  String? askedCurrency() => asked
      .lastWhere((u) => u.path.endsWith('/driver/earnings'))
      .queryParameters['currency'];

  testWidgets('a Tunis driver opens on DT, the kr tab stays', (tester) async {
    Money.zoneCurrency = 'TND';
    serve(['SEK', 'TND']);
    await open(tester);
    expect(askedCurrency(), 'TND');
    expect(chip(tester, 'TND').selected, isTrue);
    expect(chip(tester, 'SEK').selected, isFalse);
    final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
    expect(chips.first.key, const ValueKey('wallet-currency-TND'));
  });

  testWidgets('a Stockholm driver opens on kr', (tester) async {
    Money.zoneCurrency = 'SEK';
    serve(['EUR', 'SEK']);
    await open(tester);
    expect(askedCurrency(), 'SEK');
    expect(chip(tester, 'SEK').selected, isTrue);
    expect(chip(tester, 'EUR').selected, isFalse);
  });

  testWidgets('a driver with one currency gets no tabs', (tester) async {
    Money.zoneCurrency = 'TND';
    serve(['TND']);
    await open(tester);
    expect(askedCurrency(), 'TND');
    expect(find.byType(ChoiceChip), findsNothing);
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

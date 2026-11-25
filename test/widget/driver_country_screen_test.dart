import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/presentation/driver/deferred_screens.dart';

/// Contract v0.18.162 (contract.json#driverCountryFirst; owner 2026-11-25
/// "Yes"): "Which country do you work in?" right after the first sign-in,
/// no country picked by default, only open countries, saved with
/// PUT /driver/country; an account with no country needs it (once).
void main() {
  setUpAll(loadDeferredScreens);

  DriverAccountSession session(List<String> sent, {String? refuse}) {
    final client = MockClient((request) async {
      http.Response json(int status, Map<String, Object?> map) => http.Response(
        jsonEncode(map),
        status,
        headers: {'content-type': 'application/json'},
      );
      if (request.url.path != DriverAccountRepository.countryPath ||
          request.method != 'PUT') {
        return json(404, {'code': 'not_found', 'message': 'x'});
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      sent.add(body['country'] as String);
      if (refuse != null) {
        return json(409, {
          'code': 'invalid_transition',
          'message': 'x',
          'reason': refuse,
        });
      }
      return json(200, {
        'driverId': 'drv_1',
        'accountStatus': 'pending',
        'onlineStatus': 'offline',
        'firstName': '',
        'country': body['country'],
        'zoneIds': ['FR-PC'],
        'categoryIds': [],
        'documents': [],
        'version': 2,
      });
    });
    final api = ApiClient(
      client: client,
      baseUri: Uri.parse('https://api.test.movera.se'),
      tokens: MemoryTokenStore()..save(access: 'a', refresh: 'r'),
    );
    return DriverAccountSession(repository: DriverAccountRepository(api))
      ..replace(
        const DriverAccount(
          driverId: 'drv_1',
          accountStatus: 'pending',
          firstName: '',
          version: 1,
        ),
      );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  test(
    'an account with no country before approval needs the step; one with a country or approved does not',
    () {
      const none = DriverAccount(
        driverId: 'd',
        accountStatus: 'pending',
        firstName: '',
        version: 1,
      );
      const held = DriverAccount(
        driverId: 'd',
        accountStatus: 'on_hold',
        firstName: '',
        version: 1,
      );
      const chosen = DriverAccount(
        driverId: 'd',
        accountStatus: 'pending',
        firstName: '',
        version: 1,
        country: 'SE',
      );
      const active = DriverAccount(
        driverId: 'd',
        accountStatus: 'active',
        firstName: '',
        version: 1,
      );
      expect(none.needsCountry, isTrue);
      expect(held.needsCountry, isTrue);
      expect(chosen.needsCountry, isFalse);
      expect(active.needsCountry, isFalse);
    },
  );

  testWidgets(
    'nothing is picked: Continue waits; only open countries; the pick is saved',
    (tester) async {
      final sent = <String>[];
      final account = session(sent);
      final done = <String?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: driverCountryScreen(
            account: account,
            onDone: (_, saved) => done.add(saved.country),
          ),
        ),
      );
      await settle(tester);
      expect(find.text('Which country do you work in?'), findsOneWidget);
      expect(find.byKey(const ValueKey('country-SE')), findsOneWidget);
      expect(find.byKey(const ValueKey('country-FR')), findsOneWidget);
      expect(find.byKey(const ValueKey('country-TN')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('country-continue')));
      await settle(tester);
      expect(sent, isEmpty);
      await tester.tap(find.byKey(const ValueKey('country-FR')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('country-continue')));
      await settle(tester);
      expect(sent, ['FR']);
      expect(done, ['FR']);
      expect(account.account?.country, 'FR');
      expect(account.account?.needsCountry, isFalse);
    },
  );

  testWidgets('a fleet of another country: said plainly, nothing changes', (
    tester,
  ) async {
    final sent = <String>[];
    final done = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: driverCountryScreen(
          account: session(sent, refuse: 'fleet_other_country'),
          onDone: (_, saved) => done.add(saved.country),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('country-SE')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('country-continue')));
    await settle(tester);
    expect(done, isEmpty);
    expect(find.byKey(const ValueKey('country-error')), findsOneWidget);
  });
}

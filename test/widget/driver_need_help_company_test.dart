import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/legal/driver_legal.dart';
import 'package:movera/presentation/driver/auth/widgets/need_help.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// BQ-V14 (owner driver-g1.md:10 "Add help and add email and phone and
/// details for company, we add missing info later"): "Need help?" shows the
/// company details the admin set in Content › Legal (`GET /legal/{country}`
/// `company`, contract v0.18.14), as the rider app does; the built-in
/// values stay only as the fallback when none were ever read.
void main() {
  final before = DriverLegal.instance;

  setUp(() {
    DriverAppTexts.language = 'en';
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => DriverLegal.instance = before);

  Map<String, Object?> answer({Map<String, String>? company}) => {
    'country': 'SE',
    'version': 1,
    'source': 'admin',
    'reaccept': false,
    'reacceptFrom': null,
    'terms': {
      'title': {'sv': 'V', 'fr': 'C', 'en': 'Terms of use'},
      'text': {'sv': 'a', 'fr': 'a', 'en': 'a'},
    },
    'privacy': {
      'title': {'sv': 'P', 'fr': 'P', 'en': 'Privacy policy'},
      'text': {'sv': 'x', 'fr': 'x', 'en': 'x'},
    },
    'company': ?company,
  };

  const company = {
    'companyName': 'Movera AB',
    'orgNumber': '556000-0000',
    'address': 'Gatan 1, Stockholm',
    'supportEmail': 'help@movera.test',
    'supportPhone': '+46 8 000 00 00',
  };

  DriverLegal online(MemoryDriverLegalCache cache, Map<String, Object?> body) =>
      DriverLegal(
        api: ApiClient(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode(body),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
          baseUri: Uri.parse('https://api.test.movera.se'),
          tokens: MemoryTokenStore(),
        ),
        cache: cache,
      );

  Future<void> openBox(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: NeedHelpLink())),
    );
    await tester.tap(find.byKey(const ValueKey('auth-need-help')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('auth-need-help-box')), findsOneWidget);
  }

  void expectCompany() {
    expect(find.text('help@movera.test'), findsOneWidget);
    expect(find.text('+46 8 000 00 00'), findsOneWidget);
    expect(
      find.text('Movera AB\n556000-0000\nGatan 1, Stockholm'),
      findsOneWidget,
    );
    expect(find.text('Contact details coming soon'), findsNothing);
  }

  testWidgets('the admin\'s company details from GET /legal show', (
    tester,
  ) async {
    final legal = online(MemoryDriverLegalCache(), answer(company: company));
    DriverLegal.instance = legal;
    await tester.runAsync(legal.refresh);
    await openBox(tester);
    expectCompany();
  });

  testWidgets('offline: the last answer\'s company details are kept', (
    tester,
  ) async {
    final cache = MemoryDriverLegalCache();
    await tester.runAsync(online(cache, answer(company: company)).refresh);
    final offline = DriverLegal(cache: cache);
    DriverLegal.instance = offline;
    await tester.runAsync(offline.restore);
    await openBox(tester);
    expectCompany();
  });

  testWidgets('no company from the admin: the built-in fallback', (
    tester,
  ) async {
    final legal = online(MemoryDriverLegalCache(), answer());
    DriverLegal.instance = legal;
    await tester.runAsync(legal.refresh);
    await openBox(tester);
    expect(find.text('Contact details coming soon'), findsOneWidget);
  });
}

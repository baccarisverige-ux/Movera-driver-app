import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/account/details_draft.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/account/org_number.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/otp_challenge.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/presentation/driver/account/driver_details_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Round 4: the details screen after the first sign-in, against a fake
/// server that answers like movera-server's onboarding.
class _Server {
  _Server({this.refuse});

  /// A `400 invalid_request` reason to answer with, or null to accept.
  final String? refuse;
  final List<Map<String, dynamic>> bodies = [];

  http.Client get client => MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    bodies.add(body);
    http.Response json(int status, Map<String, Object?> map) => http.Response(
      jsonEncode(map),
      status,
      headers: {'content-type': 'application/json'},
    );
    if (request.url.path != DriverAccountRepository.onboardingPath) {
      return json(404, {'code': 'not_found', 'message': 'x'});
    }
    if (refuse != null) {
      return json(400, {
        'code': 'invalid_request',
        'message': 'refused',
        'reason': refuse,
      });
    }
    return json(200, {
      'driverId': 'drv_1',
      'accountStatus': 'on_hold',
      'onlineStatus': 'offline',
      'firstName': body['firstName'],
      'lastName': body['lastName'],
      'accountType': body['accountType'],
      'country': body['country'],
      'zoneIds': ['Z001'],
      'categoryIds': [],
      'documents': [],
      'requiredDocuments': ['terms', 'driving_license'],
      'version': 2,
    });
  });
}

DriverAccountSession _session(_Server server) {
  final api = ApiClient(
    client: server.client,
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

Future<({DriverAccountSession session, List<String> done})> _pump(
  WidgetTester tester,
  _Server server, {
  String? phone,
  ProviderLink? prefill,
  DetailsDraft? draft,
}) async {
  tester.view.physicalSize = const Size(390, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final session = _session(server);
  final done = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      home: DriverDetailsScreen(
        account: session,
        onDone: (_) => done.add('home'),
        clock: () => DateTime(2026, 10, 25),
        phone: phone,
        prefill: prefill,
        draft: draft ?? _memoryDraft(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return (session: session, done: done);
}

/// A draft over an in-memory settings store (no plugin in tests).
DetailsDraft _memoryDraft() {
  SharedPreferences.setMockInitialValues({});
  return DetailsDraft(repository: SettingsRepository());
}

/// Opens the picker under [box] and taps the row [row].
Future<void> _pick(WidgetTester tester, String box, String row) async {
  await _tap(tester, box);
  await tester.pump();
  await tester.tap(find.byKey(ValueKey(row)));
  await tester.pump();
  await tester.pump();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.enterText(finder, text);
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _fillPerson(
  WidgetTester tester, {
  String dob = '1990-05-04',
}) async {
  await _type(tester, 'details-first-name', 'Nils');
  await _type(tester, 'details-last-name', 'Berg');
  await _type(tester, 'details-dob', dob);
  await _type(tester, 'details-email', 'nils@example.se');
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('empty fields, an under-age date and no consent are said '
      'under the right field, nothing is sent', (tester) async {
    final server = _Server();
    await _pump(tester, server);
    await _tap(tester, 'details-continue');
    expect(find.text(tr.acctRequired), findsWidgets);
    expect(find.text(tr.acctTermsRequired), findsOneWidget);
    expect(server.bodies, isEmpty);

    await _fillPerson(tester, dob: '2010-01-01');
    await _tap(tester, 'details-terms');
    await _tap(tester, 'details-continue');
    expect(find.text(tr.acctUnderAge(21)), findsOneWidget);
    expect(find.text(tr.acctTermsRequired), findsNothing);
    expect(server.bodies, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the country picker shows the flags, Tunisia as coming soon '
      'and not pickable; the city follows the country', (tester) async {
    await _pump(tester, _Server());
    await _tap(tester, 'details-country');
    await tester.pump();
    expect(find.text(tr.acctChooseCountry), findsOneWidget);
    expect(find.text('🇸🇪'), findsWidgets);
    expect(find.text('🇫🇷'), findsOneWidget);
    expect(find.text('🇹🇳'), findsOneWidget);
    expect(find.text(tr.acctComingSoon.toUpperCase()), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pick-country-TN')));
    await tester.pump();
    // The sheet stays open, Tunisia was not taken.
    expect(find.text(tr.acctChooseCountry), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pick-country-FR')));
    await tester.pump();
    await tester.pump();
    expect(find.text(tr.acctChooseCountry), findsNothing);
    expect(find.text(tr.acctCountryFrance), findsOneWidget);
    expect(find.text('Paris'), findsOneWidget);
    expect(find.text('Stockholm län'), findsNothing);
    // The city picker lists the country's cities without flags.
    await _tap(tester, 'details-city');
    await tester.pump();
    expect(find.byKey(const ValueKey('pick-city-paris')), findsOneWidget);
    expect(find.byKey(const ValueKey('pick-city-stockholm_lan')), findsNothing);
    expect(find.text('🇫🇷'), findsOneWidget); // only the box, not the sheet
    await tester.tap(find.byKey(const ValueKey('pick-city-paris')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the language picker lists the three languages without '
      'flags and switches the app at once', (tester) async {
    DriverLanguage.resetForTest();
    addTearDown(DriverLanguage.resetForTest);
    await _pump(tester, _Server());
    expect(
      find.textContaining(tr.acctDetailsAccent, findRichText: true),
      findsOneWidget,
    );
    await _tap(tester, 'details-language');
    await tester.pump();
    expect(find.byKey(const ValueKey('pick-language-sv')), findsOneWidget);
    expect(find.byKey(const ValueKey('pick-language-fr')), findsOneWidget);
    expect(find.byKey(const ValueKey('pick-language-en')), findsOneWidget);
    expect(find.text('🇸🇪'), findsOneWidget); // the country box only
    await tester.tap(find.byKey(const ValueKey('pick-language-sv')));
    await tester.pump();
    await tester.pump();
    expect(DriverLanguage.current.value, 'sv');
    // The screen reads its texts again: Swedish now.
    expect(
      find.textContaining('uppgifter', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Svenska'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the phone is shown read-only and Apple / Google prefill the '
      'names and e-mail, editable', (tester) async {
    final server = _Server();
    final (:done, session: _) = await _pump(
      tester,
      server,
      phone: '+46701740608',
      prefill: const ProviderLink(
        provider: 'google',
        linkToken: 'lt_1',
        firstName: 'Lina',
        lastName: 'Berg',
        email: 'lina.berg@gmail.com',
      ),
    );
    expect(find.byKey(const ValueKey('details-phone')), findsOneWidget);
    expect(find.textContaining('+46 70 174 06 08'), findsOneWidget);
    expect(find.byKey(const ValueKey('details-from-google')), findsOneWidget);
    expect(find.text(tr.acctFromProvider('Google')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('details-first-name')))
          .controller!
          .text,
      'Lina',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('details-email')))
          .controller!
          .text,
      'lina.berg@gmail.com',
    );
    // Editable: the relay e-mail Apple may give is replaced.
    await _type(tester, 'details-email', 'lina@berg.se');
    await _type(tester, 'details-dob', '1990-05-04');
    await _tap(tester, 'details-terms');
    await _tap(tester, 'details-continue');
    await _settle(tester);
    expect(server.bodies.single['firstName'], 'Lina');
    expect(server.bodies.single['lastName'], 'Berg');
    expect(server.bodies.single['email'], 'lina@berg.se');
    expect(done, ['home']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('the company number is checked per country: SE 10 digits, FR SIREN '
      '9 or SIRET 14', () {
    expect(OrgNumber.isValid('556677-8899', 'SE'), isTrue);
    expect(OrgNumber.isValid('5566778899', 'SE'), isTrue);
    expect(OrgNumber.isValid('556677889', 'SE'), isFalse);
    expect(OrgNumber.isValid('123 456 789', 'FR'), isTrue);
    expect(OrgNumber.isValid('12345678900012', 'FR'), isTrue);
    expect(OrgNumber.isValid('1234567890', 'FR'), isFalse);
    expect(OrgNumber.isValid('', 'FR'), isFalse);
    expect(OrgNumber.digitsOf('556677-8899'), '5566778899');
  });

  testWidgets('a wrong company number is said under the company fields and '
      'nothing is sent', (tester) async {
    final server = _Server();
    await _pump(tester, server);
    await _fillPerson(tester);
    await _tap(tester, 'details-type-fleet');
    await _type(tester, 'details-company-name', 'Berg Taxi AB');
    await _type(tester, 'details-org-number', '55667');
    await _type(tester, 'details-company-address', 'Storgatan 1');
    // Digits only on the keyboard side.
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('details-org-number')))
          .keyboardType,
      TextInputType.number,
    );
    await _tap(tester, 'details-terms');
    await _tap(tester, 'details-continue');
    expect(find.text(tr.acctOrgNumberSeRule), findsOneWidget);
    expect(server.bodies, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('what was typed comes back after the app was closed, and '
      'goes once the details are sent', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsRepository();
    final server = _Server();
    await _pump(tester, server, draft: DetailsDraft(repository: settings));
    await _type(tester, 'details-first-name', 'Nils');
    await _type(tester, 'details-email', 'nils@example.se');
    await _tap(tester, 'details-type-fleet');
    await _type(tester, 'details-company-name', 'Berg Taxi AB');
    // The draft is written a moment after the last keystroke.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpWidget(const SizedBox.shrink());
    await SettingsRepository.settle();
    final saved = await settings.read(DetailsDraft.section);
    expect(saved['firstName'], 'Nils');
    expect(saved['accountType'], 'fleet');
    expect(saved['companyName'], 'Berg Taxi AB');
    expect(saved.containsKey('lastName'), isFalse);

    // The app opens again: the fields are filled from the draft.
    final (:done, session: _) = await _pump(
      tester,
      server,
      draft: DetailsDraft(repository: settings),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('details-first-name')))
          .controller!
          .text,
      'Nils',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('details-company-name')))
          .controller!
          .text,
      'Berg Taxi AB',
    );
    await _type(tester, 'details-last-name', 'Berg');
    await _type(tester, 'details-dob', '1990-05-04');
    await _type(tester, 'details-org-number', '556677-8899');
    await _type(tester, 'details-company-address', 'Storgatan 1');
    await _tap(tester, 'details-terms');
    await _tap(tester, 'details-continue');
    await _settle(tester);
    expect(done, ['home']);
    await SettingsRepository.settle();
    expect(await settings.read(DetailsDraft.section), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a driver who joins a fleet now: the request carries the '
      'details and fleetJoin, then the app opens', (tester) async {
    final server = _Server();
    final (:session, :done) = await _pump(tester, server);
    await _fillPerson(tester);
    await _pick(tester, 'details-language', 'pick-language-sv');
    await _tap(tester, 'details-join-toggle');
    await _type(tester, 'details-join-code', 'MV-7K3Q9');
    await _type(tester, 'details-join-owner', 'Eva Nord');
    await _type(tester, 'details-join-email', 'eva@nord.se');
    await _tap(tester, 'details-terms');
    await _tap(tester, 'details-continue');
    await _settle(tester);
    expect(server.bodies.single, {
      'firstName': 'Nils',
      'lastName': 'Berg',
      'dateOfBirth': '1990-05-04',
      'email': 'nils@example.se',
      'country': 'SE',
      'cityId': 'stockholm_lan',
      'language': 'sv',
      'accountType': 'driver',
      'termsAccepted': true,
      'fleetJoin': {
        'code': 'MV-7K3Q9',
        'ownerName': 'Eva Nord',
        'ownerEmail': 'eva@nord.se',
      },
    });
    expect(session.account?.accountStatus, 'on_hold');
    expect(done, ['home']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a fleet account needs its company; the request carries it', (
    tester,
  ) async {
    final server = _Server();
    final (:done, session: _) = await _pump(tester, server);
    await _fillPerson(tester);
    await _tap(tester, 'details-type-fleet');
    expect(find.text(tr.acctOrgNumberSe.toUpperCase()), findsOneWidget);
    await _tap(tester, 'details-terms');
    await _tap(tester, 'details-continue');
    expect(find.text(tr.acctCompanyRequired), findsOneWidget);
    expect(server.bodies, isEmpty);
    await _type(tester, 'details-company-name', 'Berg Taxi AB');
    await _type(tester, 'details-org-number', '556677-8899');
    await _type(tester, 'details-company-address', 'Storgatan 1');
    await _tap(tester, 'details-continue');
    await _settle(tester);
    expect(server.bodies.single['accountType'], 'fleet');
    expect(server.bodies.single['company'], {
      'name': 'Berg Taxi AB',
      'orgNumber': '556677-8899',
      'address': 'Storgatan 1',
    });
    expect(server.bodies.single.containsKey('fleetJoin'), isFalse);
    expect(done, ['home']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a server refusal lands under its field and the screen stays', (
    tester,
  ) async {
    final server = _Server(refuse: 'invalid_email');
    final (:done, session: _) = await _pump(tester, server);
    await _fillPerson(tester);
    await _tap(tester, 'details-terms');
    await _tap(tester, 'details-continue');
    await _settle(tester);
    expect(server.bodies, hasLength(1));
    expect(find.text(tr.acctInvalidEmail), findsOneWidget);
    expect(done, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

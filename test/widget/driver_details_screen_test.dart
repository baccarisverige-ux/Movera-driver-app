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
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/driver/account/driver_details_screen.dart';

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
  _Server server,
) async {
  tester.view.physicalSize = const Size(390, 1600);
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
      ),
    ),
  );
  await tester.pump();
  return (session: session, done: done);
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

  testWidgets('Tunisia is shown but cannot be picked; the city follows the '
      'country', (tester) async {
    await _pump(tester, _Server());
    expect(find.text(tr.acctComingSoon), findsOneWidget);
    await _tap(tester, 'details-country-TN');
    // Still Sweden: Stockholm län is the city.
    expect(find.text('Stockholm län'), findsOneWidget);
    await _tap(tester, 'details-country-FR');
    await tester.pump();
    expect(find.text('Paris'), findsOneWidget);
    expect(find.text('Stockholm län'), findsNothing);
    expect(find.text(tr.acctOrgNumberFr), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a driver who joins a fleet now: the request carries the '
      'details and fleetJoin, then the app opens', (tester) async {
    final server = _Server();
    final (:session, :done) = await _pump(tester, server);
    await _fillPerson(tester);
    await _tap(tester, 'details-language-sv');
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
    expect(find.text(tr.acctOrgNumberSe), findsOneWidget);
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

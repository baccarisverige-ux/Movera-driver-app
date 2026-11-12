// G30 (contract v0.18.76 / v0.18.77 `contract.json#emailVerified`): the
// driver app's part, checked only through what the app had before G30 (so
// each test compiles on the old code and fails there for the right reason,
// Rule 36). The new screens and fields are in g30_email_verified_test.dart.
//
// No real address, number or code: only example.test addresses and made-up
// codes.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/core/onboarding/driver_reminders.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/contracts/zone_settings.dart';
import 'package:movera/presentation/driver/account/contact_change_screen.dart';
import 'package:movera/presentation/driver/profile/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _email = 'driver@example.test';

Map<String, dynamic> get _contract =>
    jsonDecode(File('contracts/contract.json').readAsStringSync())
        as Map<String, dynamic>;

Map<String, dynamic> get _emailTexts =>
    (_contract['emailVerified'] as Map)['texts'] as Map<String, dynamic>;

Map<String, dynamic> get _reminderTexts =>
    ((_contract['driverOnboarding'] as Map)['reminders'] as Map)['texts']
        as Map<String, dynamic>;

void _speak(String language) {
  switch (language) {
    case 'sv':
      DriverLanguage.applyZone(AppLanguages.forCountry('SE'));
    case 'fr':
      DriverLanguage.applyZone(AppLanguages.forCountry('FR'));
    default:
      DriverLanguage.resetForTest();
  }
}

http.Response _json(int status, Object body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

ApiClient _api(List<http.Request> sent, Object Function(http.Request) answer) =>
    ApiClient(
      client: MockClient((request) async {
        sent.add(request);
        return _json(200, answer(request));
      }),
      baseUri: Uri.parse('https://api.test.movera.se'),
      tokens: MemoryTokenStore()..save(access: 'a', refresh: 'r'),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DriverLanguage.resetForTest();
  });
  tearDown(DriverLanguage.resetForTest);

  test(
    'G30: requests carry X-Contract-Version = the contract copy '
    '(≥ 0.18.76, so GET /driver/reminders sends email_not_verified)',
    () async {
      final sent = <http.Request>[];
      await DriverAccountRepository(
        _api(sent, (_) => {'items': []}),
      ).reminders();
      expect(sent.single.headers['X-Contract-Version'], _contract['version']);
    },
  );

  test('G30: the line email_not_verified keeps its fix verify_email', () {
    final line = DriverReminder.fromJson({
      'kind': 'email_not_verified',
      'level': 'due_soon',
      'fix': {'target': 'verify_email'},
    });
    expect(line.fix?.target.name, 'verifyEmail');
  });

  for (final language in ['en', 'fr', 'sv']) {
    test('[$language] G30: red says "needed for approval", orange the plain '
        'line (contract texts)', () {
      _speak(language);
      String title(String level) => reminderWords(
        DriverReminder.fromJson({
          'kind': 'email_not_verified',
          'level': level,
          'fix': {'target': 'verify_email'},
        }),
        nameOf: (_) => '',
      ).title;
      expect(
        title('blocks_online'),
        (_reminderTexts['email_not_verified_approval'] as Map)[language],
      );
      expect(
        title('due_soon'),
        (_reminderTexts['email_not_verified'] as Map)[language],
      );
    });
  }

  testWidgets('G30: delivery pending_provider shows "cannot be sent yet", '
      'no code field, never "We send a code"', (tester) async {
    final sent = <http.Request>[];
    final session = DriverAccountSession(
      repository: DriverAccountRepository(
        _api(
          sent,
          (_) => {
            'challengeId': 'ch_1',
            'expiresAt': '2026-11-12T12:05:00Z',
            'delivery': 'pending_provider',
          },
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ContactChangeScreen(account: session, kind: ContactKind.email),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('contact-value')),
      'new@example.test',
    );
    await tester.tap(find.byKey(const ValueKey('contact-submit')));
    await tester.pumpAndSettle();
    expect(sent.single.url.path, '/api/v1/account/email/change');
    expect(find.byKey(const ValueKey('contact-code')), findsNothing);
    expect(find.textContaining('We send a code'), findsNothing);
    expect(find.textContaining('We sent a code'), findsNothing);
    expect(
      find.text((_emailTexts['codeNotSentYet'] as Map)['en'] as String),
      findsOneWidget,
    );
  });

  testWidgets('G30: Account shows the e-mail with Not verified', (
    tester,
  ) async {
    final previous = DriverRuntimeConfig.current;
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      simulatedArrival: true,
      externalRouting: false,
      skipAccountActivation: true,
      authRequired: true,
    );
    addTearDown(() => DriverRuntimeConfig.current = previous);
    final session =
        DriverAccountSession(
          repository: DriverAccountRepository(_api([], (_) => {})),
        )..replace(
          DriverAccount.fromJson({
            'driverId': 'd1',
            'accountStatus': 'active',
            'firstName': 'Sara',
            'version': 3,
            'country': 'SE',
            'email': _email,
          }),
        );
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = DriverSessionController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          home: DriverRuntimeScope(
            session: controller,
            homeBuilder: () => const SizedBox(),
            account: session,
            child: const DriverProfile(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final notVerified = (_emailTexts['notVerified'] as Map)['en'] as String;
    expect(find.text('$_email · $notVerified'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

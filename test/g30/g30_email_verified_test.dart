// G30 (contract v0.18.76 / v0.18.77 `contract.json#emailVerified`, owner
// 2026-11-12 13:41 "fix everything like must be now", Q2 "Keep, show Not
// verified", Q3 "show on sheet home screen as no verify", S1 "Codes can't be
// sent yet", S2 "Red: needed for approval"): the driver app's part.
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
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/core/onboarding/driver_reminders.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/contracts/zone_settings.dart';
import 'package:movera/presentation/driver/account/contact_change_screen.dart';
import 'package:movera/presentation/driver/home/components/important_reminders.dart';
import 'package:movera/presentation/driver/home/reminder_fix_page.dart';
import 'package:movera/presentation/driver/profile/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _email = 'driver@example.test';
const _verifiedAt = '2026-11-12T10:00:00Z';

Map<String, dynamic> get _contract =>
    jsonDecode(File('contracts/contract.json').readAsStringSync())
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

Map<String, Object?> _profile({String? email, String? verifiedAt}) => {
  'driverId': 'd1',
  'accountStatus': 'active',
  'firstName': 'Sara',
  'lastName': 'Lind',
  'version': 3,
  'country': 'SE',
  'email': ?email,
  'emailVerifiedAt': ?verifiedAt,
};

http.Response _json(int status, Object body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

/// A fake server: [answer] by "METHOD /path"; everything else 404.
class _Server {
  _Server(this.answer);

  final Map<String, Object? Function(http.Request)> answer;
  final sent = <http.Request>[];

  ApiClient api() => ApiClient(
    client: MockClient((request) async {
      sent.add(request);
      final handler = answer['${request.method} ${request.url.path}'];
      if (handler == null) return _json(404, {'code': 'not_found'});
      final body = handler(request);
      if (body is http.Response) return body;
      return _json(200, body!);
    }),
    baseUri: Uri.parse('https://api.test.movera.se'),
    tokens: MemoryTokenStore()..save(access: 'a', refresh: 'r'),
  );

  DriverAccountSession session(Map<String, Object?> profile) =>
      DriverAccountSession(repository: DriverAccountRepository(api()))
        ..replace(DriverAccount.fromJson(profile));

  List<http.Request> to(String path) => [
    for (final request in sent)
      if (request.url.path == path) request,
  ];
}

const _change = '/api/v1/account/email/change';
const _verify = '/api/v1/account/email/verify';

void main() {
  late DriverRuntimeConfig previous;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    previous = DriverRuntimeConfig.current;
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      simulatedArrival: true,
      externalRouting: false,
      skipAccountActivation: true,
      authRequired: true,
    );
    DriverLanguage.resetForTest();
  });

  tearDown(() {
    DriverRuntimeConfig.current = previous;
    DriverLanguage.resetForTest();
  });

  Future<void> pumpProfile(
    WidgetTester tester,
    DriverAccountSession account,
  ) async {
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
            account: account,
            child: const DriverProfile(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('Account › E-mail row', () {
    testWidgets('G30: shows "address · Not verified" and opens the check '
        'with the address filled and read-only', (tester) async {
      final server = _Server({});
      await pumpProfile(tester, server.session(_profile(email: _email)));
      final row = find.byKey(const ValueKey('profile-email'));
      expect(row, findsOneWidget);
      expect(
        find.descendant(
          of: row,
          matching: find.text(tr.contactEmailNotVerified(_email)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text(tr.acctEmail)),
        findsOneWidget,
      );
      await tester.ensureVisible(row);
      await tester.tap(row);
      await settle(tester);
      final screen = tester.widget<ContactChangeScreen>(
        find.byType(ContactChangeScreen),
      );
      expect(screen.kind, ContactKind.email);
      expect(screen.verifyCurrent, _email);
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('contact-value')),
      );
      expect(field.controller!.text, _email);
      expect(field.readOnly, isTrue);
      expect(find.text(tr.contactVerifyEmail), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('G30: "address · Verified" with emailVerifiedAt (tap = the '
        'normal change); "No e-mail" without an address', (tester) async {
      final server = _Server({});
      await pumpProfile(
        tester,
        server.session(_profile(email: _email, verifiedAt: _verifiedAt)),
      );
      final row = find.byKey(const ValueKey('profile-email'));
      expect(
        find.descendant(
          of: row,
          matching: find.text(tr.contactEmailVerified(_email)),
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(row);
      await tester.tap(row);
      await settle(tester);
      final screen = tester.widget<ContactChangeScreen>(
        find.byType(ContactChangeScreen),
      );
      expect(screen.verifyCurrent, isNull);
      await tester.pumpWidget(const SizedBox());

      await pumpProfile(tester, _Server({}).session(_profile()));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('profile-email')),
          matching: find.text(tr.contactEmailNone),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    });

    test('G30: a date without an address proves nothing', () {
      final account = DriverAccount.fromJson(_profile(verifiedAt: _verifiedAt));
      expect(account.emailVerified, isFalse);
      final both = DriverAccount.fromJson(
        _profile(email: _email, verifiedAt: _verifiedAt),
      );
      expect(both.emailVerified, isTrue);
      expect(both.emailVerifiedAt, DateTime.utc(2026, 11, 12, 10));
      expect(
        DriverAccount.fromJson(_profile(email: _email)).emailVerified,
        isFalse,
      );
    });
  });

  group('the code check (Rule 35: never claim a code was sent)', () {
    Future<_Server> start(
      WidgetTester tester, {
      required Object? Function(http.Request) change,
      String? verifyCurrent,
      String typed = 'new@example.test',
    }) async {
      final server = _Server({
        'POST $_change': change,
        'POST $_verify': (_) => {
          'email': verifyCurrent ?? typed,
          'emailVerifiedAt': _verifiedAt,
        },
        'GET ${DriverAccountRepository.profilePath}': (_) =>
            _profile(email: verifyCurrent ?? typed, verifiedAt: _verifiedAt),
      });
      final session = server.session(_profile(email: verifyCurrent));
      await tester.pumpWidget(
        MaterialApp(
          home: ContactChangeScreen(
            account: session,
            kind: ContactKind.email,
            verifyCurrent: verifyCurrent,
          ),
        ),
      );
      if (verifyCurrent == null) {
        await tester.enterText(
          find.byKey(const ValueKey('contact-value')),
          typed,
        );
      }
      await tester.tap(find.byKey(const ValueKey('contact-submit')));
      await tester.pumpAndSettle();
      return server;
    }

    for (final (name, delivery) in [
      ('pending_provider', 'pending_provider'),
      ('no delivery (older server)', null),
    ]) {
      testWidgets('G30: $name says "${'cannot be sent yet'}", no code '
          'field, never "We sent a code"', (tester) async {
        await start(
          tester,
          change: (_) => {
            'challengeId': 'ch_1',
            'expiresAt': '2026-11-12T12:05:00Z',
            'delivery': ?delivery,
          },
        );
        expect(find.byKey(const ValueKey('contact-not-sent')), findsOneWidget);
        expect(find.text(tr.contactCodeNotSentYet), findsOneWidget);
        expect(find.byKey(const ValueKey('contact-code')), findsNothing);
        expect(find.text(tr.contactCodeSentEmail), findsNothing);
        expect(
          find.text(tr.contactCodeSentTo('new@example.test')),
          findsNothing,
        );
        // Not an error: the info text is not painted in the error colour.
        final text = tester.widget<Text>(
          find.byKey(const ValueKey('contact-not-sent')),
        );
        expect(
          text.style?.color,
          isNot(
            Theme.of(
              tester.element(find.byType(ContactChangeScreen)),
            ).colorScheme.error,
          ),
        );
      });
    }

    testWidgets('G30: delivery sent shows "We sent a code to {email}." and '
        'the code field', (tester) async {
      await start(
        tester,
        change: (_) => {
          'challengeId': 'ch_1',
          'expiresAt': '2026-11-12T12:05:00Z',
          'delivery': 'sent',
        },
      );
      expect(find.text(tr.contactCodeSentTo('new@example.test')), findsOne);
      expect(find.byKey(const ValueKey('contact-code')), findsOneWidget);
      expect(find.text(tr.contactCodeNotSentYet), findsNothing);
    });

    testWidgets('G30: verify-current posts the CURRENT address, then the '
        'code → "E-mail verified"', (tester) async {
      final server = await start(
        tester,
        verifyCurrent: _email,
        change: (_) => {
          'challengeId': 'ch_9',
          'expiresAt': '2026-11-12T12:05:00Z',
          'delivery': 'sent',
        },
      );
      expect(jsonDecode(server.to(_change).single.body), {'email': _email});
      expect(find.text(tr.contactCodeSentTo(_email)), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('contact-code')),
        '0000',
      );
      await tester.tap(find.byKey(const ValueKey('contact-submit')));
      await tester.pumpAndSettle();
      expect(jsonDecode(server.to(_verify).single.body), {
        'challengeId': 'ch_9',
        'code': '0000',
      });
      expect(find.text(tr.contactEmailVerifiedDone), findsOneWidget);
      expect(find.text(tr.contactEmailSaved), findsNothing);
    });

    testWidgets('G30: "Change e-mail" leaves the check for the normal '
        'change (field empty and editable)', (tester) async {
      final server = _Server({});
      await tester.pumpWidget(
        MaterialApp(
          home: ContactChangeScreen(
            account: server.session(_profile(email: _email)),
            kind: ContactKind.email,
            verifyCurrent: _email,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('contact-change-instead')));
      await tester.pump();
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('contact-value')),
      );
      expect(field.controller!.text, isEmpty);
      expect(field.readOnly, isFalse);
      expect(find.text(tr.contactChangeEmail), findsWidgets);
      expect(
        find.byKey(const ValueKey('contact-change-instead')),
        findsNothing,
      );
    });

    testWidgets('G30: an old challenge (invalid_email_challenge) reads as an '
        'expired code', (tester) async {
      final server = await start(
        tester,
        change: (_) => {
          'challengeId': 'ch_1',
          'expiresAt': '2026-11-12T12:05:00Z',
          'delivery': 'sent',
        },
      );
      server.answer['POST $_verify'] = (_) => _json(400, {
        'code': 'invalid_request',
        'reason': 'invalid_email_challenge',
        'message': 'x',
      });
      await tester.enterText(
        find.byKey(const ValueKey('contact-code')),
        '0000',
      );
      await tester.tap(find.byKey(const ValueKey('contact-submit')));
      await tester.pumpAndSettle();
      expect(find.text(tr.authCodeExpired), findsOneWidget);
    });

    testWidgets('G30: the whole check from Account: the row turns Verified', (
      tester,
    ) async {
      var verified = false;
      final server = _Server({
        'POST $_change': (_) => {
          'challengeId': 'ch_2',
          'expiresAt': '2026-11-12T12:05:00Z',
          'delivery': 'sent',
        },
        'POST $_verify': (_) {
          verified = true;
          return {'email': _email, 'emailVerifiedAt': _verifiedAt};
        },
        'GET ${DriverAccountRepository.profilePath}': (_) =>
            _profile(email: _email, verifiedAt: verified ? _verifiedAt : null),
      });
      await pumpProfile(tester, server.session(_profile(email: _email)));
      final row = find.byKey(const ValueKey('profile-email'));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('contact-submit')));
      await settle(tester);
      await tester.enterText(
        find.byKey(const ValueKey('contact-code')),
        '0000',
      );
      await tester.tap(find.byKey(const ValueKey('contact-submit')));
      await settle(tester);
      expect(find.byType(ContactChangeScreen), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('profile-email')),
          matching: find.text(tr.contactEmailVerified(_email)),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    });

    test('G30: the repository keeps delivery and the verified time', () async {
      final server = _Server({
        'POST $_change': (_) => {
          'challengeId': 'ch_3',
          'expiresAt': '2026-11-12T12:05:00Z',
          'delivery': 'sent',
        },
        'POST $_verify': (_) => {
          'email': _email,
          'emailVerifiedAt': _verifiedAt,
        },
      });
      final repo = DriverAccountRepository(server.api());
      final started = await repo.changeEmail(_email);
      expect(started.challengeId, 'ch_3');
      expect(started.sent, isTrue);
      server.answer['POST $_change'] = (_) => {
        'challengeId': 'ch_4',
        'expiresAt': '2026-11-12T12:05:00Z',
        'delivery': 'pending_provider',
      };
      expect((await repo.changeEmail(_email)).sent, isFalse);
      final saved = await repo.verifyEmail(challengeId: 'ch_3', code: '0000');
      expect(saved.email, _email);
      expect(saved.verifiedAt, DateTime.utc(2026, 11, 12, 10));
    });
  });

  group('Home reminder email_not_verified', () {
    Map<String, dynamic> texts() =>
        ((_contract['driverOnboarding'] as Map)['reminders'] as Map)['texts']
            as Map<String, dynamic>;

    DriverReminder line(String level) => DriverReminder.fromJson({
      'kind': 'email_not_verified',
      'level': level,
      'fix': {'target': 'verify_email'},
    });

    test('G30: verify_email is a contract fix target the app knows', () {
      final targets =
          ((_contract['driverOnboarding'] as Map)['reminders']
                  as Map)['fixTargets']
              as List;
      expect(targets, contains('verify_email'));
      expect(
        ReminderFixTarget.of('verify_email'),
        ReminderFixTarget.verifyEmail,
      );
      expect(line('due_soon').fix?.target, ReminderFixTarget.verifyEmail);
    });

    for (final language in ['en', 'fr', 'sv']) {
      test('[$language] G30: the words are the contract texts; red = '
          '"needed for approval", orange = the plain line', () {
        _speak(language);
        final red = line('blocks_online');
        final orange = line('due_soon');
        expect(red.level, ReminderLevel.blocksOnline);
        expect(orange.level, ReminderLevel.dueSoon);
        expect(
          reminderWords(red, nameOf: (_) => '').title,
          (texts()['email_not_verified_approval'] as Map)[language],
        );
        expect(
          reminderWords(orange, nameOf: (_) => '').title,
          (texts()['email_not_verified'] as Map)[language],
        );
        expect(
          reminderWords(orange, nameOf: (_) => '').action,
          tr.contactVerifyEmail,
        );
        expect(
          reminderActionLabel(ReminderFixTarget.verifyEmail),
          tr.contactVerifyEmail,
        );
        final contractTexts =
            (_contract['emailVerified'] as Map)['texts'] as Map;
        expect(
          tr.contactCodeNotSentYet,
          (contractTexts['codeNotSentYet'] as Map)[language],
        );
      });
    }

    test('G30: a red email_not_verified line is the hold headline', () {
      final list = DriverReminderList.fromJson({
        'items': [
          {
            'kind': 'email_not_verified',
            'level': 'blocks_online',
            'fix': {'target': 'verify_email'},
          },
        ],
      });
      expect(
        holdHeadline(list, nameOf: (_) => ''),
        tr.remEmailNotVerifiedApproval,
      );
    });

    for (final (level, color) in [
      ('blocks_online', ImportantRemindersBox.red),
      ('due_soon', ImportantRemindersBox.orange),
    ]) {
      testWidgets(
        'G30: a $level line is ${level == 'due_soon' ? 'orange' : 'red'}'
        ' and its tap opens the check with the address filled',
        (tester) async {
          final session = _Server({}).session(_profile(email: _email));
          final store = DriverRemindersStore()
            ..replace(
              DriverReminderList.fromJson({
                'items': [
                  {
                    'kind': 'email_not_verified',
                    'level': level,
                    'fix': {'target': 'verify_email'},
                  },
                ],
              }),
            );
          await tester.binding.setSurfaceSize(const Size(390, 844));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: ImportantRemindersBox(
                    store: store,
                    onFix: (reminder) => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            reminderFixPage(session, reminder, reminder.fix!),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(tr.remEmailNotVerified),
            findsNWidgets(level == 'due_soon' ? 1 : 0),
          );
          final dot = tester.widget<Container>(
            find.byKey(
              ValueKey('home-reminder-0-${ReminderLevel.of(level).name}'),
            ),
          );
          expect((dot.decoration! as BoxDecoration).color, color);
          await tester.tap(find.byKey(const ValueKey('home-reminder-0')));
          await tester.pumpAndSettle();
          final screen = tester.widget<ContactChangeScreen>(
            find.byType(ContactChangeScreen),
          );
          expect(screen.kind, ContactKind.email);
          expect(screen.verifyCurrent, _email);
        },
      );
    }
  });
}

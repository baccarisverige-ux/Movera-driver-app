import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/account/account_error_message.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/auth/auth_controller.dart';
import 'package:movera/core/auth/auth_repository.dart';
import 'package:movera/core/auth/otp_challenge.dart';
import 'package:movera/core/auth/signed_out_notice.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/core/legal/driver_legal.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/driver/driver_home_notices.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/live/live_error_message.dart';
import 'package:movera/core/live/live_trip_chat.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/onboarding/driver_reminders.dart';
import 'package:movera/core/platform/safe_area_insets.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/presentation/driver/account/fleet_invitations.dart';
import 'package:movera/presentation/driver/auth/phone_verify.dart';
import 'package:movera/presentation/driver/auth/sign_in.dart';
import 'package:movera/presentation/driver/profile/legal_document.dart';
import 'package:movera/presentation/driver/safety%20toolkits/safety_toolkits.dart';

/// Deep-fix job, contract v0.18.5 (decisions/driver-g1.md G1-B2..B6, D3;
/// driver-g2.md D1..D5.8; driver-g9.md chat storage; driver-g14.md safety
/// sheet; driver-g3.md last lines). One group per owner decision.

final _origin = Uri.parse('https://api.test.movera.se');

http.Response _json(int status, Object body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> get _contract =>
    jsonDecode(File('contracts/contract.json').readAsStringSync())
        as Map<String, dynamic>;

Map<String, dynamic> _arb(String lang) =>
    jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
        as Map<String, dynamic>;

Object? _at(Map<String, dynamic> root, String path) {
  Object? node = root;
  for (final key in path.split('.')) {
    node = (node as Map<String, dynamic>)[key];
  }
  return node;
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

AuthController _auth(Future<http.Response> Function(http.Request) answer) {
  final store = MemoryTokenStore();
  final api = ApiClient(
    client: MockClient(answer),
    baseUri: _origin,
    tokens: store,
  );
  return AuthController(
    repository: AuthRepository(api: api, tokens: store),
  );
}

void main() {
  setUp(() {
    DriverAppTexts.language = 'en';
    SignedOutNotice.clear();
  });

  test(
    'every v0.18.5 text the app shows is the contract\'s, in sv, fr, en',
    () {
      const keys = {
        'authSignedOutExpired': 'auth.signedOut.texts.expired',
        'authSignedOutRevoked': 'auth.signedOut.texts.revoked',
        'authSignedOutDetailExpired': 'auth.signedOut.detail.expired',
        'authSignedOutDetailRevoked': 'auth.signedOut.detail.revoked',
        'docInvalidFileContent':
            'driverOnboarding.documents.upload.texts.invalid_file_content',
        'docExpiryTooFar':
            'driverOnboarding.documentExpiry.texts.expiry_too_far',
        'remFleetInvitation':
            'driverOnboarding.reminders.texts.fleet_invitation',
        'remActionAcceptInvitation':
            'driverOnboarding.reminders.texts.actions.accept_invitation',
        'remActionDeclineInvitation':
            'driverOnboarding.reminders.texts.actions.decline_invitation',
        'remNoFleet': 'driverOnboarding.reminders.texts.no_fleet',
        'safetyCall112': 'safety.onlyDuringTrip.texts.call112',
      };
      for (final lang in ['sv', 'fr', 'en']) {
        final arb = _arb(lang);
        keys.forEach((key, path) {
          expect(
            arb[key],
            (_at(_contract, path) as Map<String, dynamic>)[lang],
            reason: '$lang $key',
          );
        });
      }
    },
  );

  group('G1-B3 five wrong codes: Verify off, Send new code highlighted', () {
    testWidgets('the 429 otp_too_many_attempts answer disables Verify, '
        'empties the boxes and keeps the message while typing', (tester) async {
      _phone(tester);
      DriverPhoneVerification.debugWeb = true;
      addTearDown(() => DriverPhoneVerification.debugWeb = null);
      var verifies = 0;
      final auth = _auth((request) async {
        verifies++;
        return _json(429, {
          'code': 'rate_limited',
          'message': 'Too many attempts',
          'requestId': 'r',
          'reason': 'otp_too_many_attempts',
        });
      });
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => MaterialApp(
            home: DriverPhoneVerification(
              controller: auth,
              challenge: OtpChallenge(
                phone: '+46701740605',
                sessionId: 'otp-1',
                expiresAt: DateTime.utc(2030),
                retryAfter: Duration.zero,
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(EditableText), '1234');
      await tester.pump(const Duration(milliseconds: 300));
      expect(verifies, 1);
      final message = tr.authErrTooManyWrongCodes(tr.authResendCode);
      expect(find.text(message), findsOneWidget);
      expect(find.byKey(const ValueKey('auth-resend-highlight')), findsOne);
      // Typing a new code: no second try on the spent session.
      await tester.enterText(find.byType(EditableText), '5678');
      await tester.pump(const Duration(milliseconds: 300));
      expect(verifies, 1, reason: 'no verify after "too many wrong tries"');
      await tester.tap(find.byKey(const ValueKey('auth-verify')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(verifies, 1, reason: 'Verify is off');
      expect(find.text(message), findsOneWidget);
    });
  });

  group('G1-B4 / B5 same words as the rider app', () {
    test('refused number: the rider text with the waiting list', () {
      expect(
        _arb('en')['authSignInRestricted'],
        'This number isn’t open for sign-in yet. Join the waiting list and '
        'we’ll let you know.',
      );
      expect(
        _arb('sv')['authSignInRestricted'],
        'Det här numret kan inte logga in än. Gå med i väntelistan så hör vi '
        'av oss.',
      );
    });

    test('"By continuing you accept the terms and privacy policy"; "or"; '
        'Svenska, Français, English', () {
      final en = _arb('en');
      expect(
        '${en['authConsentPrefix']}${en['authConsentTerms']}'
            '${en['authAnd']}${en['authConsentPrivacy']}',
        'By continuing you accept the terms and privacy policy',
      );
      expect(en['authOr'], 'or');
      expect(DriverLanguage.supported, ['sv', 'fr', 'en']);
      expect(
        [for (final c in DriverLanguage.supported) DriverLanguage.names[c]],
        ['Svenska', 'Français', 'English'],
      );
    });
  });

  group('G1-B6 screen-reader labels, links, and a fresh error line', () {
    testWidgets('phone field, code boxes, tick and the two links have '
        'names', (tester) async {
      _phone(tester);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: DriverSignIn(
            controller: _auth((_) async => _json(404, {})),
            showTestAccounts: false,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 6));
      expect(find.bySemanticsLabel(RegExp(r'^Mobile number')), findsWidgets);
      expect(find.bySemanticsLabel(tr.authConsentLabel), findsOneWidget);
      expect(find.semantics.byLabel(tr.authConsentTerms), findsOne);
      expect(find.semantics.byLabel(tr.authConsentPrivacy), findsOne);
      semantics.dispose();
    });

    testWidgets('a new Continue clears the old "No connection" line at '
        'once', (tester) async {
      _phone(tester);
      final second = Completer<http.Response>();
      var calls = 0;
      final auth = _auth((request) {
        calls++;
        if (calls == 1) throw http.ClientException('offline');
        return second.future;
      });
      await tester.pumpWidget(
        MaterialApp(
          home: DriverSignIn(controller: auth, showTestAccounts: false),
        ),
      );
      await tester.pump(const Duration(seconds: 6));
      await tester.enterText(
        find.byKey(const ValueKey('auth-phone-field')),
        '701740605',
      );
      await tester.tap(find.byKey(const ValueKey('auth-consent-box')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('auth-continue')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(tr.authErrOffline), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('auth-continue')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(tr.authErrOffline), findsNothing);
      second.complete(_json(500, {'code': 'internal', 'message': 'x'}));
      await tester.pump(const Duration(seconds: 1));
    });

    test('refresh retry: a lost refresh answer is sent again at once with '
        'the same token (auth.tokens.refreshRetry)', () async {
      final store = MemoryTokenStore();
      await store.save(access: 'old', refresh: 'r1');
      final refreshTokens = <String>[];
      var refreshes = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.url.path == ApiClient.refreshPath) {
            refreshes++;
            refreshTokens.add(
              (jsonDecode(request.body) as Map)['refreshToken'] as String,
            );
            if (refreshes == 1) throw http.ClientException('answer lost');
            return _json(200, {'accessToken': 'new', 'refreshToken': 'r2'});
          }
          final bearer = request.headers['Authorization'];
          return bearer == 'Bearer new'
              ? _json(200, {'ok': true})
              : _json(401, {'code': 'unauthenticated', 'message': 'x'});
        }),
        baseUri: _origin,
        tokens: store,
      );
      expect((await api.get('/api/v1/driver/profile'))['ok'], isTrue);
      expect(refreshTokens, ['r1', 'r1']);
      expect(await store.readRefresh(), 'r2');
      expect(
        (_contract['auth'] as Map)['tokens']['refreshRetryWindowSeconds'],
        ApiClient.refreshRetryWindow.inSeconds,
      );
    });
  });

  group('G1-D3 why signed out', () {
    Future<void> refusedRefresh(String reason) async {
      final store = MemoryTokenStore();
      await store.save(access: 'old', refresh: 'r1');
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.url.path == ApiClient.refreshPath) {
            return _json(401, {
              'code': 'unauthenticated',
              'message': 'Please sign in again.',
              'reason': reason,
            });
          }
          return _json(401, {'code': 'unauthenticated', 'message': 'x'});
        }),
        baseUri: _origin,
        tokens: store,
      );
      await expectLater(
        api.get('/api/v1/driver/profile'),
        throwsA(isA<ApiError>()),
      );
    }

    test('session_expired → expired; session_ended / reused / unknown → '
        'revoked (auth.signedOut.reasons)', () async {
      await refusedRefresh('session_expired');
      expect(SignedOutNotice.kind.value, SignedOutNotice.expired);
      for (final reason in [
        'session_ended',
        'refresh_token_reused',
        'refresh_token_unknown',
      ]) {
        SignedOutNotice.clear();
        await refusedRefresh(reason);
        expect(SignedOutNotice.kind.value, SignedOutNotice.revoked);
      }
      final reasons = (_contract['auth'] as Map)['signedOut']['reasons'] as Map;
      expect(reasons, SignedOutNotice.reasons);
    });

    testWidgets('the sign-in screen says it, with the reason line; own Sign '
        'out shows nothing', (tester) async {
      _phone(tester);
      final auth = _auth((_) async => _json(404, {}));
      SignedOutNotice.sessionRefused('session_expired');
      await tester.pumpWidget(
        MaterialApp(
          home: DriverSignIn(controller: auth, showTestAccounts: false),
        ),
      );
      await tester.pump(const Duration(seconds: 6));
      expect(find.text(tr.authSignedOutExpired), findsOneWidget);
      expect(find.text(tr.authSignedOutDetailExpired), findsOneWidget);
      await auth.signOut();
      await tester.pump();
      expect(find.byKey(const ValueKey('auth-signed-out')), findsNothing);
    });
  });

  group('G1-B2 legal texts per country', () {
    Map<String, Object?> legalAnswer({
      int version = 0,
      bool reaccept = false,
    }) => {
      'country': 'FR',
      'version': version,
      'source': version == 0 ? 'default' : 'admin',
      'reaccept': reaccept,
      'terms': {
        'title': {'sv': 'Villkor', 'fr': 'Conditions', 'en': 'Terms of use'},
        'text': {
          'sv': 'A\n\nB',
          'fr': 'A\n\nB',
          'en': 'Draft – to be reviewed by a lawyer before launch.\n\nTwo',
        },
      },
      'privacy': {
        'title': {'sv': 'P', 'fr': 'P', 'en': 'Privacy policy'},
        'text': {'sv': 'x', 'fr': 'x', 'en': 'Private'},
      },
    };

    test('GET /legal/{country} goes without a token; a reaccept version is '
        'due until POST /account/legal/accept', () async {
      final requests = <http.Request>[];
      final store = MemoryTokenStore();
      await store.save(access: 'a', refresh: 'r');
      final api = ApiClient(
        client: MockClient((request) async {
          requests.add(request);
          if (request.method == 'GET') {
            return _json(200, legalAnswer(version: 2, reaccept: true));
          }
          return http.Response('', 204);
        }),
        baseUri: _origin,
        tokens: store,
      );
      final legal = DriverLegal(api: api, cache: MemoryDriverLegalCache());
      await legal.start(country: 'FR');
      final get = requests.first;
      expect(get.url.path, '/api/v1/legal/FR');
      expect(get.headers.containsKey('Authorization'), isFalse);
      expect(legal.due, isTrue);
      expect(legal.screenWanted, isTrue);
      expect(await legal.accept(), isTrue);
      final post = requests.last;
      expect(post.url.path, DriverLegal.acceptPath);
      expect(jsonDecode(post.body), {'country': 'FR', 'version': 2});
      expect(post.headers['Idempotency-Key'], isNotEmpty);
      expect(legal.due, isFalse);
      expect(
        (_contract['auth'] as Map)['beforeSignIn']['allowed'],
        contains('GET /legal/{country}'),
      );
    });

    test('version 0 (Movera drafts) needs no accept; a kept answer is '
        'there offline', () async {
      final cache = MemoryDriverLegalCache();
      final online = DriverLegal(
        api: ApiClient(
          client: MockClient((_) async => _json(200, legalAnswer())),
          baseUri: _origin,
          tokens: MemoryTokenStore(),
        ),
        cache: cache,
      );
      await online.start(country: 'FR');
      expect(online.due, isFalse);
      final offline = DriverLegal(
        api: ApiClient(
          client: MockClient((_) async => throw http.ClientException('x')),
          baseUri: _origin,
          tokens: MemoryTokenStore(),
        ),
        cache: cache,
      );
      await offline.start(country: 'FR');
      expect(offline.current?.terms.titleIn('en'), 'Terms of use');
    });

    testWidgets('Terms and Privacy are two pages, from the server, in the '
        'app language, one paragraph per block', (tester) async {
      final legal = DriverLegal(
        api: ApiClient(
          client: MockClient((_) async => _json(200, legalAnswer())),
          baseUri: _origin,
          tokens: MemoryTokenStore(),
        ),
        cache: MemoryDriverLegalCache(),
      );
      await legal.start(country: 'FR');
      await tester.pumpWidget(
        MaterialApp(
          home: LegalDocumentScreen(kind: LegalKind.terms, legal: legal),
        ),
      );
      await tester.pump();
      expect(find.text('Terms of use'), findsOneWidget);
      expect(
        find.text('Draft – to be reviewed by a lawyer before launch.'),
        findsOneWidget,
      );
      expect(find.text('Two'), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          home: LegalDocumentScreen(kind: LegalKind.privacy, legal: legal),
        ),
      );
      await tester.pump();
      expect(find.text('Privacy policy'), findsOneWidget);
      expect(find.text('Private'), findsOneWidget);
    });

    test('going online refused with terms_not_accepted says "Accept the '
        'new terms to go online"', () {
      final error = ApiError(
        code: 'invalid_transition',
        message: 'x',
        reason: 'terms_not_accepted',
        statusCode: 409,
      );
      expect(
        liveAvailabilityErrorMessage(error, online: true),
        tr.contentTermsBlockOnline,
      );
    });
  });

  group('G9 chat not stored in the app', () {
    test('the trip ends: every message leaves the phone; after the trip the '
        'server\'s closed answer leaves nothing', () async {
      final chat = LiveTripChat(
        api: ApiClient(
          client: MockClient(
            (_) async =>
                _json(200, {'items': [], 'nextCursor': null, 'closed': true}),
          ),
          baseUri: _origin,
          tokens: MemoryTokenStore(),
        ),
      );
      chat.receive(
        't1',
        const RealtimeMessage(messageId: 'm1', from: 'rider', text: 'hi'),
      );
      expect(chat.thread('t1').messages, hasLength(1));
      chat.tripEnded('t1');
      expect(chat.thread('t1').messages, isEmpty);
      expect(chat.thread('t1').closed, isTrue);
      expect(chat.unreadOf('t1'), 0);
      expect(await chat.load('t2'), isTrue);
      expect(chat.thread('t2').messages, isEmpty);
      expect(chat.thread('t2').closed, isTrue);
    });

    test('no chat message is ever listed in Notifications', () async {
      final repository = DriverAccountRepository(
        ApiClient(
          client: MockClient(
            (_) async => _json(200, {
              'items': [
                {
                  'notificationId': 'n1',
                  'kind': 'trip_message',
                  'title': 'Message from your rider',
                  'body': 'hi',
                  'at': '2026-10-30T10:00:00Z',
                  'read': false,
                },
                {
                  'notificationId': 'n2',
                  'kind': 'document_approved',
                  'title': 'Approved',
                  'body': 'ok',
                  'at': '2026-10-30T10:00:00Z',
                  'read': false,
                },
              ],
            }),
          ),
          baseUri: _origin,
          tokens: MemoryTokenStore(),
        ),
      );
      final items = await repository.notifications();
      expect(items.map((n) => n.kind), ['document_approved']);
    });

    test('Notifications title and dates follow the app language', () {
      final at = DateTime(2026, 10, 30, 14, 5);
      DriverAppTexts.language = 'sv';
      expect(tr.notifications, 'Aviseringar');
      expect(DriverDates.weekdayDayMonth(at), startsWith('fre'));
      DriverAppTexts.language = 'fr';
      expect(DriverDates.weekdayDayMonth(at), startsWith('ven'));
      DriverAppTexts.language = 'en';
      expect(tr.notifications, 'Notifications');
      expect(DriverDates.weekdayDayMonth(at), 'Fri 30 Oct');
    });
  });

  group('G14 safety sheet only during a trip', () {
    Future<void> pump(WidgetTester tester, {required bool duringTrip}) async {
      _phone(tester);
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => MaterialApp(
            home: Scaffold(
              body: SafetyToolKits(
                duringTrip: duringTrip,
                launchEmergencyDial: () async => true,
                sendSos: () async => throw StateError('no SOS without a trip'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('no trip: only "Call 112" (dialer, nothing sent) and Safety '
        'preferences', (tester) async {
      await pump(tester, duringTrip: false);
      expect(find.byKey(const ValueKey('safety-call-112')), findsOneWidget);
      expect(find.text(tr.safetyCall112), findsOneWidget);
      expect(find.byKey(const ValueKey('safety-sos')), findsNothing);
      expect(find.text(tr.safetyShareTrip), findsNothing);
      expect(find.byKey(const ValueKey('ride-check-info')), findsNothing);
      expect(find.byKey(const ValueKey('safety-preferences')), findsOneWidget);
      expect(find.textContaining('preview'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('safety-call-112')));
      await tester.pump();
    });

    testWidgets('during a trip: SOS, Share trip and Ride check', (
      tester,
    ) async {
      await pump(tester, duringTrip: true);
      expect(find.byKey(const ValueKey('safety-sos')), findsOneWidget);
      expect(find.text(tr.safetyShareTrip), findsOneWidget);
      expect(find.byKey(const ValueKey('ride-check-info')), findsOneWidget);
      expect(find.textContaining('preview'), findsNothing);
    });
  });

  group('G2 onboarding deep fixes', () {
    test('D1: a renewal is its own document next to the approved one; the '
        'expiring line says the new one is being checked', () {
      final renewal = AccountDocument.fromJson({
        'documentId': 'doc-2',
        'ownerId': 'drv-1',
        'type': 'driving_licence',
        'status': 'in_review',
        'version': 1,
        'renewalOf': 'doc-1',
      });
      expect(renewal.isRenewal, isTrue);
      expect(renewal.summary.renewalOf, 'doc-1');
      final line = DriverReminder.fromJson({
        'kind': 'document_expired',
        'level': 'blocks_online',
        'documentType': 'driving_licence',
        'renewalStatus': 'in_review',
      });
      final words = reminderWords(line, nameOf: (_) => 'Driving licence');
      expect(words.detail, tr.remRenewalInReview);
      expect(words.action, isNull, reason: 'already uploaded');
      expect(line.blocksOnline, isTrue, reason: 'a renewal never unblocks');
      final rejected = DriverReminder.fromJson({
        'kind': 'document_expiring',
        'level': 'due_soon',
        'daysLeft': 5,
        'renewalStatus': 'rejected',
        'reviewNote': 'Blurry',
      });
      expect(
        reminderWords(rejected, nameOf: (_) => 'X').detail,
        '${tr.remRenewalRejected}: Blurry',
      );
    });

    test('D4: a removed / left notice opens My fleet', () {
      final notice = ServerNotification.fromJson({
        'notificationId': 'n',
        'kind': 'fleet_membership',
        'title': 'You are no longer in Taxi AB',
        'body': '',
        'at': '2026-10-30T10:00:00Z',
      });
      expect(notice.opensFleet, isTrue);
    });

    test('D5.2 / D5.8: "This file is not a photo or PDF", "Check the end '
        'date"', () {
      ApiError refused(String reason) => ApiError(
        code: 'invalid_request',
        message: 'x',
        reason: reason,
        statusCode: 400,
      );
      expect(
        accountErrorMessage(refused('invalid_file_content'), fallback: '-'),
        'This file is not a photo or PDF',
      );
      expect(
        accountErrorMessage(refused('expiry_too_far'), fallback: '-'),
        'Check the end date',
      );
    });

    testWidgets('D5.5: the owner sees "Invitation sent to +46 70…", never '
        'the name, until the driver accepts', (tester) async {
      final invitation = FleetInvitation.fromJson({
        'invitationId': 'i1',
        'fleetId': 'f1',
        'fleetName': 'Taxi AB',
        'direction': 'owner_invite',
        'status': 'pending',
        'phone': '+46701740610',
        'driverName': 'Old Server Name',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FleetInvitationCard(
              invitation: invitation,
              owner: true,
              busy: false,
            ),
          ),
        ),
      );
      expect(find.textContaining('Invitation sent to +46'), findsOneWidget);
      expect(find.textContaining('Old Server Name'), findsNothing);
    });

    test('D5.6: the fleet_invitation line, "<Fleet> invited you" with '
        'Accept / Decline', () {
      final line = DriverReminder.fromJson({
        'kind': 'fleet_invitation',
        'level': 'waiting',
        'invitationId': 'inv-1',
        'fleetName': 'Taxi AB',
        'actions': [
          {'target': 'accept_invitation', 'invitationId': 'inv-1'},
          {'target': 'decline_invitation', 'invitationId': 'inv-1'},
        ],
      });
      expect(
        reminderWords(line, nameOf: (_) => '').title,
        'Taxi AB invited you',
      );
      expect(line.actions.map((a) => a.target), [
        ReminderFixTarget.acceptInvitation,
        ReminderFixTarget.declineInvitation,
      ]);
      expect(line.actions.first.invitationId, 'inv-1');
      expect(line.actions.map((a) => reminderActionLabel(a.target)), [
        'Accept',
        'Decline',
      ]);
      final targets =
          (_contract['driverOnboarding'] as Map)['reminders']['fixTargets']
              as List;
      expect(targets, containsAll(['accept_invitation', 'decline_invitation']));
    });

    test('D5.3: Add car has no ride-type choice and sends none', () {
      final source = File(
        'lib/presentation/driver/account/add_car_screen.dart',
      ).readAsStringSync();
      expect(source, isNot(contains('FilterChip(')));
      expect(source, contains('categoryIds: const []'));
    });
  });

  group('G3 after a reload Go online sends a fresh position', () {
    test(
      'a browser answer stamped before the reload goes out stamped now',
      () async {
        final now = DateTime.utc(2026, 10, 30, 20);
        final reporter = LiveLocationReporter(
          api: ApiClient(
            client: MockClient((_) async => _json(200, {})),
            baseUri: _origin,
            tokens: MemoryTokenStore(),
          ),
          location: _Gps(measuredAt: now.subtract(const Duration(minutes: 7))),
          every: const Duration(hours: 1),
          now: () => now,
          restampHeldFix: true,
        );
        final fix = await reporter.freshFix();
        expect(fix?['measuredAt'], '2026-10-30T20:00:00.000Z');
      },
    );

    test('no position: Go online is not sent at all (long press, GPS '
        'still waking up)', () async {
      final requests = <http.Request>[];
      final api = ApiClient(
        client: MockClient((request) async {
          requests.add(request);
          return _json(200, {'onlineStatus': 'offline', 'version': 1});
        }),
        baseUri: _origin,
        tokens: MemoryTokenStore()..save(access: 'a', refresh: 'r'),
      );
      final reporter = LiveLocationReporter(
        api: api,
        location: _Gps(fails: true),
        every: const Duration(hours: 1),
      );
      final presence = LivePresence(
        api: api,
        dispatch: _FakeDispatch(),
        reporter: reporter,
      );
      expect(await presence.goOnline(), tr.locationRequired);
      expect(
        requests.where((r) => r.url.path.endsWith('/driver/availability')),
        isEmpty,
      );
      reporter.stop();
    });

    test('iPhone check: an offline driver\'s profile (every reload) never '
        'shows "not eligible in this area"; going online does', () async {
      DriverAreaWatch.instance.reset();
      Map<String, Object> profile(String status) => {
        'driverId': 'd',
        'accountStatus': 'active',
        'firstName': 'A',
        'version': 3,
        'onlineStatus': status,
        'outsideArea': true,
        'areaZones': [
          {'zoneId': 'z', 'name': 'Paris'},
        ],
      };
      var status = 'offline';
      final repository = DriverAccountRepository(
        ApiClient(
          client: MockClient((_) async => _json(200, profile(status))),
          baseUri: _origin,
          tokens: MemoryTokenStore(),
        ),
      );
      await repository.profile();
      expect(DriverAreaWatch.instance.take(), isNull);
      status = 'online';
      await repository.profile();
      expect(DriverAreaWatch.instance.take(), ['Paris']);
      DriverAreaWatch.instance.reset();
    });

    test('the broken-image box next to the car is hidden', () {
      final html = File('web/index.html').readAsStringSync();
      expect(html, contains('.gm-style img[src*="/mapfiles/transparent.png"]'));
    });
  });

  group('Owner "Map under the strip"', () {
    test('web/index.html draws under the status bar and keeps the page '
        'fixed', () {
      final html = File('web/index.html').readAsStringSync();
      expect(html, contains('content="black-translucent"'));
      expect(html, contains('viewport-fit=cover'));
      expect(html, contains('MutationObserver(cover)'));
      expect(html, contains('position: fixed;'));
      // iPhone 15 / iOS 17: no auto-zoom on a focused field, pinch zoom
      // still allowed.
      expect(
        html,
        contains('input, textarea, select { font-size: 16px !important; }'),
      );
      expect(html, isNot(contains('maximum-scale=1')));
    });

    testWidgets('the page\'s safe-area insets reach MediaQuery when the '
        'engine reports none', (tester) async {
      final source = _FixedInsets(const EdgeInsets.only(top: 47, bottom: 34));
      late EdgeInsets padding;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: SafeAreaFromPage(
            source: source,
            child: Builder(
              builder: (context) {
                padding = MediaQuery.paddingOf(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(padding.top, 47);
      expect(padding.bottom, 34);
    });
  });
}

class _FixedInsets implements SafeAreaSource {
  _FixedInsets(this.insets);
  final EdgeInsets insets;
  @override
  EdgeInsets read() => insets;
  @override
  void listen(VoidCallback onChange) {}
  @override
  void dispose() {}
}

class _Gps implements DriverLocationRepository {
  _Gps({this.measuredAt, this.fails = false});
  final DateTime? measuredAt;
  final bool fails;

  @override
  Future<DriverLocation> getCurrentPosition() async {
    if (fails) throw TimeoutException('no fix');
    return DriverLocation(
      point: const GeoPoint(59.33, 18.06),
      accuracyMeters: 20,
      measuredAt: measuredAt,
    );
  }

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream.empty();
}

class _FakeDispatch implements ApiDispatchRepository {
  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  void refreshOffers() {}

  @override
  void markOnline() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

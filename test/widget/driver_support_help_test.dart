import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/auth_controller.dart';
import 'package:movera/core/auth/auth_repository.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/presentation/driver/auth/session_gate.dart';
import 'package:movera/presentation/driver/auth/sign_in.dart';
import 'package:movera/presentation/driver/support/support_inbox.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owner 2026-10-29 (screen driver-01c): signed in, "Contact support" opens
/// the in-app support ("Open the in-app support chat"); not signed in, a
/// small "Need help?" shows Movera's contact details in a box.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  AuthController controller(
    TokenStore tokens,
    Future<http.Response> Function(http.Request) answer,
  ) => AuthController(
    repository: AuthRepository(
      api: ApiClient(
        client: MockClient(answer),
        baseUri: Uri.parse('https://api.test.movera.se'),
        tokens: tokens,
      ),
      tokens: tokens,
    ),
  );

  testWidgets('start error: Contact support opens the in-app support', (
    tester,
  ) async {
    phone(tester);
    final tokens = MemoryTokenStore();
    await tokens.save(access: 'a', refresh: 'r');
    final client = MockClient(
      (_) async => http.Response(
        '{"code":"unavailable","message":"x"}',
        503,
        headers: {'content-type': 'application/json'},
      ),
    );
    final api = ApiClient(
      client: client,
      baseUri: Uri.parse('https://api.test.movera.se'),
      tokens: tokens,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DriverSessionGate(
          auth: AuthController(
            repository: AuthRepository(api: api, tokens: tokens),
          ),
          homeBuilder: () => const Text('home'),
          signInBuilder: () => const Text('sign in'),
          account: DriverAccountSession(
            repository: DriverAccountRepository(api),
          ),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.byKey(const ValueKey('gate-support')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(SupportScreen), findsOneWidget);
  });

  testWidgets('sign-in: "Need help?" shows a box, details coming soon', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: DriverSignIn(
          controller: controller(
            MemoryTokenStore(),
            (_) async => http.Response('', 204),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 6));
    final link = find.byKey(const ValueKey('auth-need-help'));
    expect(link, findsOneWidget);
    expect(find.text('Need help?'), findsOneWidget);
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('auth-need-help-box')), findsOneWidget);
    expect(find.text('Contact details coming soon'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('auth-need-help-close')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('auth-need-help-box')), findsNothing);
  });
}

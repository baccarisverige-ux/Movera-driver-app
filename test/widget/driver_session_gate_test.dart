import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/auth_controller.dart';
import 'package:movera/core/auth/auth_repository.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/auth/auth_navigation.dart';
import 'package:movera/presentation/driver/auth/session_gate.dart';

/// Round 4: with MOVERA_AUTH_REQUIRED the app opens on Sign in until the
/// token store holds a session; the demo keeps opening Home.
void main() {
  AuthController controller(MemoryTokenStore tokens) => AuthController(
    repository: AuthRepository(
      api: ApiClient(
        client: MockClient((_) async => http.Response('{}', 200)),
        baseUri: Uri.parse('https://api.test.movera.se'),
        tokens: tokens,
      ),
      tokens: tokens,
    ),
  );

  Widget gate(AuthController auth) => MaterialApp(
    home: DriverSessionGate(
      auth: auth,
      homeBuilder: () => const Scaffold(body: Text('Driver home')),
      signInBuilder: () => const Scaffold(body: Text('Sign in')),
    ),
  );

  testWidgets('no tokens: the root is Sign in', (tester) async {
    await tester.pumpWidget(gate(controller(MemoryTokenStore())));
    await tester.pump();
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Driver home'), findsNothing);
  });

  testWidgets('both tokens: the root is Home', (tester) async {
    final tokens = MemoryTokenStore()..save(access: 'a', refresh: 'r');
    await tester.pumpWidget(gate(controller(tokens)));
    await tester.pump();
    expect(find.text('Driver home'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });

  test('the config defaults keep the demo on Home', () {
    expect(DriverRuntimeConfig.build.authRequired, isFalse);
    expect(DriverRuntimeConfig.build.apiBaseUrl, '');
    expect(DriverRuntimeConfig.production.authRequired, isTrue);
  });

  test('after a sign-out the root is Sign in only when auth is required', () {
    final previous = DriverRuntimeConfig.current;
    addTearDown(() => DriverRuntimeConfig.current = previous);
    Widget home() => const Text('home');
    Widget signIn() => const Text('sign in');
    final scope = DriverRuntimeScope(
      session: DriverSessionController(),
      homeBuilder: home,
      signInBuilder: signIn,
      child: const SizedBox(),
    );
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      simulatedArrival: true,
      externalRouting: false,
      skipAccountActivation: true,
    );
    expect(driverRootAfterSignOut(scope), same(home));
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      simulatedArrival: true,
      externalRouting: false,
      skipAccountActivation: true,
      authRequired: true,
    );
    expect(driverRootAfterSignOut(scope), same(signIn));
    expect(driverRootAfterSignOut(null), isNull);
  });
}

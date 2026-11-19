import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/auth_controller.dart';
import 'package:movera/core/auth/auth_repository.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/privacy/start_clean_up.dart';
import 'package:movera/presentation/driver/auth/session_gate.dart';

/// Owner 2026-11-19 (N1): a start clean-up past 10 s shows Sign in, the
/// session is not read, and the next sign-in clears everything first.
class _CountingTokens extends MemoryTokenStore {
  int reads = 0;
  @override
  Future<String?> readAccess() {
    reads++;
    return super.readAccess();
  }

  @override
  Future<String?> readRefresh() {
    reads++;
    return super.readRefresh();
  }
}

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

  Widget gate(AuthController auth, Future<void> ready) => MaterialApp(
    home: DriverSessionGate(
      auth: auth,
      ready: ready,
      homeBuilder: () => const Scaffold(body: Text('Driver home')),
      signInBuilder: () => const Scaffold(body: Text('Sign in')),
    ),
  );

  testWidgets('a stuck clean-up: Sign in at 10 s, no Home, no session read', (
    tester,
  ) async {
    final tokens = _CountingTokens()..save(access: 'a', refresh: 'r');
    tokens.reads = 0;
    final stuck = Completer<void>();
    await tester.pumpWidget(gate(controller(tokens), stuck.future));
    await tester.pump(const Duration(seconds: 9));
    expect(find.text('Sign in'), findsNothing);
    expect(find.text('Driver home'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Driver home'), findsNothing);
    expect(tokens.reads, 0);
    // The clean-up ending late changes nothing.
    stuck.complete();
    await tester.pump();
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Driver home'), findsNothing);
  });

  testWidgets('a fast clean-up: Home as before', (tester) async {
    final tokens = MemoryTokenStore()..save(access: 'a', refresh: 'r');
    await tester.pumpWidget(gate(controller(tokens), Future<void>.value()));
    await tester.pump();
    expect(find.text('Driver home'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });

  test('the next sign-in runs the clean-up first', () async {
    final stuck = Completer<void>();
    final cleanUp = StartCleanUp(stuck.future);
    final steps = <String>[];
    await cleanUp.beforeSignIn(() async => steps.add('clear'));
    steps.add('claim');
    expect(steps, ['clear', 'claim']);
    expect(cleanUp.abandoned, isTrue);
    // The late start clean-up may not clear or claim the new data.
    expect(cleanUp.check, throwsA(isA<StartCleanUpAbandoned>()));
    stuck.complete();
  });

  test('a finished clean-up: the sign-in does not clear again', () async {
    final cleanUp = StartCleanUp(Future<void>.value());
    await Future<void>.delayed(Duration.zero);
    var cleared = false;
    await cleanUp.beforeSignIn(() async => cleared = true);
    expect(cleared, isFalse);
    expect(cleanUp.abandoned, isFalse);
    cleanUp.check();
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/auth_controller.dart';
import 'package:movera/core/auth/auth_repository.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/auth/sign_in.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_scene.dart';

/// Owner 2026-11-02, decisions/driver-g1.md "Driver sign-in screen look":
/// the picture shows the city skyline, "Need help?" sits under Apple and
/// Google, and no test-numbers list is on the screen of the live build.
void main() {
  AuthController controller() {
    final store = MemoryTokenStore();
    final client = MockClient((request) async {
      if (request.url.path.contains('test')) {
        return http.Response(
          '{"accounts":[{"phone":"+46700000000","app":"driver",'
          '"status":"active","name":"Test"}]}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{"code":"not_found","message":"x"}', 404);
    });
    return AuthController(
      repository: AuthRepository(
        api: ApiClient(
          client: client,
          baseUri: Uri.parse('https://api.test.movera.se'),
          tokens: store,
        ),
        tokens: store,
      ),
    );
  }

  Future<void> pumpLive(WidgetTester tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final before = DriverRuntimeConfig.current;
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      simulatedArrival: false,
      externalRouting: true,
      skipAccountActivation: false,
      authRequired: true,
      apiBaseUrl: 'https://api.test.movera.se',
    );
    addTearDown(() => DriverRuntimeConfig.current = before);
    await tester.pumpWidget(
      MaterialApp(home: DriverSignIn(controller: controller())),
    );
    await tester.pump(const Duration(seconds: 6));
  }

  testWidgets('live build: no test-numbers list on the screen', (tester) async {
    await pumpLive(tester);
    expect(find.byKey(const ValueKey('auth-test-accounts')), findsNothing);
  });

  testWidgets('the picture is tall enough to show the city skyline', (
    tester,
  ) async {
    await pumpLive(tester);
    final size = tester.getSize(find.byType(AuthScene));
    expect(AuthScene.showsSkyline(size), isTrue, reason: 'scene $size');
  });

  testWidgets('"Need help?" is on screen under Apple/Google and opens help', (
    tester,
  ) async {
    await pumpLive(tester);
    final link = find.text(tr.authNeedHelp);
    expect(link, findsOneWidget);
    final screen = tester.view.physicalSize.height;
    expect(tester.getBottomLeft(link).dy, lessThanOrEqualTo(screen));
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('auth-need-help-box')), findsOneWidget);
  });
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/push/push_config.dart';
import 'package:movera/core/push/push_platform.dart';
import 'package:movera/core/push/push_registrar.dart';
import 'package:movera/core/push/push_platform_io.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/presentation/driver/push/push_explanation.dart';

/// Contract v0.18.3 (owner decision R7): after sign-in the app explains,
/// asks once, registers the FCM token, again when it changes, and
/// unregisters it on sign-out.
const _web = PushWebConfig(
  apiKey: 'public-key',
  appId: '1:42:web:driver',
  messagingSenderId: '42',
  projectId: 'movera-test',
);

class _FakePlatform implements PushPlatform {
  _FakePlatform({this.next});

  String state = 'default';
  bool allow = true;
  String? next;
  int asked = 0;
  PushWebConfig? usedConfig;

  @override
  bool supported = true;

  @override
  String get platformName => 'web';

  @override
  Future<String> permission() async => state;

  @override
  Future<bool> requestPermission() async {
    asked++;
    state = allow ? 'granted' : 'denied';
    return allow;
  }

  @override
  Future<String?> token(PushWebConfig config) async {
    usedConfig = config;
    return next;
  }

  @override
  PushOpen? takeLaunchOpen() => null;

  @override
  void onOpen(void Function(PushOpen open) handler) {}

  final offerAlerts = <bool>[];

  @override
  void setOfferAlerts({required bool vibrate}) => offerAlerts.add(vibrate);
}

class _FakeApi implements PushApi {
  PushConfig answer = const PushConfig(enabled: true, webConfig: _web);
  final calls = <String>[];

  @override
  Future<PushConfig> config() async {
    calls.add('config');
    return answer;
  }

  @override
  Future<void> register(String token, String platform) async =>
      calls.add('register $token $platform');

  @override
  Future<void> unregister(String token) async => calls.add('unregister $token');
}

class _MemoryStore implements PushStore {
  bool wasExplained = false;
  String? saved;

  @override
  Future<bool> explained() async => wasExplained;

  @override
  Future<void> setExplained() async => wasExplained = true;

  @override
  Future<String?> token() async => saved;

  @override
  Future<void> setToken(String? token) async => saved = token;
}

void main() {
  late _FakePlatform platform;
  late _FakeApi api;
  late _MemoryStore store;
  late int explanations;
  late bool wants;

  PushRegistrar registrar() => PushRegistrar(
    platform: platform,
    api: api,
    store: store,
    explain: () async {
      explanations++;
      return wants;
    },
  );

  setUp(() {
    platform = _FakePlatform(next: 'fcm-1');
    api = _FakeApi();
    store = _MemoryStore();
    explanations = 0;
    wants = true;
  });

  test('explains first, asks the system once, registers the token', () async {
    expect(await registrar().signedIn(), 'fcm-1');
    expect(explanations, 1);
    expect(platform.asked, 1);
    expect(platform.usedConfig?.apiKey, 'public-key');
    expect(api.calls, ['config', 'register fcm-1 web']);
    expect(store.saved, 'fcm-1');

    // The next start: already allowed, no question, registered again.
    expect(await registrar().signedIn(), 'fcm-1');
    expect(explanations, 1);
    expect(platform.asked, 1);
  });

  test('"Not now" asks the system nothing and never explains again', () async {
    wants = false;
    expect(await registrar().signedIn(), isNull);
    expect(await registrar().signedIn(), isNull);
    expect(explanations, 1);
    expect(platform.asked, 0);
    expect(api.calls.where((c) => c.startsWith('register')), isEmpty);
  });

  test('a refusal or an earlier block registers nothing', () async {
    platform.allow = false;
    expect(await registrar().signedIn(), isNull);
    platform.state = 'denied';
    expect(await registrar().signedIn(), isNull);
    expect(platform.asked, 1);
    expect(api.calls, ['config', 'config']);
  });

  test(
    'push off on the server, or no browser support: nothing asked',
    () async {
      api.answer = PushConfig.off;
      expect(await registrar().signedIn(), isNull);
      expect(explanations, 0);
      platform.supported = false;
      api.answer = const PushConfig(enabled: true, webConfig: _web);
      expect(await registrar().signedIn(), isNull);
      expect(api.calls, ['config']);
    },
  );

  test('a new token replaces the old one; sign-out unregisters it', () async {
    await registrar().signedIn();
    platform.next = 'fcm-2';
    expect(await registrar().signedIn(), 'fcm-2');
    expect(api.calls, [
      'config',
      'register fcm-1 web',
      'config',
      'unregister fcm-1',
      'register fcm-2 web',
    ]);
    await registrar().signingOut();
    expect(api.calls.last, 'unregister fcm-2');
    expect(store.saved, isNull);
    await registrar().signingOut();
    expect(api.calls.where((c) => c.startsWith('unregister')), hasLength(2));
  });

  test('a failing server never throws into the app', () async {
    final failing = PushRegistrar(
      platform: platform,
      api: _ThrowingApi(),
      store: store,
      explain: () async => true,
    );
    expect(await failing.signedIn(), isNull);
    store.saved = 'old';
    await failing.signingOut();
    expect(store.saved, isNull);
  });

  test(
    'Android / iOS without Firebase app files: unsupported, quiet',
    () async {
      const io = UnsupportedPushPlatform();
      expect(io.supported, isFalse);
      expect(await io.requestPermission(), isFalse);
      expect(await io.token(_web), isNull);
    },
  );

  test('ApiPushApi: GET /push/config without a token, then POST '
      '/push/devices and /push/devices/unregister', () async {
    final seen = <http.Request>[];
    final client = ApiClient(
      client: MockClient((request) async {
        seen.add(request);
        final body = request.url.path.endsWith('/push/config')
            ? {
                'provider': 'fcm',
                'enabled': true,
                'projectId': 'movera-test',
                'webConfig': _web.toJson(),
              }
            : {'status': 'registered'};
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
      baseUri: Uri.parse('https://api.test'),
      tokens: MemoryTokenStore()..save(access: 'a1', refresh: 'r1'),
    );
    final push = ApiPushApi(
      client,
      app: 'driver',
      appVersion: '1.0.0',
      locale: () => 'sv',
    );
    final config = await push.config();
    expect(config.enabled, isTrue);
    expect(config.webConfig?.messagingSenderId, '42');
    await push.register('fcm-1', 'web');
    await push.unregister('fcm-1');
    expect(
      seen[0].url.toString(),
      'https://api.test/api/v1/push/config?app=driver',
    );
    expect(seen[0].headers.containsKey('Authorization'), isFalse);
    expect(seen[1].url.path, '/api/v1/push/devices');
    expect(jsonDecode(seen[1].body), {
      'token': 'fcm-1',
      'provider': 'fcm',
      'platform': 'web',
      'appVersion': '1.0.0',
      'locale': 'sv',
    });
    expect(seen[1].headers['Idempotency-Key'], isNotNull);
    expect(seen[2].url.path, '/api/v1/push/devices/unregister');
    expect(jsonDecode(seen[2].body), {'token': 'fcm-1'});
    // A dev version is not a contract appVersion: left out.
    await ApiPushApi(
      client,
      app: 'driver',
      appVersion: 'dev',
    ).register('t', 'web');
    expect(jsonDecode(seen[3].body), isNot(contains('appVersion')));
  });

  test('PushConfig: enabled false or no web settings is off', () {
    expect(
      PushConfig.fromJson({'provider': 'fcm', 'enabled': false}).enabled,
      isFalse,
    );
    expect(
      PushConfig.fromJson({'provider': 'fcm', 'enabled': true}).enabled,
      isFalse,
    );
    expect(
      PushConfig.fromJson({
        'enabled': true,
        'webConfig': {'apiKey': 'k', 'appId': 'a', 'messagingSenderId': 's'},
      }).enabled,
      isFalse,
    );
  });

  for (final (lang, title, allow) in [
    ('sv', 'Få aviseringar när appen är stängd?', 'Slå på'),
    ('fr', 'Recevoir les avis quand l’app est fermée ?', 'Activer'),
    ('en', 'Get notices when the app is closed?', 'Turn on'),
  ]) {
    testWidgets('the explanation in $lang; "$allow" answers yes', (
      tester,
    ) async {
      final before = DriverAppTexts.language;
      DriverAppTexts.language = lang;
      addTearDown(() => DriverAppTexts.language = before);
      bool? answer;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  answer = await showPushExplanation(context),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
      expect(find.text(tr.pushAskBody), findsOneWidget);
      await tester.tap(find.text(allow));
      await tester.pumpAndSettle();
      expect(answer, isTrue);
    });
  }
}

class _ThrowingApi implements PushApi {
  @override
  Future<PushConfig> config() async => throw StateError('down');

  @override
  Future<void> register(String token, String platform) async =>
      throw StateError('down');

  @override
  Future<void> unregister(String token) async => throw StateError('down');
}

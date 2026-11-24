import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/push/native_push_platform.dart';
import 'package:movera/core/push/push_config.dart';
import 'package:movera/core/push/push_platform.dart';
import 'package:movera/core/push/push_platform_io.dart';
import 'package:movera/core/push/push_registrar.dart';

/// BQ-V43 (G4 decision 1 "Push + sound + vibration", owner R7 "Set up
/// Firebase now"; contract v0.18.105): offer push on the Android store
/// build. Firebase starts at run time from the server's public Android
/// settings (`GET /push/config?app=driver&platform=android`), so no
/// google-services.json or key is in this repository. Without them push
/// stays off and says so. iOS waits for the APNs key (Apple Developer).
const _android = PushWebConfig(
  apiKey: 'public-android-key',
  appId: '1:42:android:driver',
  messagingSenderId: '42',
  projectId: 'movera-test',
);

class _FakeGateway implements NativePushGateway {
  PushWebConfig? started;
  bool failStart = false;
  String status = 'default';
  bool allow = true;
  String? nextToken = 'fcm-a1';
  PushOpen? initial;
  int asked = 0;
  final opens = StreamController<PushOpen>.broadcast();
  final refresh = StreamController<String>.broadcast();

  @override
  Future<void> start(PushWebConfig settings) async {
    if (failStart) throw StateError('no Firebase');
    started = settings;
  }

  @override
  Future<String> permission() async => status;

  @override
  Future<bool> requestPermission() async {
    asked++;
    status = allow ? 'granted' : 'denied';
    return allow;
  }

  @override
  Future<String?> token() async => nextToken;

  @override
  Future<PushOpen?> initialOpen() async => initial;

  @override
  Stream<PushOpen> get onOpened => opens.stream;

  @override
  Stream<String> get onTokenRefresh => refresh.stream;
}

class _Api implements PushApi {
  PushConfig answer = const PushConfig(enabled: true, androidConfig: _android);
  final calls = <String>[];

  @override
  Future<PushConfig> config({String platform = 'web'}) async {
    calls.add('config $platform');
    return answer;
  }

  @override
  Future<void> register(String token, String platform) async =>
      calls.add('register $token $platform');

  @override
  Future<void> unregister(String token) async => calls.add('unregister $token');
}

class _Store implements PushStore {
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
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('PushConfig reads androidConfig (v0.18.105); web stays as it was', () {
    final android = PushConfig.fromJson({
      'provider': 'fcm',
      'enabled': true,
      'projectId': 'movera-test',
      'androidConfig': {
        'apiKey': 'public-android-key',
        'appId': '1:42:android:driver',
        'messagingSenderId': '42',
        'projectId': 'movera-test',
      },
    });
    expect(android.enabled, isTrue);
    expect(android.webConfig, isNull);
    expect(android.androidConfig?.appId, '1:42:android:driver');
    // Missing fields: no settings, off.
    expect(
      PushConfig.fromJson({
        'enabled': true,
        'androidConfig': {'apiKey': 'k'},
      }).enabled,
      isFalse,
    );
  });

  test(
    'ApiPushApi asks platform=android; web keeps the v0.18.3 query',
    () async {
      final seen = <Uri>[];
      final client = ApiClient(
        client: MockClient((request) async {
          seen.add(request.url);
          return http.Response(
            jsonEncode({'provider': 'fcm', 'enabled': false}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        baseUri: Uri.parse('https://api.test'),
        tokens: MemoryTokenStore(),
      );
      final push = ApiPushApi(client, app: 'driver');
      await push.config(platform: 'android');
      await push.config();
      expect(seen.map((u) => u.toString()), [
        'https://api.test/api/v1/push/config?app=driver&platform=android',
        'https://api.test/api/v1/push/config?app=driver',
      ]);
    },
  );

  test('the platform does nothing before Firebase is started', () async {
    final gateway = _FakeGateway();
    final native = NativePushPlatform(gateway);
    expect(native.supported, isTrue);
    expect(native.ready, isFalse);
    expect(native.platformName, 'android');
    expect(await native.permission(), 'default');
    expect(await native.requestPermission(), isFalse);
    expect(await native.token(_android), isNull);
    expect(native.takeLaunchOpen(), isNull);
    expect(gateway.asked, 0);
    expect(
      native.settingsFrom(const PushConfig(enabled: true, webConfig: _android)),
      isNull,
    );
    expect(
      native.settingsFrom(
        const PushConfig(enabled: true, androidConfig: _android),
      ),
      _android,
    );
  });

  test('a Firebase that cannot start: not ready, nothing asked', () async {
    final gateway = _FakeGateway()..failStart = true;
    final native = NativePushPlatform(gateway);
    expect(await native.prepare(_android), isFalse);
    expect(native.ready, isFalse);
    expect(await native.permission(), 'default');
  });

  test(
    'started: permission, launch tap once, taps and new tokens forwarded',
    () async {
      final gateway = _FakeGateway()
        ..initial = const PushOpen(
          notificationId: 'psh_1',
          deepLink: 'movera-driver://offers/off_1',
        );
      final native = NativePushPlatform(gateway);
      final opened = <PushOpen>[];
      final tokens = <String>[];
      native.onOpen(opened.add);
      native.onTokenRefresh(tokens.add);
      expect(await native.prepare(_android), isTrue);
      expect(await native.prepare(_android), isTrue);
      expect(gateway.started, _android);
      expect(native.ready, isTrue);
      expect(await native.permission(), 'default');
      expect(await native.requestPermission(), isTrue);
      expect(await native.permission(), 'granted');
      expect(await native.token(_android), 'fcm-a1');
      expect(native.takeLaunchOpen()?.offerId, 'off_1');
      expect(native.takeLaunchOpen(), isNull);
      gateway.opens.add(const PushOpen(notificationId: 'n2', deepLink: null));
      gateway.refresh.add('fcm-a2');
      await Future<void>.delayed(Duration.zero);
      expect(opened.single.notificationId, 'n2');
      expect(tokens, ['fcm-a2']);
      // The vibrate setting cannot reach a system notice (channel decides).
      native.setOfferAlerts(vibrate: false);
    },
  );

  test(
    'registrar: android settings from the server, token registered as android',
    () async {
      final gateway = _FakeGateway();
      final native = NativePushPlatform(gateway);
      final api = _Api();
      final store = _Store();
      var explained = 0;
      final registrar = PushRegistrar(
        platform: native,
        api: api,
        store: store,
        explain: () async {
          explained++;
          return true;
        },
      );
      expect(await registrar.signedIn(), 'fcm-a1');
      expect(explained, 1);
      expect(gateway.asked, 1);
      expect(api.calls, ['config android', 'register fcm-a1 android']);
      expect(store.saved, 'fcm-a1');

      // FCM gives a new token: the old one goes, the new one is registered.
      gateway.refresh.add('fcm-a2');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(api.calls.sublist(2), [
        'unregister fcm-a1',
        'register fcm-a2 android',
      ]);
      expect(store.saved, 'fcm-a2');

      // Signed out: a later new token is not registered.
      await registrar.signingOut();
      gateway.refresh.add('fcm-a3');
      await Future<void>.delayed(Duration.zero);
      expect(api.calls.where((c) => c.contains('fcm-a3')), isEmpty);
    },
  );

  test(
    'registrar: no Android settings on the server: off, Firebase never started',
    () async {
      final gateway = _FakeGateway();
      final api = _Api()..answer = PushConfig.off;
      final registrar = PushRegistrar(
        platform: NativePushPlatform(gateway),
        api: api,
        store: _Store(),
        explain: () async => true,
      );
      expect(await registrar.signedIn(), isNull);
      expect(gateway.started, isNull);
      expect(gateway.asked, 0);
      expect(api.calls, ['config android']);
    },
  );

  test('Android gets the native platform (one for the app); iOS its own one '
      '(v0.18.160, before: off)', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final a = createPlatformPush();
    expect(a, isA<NativePushPlatform>());
    expect(identical(a, createPlatformPush()), isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final ios = createPlatformPush();
    expect(ios, isA<NativePushPlatform>());
    expect(ios.supported, isTrue);
    expect(ios.platformName, 'ios');
    expect(identical(ios, a), isFalse);
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    expect(createPlatformPush(), isA<UnsupportedPushPlatform>());
  });

  test(
    'Android files: the two offer channels of the contract and the sound',
    () {
      final contract =
          jsonDecode(File('contracts/contract.json').readAsStringSync())
              as Map<String, dynamic>;
      final native =
          ((contract['driverOffers'] as Map)['push'] as Map)['native'] as Map;
      final activity = File(
        'android/app/src/main/kotlin/se/movera/driver/MainActivity.kt',
      ).readAsStringSync();
      expect(activity, contains('"${native['androidChannel']}"'));
      expect(activity, contains('"${native['androidQuietChannel']}"'));
      expect(activity, contains('R.raw.${native['soundFile']}'));
      expect(
        File(
          'android/app/src/main/res/raw/${native['soundFile']}.mp3',
        ).existsSync(),
        isTrue,
      );
      expect(
        File('android/app/src/main/res/raw/keep.xml').readAsStringSync(),
        contains('@raw/${native['soundFile']}'),
      );
      for (final dir in ['values', 'values-sv', 'values-fr']) {
        final strings = File(
          'android/app/src/main/res/$dir/strings.xml',
        ).readAsStringSync();
        expect(strings, contains('name="offer_channel"'), reason: dir);
        expect(strings, contains('name="offer_quiet_channel"'), reason: dir);
      }
      // No Firebase file or key in the repository.
      expect(File('android/app/google-services.json').existsSync(), isFalse);
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('firebase_messaging:'));
      expect(pubspec, contains('firebase_core:'));
    },
  );
}

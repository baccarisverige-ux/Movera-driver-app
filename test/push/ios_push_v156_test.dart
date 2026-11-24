import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/push/native_push_platform.dart';
import 'package:movera/core/push/push_config.dart';
import 'package:movera/core/push/push_platform.dart';
import 'package:movera/core/push/push_registrar.dart';

/// v0.18.156 (owner 2026-11-24 "Notifications doesn't work on iPhones?";
/// contract `auth.devices.config.ios`, `auth.devices.sending.apns`): offer
/// push on the iPhone. Firebase starts at run time from the server's
/// public iOS settings (`GET /push/config?app=driver&platform=ios` →
/// `iosConfig`), so no GoogleService-Info.plist or key is in this
/// repository; never with a web or Android app id (native Firebase on iOS
/// aborts the app for one).
const _ios = PushWebConfig(
  apiKey: 'public-ios-key',
  appId: '1:42:ios:driver',
  messagingSenderId: '42',
  projectId: 'movera-test',
  iosBundleId: 'se.movera.driver',
);

class _Gateway implements NativePushGateway {
  PushWebConfig? started;
  String status = 'default';
  int asked = 0;
  final opens = StreamController<PushOpen>.broadcast();

  @override
  Future<void> start(PushWebConfig settings) async => started = settings;

  @override
  Future<String> permission() async => status;

  @override
  Future<bool> requestPermission() async {
    asked++;
    status = 'granted';
    return true;
  }

  String? nextToken = 'fcm-ios-1';

  @override
  Future<String?> token() async => nextToken;

  @override
  Future<PushOpen?> initialOpen() async => const PushOpen(
    notificationId: 'off_9',
    deepLink: 'movera-driver://offers/off_9',
  );

  @override
  Stream<PushOpen> get onOpened => opens.stream;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
}

class _Api implements PushApi {
  _Api(this.answer);
  PushConfig answer;
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
  test('PushConfig reads iosConfig with its bundle id', () {
    final config = PushConfig.fromJson({
      'provider': 'fcm',
      'enabled': true,
      'projectId': 'movera-test',
      'iosConfig': {
        'apiKey': 'public-ios-key',
        'appId': '1:42:ios:driver',
        'messagingSenderId': '42',
        'projectId': 'movera-test',
        'iosBundleId': 'se.movera.driver',
      },
    });
    expect(config.enabled, isTrue);
    expect(config.iosConfig?.appId, '1:42:ios:driver');
    expect(config.iosConfig?.iosBundleId, 'se.movera.driver');
    expect(config.androidConfig, isNull);
    expect(config.webConfig, isNull);
    expect(
      PushConfig.fromJson({
        'enabled': true,
        'iosConfig': <String, dynamic>{},
      }).enabled,
      isFalse,
    );
  });

  test('ApiPushApi asks platform=ios', () async {
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
    await ApiPushApi(client, app: 'driver').config(platform: 'ios');
    expect(
      seen.single.toString(),
      'https://api.test/api/v1/push/config?app=driver&platform=ios',
    );
  });

  test('the iOS platform takes only iosConfig with an iOS app id', () {
    final native = NativePushPlatform(_Gateway(), platform: 'ios');
    expect(native.platformName, 'ios');
    expect(
      native.settingsFrom(const PushConfig(enabled: true, iosConfig: _ios)),
      _ios,
    );
    const android = PushWebConfig(
      apiKey: 'k',
      appId: '1:42:android:driver',
      messagingSenderId: '42',
      projectId: 'p',
    );
    const web = PushWebConfig(
      apiKey: 'k',
      appId: '1:42:web:driver',
      messagingSenderId: '42',
      projectId: 'p',
    );
    expect(
      native.settingsFrom(
        const PushConfig(enabled: true, androidConfig: android, webConfig: web),
      ),
      isNull,
    );
    expect(
      native.settingsFrom(const PushConfig(enabled: true, iosConfig: web)),
      isNull,
    );
    // Android keeps androidConfig only.
    expect(
      NativePushPlatform(
        _Gateway(),
      ).settingsFrom(const PushConfig(enabled: true, iosConfig: _ios)),
      isNull,
    );
  });

  test('registrar on iOS: explains once, asks, registers platform ios; '
      'the offer tap that started the app opens the offer', () async {
    final gateway = _Gateway();
    final native = NativePushPlatform(gateway, platform: 'ios');
    final api = _Api(const PushConfig(enabled: true, iosConfig: _ios));
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
    expect(await registrar.signedIn(), 'fcm-ios-1');
    expect(gateway.started, _ios);
    expect(gateway.started?.iosBundleId, 'se.movera.driver');
    expect(explained, 1);
    expect(gateway.asked, 1);
    expect(api.calls, ['config ios', 'register fcm-ios-1 ios']);
    expect(native.takeLaunchOpen()?.offerId, 'off_9');
    final opened = <PushOpen>[];
    native.onOpen(opened.add);
    gateway.opens.add(
      const PushOpen(
        notificationId: 'n1',
        deepLink: 'movera-driver://trips/t1',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(opened.single.routeChangeTripId, 't1');
  });

  test(
    'registrar on iOS: no iOS settings on the server: off, nothing asked',
    () async {
      final gateway = _Gateway();
      final api = _Api(PushConfig.off);
      final registrar = PushRegistrar(
        platform: NativePushPlatform(gateway, platform: 'ios'),
        api: api,
        store: _Store(),
        explain: () async => true,
      );
      expect(await registrar.signedIn(), isNull);
      expect(gateway.started, isNull);
      expect(gateway.asked, 0);
      expect(api.calls, ['config ios']);
    },
  );

  test('iOS files: remote-notification, aps-environment, the offer sound, '
      'no Firebase file', () {
    final contract =
        jsonDecode(File('contracts/contract.json').readAsStringSync())
            as Map<String, dynamic>;
    final native =
        ((contract['driverOffers'] as Map)['push'] as Map)['native'] as Map;
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('<string>remote-notification</string>'));
    expect(plist, contains('<string>location</string>'));
    expect(
      File('ios/Runner/Runner.entitlements').readAsStringSync(),
      contains('<key>aps-environment</key>'),
    );
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    expect(
      'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'
          .allMatches(project)
          .length,
      3,
    );
    final sound = native['iosSound'] as String;
    expect(File('ios/Runner/$sound').existsSync(), isTrue);
    expect(project, contains('$sound in Resources'));
    expect(File('ios/Runner/GoogleService-Info.plist').existsSync(), isFalse);
    final workflow = File(
      '.github/workflows/ios-testflight.yml',
    ).readAsStringSync();
    expect(workflow, contains("Set :aps-environment production"));
    expect(
      workflow,
      contains(
        'codesign --force --sign - --timestamp=none --entitlements "\$ent" "\$app"',
      ),
    );
    final entitlements = File(
      'ios/Runner/Runner.entitlements',
    ).readAsStringSync();
    expect(
      entitlements,
      contains('com.apple.developer.usernotifications.time-sensitive'),
    );

    expect(workflow, contains('aps-environment production (push would never'));
  });
}

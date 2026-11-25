/// Contract v0.18.3 (R7) `PushConfig`: `GET /push/config?app=driver`, the
/// public Firebase web settings the server reads for the app, so no key is
/// kept in this repository.
///
/// v0.18.105 (BQ-V43): `&platform=android` gives `androidConfig`, the
/// Android Firebase app's public settings (the same four fields), so the
/// Android store build starts Firebase without a google-services.json.
///
/// v0.18.156 (owner 2026-11-24 "Notifications doesn't work on iPhones?"):
/// `&platform=ios` gives `iosConfig`, the iOS Firebase app's public
/// settings (the same four fields plus `iosBundleId`), so the iPhone build
/// starts Firebase without a GoogleService-Info.plist.
class PushConfig {
  const PushConfig({
    required this.enabled,
    this.projectId,
    this.webConfig,
    this.androidConfig,
    this.iosConfig,
  });

  factory PushConfig.fromJson(Map<String, dynamic> json) {
    PushWebConfig? read(String key) {
      final value = json[key];
      return value is Map<String, dynamic>
          ? PushWebConfig.fromJson(value)
          : null;
    }

    final config = read('webConfig');
    final android = read('androidConfig');
    final ios = read('iosConfig');
    return PushConfig(
      enabled:
          json['enabled'] == true &&
          (config != null || android != null || ios != null),
      projectId: json['projectId'] is String
          ? json['projectId'] as String
          : null,
      webConfig: config,
      androidConfig: android,
      iosConfig: ios,
    );
  }

  static const off = PushConfig(enabled: false);

  final bool enabled;
  final String? projectId;
  final PushWebConfig? webConfig;

  /// v0.18.105: the Android app's settings (only with `platform=android`).
  final PushWebConfig? androidConfig;

  /// v0.18.156: the iOS app's settings (only with `platform=ios`).
  final PushWebConfig? iosConfig;
}

class PushWebConfig {
  const PushWebConfig({
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.projectId,
    this.authDomain,
    this.iosBundleId,
  });

  static PushWebConfig? fromJson(Map<String, dynamic> json) {
    String? text(String key) {
      final value = json[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    final apiKey = text('apiKey');
    final appId = text('appId');
    final sender = text('messagingSenderId');
    final project = text('projectId');
    if (apiKey == null || appId == null || sender == null || project == null) {
      return null;
    }
    return PushWebConfig(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: sender,
      projectId: project,
      authDomain: text('authDomain'),
      iosBundleId: text('iosBundleId'),
    );
  }

  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;
  final String? authDomain;

  /// v0.18.156: the bundle id of an `iosConfig` (else null).
  final String? iosBundleId;

  /// The options `firebase.initializeApp` takes on the web.
  Map<String, String> toJson() => {
    'apiKey': apiKey,
    'appId': appId,
    'messagingSenderId': messagingSenderId,
    'projectId': projectId,
    if (authDomain != null) 'authDomain': authDomain!,
  };
}

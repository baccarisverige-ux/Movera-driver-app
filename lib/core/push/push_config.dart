/// Contract v0.18.3 (R7) `PushConfig`: `GET /push/config?app=driver`, the
/// public Firebase web settings the server reads for the app, so no key is
/// kept in this repository.
///
/// v0.18.105 (BQ-V43): `&platform=android` gives `androidConfig`, the
/// Android Firebase app's public settings (the same four fields), so the
/// Android store build starts Firebase without a google-services.json.
class PushConfig {
  const PushConfig({
    required this.enabled,
    this.projectId,
    this.webConfig,
    this.androidConfig,
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
    return PushConfig(
      enabled: json['enabled'] == true && (config != null || android != null),
      projectId: json['projectId'] is String
          ? json['projectId'] as String
          : null,
      webConfig: config,
      androidConfig: android,
    );
  }

  static const off = PushConfig(enabled: false);

  final bool enabled;
  final String? projectId;
  final PushWebConfig? webConfig;

  /// v0.18.105: the Android app's settings (only with `platform=android`).
  final PushWebConfig? androidConfig;
}

class PushWebConfig {
  const PushWebConfig({
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.projectId,
    this.authDomain,
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
    );
  }

  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;
  final String? authDomain;

  /// The options `firebase.initializeApp` takes on the web.
  Map<String, String> toJson() => {
    'apiKey': apiKey,
    'appId': appId,
    'messagingSenderId': messagingSenderId,
    'projectId': projectId,
    if (authDomain != null) 'authDomain': authDomain!,
  };
}

/// Contract v0.18.3 (R7) `PushConfig`: `GET /push/config?app=driver`, the
/// public Firebase web settings the server reads for the app, so no key is
/// kept in this repository.
class PushConfig {
  const PushConfig({required this.enabled, this.projectId, this.webConfig});

  factory PushConfig.fromJson(Map<String, dynamic> json) {
    final web = json['webConfig'];
    final config = web is Map<String, dynamic>
        ? PushWebConfig.fromJson(web)
        : null;
    return PushConfig(
      enabled: json['enabled'] == true && config != null,
      projectId: json['projectId'] is String
          ? json['projectId'] as String
          : null,
      webConfig: config,
    );
  }

  static const off = PushConfig(enabled: false);

  final bool enabled;
  final String? projectId;
  final PushWebConfig? webConfig;
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

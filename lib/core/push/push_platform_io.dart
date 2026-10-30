import 'package:movera/core/push/push_config.dart';
import 'package:movera/core/push/push_platform.dart';

/// Android, iOS and tests: no push until a store build brings the Firebase
/// app files (docs/push.md).
PushPlatform createPlatformPush() => const UnsupportedPushPlatform();

class UnsupportedPushPlatform implements PushPlatform {
  const UnsupportedPushPlatform();

  @override
  bool get supported => false;

  @override
  String get platformName => 'android';

  @override
  Future<String> permission() async => 'denied';

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<String?> token(PushWebConfig config) async => null;

  @override
  PushOpen? takeLaunchOpen() => null;

  @override
  void onOpen(void Function(PushOpen open) handler) {}
}

import 'package:flutter/foundation.dart';
import 'package:movera/core/push/firebase_push_gateway.dart';
import 'package:movera/core/push/native_push_platform.dart';
import 'package:movera/core/push/push_config.dart';
import 'package:movera/core/push/push_platform.dart';

NativePushPlatform? _android;
NativePushPlatform? _ios;

/// Android (BQ-V43): one [NativePushPlatform] for the whole app (the
/// registrar starts it; the phone checks read its permission). It does
/// nothing until the server gives the Android settings. iOS (v0.18.160,
/// the APNs key is in Firebase): the same with the server's iOS settings.
/// Other systems: no push.
PushPlatform createPlatformPush() {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return _android ??= NativePushPlatform(FirebasePushGateway());
  }
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return _ios ??= NativePushPlatform(FirebasePushGateway(), platform: 'ios');
  }
  return const UnsupportedPushPlatform();
}

class UnsupportedPushPlatform implements PushPlatform {
  const UnsupportedPushPlatform();

  @override
  bool get supported => false;

  @override
  bool get ready => false;

  @override
  PushWebConfig? settingsFrom(PushConfig config) => null;

  @override
  Future<bool> prepare(PushWebConfig settings) async => false;

  @override
  void onTokenRefresh(void Function(String token) handler) {}

  @override
  String get platformName =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

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

  @override
  void setOfferAlerts({required bool vibrate}) {}
}

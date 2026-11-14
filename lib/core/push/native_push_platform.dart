import 'dart:async';

import 'package:movera/core/logging/driver_log.dart';
import 'package:movera/core/push/push_config.dart';
import 'package:movera/core/push/push_platform.dart';

/// The Firebase side of [NativePushPlatform], a seam so tests need no
/// Firebase (`firebase_push_gateway.dart` is the real one).
abstract class NativePushGateway {
  /// Starts Firebase with the server's public Android settings.
  Future<void> start(PushWebConfig settings);

  /// `granted`, `denied` or `default` (not asked yet).
  Future<String> permission();

  Future<bool> requestPermission();

  Future<String?> token();

  /// The push the app was started from (a tap while it was closed).
  Future<PushOpen?> initialOpen();

  /// Taps while the app runs in the background.
  Stream<PushOpen> get onOpened;

  Stream<String> get onTokenRefresh;
}

/// BQ-V43 (G4 decision 1 "Push + sound + vibration", owner R7; contract
/// v0.18.105 `auth.devices.config.android`): push on the Android store
/// build. Firebase is started at run time from
/// `GET /push/config?app=driver&platform=android` ([prepare]); no
/// google-services.json and no key is in this repository. Until it is
/// started this does nothing: no permission is read or asked and no token
/// is made, so a build or a server without the Android settings stays
/// quiet (the registrar logs why).
///
/// The notice itself is shown by Android from the server's message: the
/// offer channels `movera_offers` (Movera offer sound, vibration) and
/// `movera_offers_quiet` (Radar) are made in `MainActivity.kt`. A push that
/// comes while the app is open is not shown (the offer stream shows it).
class NativePushPlatform implements PushPlatform {
  NativePushPlatform(this._gateway);

  final NativePushGateway _gateway;
  bool _ready = false;
  Future<bool>? _starting;
  PushOpen? _launch;
  bool _launchTaken = false;
  void Function(PushOpen open)? _openHandler;
  void Function(String token)? _tokenHandler;

  @override
  bool get supported => true;

  @override
  bool get ready => _ready;

  @override
  String get platformName => 'android';

  @override
  PushWebConfig? settingsFrom(PushConfig config) => config.androidConfig;

  @override
  Future<bool> prepare(PushWebConfig settings) {
    if (_ready) return Future.value(true);
    return _starting ??= _start(settings).whenComplete(() => _starting = null);
  }

  Future<bool> _start(PushWebConfig settings) async {
    try {
      await _gateway.start(settings);
      _gateway.onOpened.listen((open) => _openHandler?.call(open));
      _gateway.onTokenRefresh.listen((token) => _tokenHandler?.call(token));
      try {
        _launch = await _gateway.initialOpen();
      } catch (_) {
        _launch = null;
      }
      _ready = true;
      return true;
    } catch (error) {
      DriverLog.warn(
        'push off: Firebase did not start (${error.runtimeType})',
        name: 'push',
      );
      return false;
    }
  }

  @override
  Future<String> permission() async =>
      _ready ? await _gateway.permission() : 'default';

  @override
  Future<bool> requestPermission() async =>
      _ready && await _gateway.requestPermission();

  @override
  Future<String?> token(PushWebConfig config) async =>
      _ready ? await _gateway.token() : null;

  @override
  PushOpen? takeLaunchOpen() {
    if (_launchTaken || !_ready) return null;
    _launchTaken = true;
    return _launch;
  }

  @override
  void onOpen(void Function(PushOpen open) handler) => _openHandler = handler;

  @override
  void onTokenRefresh(void Function(String token) handler) =>
      _tokenHandler = handler;

  /// G4-E6 on Android: the system shows the notice on the channel the
  /// server names, so the driver's in-app Vibrate setting cannot change it
  /// (Android settings › Movera › notifications can). Kept as a gap in
  /// Rules audits/impact/v43-driver-native-push.md.
  @override
  void setOfferAlerts({required bool vibrate}) {}
}

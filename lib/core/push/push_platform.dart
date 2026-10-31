import 'package:movera/core/push/push_config.dart';
import 'package:movera/core/push/push_platform_io.dart'
    if (dart.library.js_interop) 'package:movera/core/push/push_platform_web.dart';

/// What a push tap carries (contract v0.18.3 `auth.devices.sending.data`).
class PushOpen {
  const PushOpen({required this.notificationId, this.deepLink});

  final String notificationId;
  final String? deepLink;

  static final RegExp _offerLink = RegExp(
    r'^movera-driver://offers/([^/?#]+)$',
  );

  /// G4 decision 1 (contract v0.18.6 `driverOffers.push`): the offer of a
  /// `new_offer` push (`movera-driver://offers/{offerId}`), else null. Its
  /// `notificationId` is not a bell notice (never marked read).
  String? get offerId {
    final match = _offerLink.firstMatch(deepLink?.trim() ?? '');
    final id = match == null ? null : Uri.decodeComponent(match.group(1)!);
    return id == null || id.isEmpty ? null : id;
  }
}

/// The device side of push: the permission, the FCM token and taps.
///
/// The web build (what is live) uses Firebase Cloud Messaging through
/// `web/movera_push.js` and the service worker `web/firebase-messaging-sw.js`,
/// both started from [PushConfig] at run time. Android and iOS have no push
/// yet: they need the Firebase app files of a store build (see
/// `docs/push.md`), so [supported] is false there and nothing is asked.
abstract class PushPlatform {
  bool get supported;

  /// `granted`, `denied` or `default` (not asked yet).
  Future<String> permission();

  /// Asks the system once; true when allowed.
  Future<bool> requestPermission();

  /// The FCM token, or null when there is none.
  Future<String?> token(PushWebConfig config);

  /// `web`, `android` or `ios`.
  String get platformName;

  /// The push the app was opened from, once.
  PushOpen? takeLaunchOpen();

  /// Called on every tap on a push while the app runs.
  void onOpen(void Function(PushOpen open) handler);

  /// G4-E6: tells the push side (the web service worker) whether an offer
  /// push may vibrate: only while the driver's own Vibrate setting is on.
  void setOfferAlerts({required bool vibrate});
}

PushPlatform createPushPlatform() => createPlatformPush();

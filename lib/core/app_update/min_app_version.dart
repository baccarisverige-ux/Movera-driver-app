import 'package:flutter/foundation.dart';
import 'package:movera/core/content/driver_content.dart';
import 'package:movera/core/logging/crash_reports.dart';

/// Contract v0.18.154 P16c (`contract.json#appUpdate`; owner 2026-11-21
/// "Yes, build it now (Recommended)"): the zone's minimum app version per
/// platform (`DriverAppConfig.appUpdate.minVersion { android, ios }`, null =
/// off) and the store links (`appUpdate.storeUrls`, null = the built-in
/// link). Below it the app shows one full screen "Update Movera to
/// continue", never while a trip is active.
@immutable
class MinAppVersionRule {
  const MinAppVersionRule({
    this.minVersion = const {},
    this.storeUrls = const {},
  });

  static const off = MinAppVersionRule();

  /// Platform → minimum (`android`, `ios`).
  final Map<String, AppVersion> minVersion;

  /// Platform → https store link.
  final Map<String, String> storeUrls;

  /// `DriverAppConfig.appUpdate`; anything not valid reads as off. The
  /// older keys (minimumVersion, latestVersion, storeUrl) never block.
  factory MinAppVersionRule.fromJson(Object? appUpdate) {
    if (appUpdate is! Map) return off;
    final mins = appUpdate['minVersion'];
    final urls = appUpdate['storeUrls'];
    return MinAppVersionRule(
      minVersion: {
        if (mins is Map)
          for (final platform in MinAppVersion.platforms)
            if (_semver.hasMatch('${mins[platform]}'))
              platform: AppVersion.tryParse(mins[platform])!,
      },
      storeUrls: {
        if (urls is Map)
          for (final platform in MinAppVersion.platforms)
            if (urls[platform] case final String url
                when url.startsWith('https://'))
              platform: url,
      },
    );
  }

  static final _semver = RegExp(r'^\d+\.\d+\.\d+$');

  /// True when [running] on [platform] is below this rule's minimum.
  bool blocks(AppVersion? running, String? platform) {
    if (running == null || platform == null) return false;
    final min = minVersion[platform];
    return min != null && running < min;
  }

  @override
  bool operator ==(Object other) =>
      other is MinAppVersionRule &&
      mapEquals(
        other.minVersion.map((k, v) => MapEntry(k, '$v')),
        minVersion.map((k, v) => MapEntry(k, '$v')),
      ) &&
      mapEquals(other.storeUrls, storeUrls);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(
      minVersion.entries.map((e) => '${e.key}${e.value}'),
    ),
    Object.hashAllUnordered(storeUrls.entries.map((e) => '${e.key}${e.value}')),
  );
}

/// The rule in use and the build this phone runs.
abstract final class MinAppVersion {
  static const platforms = ['android', 'ios'];

  /// The zone's rule, from the driver document in use (config start and
  /// every `config_published`).
  static final ValueNotifier<MinAppVersionRule> rule = ValueNotifier(
    MinAppVersionRule.off,
  );

  /// The server answered 426 `app_update_required` (a newer rule than the
  /// one in use); cleared by the next document.
  static final ValueNotifier<bool> serverSaid = ValueNotifier(false);

  /// The start's active-trip check answered with no trip (Home's restore,
  /// saved trip + server). Until then, or a trip was seen, nothing blocks:
  /// a cold start mid-trip never flashes the block before the trip screen.
  static final ValueNotifier<bool> tripChecked = ValueNotifier(false);

  /// Review O-2: whether the driver holds a booked ride not started yet
  /// (`GET /driver/reservations?scope=accepted`); null = not known. Held or
  /// unknown: no block, only the small line (the server never refuses his
  /// go-online then, contract.json#appUpdate.neverRefused).
  static final ValueNotifier<bool?> bookedHeld = ValueNotifier(null);

  /// The answer of the start's (or after-trip) active-trip check. Only a
  /// server read that worked confirms "no trip"; a failed read (or the
  /// saved trip alone) leaves it unknown (review S-D1). No live server
  /// (the demo): the saved trip is the whole answer.
  static void answerTripCheck({
    required bool askedServer,
    required bool serverReadFailed,
    required bool liveServer,
  }) {
    if (!liveServer || (askedServer && !serverReadFailed)) {
      tripChecked.value = true;
    }
  }

  /// Review S-D2: a sign-out forgets what this account's checks said.
  static void signedOut() {
    tripChecked.value = false;
    serverSaid.value = false;
    bookedHeld.value = null;
  }

  /// A new driver document: its rule replaces the one in use.
  static void accept(Object? appUpdate) {
    rule.value = MinAppVersionRule.fromJson(appUpdate);
    serverSaid.value = false;
  }

  /// A 426 answer with reason `app_update_required`.
  static void markServerSaid(Map<String, dynamic>? body) {
    // A body that cannot be read, or another reason, never blocks.
    if (body?['reason'] != 'app_update_required') return;
    serverSaid.value = true;
  }

  /// Tests.
  @visibleForTesting
  static void reset() {
    rule.value = MinAppVersionRule.off;
    serverSaid.value = false;
    tripChecked.value = false;
    bookedHeld.value = null;
  }

  /// This build's version x.y.z (`MOVERA_APP_VERSION`); null for a local
  /// ("dev") build, which is never blocked and sends no header.
  static AppVersion? running = AppVersion.tryParse(
    _plain(CrashReports.splitVersion(driverAppVersion).version),
  );

  static String _plain(String version) =>
      RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version) ? version : '';

  /// `android` / `ios`; null on the web and other platforms (no check).
  static String? platform = _platform();

  static String? _platform() {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => null,
    };
  }

  /// `X-App-Version` + `X-App-Platform`, only on an Android / iOS build
  /// with a version (contract.json#appUpdate.headers).
  static Map<String, String> get headers {
    final version = running;
    final on = platform;
    if (version == null || on == null) return const {};
    return {'X-App-Version': '$version', 'X-App-Platform': on};
  }

  /// True when this phone must update (from the rule or the server).
  static bool get required {
    if (running == null || platform == null) return false;
    return serverSaid.value || rule.value.blocks(running, platform);
  }

  /// The store link for this phone: the zone's, else [fallback].
  static Uri storeUri(String fallback) {
    final own = platform == null ? null : rule.value.storeUrls[platform];
    return Uri.parse(own ?? fallback);
  }
}

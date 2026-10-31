import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_service.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:movera/core/phone/browser_online_io.dart'
    if (dart.library.js_interop) 'package:movera/core/phone/browser_online_web.dart';
import 'package:movera/core/push/push_platform.dart';

/// Owner 2026-10-31 ("new set offline message", decisions/driver-g3.md):
/// the offline card's "Check my phone" — what can keep a driver from
/// staying online, each with a fix.
enum PhoneCheckKind { location, internet, batterySaver, notifications }

/// ✓, ✗, or the phone (browser) cannot tell.
enum PhoneCheckState { ok, problem, unknown }

/// What the fix button of a ✗ line does.
enum PhoneCheckFix {
  /// No button.
  none,

  /// Asks the system for the permission (location, notifications).
  turnOn,

  /// The app's page (or the location page) in the phone's settings.
  openSettings,

  /// Runs the check again (internet).
  retry,

  /// Blocked in the browser: no button can open its site settings, so
  /// the line says where to allow it.
  browserSettings,
}

@immutable
class PhoneCheckResult {
  const PhoneCheckResult(
    this.kind,
    this.state, {
    this.fix = PhoneCheckFix.none,
  });

  const PhoneCheckResult.ok(this.kind)
    : state = PhoneCheckState.ok,
      fix = PhoneCheckFix.none;

  const PhoneCheckResult.unknown(this.kind)
    : state = PhoneCheckState.unknown,
      fix = PhoneCheckFix.none;

  final PhoneCheckKind kind;
  final PhoneCheckState state;
  final PhoneCheckFix fix;
}

/// Runs one check and its fix. [PhoneChecks.current] is the phone's own;
/// tests put their own there.
abstract class PhoneChecks {
  const PhoneChecks();

  static PhoneChecks current = const DevicePhoneChecks();

  /// The longest one check may take before it counts as "can't tell".
  static const Duration limit = Duration(seconds: 8);

  Future<PhoneCheckResult> check(PhoneCheckKind kind);

  /// Does [result]'s fix; the card checks again afterwards.
  Future<void> fix(PhoneCheckResult result);

  /// Every check, side by side, each within [limit].
  Future<List<PhoneCheckResult>> all() => Future.wait([
    for (final kind in PhoneCheckKind.values)
      check(
        kind,
      ).timeout(limit).catchError((Object _) => PhoneCheckResult.unknown(kind)),
  ]);
}

/// The real phone or browser.
class DevicePhoneChecks extends PhoneChecks {
  const DevicePhoneChecks();

  /// Set by the app root: registers push once notifications are allowed.
  static void Function()? notificationsAllowed;

  static PushPlatform? _push;
  static PushPlatform get _pushPlatform => _push ??= createPushPlatform();

  @override
  Future<PhoneCheckResult> check(PhoneCheckKind kind) async {
    try {
      return switch (kind) {
        PhoneCheckKind.location => await _location(),
        PhoneCheckKind.internet => await _internet(),
        PhoneCheckKind.batterySaver => await _batterySaver(),
        PhoneCheckKind.notifications => await _notifications(),
      };
    } catch (error) {
      DriverLog.warn('phone check $kind: ${error.runtimeType}', name: 'check');
      return PhoneCheckResult.unknown(kind);
    }
  }

  Future<PhoneCheckResult> _location() async {
    const kind = PhoneCheckKind.location;
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const PhoneCheckResult(
        kind,
        PhoneCheckState.problem,
        fix: PhoneCheckFix.openSettings,
      );
    }
    return switch (await Geolocator.checkPermission()) {
      LocationPermission.always ||
      LocationPermission.whileInUse => const PhoneCheckResult.ok(kind),
      LocationPermission.denied => const PhoneCheckResult(
        kind,
        PhoneCheckState.problem,
        fix: PhoneCheckFix.turnOn,
      ),
      LocationPermission.deniedForever => const PhoneCheckResult(
        kind,
        PhoneCheckState.problem,
        fix: kIsWeb
            ? PhoneCheckFix.browserSettings
            : PhoneCheckFix.openSettings,
      ),
      LocationPermission.unableToDetermine => const PhoneCheckResult.unknown(
        kind,
      ),
    };
  }

  /// `navigator.onLine` (web) and a quick `GET /healthz` of the server.
  Future<PhoneCheckResult> _internet() async {
    const kind = PhoneCheckKind.internet;
    const problem = PhoneCheckResult(
      kind,
      PhoneCheckState.problem,
      fix: PhoneCheckFix.retry,
    );
    final online = browserOnline();
    if (online == false) return problem;
    final api = LiveDriverServices.instance?.api;
    if (api == null) {
      // The demo has no server: only the browser can tell.
      return online == true
          ? const PhoneCheckResult.ok(kind)
          : const PhoneCheckResult.unknown(kind);
    }
    try {
      await api.get(
        '/healthz',
        authenticated: false,
        timeout: PhoneChecks.limit,
      );
      return const PhoneCheckResult.ok(kind);
    } catch (_) {
      return problem;
    }
  }

  /// Browsers do not tell battery saver (the Battery Status API has only
  /// the level and charging); Android and iOS do (battery_plus).
  Future<PhoneCheckResult> _batterySaver() async {
    const kind = PhoneCheckKind.batterySaver;
    if (kIsWeb) return const PhoneCheckResult.unknown(kind);
    if (await Battery().isInBatterySaveMode) {
      return const PhoneCheckResult(
        kind,
        PhoneCheckState.problem,
        fix: PhoneCheckFix.openSettings,
      );
    }
    return const PhoneCheckResult.ok(kind);
  }

  /// The push permission (web build); Android and iOS have no push yet
  /// (docs/push.md), so they cannot tell.
  Future<PhoneCheckResult> _notifications() async {
    const kind = PhoneCheckKind.notifications;
    final push = _pushPlatform;
    if (!push.supported) return const PhoneCheckResult.unknown(kind);
    return switch (await push.permission()) {
      'granted' => const PhoneCheckResult.ok(kind),
      'denied' => const PhoneCheckResult(
        kind,
        PhoneCheckState.problem,
        fix: kIsWeb
            ? PhoneCheckFix.browserSettings
            : PhoneCheckFix.openSettings,
      ),
      _ => const PhoneCheckResult(
        kind,
        PhoneCheckState.problem,
        fix: PhoneCheckFix.turnOn,
      ),
    };
  }

  @override
  Future<void> fix(PhoneCheckResult result) async {
    switch (result.fix) {
      case PhoneCheckFix.none ||
          PhoneCheckFix.retry ||
          PhoneCheckFix.browserSettings:
        return;
      case PhoneCheckFix.openSettings:
        if (result.kind == PhoneCheckKind.location) {
          await DriverLocationService.openLocationSettings();
        } else {
          await DriverLocationService.openSettings();
        }
      case PhoneCheckFix.turnOn:
        if (result.kind == PhoneCheckKind.location) {
          DriverLocationService.allowPrompt();
          await Geolocator.requestPermission();
        } else if (result.kind == PhoneCheckKind.notifications) {
          if (await _pushPlatform.requestPermission()) {
            notificationsAllowed?.call();
          }
        }
    }
  }
}

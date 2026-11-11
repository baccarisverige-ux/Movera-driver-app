import 'package:flutter/material.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/logging/crash_reports.dart';

/// Owner 2026-11-11 (set 2 "Yes, both apps"; contract v0.18.66 §87, app
/// only, Rule 43(1)): the last line of the Account screen, the app version
/// and build number, e.g. "Version 1.0.0 (583)". Read from the build
/// ([driverAppVersion], `--dart-define=MOVERA_APP_VERSION=<version>+<build>`
/// as the crash reports use it); a local build says "Version dev".
class AppVersionLine extends StatelessWidget {
  const AppVersionLine({super.key, this.raw = driverAppVersion});

  /// `1.0.0+583`; tests pass their own.
  final String raw;

  /// "Version 1.0.0 (583)", or "Version 1.0.0" without a build number.
  static String text(String raw) {
    final parts = CrashReports.splitVersion(raw);
    final build = parts.build;
    return build == null
        ? tr.appVersionOnly(parts.version)
        : tr.appVersionLine(parts.version, build);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      text(raw),
      key: const ValueKey<String>('account-app-version'),
      textAlign: TextAlign.center,
      style: const TextStyle(color: Color(0xFF8A8A8A), fontSize: 12),
    ),
  );
}

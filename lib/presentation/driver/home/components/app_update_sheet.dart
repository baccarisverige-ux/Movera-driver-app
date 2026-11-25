import 'package:movera/core/l10n/driver_l10n.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/logging/crash_reports.dart';
import 'package:movera/presentation/driver/profile/app_version_line.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:url_launcher/url_launcher.dart';

/// BQ-V46 (G6; owner 2026-11-11 set 2 "App version + build number inside
/// both apps": "Yes, both apps"): the admin's latest version is offered
/// only when it is newer than the version this build really is
/// ([driverAppVersion], `MOVERA_APP_VERSION`, the same source as the Account
/// "Version x (build)" line; was a hard-coded '1.0.0'). A local build
/// ("dev") has no version and is never offered an update.
bool appUpdateOffered(
  AppUpdateAdminConfig update, {
  String installed = driverAppVersion,
}) {
  if (!update.enabled) return false;
  final current = _versionNumbers(CrashReports.splitVersion(installed).version);
  final latest = _versionNumbers(update.latestVersion);
  if (current == null || latest == null) return false;
  final length = math.max(current.length, latest.length);
  for (var i = 0; i < length; i++) {
    final a = i < latest.length ? latest[i] : 0;
    final b = i < current.length ? current[i] : 0;
    if (a != b) return a > b;
  }
  return false;
}

/// "1.4.0" → [1, 4, 0]; null when it is not a dotted number ("dev").
List<int>? _versionNumbers(String value) {
  final parts = value.trim().split('.');
  final numbers = <int>[];
  for (final part in parts) {
    final n = int.tryParse(part);
    if (n == null || n < 0) return null;
    numbers.add(n);
  }
  return numbers;
}

class AppUpdateSheet extends StatefulWidget {
  const AppUpdateSheet({
    super.key,
    required this.update,
    this.launchUpdate,
    this.installed = driverAppVersion,
  });

  final AppUpdateAdminConfig update;
  final String installed;

  /// "Installed: 1.4.0 (583)": the version and build number on this phone.
  static String installedText(String raw) =>
      tr.versionInstalled(AppVersionLine.short(raw));
  final Future<bool> Function(Uri)? launchUpdate;

  @override
  State<AppUpdateSheet> createState() => _AppUpdateSheetState();
}

class _AppUpdateSheetState extends State<AppUpdateSheet> {
  bool _launching = false;
  bool _launchFailed = false;
  bool get _ownsRoute => mounted && ModalRoute.of(context)?.isCurrent == true;

  Future<void> _openUpdate() async {
    if (!_ownsRoute || _launching) return;
    setState(() {
      _launching = true;
      _launchFailed = false;
    });
    var opened = false;
    try {
      final raw = widget.update.updateUrl;
      final uri = raw == null ? null : Uri.tryParse(raw.trim());
      if (uri != null && uri.hasScheme) {
        opened =
            await (widget.launchUpdate ??
                (uri) =>
                    launchUrl(uri, mode: LaunchMode.externalApplication))(uri);
      }
    } catch (_) {
      opened = false;
    } finally {
      if (mounted) {
        setState(() {
          _launching = false;
          _launchFailed = !opened;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final update = widget.update;
    return PopScope<void>(
      canPop: !update.mandatory,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        decoration: const BoxDecoration(
          color: Color(0xFFF9FBFA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD7DEDB),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFE6F5EE),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.system_update_alt_rounded,
                color: Color(0xFF19865C),
                size: 27,
              ),
            ),
            const SizedBox(height: 13),
            Text(
              update.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF252E3A),
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.35,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              update.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF7D898F),
                fontSize: 11.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr.versionLatestVersion(update.latestVersion),
              style: const TextStyle(
                color: Color(0xFF19865C),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppUpdateSheet.installedText(widget.installed),
              key: const ValueKey<String>('app-update-installed'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF7D898F),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _launching ? null : _openUpdate,
                style: FilledButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFF252E3A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _launching ? tr.openingUpdateEllipsis : update.actionLabel,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            if (_launchFailed) ...[
              const SizedBox(height: 8),
              Text(
                tr.couldNotOpenUpdatePleaseTry,
                key: ValueKey('app-update-error'),
                textAlign: TextAlign.center,
              ),
            ],
            if (!update.mandatory) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => popOwned(context),
                child: Text(
                  update.dismissLabel,
                  style: const TextStyle(
                    color: Color(0xFF66737A),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

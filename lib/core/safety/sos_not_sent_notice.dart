import 'dart:async';

import 'package:flutter/material.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owner 2026-11-20 "Show 'SOS not sent' (Rec.)": a kept SOS that was given
/// up on (too old, refused, another driver, sign-out) is told to the driver
/// in a dialog that stays until OK. It is kept on the phone, so a locked
/// phone, the background or a restart still shows it on the next resume or
/// start (existing texts `safetySosNotSent` and `ok`).
class SosNotSentNotice with WidgetsBindingObserver {
  SosNotSentNotice._();

  static final SosNotSentNotice instance = SosNotSentNotice._();

  static const prefKey = 'sos_not_sent_notice_v1';

  /// Where the dialog opens (the app's navigator); null: none yet.
  BuildContext? Function()? context;

  bool _open = false;
  bool _observing = false;

  /// Starts showing a kept notice on each resume.
  void attach(BuildContext? Function() where) {
    context = where;
    if (!_observing) {
      _observing = true;
      WidgetsBinding.instance.addObserver(this);
    }
    unawaited(showIfPending());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(showIfPending());
  }

  /// An SOS was given up on: kept, then shown.
  Future<void> raise() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefKey, true);
    } catch (_) {}
    await showIfPending(force: true);
  }

  Future<bool> pending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(prefKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> showIfPending({bool force = false}) async {
    if (_open) return;
    if (!force && !await pending()) return;
    final where = context?.call();
    if (where == null || !where.mounted) return;
    _open = true;
    try {
      await showDialog<void>(
        context: where,
        barrierDismissible: false,
        builder: (dialog) => AlertDialog(
          key: const ValueKey('sos-not-sent-notice'),
          content: Text(tr.safetySosNotSent),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialog).pop(),
              child: Text(tr.ok),
            ),
          ],
        ),
      );
      // Dismissed with OK: not shown again.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(prefKey);
      } catch (_) {}
    } finally {
      _open = false;
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _open = false;
    context = null;
  }
}

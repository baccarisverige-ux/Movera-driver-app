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

  /// Raised while a dialog was up: shown again once it is closed.
  bool _raisedWhileOpen = false;

  /// An SOS was given up on: kept, then shown.
  Future<void> raise() async {
    if (_open) _raisedWhileOpen = true;
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
    // Set before any wait: two calls never stack two dialogs.
    if (_open) return;
    _open = true;
    var again = false;
    try {
      if (!force && !await pending()) return;
      final where = context?.call();
      if (where == null || !where.mounted) return;
      _raisedWhileOpen = false;
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
      } catch (_) {
        // Not shown (no navigator now): kept for the next resume.
        return;
      }
      // Dismissed with OK: not shown again, unless a new one came meanwhile.
      again = _raisedWhileOpen;
      _raisedWhileOpen = false;
      if (!again) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(prefKey);
        } catch (_) {}
      }
    } finally {
      _open = false;
    }
    if (again) await showIfPending(force: true);
  }

  @visibleForTesting
  void resetForTesting() {
    _open = false;
    _raisedWhileOpen = false;
    context = null;
  }
}

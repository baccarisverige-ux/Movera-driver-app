import 'package:flutter/material.dart';
import 'package:movera/core/l10n/driver_l10n.dart';

/// Owner button 2026-11-20 "Change meter to app (Rec.)": "Ändra
/// taxametern till 240,00 kr". It stays until the driver taps OK (no tap
/// beside it, no back press closes it); a newer price while it is open
/// replaces the amount in the same notice. [close] takes it away when the
/// trip ends or the screen goes.
class MeterChangeNotice {
  final ValueNotifier<String?> _amount = ValueNotifier<String?>(null);
  BuildContext? _dialog;
  VoidCallback? _onOk;
  bool _open = false, _disposed = false;

  bool get isOpen => _open;

  /// Shows [amount] (the server's formatted fare) on [context]'s
  /// navigator; [onOk] runs when the driver taps OK on that amount.
  void show(BuildContext context, String amount, {VoidCallback? onOk}) {
    if (_disposed) return;
    _amount.value = amount;
    _onOk = onOk;
    if (_open) return;
    _open = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        _dialog = dialogContext;
        return PopScope(
          canPop: false,
          child: ValueListenableBuilder<String?>(
            valueListenable: _amount,
            builder: (_, value, _) => AlertDialog(
              key: const ValueKey('meter-change-notice'),
              content: Text(
                tr.meterChangeToAppPrice(value ?? amount),
                style: Theme.of(dialogContext).textTheme.titleLarge,
              ),
              actions: [
                FilledButton(
                  key: const ValueKey('meter-change-ok'),
                  onPressed: () {
                    _onOk?.call();
                    _pop();
                  },
                  child: Text(tr.ok),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      _open = false;
      _dialog = null;
    });
  }

  void _pop() {
    final dialog = _dialog;
    if (dialog != null && dialog.mounted) Navigator.of(dialog).pop();
  }

  /// Takes an open notice away without OK (the trip ended).
  void close() {
    _onOk = null;
    if (_open) _pop();
  }

  /// The screen goes: the notice goes with it (after this frame, as the
  /// navigator may be busy).
  void dispose() {
    _disposed = true;
    _onOk = null;
    if (_open) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pop();
        _amount.dispose();
      });
    } else {
      _amount.dispose();
    }
  }
}

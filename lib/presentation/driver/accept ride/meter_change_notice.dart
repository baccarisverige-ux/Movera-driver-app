import 'package:flutter/material.dart';
import 'package:movera/core/l10n/driver_l10n.dart';

/// Owner button 2026-11-20 "Change meter to app (Rec.)": "Ändra
/// taxametern till 240,00 kr". It stays until the driver taps OK (no tap
/// beside it, no back press closes it); a newer price while it is open
/// replaces the amount in the same notice.
class MeterChangeNotice {
  final ValueNotifier<String?> _amount = ValueNotifier<String?>(null);
  bool _open = false;

  /// Shows [amount] (the server's formatted fare) on [context]'s navigator.
  void show(BuildContext context, String amount) {
    _amount.value = amount;
    if (_open) return;
    _open = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
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
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(tr.ok),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() => _open = false);
  }
}

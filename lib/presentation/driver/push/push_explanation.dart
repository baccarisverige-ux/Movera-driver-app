import 'package:movera/widgets/movera_dialog_theme.dart';
import 'package:flutter/material.dart';
import 'package:movera/core/l10n/driver_l10n.dart';

/// Contract v0.18.3 R7: why Movera wants to send notices, before the
/// system asks (sv / fr / en). True when the driver wants them.
Future<bool> showPushExplanation(BuildContext context) async {
  final answer = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialog) => MoveraDialogTheme(
      child: AlertDialog(
        key: const ValueKey('push-explanation'),
        icon: const Icon(Icons.notifications_active_outlined),
        title: Text(tr.pushAskTitle),
        content: Text(tr.pushAskBody),
        actions: [
          TextButton(
            key: const ValueKey('push-later'),
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(tr.pushAskLater),
          ),
          FilledButton(
            key: const ValueKey('push-allow'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(tr.pushAskAllow),
          ),
        ],
      ),
    ),
  );
  return answer ?? false;
}

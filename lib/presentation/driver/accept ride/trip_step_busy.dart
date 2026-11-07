import 'package:flutter/material.dart';

/// Finder A4 (2026-11-07): a trip step button (Arrived, Collect cash) while
/// its request to the server runs is disabled, keeps its own colours and
/// shows a spinner, so a slow network never looks like a dead button.
ButtonStyle tripStepStyle(ButtonStyle style) {
  const enabled = <WidgetState>{};
  return style.copyWith(
    backgroundColor: WidgetStatePropertyAll(
      style.backgroundColor?.resolve(enabled),
    ),
    foregroundColor: WidgetStatePropertyAll(
      style.foregroundColor?.resolve(enabled),
    ),
  );
}

/// The button's label, or the spinner (same size and stroke as the PIN
/// sheet's Confirm) in the label's colour while [busy].
Widget tripStepLabel({required bool busy, required Widget child}) {
  if (!busy) return child;
  return Builder(
    builder: (context) => SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(
        strokeWidth: 2.4,
        color: DefaultTextStyle.of(context).style.color,
      ),
    ),
  );
}

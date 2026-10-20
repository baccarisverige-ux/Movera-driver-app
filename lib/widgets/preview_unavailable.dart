import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:flutter/material.dart';
class PreviewUnavailable extends StatelessWidget {
 const PreviewUnavailable({super.key, required this.label, required this.child});
 final String label;
 final Widget child;
 @override
 Widget build(BuildContext context) => Semantics(enabled: false, label: tr.labelUnavailableInDemo(label),
 child: Tooltip(message: tr.labelUnavailableInDemo(label), child: AbsorbPointer(child: child)));
}

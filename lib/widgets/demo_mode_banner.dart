import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:flutter/material.dart';
class DemoModeBanner extends StatelessWidget {
 const DemoModeBanner({super.key});
 @override
 Widget build(BuildContext context) => SafeArea(bottom: false,
 child: Semantics(label: tr.demoModeNoAccount, child: ColoredBox(
 color: Color(0xFFF4F6F7), child: Padding(padding: EdgeInsets.all(4),
 child: Center(child: Text(tr.demoModeNoAccount, style: TextStyle(fontSize: 12, color: Color(0xFF252E3A))))))));
}

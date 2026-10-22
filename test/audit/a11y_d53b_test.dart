// Wave 5 D5.3 (part b): small accessibility checks, one per audit finding.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/side%20menu/side_menu.dart';

/// WCAG contrast of [fg] on [bg] (both opaque).
double _contrast(Color fg, Color bg) {
  final a = fg.computeLuminance(), b = bg.computeLuminance();
  return (math.max(a, b) + .05) / (math.min(a, b) + .05);
}

/// [c] painted over white.
Color _onWhite(Color c) => Color.alphaBlend(c, Colors.white);

void main() {
  testWidgets('driver-u170: the menu ONLINE / OFFLINE pill reads at 4.5:1',
      (tester) async {
    for (final online in [true, false]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: DriverSideMenu(isOnline: online)),
      ));
      final pill = find.byKey(const ValueKey<String>('menu-live-status'));
      final fill = (tester.widget<Container>(pill).decoration! as BoxDecoration)
          .color!;
      final word = tester
          .widget<Text>(find.descendant(of: pill, matching: find.byType(Text)));
      expect(_contrast(word.style!.color!, _onWhite(fill)),
          greaterThanOrEqualTo(4.5),
          reason: online ? 'online' : 'offline');
    }
  });
}

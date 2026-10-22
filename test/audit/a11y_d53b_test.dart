// Wave 5 D5.3 (part b): small accessibility checks, one per audit finding.
import 'dart:math' as math;
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/side%20menu/side_menu.dart';
import 'package:movera/widgets/movera_radar_orb.dart';

/// WCAG contrast of [fg] on [bg] (both opaque).
double _contrast(Color fg, Color bg) {
  final a = fg.computeLuminance(), b = bg.computeLuminance();
  return (math.max(a, b) + .05) / (math.min(a, b) + .05);
}

/// [c] painted over white.
Color _onWhite(Color c) => Color.alphaBlend(c, Colors.white);

Widget _orb({
  VoidCallback? onTap,
  bool active = false,
  bool offer = false,
  bool reserve = false,
  bool blocked = false,
  String status = 'LIVE',
  String subtitle = 'Scanning',
}) =>
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: MoveraRadarOrb(
            title: 'Radar',
            status: status,
            subtitle: subtitle,
            active: active,
            offer: offer,
            reserve: reserve,
            blocked: blocked,
            onTap: onTap,
          ),
        ),
      ),
    );

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

  testWidgets('driver-u178: the radar orb is a button only when a tap acts',
      (tester) async {
    final semantics = tester.ensureSemantics();
    for (final onTap in [null, () {}]) {
      await tester.pumpWidget(_orb(onTap: onTap));
      final data = tester
          .getSemantics(find.bySemanticsLabel(RegExp('^Radar, LIVE')))
          .getSemanticsData();
      expect(data.flagsCollection.isButton, onTap != null);
      expect(data.hasAction(SemanticsAction.tap), onTap != null);
    }
    semantics.dispose();
  });
}

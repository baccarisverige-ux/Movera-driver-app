// Wave 5 D5.3 (part b): small accessibility checks, one per audit finding.
import 'dart:math' as math;
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/side%20menu/side_menu.dart';
import 'package:movera/widgets/movera_radar_orb.dart';
import 'package:movera/widgets/radar_offer_card.dart';

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
}) => MaterialApp(
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

/// The orb's disc colour under [at], over a white sheet.
Color _discAt(WidgetTester tester, Offset at) {
  final ink = find.byType(Ink);
  final disc = tester.getRect(ink);
  final g =
      (tester.widget<Ink>(ink).decoration! as BoxDecoration).gradient!
          as RadialGradient;
  final centre = (g.center as Alignment).withinRect(disc);
  final t = ((at - centre).distance / (g.radius * disc.shortestSide)).clamp(
    0.0,
    1.0,
  );
  final stops = g.stops!;
  var i = 0;
  while (i < stops.length - 2 && t > stops[i + 1]) {
    i++;
  }
  final f = ((t - stops[i]) / (stops[i + 1] - stops[i])).clamp(0.0, 1.0);
  return _onWhite(Color.lerp(g.colors[i], g.colors[i + 1], f)!);
}

void main() {
  testWidgets('driver-u170: the menu ONLINE / OFFLINE pill reads at 4.5:1', (
    tester,
  ) async {
    for (final online in [true, false]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DriverSideMenu(isOnline: online)),
        ),
      );
      final pill = find.byKey(const ValueKey<String>('menu-live-status'));
      final fill =
          (tester.widget<Container>(pill).decoration! as BoxDecoration).color!;
      final word = tester.widget<Text>(
        find.descendant(of: pill, matching: find.byType(Text)),
      );
      expect(
        _contrast(word.style!.color!, _onWhite(fill)),
        greaterThanOrEqualTo(4.5),
        reason: online ? 'online' : 'offline',
      );
    }
  });

  testWidgets('driver-u178: the radar orb is a button only when a tap acts', (
    tester,
  ) async {
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

  testWidgets('driver-u179: the radar status and subtitle keep their size and '
      'read at 4.5:1 on the disc', (tester) async {
    for (final (name, orb) in [
      ('off', _orb(status: 'OFF', subtitle: 'Tap to scan')),
      ('live', _orb(active: true)),
      (
        'found',
        _orb(active: true, offer: true, status: 'NEW', subtitle: 'Tap for all'),
      ),
      (
        'reservation',
        _orb(
          active: true,
          reserve: true,
          status: 'MATCH',
          subtitle: 'Tap to accept',
        ),
      ),
      ('on hold', _orb(blocked: true, status: 'PAUSED', subtitle: 'Hold')),
    ]) {
      await tester.pumpWidget(orb);
      final widget = tester.widget<MoveraRadarOrb>(find.byType(MoveraRadarOrb));
      for (final words in [widget.status, widget.subtitle]) {
        final text = find.text(words);
        final style = tester.widget<Text>(text).style!;
        // Owner (23 Oct 2026): the orb's word is 11.5 px and its hint 7.5 px,
        // Urbanist; the 4.5:1 contrast rule below still holds for both.
        expect(
          style.fontSize,
          greaterThanOrEqualTo(7.5),
          reason: '$name $words',
        );
        final ink = style.color!;
        final box = tester.getRect(text);
        for (final at in [
          box.topLeft,
          box.topRight,
          box.center,
          box.bottomLeft,
          box.bottomRight,
        ]) {
          final bg = _discAt(tester, at);
          expect(
            _contrast(Color.alphaBlend(ink, bg), bg),
            greaterThanOrEqualTo(4.5),
            reason: '$name $words at $at',
          );
        }
      }
    }
  });

  testWidgets('driver-u183: the Radar card Route and × are named, the × '
      'a 48 px target', (tester) async {
    final semantics = tester.ensureSemantics();
    var hidden = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RadarOfferCard(
              offer: const RadarOfferView(
                id: 'o1',
                category: 'Comfort',
                payment: 'Card',
                rating: '4.96',
                fare: '104,80 kr',
                pickupMinutes: 2,
                pickupKm: 0.65,
                tripMinutes: 9,
                tripKm: 4.2,
                pickup: 'Kungsgatan 42, Stockholm',
                dropoff: 'Hornstull, Stockholm',
              ),
              onRoute: () {},
              onDismiss: () => hidden++,
            ),
          ),
        ),
      ),
    );
    final route = find.byKey(const ValueKey<String>('radar-route-o1'));
    final dismiss = find.byKey(
      const ValueKey<String>('radar-offer-dismiss-o1'),
    );
    expect(tester.getSemantics(route).label, 'Show route');
    expect(tester.getSemantics(dismiss).label, 'Close offer');
    expect(tester.getSize(dismiss), const Size.square(48));
    // A corner of the box, outside the 30 px circle, still hides it.
    await tester.tapAt(tester.getTopLeft(dismiss) + const Offset(3, 3));
    expect(hidden, 1);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });
}

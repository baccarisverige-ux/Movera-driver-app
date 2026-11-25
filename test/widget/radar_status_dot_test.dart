import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/widgets/movera_radar_orb.dart';

// Owner 2026-11-24: the Radar status dot, P1 (top-centre inside the disc,
// text not moved) with S2 (5 px dot + 1 px white ring = 7 px).

enum _State { on, off, hold, paused, starting, offer, exclusive, reserve }

MoveraRadarOrb _orb(_State st, {double size = 104}) => switch (st) {
  _State.on => MoveraRadarOrb(
    title: 'Radar',
    status: 'LIVE',
    subtitle: 'Finding trips',
    active: true,
    size: size,
  ),
  _State.off => MoveraRadarOrb(
    title: 'Radar',
    status: 'OFF',
    subtitle: 'Tap to scan',
    size: size,
  ),
  _State.hold => MoveraRadarOrb(
    title: 'Radar',
    status: 'HOLD',
    subtitle: 'Movera has not approved your fleet yet',
    blocked: true,
    size: size,
  ),
  _State.paused => MoveraRadarOrb(
    title: 'Account',
    status: 'PAUSED',
    subtitle: 'Tap for details',
    size: size,
  ),
  _State.starting => MoveraRadarOrb(
    title: 'Radar',
    status: 'STARTING',
    subtitle: 'Wait',
    active: true,
    loading: true,
    size: size,
  ),
  _State.offer => MoveraRadarOrb(
    title: 'Radar',
    status: 'MATCH',
    subtitle: 'New trip',
    active: true,
    offer: true,
    size: size,
  ),
  _State.exclusive => MoveraRadarOrb(
    title: 'Accept',
    status: 'MATCH',
    subtitle: 'Exclusive',
    active: true,
    exclusive: true,
    size: size,
  ),
  _State.reserve => MoveraRadarOrb(
    title: 'Accept',
    status: 'MATCH',
    subtitle: 'Reservation',
    active: true,
    reserve: true,
    size: size,
  ),
};

Future<void> _pump(
  WidgetTester tester,
  Widget orb, {
  Size surface = const Size(390, 844),
  bool reduceMotion = false,
}) async {
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: surface, disableAnimations: reduceMotion),
        child: Scaffold(body: Center(child: orb)),
      ),
    ),
  );
}

Color _dotColor(WidgetTester tester) {
  final box = tester.widget<Container>(find.byKey(RadarStatusDot.dotKey));
  return (box.decoration! as BoxDecoration).color!;
}

double _dotScale(WidgetTester tester) {
  final t = tester.widget<Transform>(
    find
        .ancestor(
          of: find.byKey(RadarStatusDot.dotKey),
          matching: find.byType(Transform),
        )
        .first,
  );
  return t.transform.getMaxScaleOnAxis();
}

void main() {
  const green = Color(0xFF2FBF5B);
  const red = Color(0xFFE5341C);
  final expected = {
    _State.on: green,
    _State.starting: green,
    _State.offer: green,
    _State.exclusive: green,
    _State.reserve: green,
    _State.off: red,
    _State.hold: red,
    _State.paused: red,
  };

  for (final e in expected.entries) {
    testWidgets(
      '${e.key.name}: one dot, ${e.value == green ? 'green' : 'red'}',
      (tester) async {
        await _pump(tester, _orb(e.key));
        expect(find.byKey(RadarStatusDot.dotKey), findsOneWidget);
        expect(_dotColor(tester), e.value);
        final label = e.value == green ? 'Online' : 'Offline';
        expect(
          find.bySemanticsLabel(RegExp('\\. $label')),
          findsWidgets,
          reason: 'the status is said, not only shown',
        );
      },
    );
  }

  for (final surface in const [Size(320, 568), Size(390, 844)]) {
    for (final st in [_State.on, _State.off, _State.hold]) {
      testWidgets(
        '${st.name} at ${surface.width.toInt()}x${surface.height.toInt()}: '
        'dot top-centre inside the disc, 7 px, clear of the text',
        (tester) async {
          await _pump(tester, _orb(st), surface: surface);
          final dot = tester.getRect(find.byKey(RadarStatusDot.dotKey));
          expect(dot.width, closeTo(7, 0.01));
          final orb = tester.getRect(find.byType(MoveraRadarOrb));
          final c = orb.center;
          const r = 73 / 2;
          // Top-centre of the disc (owner: P1 position, S2 size).
          expect(dot.center.dx, closeTo(c.dx, 0.01));
          expect(dot.center.dy, lessThan(c.dy));
          expect(dot.top - (c.dy - r), closeTo(6.5, 0.01));
          // Wholly inside the disc.
          expect((dot.center - c).distance + dot.width / 2, lessThan(r));
          for (final t in tester.widgetList<Text>(find.byType(Text))) {
            final rect = tester.getRect(find.byWidget(t));
            expect(
              rect.overlaps(dot),
              isFalse,
              reason: '"${t.data}" must not touch the dot',
            );
          }
        },
      );
    }
  }

  testWidgets('the dot scales with the orb', (tester) async {
    await _pump(tester, _orb(_State.on, size: 52));
    expect(
      tester.getRect(find.byKey(RadarStatusDot.dotKey)).width,
      closeTo(3.5, 0.01),
    );
  });

  testWidgets('green pulses to 1.06 over 2.2 s; red stands still', (
    tester,
  ) async {
    await _pump(tester, _orb(_State.on));
    expect(_dotScale(tester), closeTo(1, 0.001));
    await tester.pump(const Duration(milliseconds: 1100));
    expect(_dotScale(tester), closeTo(1.06, 0.001));
    await tester.pump(const Duration(milliseconds: 1100));
    expect(_dotScale(tester), closeTo(1, 0.001));

    await _pump(tester, _orb(_State.off));
    await tester.pump(const Duration(milliseconds: 1100));
    expect(_dotScale(tester), 1);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('reduce motion: no pulse', (tester) async {
    await _pump(tester, _orb(_State.on), reduceMotion: true);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(_dotScale(tester), 1);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('screenshot ON / OFF / HOLD', (tester) async {
    final out = Platform.environment['RADAR_DOT_SHOT'];
    if (out == null) return;
    const key = ValueKey<String>('shot');
    await _pump(
      tester,
      RepaintBoundary(
        key: key,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Transform.scale(
            scale: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final st in [_State.on, _State.off, _State.hold])
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: _orb(st, size: 208),
                  ),
              ],
            ),
          ),
        ),
      ),
      surface: const Size(760, 300),
    );
    await tester.pump(const Duration(milliseconds: 1100));
    final boundary =
        tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}

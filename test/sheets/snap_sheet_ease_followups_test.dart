import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/sheets/movera_snap_sheet_controller.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

/// Follow-ups 2026-11-26 (radar review): the ease leaves no no-bounce flag
/// behind; keepHeight carries the ease's speed in panel units; the radar
/// long press gives one haptic, not two.
class _Harness extends StatefulWidget {
  const _Harness();
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> with TickerProviderStateMixin {
  final panel = PanelController();
  late final snap = MoveraSnapSheetController(panel: panel, vsync: this);
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SlidingUpPanel(
      controller: panel,
      minHeight: 50,
      maxHeight: 300,
      panelSnapping: false,
      panel: const Text('Panel'),
    ),
  );
  @override
  void dispose() {
    snap.dispose();
    super.dispose();
  }
}

void main() {
  testWidgets('after the ease ends, no no-bounce flag stays', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _Harness()));
    final snap = tester.state<_HarnessState>(find.byType(_Harness)).snap;
    snap.rangePx = 250;
    final done = snap.easeTo(1);
    await tester.pump(const Duration(milliseconds: 100));
    expect(snap.noOvershootForTest, isTrue);
    await tester.pumpAndSettle();
    await done;
    expect(snap.noOvershootForTest, isFalse);
  });

  testWidgets('during the ease, the speed is in panel units', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _Harness()));
    final snap = tester.state<_HarnessState>(find.byType(_Harness)).snap;
    snap.rangePx = 250;
    final done = snap.easeTo(0.2);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final before = snap.position;
    final speed = snap.panelVelocity;
    final (value1, rate) = snap.rawForTest!;
    await tester.pump(const Duration(milliseconds: 16));
    final (value2, _) = snap.rawForTest!;
    // Panel units per controller unit, times the controller's speed.
    final measured = (snap.position - before) / (value2 - value1) * rate;
    expect(speed, closeTo(measured, measured.abs() * 0.1));
    // Before: the controller's own speed (0..1 over 550 ms) was taken.
    expect((speed - rate).abs(), greaterThan(0.3));
    await tester.pumpAndSettle();
    await done;
  });

  test('the radar long press plays one haptic (going offline has its own)', () {
    final source = File(
      'lib/presentation/driver/home/home_map_panels.dart',
    ).readAsStringSync();
    final longPress = source.substring(
      source.indexOf('Widget _radarLongPressOff('),
      source.indexOf('Widget _holdOffRadar()'),
    );
    expect(longPress, isNot(contains('HapticFeedback')));
  });
}

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/routing/route_instruction.dart';
import 'package:movera/presentation/driver/accept%20ride/navigation_instruction_banner.dart';

/// Mean x (0..1) of the lit pixels in the top part of the cue: where the
/// arrow points to.
Future<double> _tipX(NavigationBannerSymbol symbol) async {
  const size = 44;
  final recorder = ui.PictureRecorder();
  NavigationCuePainter(
    symbol: symbol,
    icon: Icons.navigation_rounded,
  ).paint(Canvas(recorder), const Size.square(44));
  final image = await recorder.endRecording().toImage(size, size);
  final bytes = (await image.toByteData())!;
  image.dispose();
  var sum = 0.0;
  var count = 0;
  for (var y = 0; y < size * .35; y++) {
    for (var x = 0; x < size; x++) {
      if (bytes.getUint8((y * size + x) * 4 + 3) > 128) {
        sum += x;
        count++;
      }
    }
  }
  expect(count, greaterThan(0), reason: '$symbol draws an arrow');
  return sum / count / size;
}

void main() {
  test('exit and merge keep their side', () {
    NavigationBannerSymbol symbol(RouteManeuverType type, String modifier) =>
        RouteInstructionCopy.symbolFor(type: type, modifier: modifier);
    for (final type in [RouteManeuverType.offRamp, RouteManeuverType.ramp]) {
      expect(symbol(type, 'slight left'), NavigationBannerSymbol.exitLeft);
      expect(symbol(type, 'left'), NavigationBannerSymbol.exitLeft);
      expect(symbol(type, 'slight right'), NavigationBannerSymbol.exitRight);
      expect(symbol(type, 'right'), NavigationBannerSymbol.exitRight);
      expect(symbol(type, ''), NavigationBannerSymbol.exit);
    }
    expect(
      symbol(RouteManeuverType.merge, 'slight left'),
      NavigationBannerSymbol.mergeLeft,
    );
    expect(
      symbol(RouteManeuverType.merge, 'slight right'),
      NavigationBannerSymbol.mergeRight,
    );
    expect(
      symbol(RouteManeuverType.merge, 'straight'),
      NavigationBannerSymbol.merge,
    );
    // Entering a highway has its own ramp arrow.
    expect(
      symbol(RouteManeuverType.onRamp, 'slight left'),
      NavigationBannerSymbol.onRampLeft,
    );
    expect(
      symbol(RouteManeuverType.onRamp, 'right'),
      NavigationBannerSymbol.onRampRight,
    );
  });

  testWidgets('left arrows point left, right arrows point right', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final exitLeft = await _tipX(NavigationBannerSymbol.exitLeft);
      final exitRight = await _tipX(NavigationBannerSymbol.exitRight);
      expect(exitLeft, lessThan(.45));
      expect(exitRight, greaterThan(.55));
      expect(exitLeft + exitRight, closeTo(1, .03), reason: 'Mirrored.');
      final mergeLeft = await _tipX(NavigationBannerSymbol.mergeLeft);
      final mergeRight = await _tipX(NavigationBannerSymbol.mergeRight);
      expect(mergeLeft, lessThan(.45));
      expect(mergeRight, greaterThan(.55));
      expect(mergeLeft + mergeRight, closeTo(1, .03), reason: 'Mirrored.');
      // Not a plain straight arrow: the tip sits off the center line.
      final straight = await _tipX(NavigationBannerSymbol.straight);
      expect((mergeLeft - straight).abs(), greaterThan(.08));
    });
  });
}

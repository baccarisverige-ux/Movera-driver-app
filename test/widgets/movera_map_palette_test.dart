import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/styles/movera_map_palette.dart';
import 'package:movera/styles/movera_map_style.dart';

String _painter(String path, String name) {
  final source = File(path).readAsStringSync();
  final start = source.indexOf('class $name extends CustomPainter');
  expect(start, isNonNegative, reason: '$name not found in $path');
  final end = source.indexOf('\nclass ', start + 1);
  return source.substring(start, end < 0 ? source.length : end);
}

void main() {
  test('the palette is the Home map style', () {
    for (final color in MoveraMapPalette.all) {
      expect(moveraMapStyle, contains(MoveraMapPalette.hex(color)));
    }
    expect(MoveraMapPalette.hex(MoveraMapPalette.land), '#FAFCFA');
    expect(MoveraMapPalette.hex(MoveraMapPalette.building), '#E1E4E5');
    expect(MoveraMapPalette.hex(MoveraMapPalette.park), '#C8F0CC');
    expect(MoveraMapPalette.hex(MoveraMapPalette.parkLabel), '#3D8549');
    expect(MoveraMapPalette.hex(MoveraMapPalette.water), '#ADE2FC');
    expect(MoveraMapPalette.hex(MoveraMapPalette.path), '#DBD3B2');
    expect(MoveraMapPalette.hex(MoveraMapPalette.road), '#C8CCD0');
    expect(MoveraMapPalette.hex(MoveraMapPalette.mainRoad), '#A1A6AB');
    expect(MoveraMapPalette.hex(MoveraMapPalette.highway), '#8A8F96');
    expect(MoveraMapPalette.hex(MoveraMapPalette.label), '#575C60');
    expect(MoveraMapPalette.hex(MoveraMapPalette.cityLabel), '#6F8B9D');
  });

  test('the palette is the cloud style linked to the web Map ID', () {
    // Same colours as the v3 cloud style (Google "variant/styles" format).
    final cloud = File('docs/movera_map_style_v3.json').readAsStringSync();
    for (final color in [...MoveraMapPalette.all, MoveraMapPalette.path]) {
      expect(cloud, contains(MoveraMapPalette.hex(color)));
    }
  });

  test('drawn maps use the Home palette, route line and pins', () {
    final preview = _painter(
      'lib/presentation/driver/scheduled rides/scheduled_rides.dart',
      '_RoutePreviewPainter',
    );
    final area = _painter(
      'lib/presentation/driver/notifications/driver_notifications_screen.dart',
      '_AreaMapPainter',
    );
    for (final painter in [preview, area]) {
      for (final use in [
        'MoveraMapPalette.land',
        'MoveraMapPalette.water',
        'MoveraMapPalette.park',
        'MoveraMapPalette.building',
        'MoveraMapPalette.footpath(',
        'MoveraMapPalette.mainStreet(',
        'MoveraMapPalette.street(',
        'MoveraMapPalette.drawHighway(',
      ]) {
        expect(painter, contains(use));
      }
    }
    // The route preview: no colours of its own, the app's route line and pins.
    expect(preview, isNot(contains('Color(0x')));
    expect(preview, contains('DriverRouteStyle.paintOn('));
    expect(preview, contains('RouteMarkKind.pickup'));
    expect(preview, contains('RouteMarkKind.dropoff'));
  });
}

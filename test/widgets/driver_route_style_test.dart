import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/widgets/driver_route_style.dart';

void main() {
  test('route line width follows the reference zoom steps', () {
    // Total (casing) / core: ~6 at overview, 8 at city, 12 at street,
    // 14 from zoom 17; the core is always 3 narrower (1.5 pt outline).
    final expected = <double, (int, int)>{
      3: (6, 3),
      10.9: (6, 3),
      11: (6, 3),
      11.9: (6, 3),
      12: (7, 4),
      13: (8, 5),
      13.9: (8, 5),
      14: (9, 6),
      15: (10, 7),
      15.5: (11, 8),
      16: (12, 9),
      16.5: (13, 10),
      17: (14, 11),
      21: (14, 11),
    };
    expected.forEach((zoom, widths) {
      final lines = DriverRouteStyle.polylines(
        id: 'r',
        points: const [LatLng(0, 0), LatLng(1, 1)],
        zoom: zoom,
      );
      final casing = lines.firstWhere((l) => l.polylineId.value == 'r-casing');
      final core = lines.firstWhere((l) => l.polylineId.value == 'r');
      expect((casing.width, core.width), widths, reason: 'zoom $zoom');
      expect(casing.color, DriverRouteStyle.casingColor);
      expect(core.color, DriverRouteStyle.gradientColors.first);
      expect(core.zIndex, greaterThan(casing.zIndex));
      // Every core piece has the core width; sized() restyles stored lines
      // exactly like a fresh build.
      final pieces = lines.where(DriverRouteStyle.isCorePiece).toList();
      expect(pieces, hasLength(DriverRouteStyle.gradientSteps));
      for (final piece in pieces) {
        expect(piece.width, widths.$2, reason: 'zoom $zoom');
      }
      final resized = DriverRouteStyle.sized(
        DriverRouteStyle.polylines(id: 'r', points: casing.points),
        zoom,
      );
      expect(
        {for (final l in resized) l.polylineId.value: l.width},
        {for (final l in lines) l.polylineId.value: l.width},
      );
    });
    expect(DriverRouteStyle.stepZoom(10.2), 10);
    expect(DriverRouteStyle.stepZoom(11.5), 11);
    expect(DriverRouteStyle.stepZoom(12.4), 12);
    expect(DriverRouteStyle.stepZoom(13), 13);
    expect(DriverRouteStyle.stepZoom(15.7), 15.5);
    expect(DriverRouteStyle.stepZoom(16.8), 16.5);
    expect(DriverRouteStyle.stepZoom(18), 17);
    expect(DriverRouteStyle.widthAt(DriverRouteStyle.defaultZoom), 9);
  });

  test('route width never jumps more than one pixel between steps', () {
    var previous = DriverRouteStyle.widthAt(3);
    for (var zoom = 3.0; zoom <= 21; zoom += 0.05) {
      final width = DriverRouteStyle.widthAt(zoom);
      expect(width - previous, inInclusiveRange(0, 1), reason: 'zoom $zoom');
      previous = width;
    }
  });

  test('route line is the Movera gradient, pickup green to destination blue, '
      'under a white casing', () {
    expect(DriverRouteStyle.pickupColor, const Color(0xFF079A60));
    expect(DriverRouteStyle.destinationColor, const Color(0xFF1769E8));
    expect(DriverRouteStyle.casingColor, const Color(0xFFFFFFFF));
    final lines = DriverRouteStyle.polylines(
      id: 'r',
      points: const [
        LatLng(59.30, 18.0),
        LatLng(59.35, 18.0),
        LatLng(59.40, 18.0),
      ],
    );
    final pieces = lines.where(DriverRouteStyle.isCorePiece).toList()
      ..sort(
        (a, b) => a.points.first.latitude.compareTo(b.points.first.latitude),
      );
    expect(pieces.first.points.first, const LatLng(59.30, 18.0));
    expect(pieces.last.points.last, const LatLng(59.40, 18.0));
    expect(pieces.first.color, DriverRouteStyle.at(0.5 / 12));
    expect(pieces.last.color, DriverRouteStyle.at(11.5 / 12));
    // Pieces join end to start, so the line has no gaps.
    for (var i = 1; i < pieces.length; i++) {
      expect(pieces[i].points.first, pieces[i - 1].points.last);
    }
    // The first piece keeps the route's id for lookups.
    expect(pieces.first.polylineId.value, 'r');
    expect(pieces[1].polylineId.value, 'r-g1');
  });

  test('a route of one point or no length is one piece', () {
    final one = DriverRouteStyle.gradientPieces(
      id: 'r',
      points: const [LatLng(1, 1)],
      width: 4,
    );
    expect(one, hasLength(1));
    final flat = DriverRouteStyle.gradientPieces(
      id: 'r',
      points: const [LatLng(1, 1), LatLng(1, 1)],
      width: 4,
    );
    expect(flat.single.color, DriverRouteStyle.color);
  });
}

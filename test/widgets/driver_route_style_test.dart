import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/widgets/driver_route_style.dart';

void main() {
  test('route line width follows the reference zoom steps', () {
    // ~4 at overview, 6 at city, 10 at street, 12 from zoom 17.
    final expected = <double, int>{
      3: 4,
      10.9: 4,
      11: 4,
      11.9: 4,
      12: 5,
      13: 6,
      13.9: 6,
      14: 7,
      15: 8,
      15.5: 9,
      16: 10,
      16.5: 11,
      17: 12,
      21: 12,
    };
    expected.forEach((zoom, width) {
      final lines = DriverRouteStyle.polylines(
        id: 'r',
        points: const [LatLng(0, 0), LatLng(1, 1)],
        zoom: zoom,
      );
      final first = lines.firstWhere((l) => l.polylineId.value == 'r');
      expect(first.width, width, reason: 'zoom $zoom');
      expect(first.color, DriverRouteStyle.gradientColors.first);
      // Every piece has the width; sized() restyles stored lines exactly
      // like a fresh build.
      final pieces = lines.where(DriverRouteStyle.isPiece).toList();
      expect(pieces, hasLength(DriverRouteStyle.gradientSteps));
      expect(lines, hasLength(DriverRouteStyle.gradientSteps));
      for (final piece in pieces) {
        expect(piece.width, width, reason: 'zoom $zoom');
      }
      final resized = DriverRouteStyle.sized(
        DriverRouteStyle.polylines(id: 'r', points: first.points),
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
    expect(DriverRouteStyle.widthAt(DriverRouteStyle.defaultZoom), 7);
  });

  test('route width never jumps more than one pixel between steps', () {
    var previous = DriverRouteStyle.widthAt(3);
    for (var zoom = 3.0; zoom <= 21; zoom += 0.05) {
      final width = DriverRouteStyle.widthAt(zoom);
      expect(width - previous, inInclusiveRange(0, 1), reason: 'zoom $zoom');
      previous = width;
    }
  });

  test('route line is the Movera gradient in its dark shades, pickup green to '
      'destination blue, with no outline and nothing white', () {
    expect(DriverRouteStyle.pickupColor, const Color(0xFF05663F));
    expect(DriverRouteStyle.destinationColor, const Color(0xFF0F4599));
    expect(DriverRouteStyle.pickupLight, const Color(0xFF079A60));
    expect(DriverRouteStyle.destinationLight, const Color(0xFF1769E8));
    // Same hues, darker: every channel of the line is below the bright
    // shade's, in the same proportions.
    for (final (dark, light) in [
      (DriverRouteStyle.pickupColor, DriverRouteStyle.pickupLight),
      (DriverRouteStyle.destinationColor, DriverRouteStyle.destinationLight),
    ]) {
      expect(dark.r, lessThan(light.r));
      expect(dark.g, lessThan(light.g));
      expect(dark.b, lessThan(light.b));
      expect(dark.g / light.g, closeTo(dark.b / light.b, 0.03));
    }
    final lines = DriverRouteStyle.polylines(
      id: 'r',
      points: const [
        LatLng(59.30, 18.0),
        LatLng(59.35, 18.0),
        LatLng(59.40, 18.0),
      ],
    );
    for (final line in lines) {
      expect(line.color, isNot(const Color(0xFFFFFFFF)));
      expect(line.polylineId.value, isNot(endsWith('-casing')));
    }
    final pieces = lines.where(DriverRouteStyle.isPiece).toList()
      ..sort(
        (a, b) => a.points.first.latitude.compareTo(b.points.first.latitude),
      );
    expect(pieces, hasLength(lines.length));
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
    expect(DriverRouteStyle.color, DriverRouteStyle.at(0.5));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/presentation/driver/accept%20ride/trip_route_lines.dart';
import 'package:movera/widgets/driver_route_style.dart';

// v0.18.171 (plan section 4.3): a GET /routes/driving answer with
// source "estimate" is drawn dashed in Movera grey (#12201C at 50 %),
// no blue and no new text. A Google ("google"/"stored") line keeps the
// solid Movera green-to-dark line.

const _points = [
  GeoPoint(59.33, 18.06),
  GeoPoint(59.32, 18.065),
  GeoPoint(59.31, 18.07),
];

bool _blue(Color c) => c.b > c.r + 0.15 && c.b > c.g + 0.15;

void main() {
  test('estimate: one dashed Movera-grey line', () {
    final lines = TripRouteLines()..sync(_points, 0, 14, approximate: true);
    expect(lines.value, hasLength(1));
    final line = lines.value.single;
    expect(line.patterns, isNotEmpty);
    expect(line.color, DriverRouteStyle.approximateColor);
    expect(DriverRouteStyle.approximateColor, const Color(0x8012201C));
    expect(_blue(line.color), isFalse);
  });

  test('google: the solid gradient line, no dashes', () {
    final lines = TripRouteLines()..sync(_points, 0, 14);
    expect(lines.value.length, DriverRouteStyle.gradientSteps);
    for (final line in lines.value) {
      expect(line.patterns, isEmpty);
      expect(_blue(line.color), isFalse);
    }
  });

  test('the same points switching to estimate redraw the line', () {
    final lines = TripRouteLines()..sync(_points, 0, 14);
    lines.sync(_points, 0, 14, approximate: true);
    expect(lines.value.single.patterns, isNotEmpty);
  });

  test('driven part stays drawn on an estimate line', () {
    final lines = TripRouteLines()..sync(_points, 300, 14, approximate: true);
    expect(lines.value, hasLength(2));
    expect(
      lines.value.where((l) => l.polylineId.value == 'traveled-road-route'),
      hasLength(1),
    );
  });
}

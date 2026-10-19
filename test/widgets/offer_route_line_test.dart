import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/widgets/offer_route_line.dart';

// R14-2: the offer line's black-and-white cycle.
void main() {
  OfferLinePhase at(int ms) =>
      OfferRouteLine.phaseAt(Duration(milliseconds: ms));

  test('the core turns white, fills back black pickup → drop-off, rests', () {
    expect(at(0), const OfferLinePhase(light: 0, front: 0));
    expect(at(0).dark, isTrue);
    expect(at(125).light, closeTo(0.5, 1e-9));
    expect(at(300), const OfferLinePhase(light: 1, front: 0));
    // Half-way through the 2 s fill (ease-in-out: exactly half).
    expect(at(1350).front, closeTo(0.5, 1e-9));
    expect(at(1350).light, 1);
    expect(at(2350).dark, isTrue);
    expect(at(3000).dark, isTrue);
    // Repeats every 3.6 s.
    expect(at(3600 + 1350), at(1350));
  });

  test('white only ahead of the front, with a soft edge', () {
    const route = [GeoPoint(59.30, 18.00), GeoPoint(59.40, 18.00)];
    final lines = OfferRouteLine.light(route, at(1350));
    final solid = lines.firstWhere(
      (l) => l.polylineId.value == OfferRouteLine.lightId,
    );
    expect(solid.color, const Color(0xFFFFFFFF));
    // The front is half-way; the solid white starts after the soft edge.
    expect(solid.points.first.latitude, closeTo(59.36, 1e-6));
    expect(solid.points.last, const LatLng(59.40, 18.00));
    final soft = lines.where((l) => l != solid).toList()
      ..sort((a, b) => a.color.a.compareTo(b.color.a));
    expect(soft, hasLength(OfferRouteLine.softSteps));
    expect(soft.first.points.first.latitude, closeTo(59.35, 1e-6));
    expect(soft.first.color.a, lessThan(soft.last.color.a));
    expect(OfferRouteLine.light(route, at(3000)), isEmpty);
  });

  test('a black outline around a black core, 15 / 8 px at offer zoom', () {
    final lines = OfferRouteLine.polylines(
      const [LatLng(59.3, 18.0), LatLng(59.4, 18.0)],
    );
    final outline = lines.firstWhere(
      (l) => l.polylineId.value == OfferRouteLine.outlineId,
    );
    final core = lines.firstWhere(
      (l) => l.polylineId.value == OfferRouteLine.coreId,
    );
    expect(outline.color, const Color(0xFF000000));
    expect(outline.width, 15);
    expect(core.color, const Color(0xFF141414));
    expect(core.width, 8);
    expect(
      OfferRouteLine.sized(lines, 16).map((l) => l.width).toSet(),
      {17, 9},
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/widgets/driver_route_style.dart';
import 'package:movera/widgets/offer_route_line.dart';

// R14-2 / owner round 4: the offer line's motion is a bright band in the
// route's own colours flowing pickup → drop-off; nothing white.
void main() {
  OfferLinePhase at(int ms) =>
      OfferRouteLine.phaseAt(Duration(milliseconds: ms));

  test('the band runs pickup → drop-off over 2 s, then the line rests', () {
    expect(at(0).resting, isFalse);
    expect(at(0).front, -OfferRouteLine.band / 2, reason: 'enters from before');
    // Half-way through the 2 s run (ease-in-out: exactly half).
    expect(at(1000).front, closeTo(0.5, 1e-9));
    expect(at(1999).front, closeTo(1 + OfferRouteLine.band / 2, 0.01));
    expect(at(2000).resting, isTrue);
    expect(at(2500).resting, isTrue);
    // Repeats every 2.6 s.
    expect(at(2600 + 1000), at(1000));
    expect(OfferRouteLine.cycle.inMilliseconds, 2600);
  });

  test('the band is the bright shade of the line colour, fading to the dark '
      'line at both ends; nothing white', () {
    const route = [GeoPoint(59.30, 18.00), GeoPoint(59.40, 18.00)];
    final lines = OfferRouteLine.flow(route, at(1000)).toList()
      ..sort(
        (a, b) => a.points.first.latitude.compareTo(b.points.first.latitude),
      );
    expect(lines, hasLength(OfferRouteLine.bandSteps));
    // Centred on the middle of the route, 26 % long.
    expect(lines.first.points.first.latitude, closeTo(59.337, 1e-3));
    expect(lines.last.points.last.latitude, closeTo(59.363, 1e-3));
    expect(lines.map(OfferRouteLine.isBand), everyElement(isTrue));
    final middle = lines[OfferRouteLine.bandSteps ~/ 2];
    final end = lines.first;
    // The middle is near the bright shade, the ends near the dark line.
    expect(
      (middle.color.g - DriverRouteStyle.lightAt(0.5).g).abs(),
      lessThan(0.03),
    );
    expect(end.color.g, lessThan(middle.color.g));
    expect((end.color.g - DriverRouteStyle.at(0.37).g).abs(), lessThan(0.08));
    for (final line in lines) {
      expect(line.color, isNot(const Color(0xFFFFFFFF)));
      expect(line.color.a, 1.0);
      expect(line.zIndex, greaterThan(2));
    }
    // At rest there is no band; entering, only the part on the route.
    expect(OfferRouteLine.flow(route, at(2300)), isEmpty);
    expect(OfferRouteLine.flow(route, at(0)), isEmpty, reason: 'not in yet');
    final entering = OfferRouteLine.flow(route, at(600));
    expect(entering.length, inInclusiveRange(1, OfferRouteLine.bandSteps - 1));
    for (final line in entering) {
      expect(line.points.first.latitude, greaterThanOrEqualTo(59.30));
    }
  });

  test('the line itself is the dark gradient, no outline, 5 / 7 px', () {
    final lines = OfferRouteLine.polylines(const [
      LatLng(59.3, 18.0),
      LatLng(59.4, 18.0),
    ]);
    expect(lines, hasLength(DriverRouteStyle.gradientSteps));
    expect(lines.map(OfferRouteLine.isCore), everyElement(isTrue));
    final core = lines.firstWhere(
      (l) => l.polylineId.value == OfferRouteLine.coreId,
    );
    expect(core.color, DriverRouteStyle.gradientColors.first);
    expect(core.width, 5);
    for (final line in lines) {
      expect(line.color, isNot(const Color(0xFFFFFFFF)));
    }
    // R15-8: 5 on every offer zoom, 7 only close up; the band follows.
    const route = [GeoPoint(59.30, 18.00), GeoPoint(59.40, 18.00)];
    for (final (zoom, width) in [(10.0, 5), (12.0, 5), (14.0, 5), (16.0, 7)]) {
      final sized = OfferRouteLine.sized({
        ...lines,
        ...OfferRouteLine.flow(route, at(1000)),
      }, zoom);
      for (final line in sized) {
        expect(line.width, width, reason: 'zoom $zoom ${line.polylineId}');
      }
      expect(
        OfferRouteLine.flow(route, at(1000), zoom: zoom).first.width,
        width,
      );
    }
  });
}

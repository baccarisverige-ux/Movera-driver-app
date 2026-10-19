import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/widgets/driver_route_style.dart';

void main() {
  test('route line width follows the Uber zoom steps', () {
    // zoom <= 11 -> 9/6, 12-15 -> 10.5/7.5 (rounded to 11/8), >= 16 -> 12/9.
    final expected = <double, (int, int)>{
      3: (9, 6), 11: (9, 6), 11.9: (9, 6),
      12: (11, 8), 14: (11, 8), 15.9: (11, 8),
      16: (12, 9), 19: (12, 9),
    };
    expected.forEach((zoom, widths) {
      final lines = DriverRouteStyle.polylines(
        id: 'r', points: const [LatLng(0, 0), LatLng(1, 1)], zoom: zoom,
      );
      final casing = lines.firstWhere((l) => l.polylineId.value == 'r-casing');
      final core = lines.firstWhere((l) => l.polylineId.value == 'r');
      expect((casing.width, core.width), widths, reason: 'zoom $zoom');
      expect(casing.color, DriverRouteStyle.casingColor);
      expect(core.zIndex, greaterThan(casing.zIndex));
      // sized() restyles stored lines exactly like a fresh build.
      final resized = DriverRouteStyle.sized(
        DriverRouteStyle.polylines(id: 'r', points: casing.points), zoom,
      );
      expect({for (final l in resized) l.polylineId.value: l.width},
          {'r-casing': widths.$1, 'r': widths.$2});
    });
    expect(DriverRouteStyle.stepZoom(10.2), 10);
    expect(DriverRouteStyle.stepZoom(11.5), 11);
    expect(DriverRouteStyle.stepZoom(12.4), 12);
    expect(DriverRouteStyle.stepZoom(13), 14);
    expect(DriverRouteStyle.stepZoom(17), 16);
    expect(DriverRouteStyle.widthAt(DriverRouteStyle.defaultZoom), 11);
  });
}

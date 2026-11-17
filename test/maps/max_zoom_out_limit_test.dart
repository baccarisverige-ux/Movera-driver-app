import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/navigation/map_zoom_limit.dart';
import 'package:movera/core/navigation/route_camera_fit.dart';
import 'package:movera/widgets/custom_google_map.dart';

import '../../integration_test/headless_map_platform.dart';

/// Owner 2026-11-17 ("Make Max zoom out like that not all planet"; both
/// apps, fixed): no map zooms out wider than Scandinavia + Baltic on a
/// phone (zoom 4.5). A zoom level, not a region lock.
void main() {
  test('the limit is zoom 4.5, never the planet', () {
    expect(kMapMinZoom, 4.5);
  });

  testWidgets('the map is built with the zoom-out limit, panning free', (
    tester,
  ) async {
    final maps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CustomGoogleMap())),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    expect(map.minMaxZoomPreference.minZoom, kMapMinZoom);
    expect(map.minMaxZoomPreference.maxZoom, isNull);
    expect(map.cameraTargetBounds, CameraTargetBounds.unbounded);
  });

  test('a camera fit to two far-apart points clamps to the limit', () {
    const free = Rect.fromLTWH(0, 0, 390, 600);
    for (final far in const [
      GeoPoint(-33.92, 18.42), // Cape Town
      GeoPoint(-33.87, 151.2), // Sydney
    ]) {
      final fit = fitRouteCamera(
        points: [
          const RouteFitPoint(GeoPoint(59.33, 18.07)), // Stockholm
          RouteFitPoint(far),
        ],
        free: free,
        targetAt: free.center,
      )!;
      expect(fit.zoom, closeTo(kMapMinZoom, 1e-6));
    }
  });
}

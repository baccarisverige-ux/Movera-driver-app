import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/navigation/driver_camera_controller.dart';
import 'package:movera/core/navigation/route_camera_fit.dart';

// R13-7: an Exclusive or reservation route is always shown whole, chips
// included, between the island and the sheet with its orb.

const _screen = Size(375, 812);
const _safeTop = 47.0;

/// The free map as Home works it out: under the island (68) and above the
/// measured sheet, whose height includes the orb's upper half over it.
Rect _free() {
  const sheetWithOrb = 812 * 0.4 + 104 / 2;
  return const Rect.fromLTRB(
    16,
    _safeTop + 68 + 12,
    375 - 16,
    812 - (sheetWithOrb + 18) - 6,
  );
}

/// Pickup chip on the left, drop-off chip on the right; road between.
List<RouteFitPoint> _route(List<GeoPoint> road) => [
  RouteFitPoint(road.first, left: 82, right: 17, up: 19, down: 19),
  RouteFitPoint(road.last, left: 17, right: 88, up: 19, down: 19),
  for (final p in road) RouteFitPoint(p, left: 6, right: 6, up: 6, down: 6),
];

List<GeoPoint> _road(GeoPoint from, GeoPoint to, {double bend = 0.01}) => [
  for (var i = 0; i <= 20; i++)
    GeoPoint(
      from.latitude + (to.latitude - from.latitude) * i / 20,
      from.longitude +
          (to.longitude - from.longitude) * i / 20 +
          // A road bends away from the straight line.
          bend * (1 - ((i - 10) / 10) * ((i - 10) / 10)),
    ),
];

void expectInside(
  RouteCameraFit fit,
  Offset targetAt,
  List<RouteFitPoint> points,
) {
  final free = _free();
  for (final p in points) {
    final at = routeFitProject(fit, targetAt, p.point);
    expect(at.dx - p.left, greaterThanOrEqualTo(free.left - 0.5));
    expect(at.dx + p.right, lessThanOrEqualTo(free.right + 0.5));
    expect(at.dy - p.up, greaterThanOrEqualTo(free.top - 0.5));
    expect(at.dy + p.down, lessThanOrEqualTo(free.bottom + 0.5));
  }
}

class _FramingPort implements DriverCameraPort, DriverCameraFraming {
  final frames = <double>[];
  @override
  Future<void> frame(GeoPoint target, double zoom) async => frames.add(zoom);
  @override
  Future<void> animate(DriverCameraPose pose) async {}
  @override
  Future<void> overview(List<GeoPoint> points, double padding) async {}
  @override
  void retarget(DriverCameraPose pose) {}
  @override
  void interrupt() {}
  @override
  void dispose() {}
}

void main() {
  // Web: the camera target is the middle of the whole view.
  final webTarget = _screen.center(Offset.zero);

  test('a short and a long route both fit whole above the sheet and orb; '
      'the long one zooms out', () {
    final short = _route(
      _road(
        const GeoPoint(59.3343, 18.0615), // Kungsgatan
        const GeoPoint(59.3157, 18.0335), // Hornstull
        bend: 0.002,
      ),
    );
    final arlanda = _route(
      _road(
        const GeoPoint(59.3326, 18.0291), // Fridhemsplan
        const GeoPoint(59.6497, 17.9237), // Arlanda T5
        bend: 0.04,
      ),
    );
    final shortFit = fitRouteCamera(
      points: short,
      free: _free(),
      targetAt: webTarget,
    )!;
    final longFit = fitRouteCamera(
      points: arlanda,
      free: _free(),
      targetAt: webTarget,
    )!;
    expectInside(shortFit, webTarget, short);
    expectInside(longFit, webTarget, arlanda);
    expect(longFit.zoom, lessThan(shortFit.zoom - 1));

    // It fills the free area well: not a small route in the middle.
    for (final (fit, points) in [(shortFit, short), (longFit, arlanda)]) {
      var left = double.infinity, right = -double.infinity;
      var top = double.infinity, bottom = -double.infinity;
      for (final p in points) {
        final at = routeFitProject(fit, webTarget, p.point);
        if (at.dx - p.left < left) left = at.dx - p.left;
        if (at.dx + p.right > right) right = at.dx + p.right;
        if (at.dy - p.up < top) top = at.dy - p.up;
        if (at.dy + p.down > bottom) bottom = at.dy + p.down;
      }
      expect(
        (right - left) / _free().width > 0.98 ||
            (bottom - top) / _free().height > 0.98,
        isTrue,
      );
    }

    // A map that keeps its target in its padded middle (Android, iOS)
    // still gets the whole route above the sheet.
    final padded = Offset(36 + (375 - 36 - 72) / 2, 300);
    final nativeFit = fitRouteCamera(
      points: arlanda,
      free: _free(),
      targetAt: padded,
    )!;
    expectInside(nativeFit, padded, arlanda);
  });

  test('a new offer takes the map even after the driver moved it; '
      'its later fits leave a moved map alone', () async {
    final camera = DriverCameraController();
    final port = _FramingPort();
    camera.attach(port);
    camera.userGesture();
    const fit = RouteCameraFit(GeoPoint(59.33, 18.05), 13.2);
    await camera.previewFit(fit, points: const [], takeOver: true);
    expect(port.frames, [13.2]);
    expect(camera.mode, DriverCameraMode.overview);
    camera.userGesture();
    await camera.previewFit(fit, points: const []);
    expect(port.frames, [13.2]);
    camera.dispose();
  });

  test('the line highlight is a short piece that runs pickup → drop-off', () {
    final road = _road(
      const GeoPoint(59.30, 18.00),
      const GeoPoint(59.40, 18.00),
      bend: 0,
    );
    final start = routeSlice(road, -0.18, 0.05);
    final end = routeSlice(road, 0.82, 1.0);
    expect(start.first.latitude, closeTo(59.30, 1e-6));
    expect(start.last.latitude, closeTo(59.305, 1e-4));
    expect(end.first.latitude, closeTo(59.382, 1e-4));
    expect(end.last.latitude, closeTo(59.40, 1e-6));
  });
}

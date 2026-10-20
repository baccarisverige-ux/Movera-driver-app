import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/navigation/driver_camera_controller.dart';
import 'package:movera/core/routing/route_repository.dart';

GeoPoint _east(GeoPoint p, double m) =>
    GeoPoint(p.latitude, p.longitude + m / (111320 * 0.5094));

class _Port implements DriverCameraPort {
  _Port(this.takes);
  final Duration takes;
  int animates = 0, retargets = 0;
  @override
  Future<void> animate(DriverCameraPose pose) async {
    animates++;
    await Future<void>.delayed(takes);
  }

  @override
  void retarget(DriverCameraPose pose) => retargets++;
  @override
  Future<void> overview(List<GeoPoint> points, double padding) async {}
  @override
  void interrupt() {}
  @override
  void dispose() {}
}

// D-14: one GPS fix is one camera command. When an animation outlasts the
// GPS interval, the newer pose steers it (retarget) and is not animated a
// second time after it ends.
void main() {
  const origin = GeoPoint(59.3293, 18.0686);
  for (final takes in const [
    Duration(milliseconds: 450),
    Duration(milliseconds: 1400),
  ]) {
    testWidgets('one command per fix with ${takes.inMilliseconds} ms animations',
        (tester) async {
        final camera = DriverCameraController(
            now: () => tester.binding.clock.now());
        final port = _Port(takes);
        camera.attach(port);
        final route = RoadRoute(
          points: [for (var i = 0; i <= 100; i++) _east(origin, i * 100.0)],
          distanceMeters: 10000,
          durationSeconds: 900,
        );
        await tester.pump();
        port
          ..animates = 0
          ..retargets = 0;
        const fixes = 300;
        for (var i = 0; i < fixes; i++) {
          camera.update(
            location: DriverLocation(
              point: _east(origin, i * 14.0),
              headingDegrees: 90,
              speedMetersPerSecond: 14,
              measuredAt: tester.binding.clock.now(),
              accuracyMeters: 5,
            ),
            route: route,
            navigating: true,
          );
          await tester.pump(const Duration(seconds: 1));
        }
        // Before: 1400 ms took 0.71 animates + 0.99 retargets a fix.
        expect(port.animates + port.retargets, lessThanOrEqualTo(fixes + 1));
        expect(port.animates, greaterThan(0));
        camera.dispose();
        await tester.pump(const Duration(seconds: 2));
    });
  }
}

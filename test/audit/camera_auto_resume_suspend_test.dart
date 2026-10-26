import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/navigation/driver_camera_controller.dart';

// driver-20: the trip camera's return to the car must survive the app
// being paused (notification shade, another app) while the timer runs.

class _Port implements DriverCameraPort {
  final commands = <DriverCameraPose>[];
  @override
  Future<void> animate(DriverCameraPose pose) async => commands.add(pose);
  @override
  void retarget(DriverCameraPose pose) {}
  @override
  Future<void> overview(List<GeoPoint> points, double padding) async {}
  @override
  void interrupt() {}
  @override
  void dispose() {}
}

final _now = DateTime.utc(2026, 10, 18, 9);

DriverLocation _fix(double lat) => DriverLocation(
  point: GeoPoint(lat, 18),
  speedMetersPerSecond: 10,
  headingDegrees: 0,
  measuredAt: _now,
  accuracyMeters: 5,
);

void main() {
  testWidgets('driver-r4-39: a finger held on the map stops follow frames', (
    tester,
  ) async {
    final camera = DriverCameraController(now: () => _now);
    addTearDown(camera.dispose);
    final port = _Port();
    camera.attach(port);
    camera.update(location: _fix(59), navigating: true);
    await tester.pump(const Duration(milliseconds: 50));
    final before = port.commands.length;
    camera.touching = true; // pressed, not yet a gesture
    camera.update(location: _fix(59.001), navigating: true);
    await tester.pump(const Duration(seconds: 1));
    expect(port.commands, hasLength(before), reason: 'no move under a finger');
    camera.touching = false;
    await tester.pump(const Duration(milliseconds: 50));
    expect(port.commands, hasLength(before + 1));
    expect(port.commands.last.target.latitude, greaterThan(59.0005));
  });

  testWidgets('driver-20: an auto-resume that came due while suspended '
      'still brings the camera back after resume', (tester) async {
    var resumes = 0;
    final camera = DriverCameraController(now: () => _now)
      ..autoResumeAfter = DriverCameraController.tripAutoResume;
    camera.onAutoResume = () {
      resumes++;
      camera.recenter();
      return true;
    };
    addTearDown(camera.dispose);
    camera.attach(_Port());
    camera.update(location: _fix(59), navigating: true);
    await tester.pump(const Duration(milliseconds: 50));

    camera.touching = true;
    camera.userGesture();
    camera.touching = false;
    await tester.pump(const Duration(seconds: 5));
    camera.suspend();
    await tester.pump(const Duration(seconds: 20)); // timer fires, paused
    camera.resume();
    for (var i = 1; i <= 15; i++) {
      camera.update(location: _fix(59 + i * .0001), navigating: true);
      await tester.pump(const Duration(seconds: 1));
    }
    expect(resumes, 1, reason: 'the camera must still return to the car');
    expect(camera.mode, DriverCameraMode.following);
  });

  testWidgets('driver-20: a pause shorter than the wait keeps the original '
      'timer', (tester) async {
    var resumes = 0;
    final camera = DriverCameraController(now: () => _now)
      ..autoResumeAfter = DriverCameraController.tripAutoResume
      ..onAutoResume = () {
        resumes++;
        return true;
      };
    addTearDown(camera.dispose);
    camera.attach(_Port());
    camera.update(location: _fix(59), navigating: true);
    await tester.pump(const Duration(milliseconds: 50));
    camera.userGesture();
    await tester.pump(const Duration(seconds: 2));
    camera.suspend();
    await tester.pump(const Duration(seconds: 2));
    camera.resume();
    await tester.pump(const Duration(seconds: 9));
    expect(resumes, 1, reason: '12 s after the pan, not 12 s after resume');
  });
}

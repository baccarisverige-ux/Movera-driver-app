import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/navigation/driver_camera_controller.dart';
import 'package:movera/core/navigation/trip_camera_sheet_inset.dart';

// D8: one camera owner for the trip. Steady zoom, short-way turns, no
// move under the driver's finger, and back to the car on its own.

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

DriverLocation _fix(double lat, {double speed = 10, double heading = 0}) =>
    DriverLocation(
      point: GeoPoint(lat, 18),
      speedMetersPerSecond: speed,
      headingDegrees: heading,
      measuredAt: _now,
      accuracyMeters: 5,
    );

void main() {
  test('a turn through north takes the short way (355° → 5°)', () {
    final policy = DriverCameraPolicy();
    policy.resolve(
      location: _fix(59, heading: 355),
      navigating: true,
      immediate: true,
    );
    final pose = policy.resolve(
      location: _fix(59.0001, heading: 5),
      navigating: true,
    );
    // Short way: just past north, never swinging through south.
    expect(
      pose.bearing < 10 || pose.bearing > 350,
      isTrue,
      reason: 'bearing ${pose.bearing}',
    );
  });

  test('zoom follows speed but does not breathe with GPS speed noise', () {
    final policy = DriverCameraPolicy();
    final zooms = <double>[];
    for (var i = 0; i < 20; i++) {
      zooms.add(
        policy
            .resolve(
              location: _fix(59 + i * .0001, speed: i.isEven ? 8 : 12),
              navigating: true,
              immediate: i == 0,
            )
            .zoom,
      );
    }
    final settled = zooms.skip(5);
    final swing =
        settled.reduce((a, b) => a > b ? a : b) -
        settled.reduce((a, b) => a < b ? a : b);
    expect(swing, lessThan(0.1), reason: 'city stop-and-go must not pump');

    final highway = DriverCameraPolicy();
    var zoom = 0.0;
    for (var i = 0; i < 30; i++) {
      zoom = highway
          .resolve(location: _fix(59 + i * .001, speed: 30), navigating: true)
          .zoom;
    }
    expect(
      zoom,
      lessThan(settled.first - .75),
      reason: 'fast roads show more road ahead',
    );
  });

  testWidgets('no camera move while the driver holds or moves the map; '
      'the trip camera comes back on its own afterwards', (tester) async {
    final camera = DriverCameraController(now: () => _now)
      ..autoResumeAfter = DriverCameraController.tripAutoResume;
    final port = _Port();
    addTearDown(camera.dispose);
    camera.attach(port);
    camera.update(location: _fix(59), navigating: true);
    await tester.pump(const Duration(milliseconds: 50));
    final before = port.commands.length;

    camera.touching = true;
    camera.userGesture();
    for (var i = 1; i <= 30; i++) {
      camera.update(location: _fix(59 + i * .0001), navigating: true);
      await tester.pump(const Duration(seconds: 1));
    }
    expect(port.commands.length, before, reason: 'finger on the map');
    expect(camera.mode, DriverCameraMode.browsing);

    camera.touching = false;
    await tester.pump(const Duration(seconds: 6));
    camera.mapActivity(); // inertia / a late pan restarts the wait
    await tester.pump(const Duration(seconds: 11));
    expect(port.commands.length, before);
    await tester.pump(const Duration(seconds: 2));
    expect(camera.mode, DriverCameraMode.following);
    expect(port.commands.length, greaterThan(before));
  });

  test('the same fix reported twice moves the camera once', () {
    final camera = DriverCameraController(now: () => _now);
    final port = _Port();
    camera.attach(port);
    final fix = _fix(59);
    camera.update(location: fix, navigating: true);
    camera.update(location: fix, navigating: true);
    expect(port.commands, hasLength(1));
    camera.dispose();
  });

  testWidgets('the camera follows the sheet only once it rests', (
    tester,
  ) async {
    final inset = TripCameraSheetInset();
    addTearDown(inset.dispose);
    expect(inset.resolve(111), 111);
    inset.sheetMoved(180, maxInset: 400);
    inset.sheetMoved(260, maxInset: 400);
    await tester.pump(const Duration(milliseconds: 100));
    expect(inset.value, isNull, reason: 'still moving');
    await tester.pump(const Duration(milliseconds: 200));
    expect(inset.resolve(111), 260);
    inset.sheetMoved(700, maxInset: 400);
    await tester.pump(const Duration(milliseconds: 300));
    expect(inset.resolve(111), 400, reason: 'map above the sheet stays free');
  });
}

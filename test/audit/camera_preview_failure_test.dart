import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/navigation/driver_camera_controller.dart';

class _PendingOverviewPort implements DriverCameraPort {
  final overviewDone = Completer<void>();
  int followCommands = 0;
  @override
  Future<void> animate(DriverCameraPose pose) async {
    followCommands++;
  }

  @override
  Future<void> overview(List<GeoPoint> points, double padding) =>
      overviewDone.future;

  @override
  void retarget(DriverCameraPose pose) {}

  @override
  void interrupt() {}

  @override
  void dispose() {}
}

void main() {
  final now = DateTime.utc(2026, 10, 8);
  const origin = GeoPoint(59.3279, 18.0615);
  const target = GeoPoint(59.3290, 18.0630);
  DriverLocation fresh() =>
      DriverLocation(point: origin, measuredAt: now, accuracyMeters: 5);

  test(
    'dismissing a route preview restores following and discards late fit',
    () async {
      final camera = DriverCameraController(now: () => now);
      addTearDown(camera.dispose);
      final port = _PendingOverviewPort();
      camera.attach(port);
      camera.update(location: fresh());
      await Future<void>.delayed(Duration.zero);

      final preview = camera.preview([origin, target]);
      expect(camera.mode, DriverCameraMode.overview);
      final before = port.followCommands;
      camera.endPreview();
      expect(camera.mode, DriverCameraMode.following);
      expect(
        port.followCommands,
        greaterThan(before),
        reason: 'Closing an offer resumes GPS camera following',
      );

      port.overviewDone.complete();
      await preview;
      expect(
        camera.mode,
        DriverCameraMode.following,
        reason: 'The delayed old camera fit cannot restore Overview',
      );
    },
  );

  test(
    'dismissing preview never overrides a later manual camera pan',
    () async {
      final camera = DriverCameraController(now: () => now);
      addTearDown(camera.dispose);
      final port = _PendingOverviewPort();
      camera.attach(port);
      camera.update(location: fresh());
      await Future<void>.delayed(Duration.zero);

      final preview = camera.preview([origin, target]);
      camera.userGesture();
      final before = port.followCommands;
      camera.endPreview();
      expect(camera.mode, DriverCameraMode.browsing);
      expect(port.followCommands, before);
      port.overviewDone.complete();
      await preview;
      expect(camera.mode, DriverCameraMode.browsing);
    },
  );

  test('failed overview returns to following and resumes fresh GPS', () async {
    final camera = DriverCameraController(now: () => now);
    addTearDown(camera.dispose);
    final port = _PendingOverviewPort();
    camera.attach(port);
    camera.update(location: fresh());
    await Future<void>.delayed(Duration.zero);
    final before = port.followCommands;
    expect(before, greaterThan(0));

    final preview = camera.preview([origin, target]);
    expect(camera.mode, DriverCameraMode.overview);
    port.overviewDone.completeError(StateError('Map is unavailable'));
    await preview;
    expect(camera.mode, DriverCameraMode.following);
    expect(port.followCommands, greaterThan(before));
  });

  test(
    'failed overview cannot reclaim viewport after manual gesture',
    () async {
      final camera = DriverCameraController(now: () => now);
      addTearDown(camera.dispose);
      final port = _PendingOverviewPort();
      camera.attach(port);
      camera.update(location: fresh());
      await Future<void>.delayed(Duration.zero);
      final preview = camera.preview([origin, target]);
      final before = port.followCommands;
      camera.userGesture();
      expect(camera.mode, DriverCameraMode.browsing);

      port.overviewDone.completeError(StateError('Stale fit-to-route failed'));
      await preview;
      expect(camera.mode, DriverCameraMode.browsing);
      expect(port.followCommands, before);
    },
  );
}

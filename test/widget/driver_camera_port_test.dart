import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/navigation/driver_camera_controller.dart';
import 'package:movera/widgets/google_driver_camera_port.dart';
import 'package:movera/presentation/driver/overlays/map_overlay_insets.dart';

import '../../integration_test/headless_map_platform.dart';

class RecordingMapPlatform extends HeadlessMapPlatform {
  final List<CameraUpdate> moves = [];
  bool fail = false;
  @override
  Future<void> moveCamera(CameraUpdate update, {required int mapId}) async {
    if (fail) {
      throw StateError('SDK unavailable');
    }
    moves.add(update);
  }
}

class _DelayedCameraAckPlatform extends RecordingMapPlatform {
  final ack = Completer<void>();
  @override
  Future<void> moveCamera(CameraUpdate update, {required int mapId}) async {
    moves.add(update);
    await ack.future;
  }
}

void main() {
  test('driving anchor is 75% of screen and clears overlays', () {
    const low = MapOverlayInsets(top: 100, bottom: 100, left: 32, right: 32);
    final car = low.drivingInsets(800, following: true);
    expect((800 + car.top - car.bottom) / 2, 600);
    // A taller sheet keeps the car above it.
    const insets = MapOverlayInsets(top: 100, bottom: 200, left: 32, right: 32);
    final padding = insets.drivingInsets(800, following: true);
    expect((800 + padding.top - padding.bottom) / 2, 576);
    expect(() => insets.drivingInsets(250, following: true), returnsNormally);
  });
  testWidgets('four axes interpolate shortest-angle and input cancels frames', (
    tester,
  ) async {
    final original = GoogleMapsFlutterPlatform.instance;
    final platform = RecordingMapPlatform();
    GoogleMapsFlutterPlatform.instance = platform;
    addTearDown(() => GoogleMapsFlutterPlatform.instance = original);
    GoogleMapController? controller;
    const start = CameraPosition(
      target: LatLng(59, 18),
      zoom: 16,
      bearing: 359,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GoogleMap(
          initialCameraPosition: start,
          onMapCreated: (value) => controller = value,
        ),
      ),
    );
    await tester.pump();
    expect(controller, isNotNull);
    final port = GoogleDriverCameraPort(controller!, initialPosition: start);
    final animation = port.animate(
      const DriverCameraPose(GeoPoint(59.001, 18.001), 17, 1, 45),
    );
    await tester.pump();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final payload = platform.moves.last.toJson() as List<dynamic>;
    final pose = payload[1] as Map<String, dynamic>;
    expect(pose['zoom'], greaterThan(16));
    expect(pose['tilt'], greaterThan(0));
    final bearing = pose['bearing'] as double;
    expect(bearing > 358 || bearing < 2, isTrue);
    port.interrupt();
    final count = platform.moves.length;
    await tester.pump(const Duration(seconds: 1));
    await animation;
    expect(
      platform.moves.length,
      count,
      reason: 'Interrupt cancels actual future camera moves',
    );
    final reduced = GoogleDriverCameraPort(controller!, reducedMotion: true);
    await reduced.animate(
      const DriverCameraPose(GeoPoint(59, 18), 17.5, 90, 45),
    );
    expect(platform.moves.length, count + 1);
    reduced.dispose();
    port.dispose();
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('a whole-route overview lands flat even from a tilted map', (
    tester,
  ) async {
    final original = GoogleMapsFlutterPlatform.instance;
    final platform = RecordingMapPlatform();
    GoogleMapsFlutterPlatform.instance = platform;
    addTearDown(() => GoogleMapsFlutterPlatform.instance = original);
    GoogleMapController? controller;
    const start = CameraPosition(
      target: LatLng(59, 18),
      zoom: 17,
      tilt: 67.5,
      bearing: 40,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GoogleMap(
          initialCameraPosition: start,
          onMapCreated: (value) => controller = value,
        ),
      ),
    );
    await tester.pump();
    // Reduced motion lands in one move: the pose a flight ends at.
    final port = GoogleDriverCameraPort(controller!,
        initialPosition: start, reducedMotion: true);
    await port.frame(const GeoPoint(59.01, 18.01), 13.4);
    final pose =
        (platform.moves.last.toJson() as List<dynamic>)[1]
            as Map<String, dynamic>;
    expect(pose['zoom'], closeTo(13.4, .001));
    expect(pose['tilt'], 0);
    port.dispose();
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('failed SDK bounds fit propagates for camera mode recovery', (
    tester,
  ) async {
    final original = GoogleMapsFlutterPlatform.instance;
    final platform = RecordingMapPlatform();
    GoogleMapsFlutterPlatform.instance = platform;
    addTearDown(() => GoogleMapsFlutterPlatform.instance = original);
    GoogleMapController? controller;
    await tester.pumpWidget(MaterialApp(
      home: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(59, 18),
          zoom: 16,
        ),
        onMapCreated: (value) => controller = value,
      ),
    ));
    await tester.pump();
    expect(controller, isNotNull);
    final statuses = <String?>[];
    // No initial logical camera: preview goes directly to fit bounds.
    final port = GoogleDriverCameraPort(
      controller!,
      onStatus: statuses.add,
    );
    const bounds = [GeoPoint(59.32, 18.04), GeoPoint(59.36, 18.10)];
    platform.fail = true;
    await expectLater(port.overview(bounds, 80), throwsStateError);
    expect(statuses.last, contains('unavailable'));

    platform.fail = false;
    await port.overview(bounds, 80);
    expect(statuses.last, isNull);
    expect(platform.moves, isNotEmpty);
    port.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('late route-fit acknowledgement cannot clear camera error', (
    tester,
  ) async {
    final original = GoogleMapsFlutterPlatform.instance;
    final platform = _DelayedCameraAckPlatform();
    GoogleMapsFlutterPlatform.instance = platform;
    addTearDown(() => GoogleMapsFlutterPlatform.instance = original);
    GoogleMapController? controller;
    await tester.pumpWidget(MaterialApp(
      home: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(59, 18),
          zoom: 16,
        ),
        onMapCreated: (value) => controller = value,
      ),
    ));
    await tester.pump();
    expect(controller, isNotNull);
    final statuses = <String?>[];
    final port = GoogleDriverCameraPort(
      controller!,
      onStatus: statuses.add,
    );
    const points = [GeoPoint(59.32, 18.04), GeoPoint(59.36, 18.10)];
    final pending = port.overview(points, 80);
    await tester.pump();
    expect(platform.moves, hasLength(1));
    port.interrupt(); // A later manual pan or dismissed route owns the map.
    platform.ack.complete();
    await tester.pump();
    await pending;
    expect(statuses, isEmpty,
        reason: 'Old route-fit success must not clear newer camera status');
    port.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('late SDK move cannot update marker after manual camera pan', (
    tester,
  ) async {
    final original = GoogleMapsFlutterPlatform.instance;
    final platform = _DelayedCameraAckPlatform();
    GoogleMapsFlutterPlatform.instance = platform;
    addTearDown(() => GoogleMapsFlutterPlatform.instance = original);
    GoogleMapController? controller;
    await tester.pumpWidget(MaterialApp(
      home: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(59, 18),
          zoom: 16,
        ),
        onMapCreated: (value) => controller = value,
      ),
    ));
    await tester.pump();
    expect(controller, isNotNull);
    final statuses = <String?>[];
    final frames = <CameraPosition>[];
    final port = GoogleDriverCameraPort(
      controller!,
      reducedMotion: true,
      onStatus: statuses.add,
      onFrame: frames.add,
    );
    final pending = port.animate(
      const DriverCameraPose(GeoPoint(59.002, 18.003), 17, 25, 35),
    );
    await tester.pump();
    expect(platform.moves, hasLength(1));
    // The physical gesture happens before Maps resolves moveCamera().
    port.interrupt();
    platform.ack.complete();
    await tester.pump();
    await pending;
    expect(frames, isEmpty,
        reason: 'An obsolete SDK response cannot reposition the vehicle');
    expect(statuses, isEmpty,
        reason: 'An obsolete SDK response cannot clear a new camera error');
    port.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('settled follow stops scheduling and camera error is retryable', (
    tester,
  ) async {
    final original = GoogleMapsFlutterPlatform.instance;
    final platform = RecordingMapPlatform();
    GoogleMapsFlutterPlatform.instance = platform;
    addTearDown(() => GoogleMapsFlutterPlatform.instance = original);
    GoogleMapController? controller;
    const start = CameraPosition(target: LatLng(59, 18), zoom: 16);
    await tester.pumpWidget(
      MaterialApp(
        home: GoogleMap(
          initialCameraPosition: start,
          onMapCreated: (value) => controller = value,
        ),
      ),
    );
    await tester.pump();
    final statuses = <String?>[];
    final port = GoogleDriverCameraPort(
      controller!,
      initialPosition: start,
      onStatus: statuses.add,
    );
    await port.animate(const DriverCameraPose(GeoPoint(59, 18), 16, 0, 0));
    final count = platform.moves.length;
    await tester.pump(const Duration(seconds: 5));
    expect(platform.moves.length, count);
    platform.fail = true;
    final retryable = GoogleDriverCameraPort(
      controller!,
      reducedMotion: true,
      onStatus: statuses.add,
    );
    await retryable.animate(
      const DriverCameraPose(GeoPoint(59.001, 18), 16, 0, 0),
    );
    expect(statuses.last, contains('unavailable'));
    platform.fail = false;
    await retryable.animate(
      const DriverCameraPose(GeoPoint(59.001, 18), 16, 0, 0),
    );
    expect(statuses.last, isNull);
    port.dispose();
    retryable.dispose();
    await tester.pumpWidget(const SizedBox());
  });
}

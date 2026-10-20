// Owner: "when click on the icon [locate] must zoom in like photos but not
// toooo much zoom so become bad". The locate button, on Home and on a
// trip, flies to the reference app's locate view: street zoom 15, tilted
// by the tilt curve (about 58 deg), in one smooth flight. Home still opens
// at 11.7, flat.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/navigation/driver_camera_controller.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/styles/movera_map_style.dart';
import 'package:movera/widgets/google_driver_camera_port.dart';

import '../../integration_test/headless_map_platform.dart';

const _origin = GeoPoint(59.33, 18.06);

DriverLocation _fix(GeoPoint p, {double speed = 0}) => DriverLocation(
  point: p,
  headingDegrees: 90,
  speedMetersPerSecond: speed,
  measuredAt: DateTime.now(),
  accuracyMeters: 5,
);

GeoPoint _east(GeoPoint p, double meters) =>
    GeoPoint(p.latitude, p.longitude + meters / 56700);

final _road = RoadRoute(
  points: [for (var i = 0; i <= 40; i++) _east(_origin, i * 250.0)],
  distanceMeters: 10000,
  durationSeconds: 600,
);

class _Recorder implements DriverCameraPort {
  final poses = <DriverCameraPose>[];
  @override
  Future<void> animate(DriverCameraPose pose) async => poses.add(pose);
  @override
  void retarget(DriverCameraPose pose) => poses.add(pose);
  @override
  Future<void> overview(List<GeoPoint> points, double padding) async {}
  @override
  void interrupt() {}
  @override
  void dispose() {}
}

class _Moves extends HeadlessMapPlatform {
  final List<Map<String, dynamic>> poses = [];
  @override
  Future<void> moveCamera(CameraUpdate update, {required int mapId}) async {
    final json = update.toJson() as List<dynamic>;
    if (json.first == 'newCameraPosition') {
      poses.add(json[1] as Map<String, dynamic>);
    }
  }
}

void main() {
  test('the locate view: street zoom 15, strongly tilted, never closer', () {
    const z = DriverCameraPolicy.locateZoom;
    expect(z, 15);
    // Not closer than guidance at a standstill, and short of the zoom
    // where the roads switch to their bold close-up style.
    expect(z, lessThanOrEqualTo(DriverCameraPolicy.guidanceStartZoom));
    expect(z, lessThan(MoveraMapStyleBand.closeSplit));
    final tilt = DriverCameraPolicy.tiltForZoom(z);
    expect(tilt, closeTo(67.5 * 3 / 3.5, 1e-9)); // about 57.9 deg
    expect(tilt, lessThan(DriverCameraPolicy.sdkMaxTilt(z)));
  });

  test('Home opens at 11.7 flat; locate flies to 15 tilted and stays', () {
    final policy = DriverCameraPolicy();
    final open = policy.resolve(location: _fix(_origin), immediate: true);
    expect(open.zoom, DriverCameraPolicy.exploreZoom);
    expect(open.zoom, 11.7);
    expect(open.tilt, 0);
    policy.locate();
    final located = policy.resolve(location: _fix(_origin), immediate: true);
    expect(located.zoom, 15);
    expect(located.tilt, closeTo(DriverCameraPolicy.tiltForZoom(15), 1e-9));
    expect(located.duration.inMilliseconds, 900);
    // Following on: the next GPS fixes keep the locate view.
    final next = policy.resolve(location: _fix(_east(_origin, 20)));
    expect(next.zoom, 15);
    expect(next.tilt, closeTo(DriverCameraPolicy.tiltForZoom(15), 1e-9));
    // A fresh Home map still opens at 11.7.
    expect(DriverCameraPolicy().resolve(location: _fix(_origin)).zoom, 11.7);
  });

  test('trip: locate shows 15, then eases back to the speed zoom', () {
    final policy = DriverCameraPolicy();
    var at = _origin;
    DriverCameraPose fix({bool immediate = false}) {
      at = _east(at, 30);
      return policy.resolve(location: _fix(at, speed: 30), route: _road,
          navigating: true, immediate: immediate);
    }

    for (var i = 0; i < 10; i++) {
      fix(immediate: i == 0);
    }
    expect(fix().zoom, closeTo(13.625, 1e-9), reason: 'highway cruise');
    policy.locate();
    final located = fix(immediate: true);
    expect(located.zoom, 15);
    expect(located.tilt, closeTo(DriverCameraPolicy.tiltForZoom(15), 1e-9));
    var previous = located.zoom;
    for (var i = 0; i < 12; i++) {
      final zoom = fix().zoom;
      expect(previous - zoom,
          lessThanOrEqualTo(DriverCameraPolicy.maxZoomOutPerFix + 1e-9),
          reason: 'smooth return, no jump');
      expect(zoom, lessThanOrEqualTo(previous));
      previous = zoom;
    }
    expect(previous, closeTo(13.625, 1e-9));
  });

  test('waiting at a stop keeps its own flat view', () {
    final policy = DriverCameraPolicy()..locate();
    final pose = policy.resolve(
        location: _fix(_origin), navigating: true, waiting: true,
        immediate: true);
    expect(pose.zoom, DriverCameraPolicy.waitingZoom);
    expect(pose.tilt, 0);
  });

  test('controller: locate takes the map back from a browsing driver', () {
    final camera = DriverCameraController();
    addTearDown(camera.dispose);
    final port = _Recorder();
    camera.attach(port);
    camera.update(location: _fix(_origin));
    expect(port.poses.last.zoom, 11.7);
    camera.userGesture();
    expect(camera.mode, DriverCameraMode.browsing);
    camera.locate();
    expect(camera.mode, DriverCameraMode.following);
    expect(port.poses.last.zoom, 15);
    expect(port.poses.last.tilt, greaterThan(55));
    // A plain recenter (offer preview closing) keeps the followed zoom.
    camera.recenter();
    expect(port.poses.last.zoom, 15);
  });

  testWidgets('the locate flight is smooth: eased start, continuous zoom '
      'and tilt, tilt on the curve, no cut', (tester) async {
    final original = GoogleMapsFlutterPlatform.instance;
    final platform = _Moves();
    GoogleMapsFlutterPlatform.instance = platform;
    addTearDown(() => GoogleMapsFlutterPlatform.instance = original);
    GoogleMapController? controller;
    const start = CameraPosition(target: LatLng(59.33, 18.06), zoom: 11.7);
    await tester.pumpWidget(MaterialApp(
      home: GoogleMap(
        initialCameraPosition: start,
        onMapCreated: (value) => controller = value,
      ),
    ));
    await tester.pump();
    final port = GoogleDriverCameraPort(controller!, initialPosition: start);
    final policy = DriverCameraPolicy()..locate();
    final pose = policy.resolve(location: _fix(_origin), immediate: true);
    var done = false;
    unawaited(port.animate(pose).then((_) => done = true));
    for (var i = 0; i < 4000 && !done; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(done, isTrue);
    final zooms = [for (final p in platform.poses) p['zoom'] as double];
    final tilts = [for (final p in platform.poses) p['tilt'] as double];
    expect(zooms.length, greaterThan(30), reason: 'a flight, not a cut');
    expect(zooms.last, closeTo(15, .03));
    expect(tilts.last, closeTo(DriverCameraPolicy.tiltForZoom(15), .6));
    // Eased start: the first frames move far less than the fastest ones.
    final steps = [for (var i = 1; i < zooms.length; i++) zooms[i] - zooms[i - 1]];
    final fastest = steps.reduce((a, b) => a > b ? a : b);
    expect(steps.first, lessThan(fastest * .3));
    expect(fastest, lessThan(.12), reason: 'no zoom jump between frames');
    for (var i = 0; i < steps.length; i++) {
      expect(steps[i], greaterThanOrEqualTo(-1e-9), reason: 'frame $i');
      expect(tilts[i + 1], greaterThanOrEqualTo(tilts[i] - 1e-9));
    }
    port.dispose();
    await tester.pumpWidget(const SizedBox());
  });
}

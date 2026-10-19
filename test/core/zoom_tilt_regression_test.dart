// Owner report: "can't zoom on the Home screen, and the camera animation
// when zooming on a trip looks bad", plus "tilt must change proportionally
// with the zoom, live while zooming".
//
// Root cause: Maps reports camera idle whenever the camera pauses, also
// while a pinch is held. Home never told the camera a finger was down, so
// each idle started the 350 ms tilt ease, whose frames re-asserted the old
// zoom under the driver's fingers. The ease also restarted from rest on
// every idle of its own frames, so the tilt crept up in stutters.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/navigation/driver_camera_controller.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/widgets/custom_google_map.dart';
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

class _Port implements DriverCameraPort, DriverCameraTilting {
  final tilts = <double>[];
  var interrupts = 0;
  @override
  double? currentZoom;
  @override
  double? currentTilt;
  @override
  Future<void> animate(DriverCameraPose pose) async {}
  @override
  void retarget(DriverCameraPose pose) {}
  @override
  Future<void> overview(List<GeoPoint> points, double padding) async {}
  @override
  Future<void> tiltTo(double tilt) async => tilts.add(tilt);
  @override
  void interrupt() => interrupts++;
  @override
  void dispose() {}
}

class _BindingPort extends _Port implements DriverCameraTiltBinding {
  final bindings = <bool>[];
  @override
  void bindTiltToZoom(bool enabled) => bindings.add(enabled);
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
  group('tilt is proportional to zoom', () {
    double t(double z) => DriverCameraPolicy.tiltForZoom(z);
    test('0 deg at zoom 12, linear to 67.5 deg at zoom 16', () {
      expect(t(11), 0);
      expect(t(DriverCameraPolicy.exploreZoom), 0); // Home opens flat.
      expect(t(12), 0);
      expect(t(13), closeTo(16.875, 1e-9));
      expect(t(14), closeTo(33.75, 1e-9));
      expect(t(15), closeTo(50.625, 1e-9));
      expect(t(16), 67.5);
      expect(t(20), 67.5);
      // Every small zoom step between 12 and 16 changes the tilt by the
      // same amount: no plateau from the SDK limit, no steep middle.
      for (var z = 12.0; z < 15.99; z += .05) {
        final step = t(z + .05) - t(z);
        expect(step, closeTo(67.5 / 4 * .05, 1e-6), reason: 'at $z');
        expect(t(z), lessThan(DriverCameraPolicy.sdkMaxTilt(z)),
            reason: 'never clamped by the SDK at $z');
      }
    });

    test('the web gesture layer uses the same curve', () {
      final js = File('web/driver_map_camera.js').readAsStringSync();
      expect(js, contains('const MAX_TILT = 67.5;'));
      expect(js, contains('MAX_TILT * clamp((zoom - 12) / 4, 0, 1)'));
      expect(DriverCameraPolicy.flatZoom, 12);
      expect(DriverCameraPolicy.fullTiltZoom, 16);
      expect(DriverCameraPolicy.maxTilt, 67.5);
    });
  });

  group('guidance stays wide while tilted', () {
    test('cruise 16 standstill, 15.5 urban, 15 fast, 14.625 highway', () {
      expect(DriverCameraPolicy.guidanceStartZoom, 16);
      expect(DriverCameraPolicy.zoomForSpeed(0), 16);
      expect(DriverCameraPolicy.zoomForSpeed(10), 15.5);
      expect(DriverCameraPolicy.zoomForSpeed(20), 15);
      expect(DriverCameraPolicy.zoomForSpeed(30), 14.625);
      var previous = DriverCameraPolicy.zoomForSpeed(0);
      for (var s = 0.0; s <= 40; s += .25) {
        final z = DriverCameraPolicy.zoomForSpeed(s);
        expect(z, lessThanOrEqualTo(previous));
        expect(previous - z, lessThan(.03), reason: 'no step at $s m/s');
        previous = z;
      }
    });

    test('a turn adds at most 0.4; arrival is 16.5 at 60 deg', () {
      expect(DriverCameraPolicy.maxTurnZoomIn, .4);
      expect(DriverCameraPolicy.arrivalZoom, 16.5);
      expect(DriverCameraPolicy.arrivalTilt, 60);
      final road = RoadRoute(
        points: [for (var i = 0; i <= 20; i++) _east(_origin, i * 100.0)],
        distanceMeters: 2000,
        durationSeconds: 200,
      );
      final cruise = DriverCameraPolicy().resolve(
          location: _fix(_origin), route: road, navigating: true,
          immediate: true);
      expect(cruise.zoom, 16);
      expect(cruise.tilt, 67.5);
      final arrival = DriverCameraPolicy().resolve(
          location: _fix(_east(_origin, 2000)), route: road,
          navigating: true, immediate: true);
      expect(arrival.zoom, closeTo(16.5, 1e-9));
      expect(arrival.tilt, 60);
    });
  });

  group('the camera never moves under a finger', () {
    test('Home: idle during a held pinch waits for the finger to lift', () {
      final camera = DriverCameraController();
      addTearDown(camera.dispose);
      final port = _Port();
      camera.attach(port);
      camera.update(location: _fix(_origin)); // Home.
      camera.touching = true;
      camera.userGesture();
      port
        ..currentZoom = 14
        ..currentTilt = 0;
      camera.browseSettled(); // Maps idle while the fingers rest.
      expect(port.tilts, isEmpty);
      camera.touching = false;
      expect(port.tilts.single, closeTo(33.75, 1e-9));
    });

    test('the live tilt-with-zoom is off while waiting (flat map)', () {
      final camera = DriverCameraController();
      addTearDown(camera.dispose);
      final port = _BindingPort();
      camera.attach(port);
      expect(port.bindings.last, isTrue);
      camera.update(location: _fix(_origin), navigating: true, waiting: true);
      expect(port.bindings.last, isFalse);
      camera.update(location: _fix(_east(_origin, 5)), navigating: true);
      expect(port.bindings.last, isTrue);
    });

    test('a new finger stops a tilt ease that is still running', () {
      final camera = DriverCameraController();
      addTearDown(camera.dispose);
      final port = _Port();
      camera.attach(port);
      camera.update(location: _fix(_origin));
      camera.userGesture();
      final before = port.interrupts;
      camera.touching = true;
      expect(port.interrupts, before + 1);
    });

    testWidgets('CustomGoogleMap reports fingers down and up', (tester) async {
      final original = GoogleMapsFlutterPlatform.instance;
      GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
      addTearDown(() => GoogleMapsFlutterPlatform.instance = original);
      final events = <bool>[];
      await tester.pumpWidget(MaterialApp(
        home: CustomGoogleMap(onTouching: events.add),
      ));
      final center = tester.getCenter(find.byType(CustomGoogleMap));
      final a = await tester.startGesture(center, pointer: 1);
      final b = await tester.startGesture(center + const Offset(40, 0),
          pointer: 2);
      await b.moveBy(const Offset(60, 0));
      expect(events, [true]);
      await b.up();
      expect(events, [true], reason: 'one finger is still down');
      await a.up();
      expect(events, [true, false]);
      await tester.pumpWidget(const SizedBox());
    });

    test('both Home maps tell the camera about fingers on the map', () {
      final src = File('lib/presentation/driver/home/home_map_sheet.dart')
          .readAsStringSync();
      expect(
          'onTouching: (down) => _camera.touching = down'.allMatches(src).length,
          2);
    });
  });

  group('tilt ease after a zoom', () {
    testWidgets('a repeated idle keeps the ease going (no restart stutter)',
        (tester) async {
      final original = GoogleMapsFlutterPlatform.instance;
      final platform = _Moves();
      GoogleMapsFlutterPlatform.instance = platform;
      addTearDown(() => GoogleMapsFlutterPlatform.instance = original);
      GoogleMapController? controller;
      const start = CameraPosition(target: LatLng(59, 18), zoom: 14.2);
      await tester.pumpWidget(MaterialApp(
        home: GoogleMap(
          initialCameraPosition: start,
          onMapCreated: (value) => controller = value,
        ),
      ));
      await tester.pump();
      final port = GoogleDriverCameraPort(controller!, initialPosition: start);
      var done = false;
      unawaited(port.tiltTo(40).then((_) => done = true));
      for (var i = 0; i < 4000 && !done; i++) {
        // Maps reports idle between the ease's own frames.
        if (i % 3 == 1) unawaited(port.tiltTo(40));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(done, isTrue);
      final tilts = [for (final p in platform.poses) p['tilt'] as double];
      expect(tilts.last, 40);
      for (var i = 1; i < tilts.length; i++) {
        expect(tilts[i], greaterThan(tilts[i - 1]),
            reason: 'frame $i restarted the ease');
      }
      for (final p in platform.poses) {
        expect(p['zoom'], 14.2, reason: 'the ease never changes the zoom');
      }
      port.dispose();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a pinch during a running tilt ease is never undone',
        (tester) async {
      final original = GoogleMapsFlutterPlatform.instance;
      final platform = _Moves();
      GoogleMapsFlutterPlatform.instance = platform;
      addTearDown(() => GoogleMapsFlutterPlatform.instance = original);
      GoogleMapController? controller;
      const start = CameraPosition(target: LatLng(59, 18), zoom: 14);
      await tester.pumpWidget(MaterialApp(
        home: GoogleMap(
          initialCameraPosition: start,
          onMapCreated: (value) => controller = value,
        ),
      ));
      await tester.pump();
      final camera = DriverCameraController();
      final port = GoogleDriverCameraPort(controller!, initialPosition: start);
      camera.attach(port);
      camera.update(location: _fix(const GeoPoint(59, 18)));
      for (var i = 0; i < 200; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      camera.userGesture(); // The driver zoomed by hand to 14, flat ...
      port.onMove(const CameraPosition(target: LatLng(59, 18), zoom: 14));
      camera.browseSettled(); // ... let go: the tilt eases toward 33.75.
      // The ease runs on the wall clock: wait until it is under way.
      for (var i = 0; i < 20000 && (platform.poses.last['tilt'] as double) < 1;
          i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(platform.poses.last['tilt'], inExclusiveRange(1, 33.75));
      // A finger lands mid-ease and pinches the map to zoom 15.6 (the web
      // gesture layer moves the camera; Flutter sees the moves).
      camera.touching = true;
      final count = platform.poses.length;
      port.onMove(const CameraPosition(
          target: LatLng(59, 18), zoom: 15.6, tilt: 60.75));
      camera.browseSettled(); // Maps idle under the resting fingers.
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(platform.poses.length, count,
          reason: 'nothing moves the camera under the finger');
      camera.touching = false; // On curve already: nothing left to ease.
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      for (final p in platform.poses.skip(count)) {
        expect(p['zoom'], 15.6, reason: 'the zoom is never reset');
      }
      expect(port.currentZoom, 15.6);
      camera.dispose();
      await tester.pumpWidget(const SizedBox());
    });
  });
}

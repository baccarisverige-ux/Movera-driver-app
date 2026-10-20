import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/widgets/custom_google_map.dart';
import 'package:movera/widgets/movera_vehicle_marker.dart';

import '../../integration_test/headless_map_platform.dart';

Marker _own(double heading, {bool flat = false, String id = 'driver'}) =>
    Marker(
      markerId: MarkerId(id),
      position: const LatLng(59.33, 18.06),
      rotation: heading,
      flat: flat,
      anchor: MoveraVehicleMarker.anchor,
      zIndexInt: 12,
    );

void main() {
  group('the own vehicle is an upright arrow', () {
    test('its rotation is the heading seen from the camera', () {
      double r(double h, double b, double t) =>
          MoveraVehicleMarker.screenRotation(h, b, t);
      // Heading-up guidance: the arrow points straight up at any tilt.
      expect(r(90, 90, 0), closeTo(0, 1e-9));
      expect(r(90, 90, 67.5), closeTo(0, 1e-9));
      // North-up flat map: the compass heading itself.
      expect(r(135, 0, 0), closeTo(135, 1e-9));
      // A camera turned 30 deg: the arrow turns back by 30.
      expect(r(90, 30, 0), closeTo(60, 1e-9));
      // Across a tilted view the course looks steeper, like the road.
      expect(r(45, 0, 60), greaterThan(60));
      expect(r(90, 0, 60), closeTo(90, 1e-9));
      expect(r(270, 0, 60), closeTo(270, 1e-9));
      expect(r(180, 0, 60), closeTo(180, 1e-9));
    });

    test('the bitmaps are drawn at 3x the largest size, shown at the '
        'reference size at zoom 15', () async {
      final arrow = await MoveraVehicleMarker.createIcon() as BytesMapBitmap;
      expect(arrow.width, MoveraVehicleMarker.size);
      expect(arrow.height, MoveraVehicleMarker.size);
      final image = await decodeImageFromList(arrow.byteData);
      expect(image.width,
          (MoveraVehicleMarker.size * MoveraVehicleMarker.maxScale * 3).round());
      final halo = MoveraVehicleMarker.halo! as BytesMapBitmap;
      expect(halo.width, MoveraVehicleMarker.haloSize);
    });

    test('the arrow grows zoomed in and shrinks zoomed out, like the '
        'reference', () {
      double s(double z) => MoveraVehicleMarker.scaleAt(z);
      // Reference: ~6.5 % of the screen width over the region, ~8 % at
      // neighbourhood zoom, ~10 % at street zoom, ~11 % right in.
      expect(s(11.7), .6); // Home opens here.
      expect(s(14), .85);
      expect(s(15), 1); // Locate and guidance standstill.
      expect(s(17), 1.1);
      expect(s(21), 1.1, reason: 'clamped');
      expect(s(3), .6, reason: 'clamped');
      expect(s(double.nan), 1);
      // Interpolated: never shrinks while zooming in.
      var previous = 0.0;
      for (var z = 8.0; z <= 20; z += .01) {
        final raw = MoveraVehicleMarker.scaleForZoom(z);
        expect(raw, greaterThanOrEqualTo(previous - 1e-12));
        previous = raw;
      }
      // Small like the reference (owner: the old arrow looked too big):
      // about 6.5 % of a phone (393 pt) at zoom 15, 4 % zoomed out. The
      // arrow is 34 of its box's 52 drawing units wide.
      expect(34 / 52 * MoveraVehicleMarker.size * s(15) / 393,
          closeTo(.065, .01));
      expect(34 / 52 * MoveraVehicleMarker.size * s(11.7) / 393,
          closeTo(.04, .01));
    });

    test('size buckets: no flicker at a bucket edge', () {
      double next(double shown, double z) =>
          MoveraVehicleMarker.nextScale(shown, z);
      expect(MoveraVehicleMarker.scaleAt(14.28), .9);
      expect(next(.85, 14.28), .85, reason: 'under 0.7 of a bucket away');
      expect(next(.85, 14.36), .9);
      expect(next(.9, 14.28), .9);
      expect(next(.6, 15), 1, reason: 'a jump goes straight to its bucket');
    });

    test('each bucket is one cached bitmap of the same picture', () async {
      await MoveraVehicleMarker.createIcon();
      final a = MoveraVehicleMarker.arrowAt(.85)! as BytesMapBitmap;
      expect(identical(MoveraVehicleMarker.arrowAt(.85), a), isTrue);
      expect(a.width, closeTo(MoveraVehicleMarker.size * .85, 1e-9));
      final big = MoveraVehicleMarker.arrowAt(1.1)! as BytesMapBitmap;
      expect(identical(big.byteData, a.byteData), isTrue);
      final halo = MoveraVehicleMarker.haloAt(.6)! as BytesMapBitmap;
      expect(halo.width, closeTo(MoveraVehicleMarker.haloSize * .6, 1e-9));
    });

    test('flat blue face, white outline, clear around it', () async {
      // Drawn in its 52-unit design box so the pixel spots stay fixed.
      const box = 52.0;
      final recorder = ui.PictureRecorder();
      MoveraVehicleMarker.paintArrow(Canvas(recorder), box);
      final image =
          await recorder.endRecording().toImage(box.round(), box.round());
      final data = (await image.toByteData())!;
      Color at(int x, int y) {
        final i = (y * box.round() + x) * 4;
        return Color.fromARGB(data.getUint8(i + 3), data.getUint8(i),
            data.getUint8(i + 1), data.getUint8(i + 2));
      }

      final face = at(26, 24);
      expect(face.a, 1);
      expect(face.b, greaterThan(face.r));
      // White outline just outside the tip.
      final rim = at(26, 6);
      expect(rim.a, greaterThan(.9));
      expect(rim.r, greaterThan(.9));
      expect(rim.b, greaterThan(.9));
      expect(at(2, 2).a, 0);
    });

    testWidgets('CustomGoogleMap turns the billboard with the camera, '
        'over a flat halo, without churning on small turns', (tester) async {
      final maps = GoogleMapsFlutterPlatform.instance;
      GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
      addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
      await tester.runAsync(MoveraVehicleMarker.createIcon);
      final other = const Marker(markerId: MarkerId('pickup'), rotation: 40);
      await tester.pumpWidget(MaterialApp(
        home: CustomGoogleMap(
          initialPosition: const CameraPosition(
              target: LatLng(59.33, 18.06), zoom: 15, bearing: 30),
          markers: {_own(90), other},
        ),
      ));
      await tester.pump();
      GoogleMap map() => tester.widget<GoogleMap>(find.byType(GoogleMap));
      Marker marker(String id) =>
          map().markers.singleWhere((m) => m.markerId.value == id);
      expect(marker('driver').flat, isFalse);
      expect(marker('driver').rotation, closeTo(60, 1e-9));
      expect(marker('pickup').rotation, 40);
      final halo = marker('driver_halo');
      expect(halo.flat, isTrue);
      expect(halo.position, marker('driver').position);
      expect(halo.zIndexInt, 11);

      // Heading-up and tilted: points straight up.
      map().onCameraMove!(const CameraPosition(
          target: LatLng(59.33, 18.06), zoom: 15, bearing: 90, tilt: 58));
      await tester.pump();
      expect(marker('driver').rotation, closeTo(0, 1e-9));
      // A half-degree camera wobble does not rebuild the markers.
      final before = map().markers;
      map().onCameraMove!(const CameraPosition(
          target: LatLng(59.33, 18.06), zoom: 15, bearing: 90.5, tilt: 58));
      await tester.pump();
      expect(identical(map().markers, before), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('CustomGoogleMap sizes the arrow and halo for the zoom, '
        'rebuilding only on a new bucket', (tester) async {
      final maps = GoogleMapsFlutterPlatform.instance;
      GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
      addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
      await tester.runAsync(MoveraVehicleMarker.createIcon);
      await tester.pumpWidget(MaterialApp(
        home: CustomGoogleMap(
          initialPosition: const CameraPosition(
              target: LatLng(59.33, 18.06), zoom: 11.7),
          markers: {_own(0)},
        ),
      ));
      await tester.pump();
      GoogleMap map() => tester.widget<GoogleMap>(find.byType(GoogleMap));
      double width(String id) => (map().markers
              .singleWhere((m) => m.markerId.value == id)
              .icon as BytesMapBitmap)
          .width!;
      expect(width('driver'), closeTo(MoveraVehicleMarker.size * .6, 1e-9));
      expect(width('driver_halo'),
          closeTo(MoveraVehicleMarker.haloSize * .6, 1e-9));
      // A smooth zoom in from Home to the locate view: a handful of
      // rebuilds (one per bucket), not one per camera frame.
      var rebuilds = 0;
      var markers = map().markers;
      for (var i = 1; i <= 120; i++) {
        final zoom = 11.7 + 3.3 * i / 120;
        map().onCameraMove!(CameraPosition(
            target: const LatLng(59.33, 18.06), zoom: zoom));
        await tester.pump();
        if (!identical(map().markers, markers)) rebuilds++;
        markers = map().markers;
      }
      expect(rebuilds, inInclusiveRange(1, 9));
      expect(width('driver'), closeTo(MoveraVehicleMarker.size, 1e-9));
      expect(width('driver_halo'), closeTo(MoveraVehicleMarker.haloSize, 1e-9));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}

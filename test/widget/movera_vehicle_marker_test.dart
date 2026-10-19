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

    test('the bitmaps are drawn at 3x and shown at the reference size',
        () async {
      final arrow = await MoveraVehicleMarker.createIcon() as BytesMapBitmap;
      expect(arrow.width, MoveraVehicleMarker.size);
      expect(arrow.height, MoveraVehicleMarker.size);
      final image = await decodeImageFromList(arrow.byteData);
      expect(image.width, (MoveraVehicleMarker.size * 3).round());
      final halo = MoveraVehicleMarker.halo! as BytesMapBitmap;
      expect(halo.width, MoveraVehicleMarker.haloSize);
    });

    test('blue top face, darker edge under it, clear around it', () async {
      const box = MoveraVehicleMarker.size;
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
      final edge = at(40, 38);
      expect(edge.a, greaterThan(.9));
      double light(Color c) => c.r + c.g + c.b;
      expect(light(edge), lessThan(light(face)));
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
  });
}

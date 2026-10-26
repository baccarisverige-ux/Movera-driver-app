import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/widgets/custom_google_map.dart';
import 'package:movera/widgets/movera_vehicle_marker.dart';

import '../../integration_test/headless_map_platform.dart';

Marker _own(double heading, {BitmapDescriptor? icon, String id = 'driver'}) =>
    Marker(
      markerId: MarkerId(id),
      position: const LatLng(59.33, 18.06),
      rotation: heading,
      flat: false,
      anchor: MoveraVehicleMarker.anchor,
      icon: icon ?? BitmapDescriptor.defaultMarker,
      zIndexInt: 12,
    );

/// The pixels of [paint] drawn in a [box] x [box] square at 1x.
Future<Color Function(int x, int y)> _pixels(
  void Function(Canvas, double) paint,
  double box,
) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder), box);
  final image = await recorder.endRecording().toImage(box.round(), box.round());
  final data = (await image.toByteData())!;
  return (int x, int y) {
    final i = (y * box.round() + x) * 4;
    return Color.fromARGB(
      data.getUint8(i + 3),
      data.getUint8(i),
      data.getUint8(i + 1),
      data.getUint8(i + 2),
    );
  };
}

void main() {
  group(
    'the own vehicle is an upright arrow of one size over a small ring',
    () {
      test(
        'its rotation is the heading minus the map bearing, nothing else',
        () {
          double r(double h, double b) =>
              MoveraVehicleMarker.screenRotation(h, b);
          // Heading-up guidance: the arrow points straight up.
          expect(r(90, 90), closeTo(0, 1e-9));
          // North-up map: the compass heading itself.
          expect(r(135, 0), closeTo(135, 1e-9));
          // A camera turned 30 deg: the arrow turns back by 30.
          expect(r(90, 30), closeTo(60, 1e-9));
          expect(r(10, 30), closeTo(340, 1e-9));
          expect(r(-10, 0), closeTo(350, 1e-9));
        },
      );

      test('one bitmap holds the arrow and the ring, drawn at 3x', () async {
        final icon = await MoveraVehicleMarker.createIcon() as BytesMapBitmap;
        expect(identical(MoveraVehicleMarker.icon, icon), isTrue);
        expect(icon.width, MoveraVehicleMarker.box);
        expect(icon.height, MoveraVehicleMarker.box);
        expect(MoveraVehicleMarker.box, greaterThan(MoveraVehicleMarker.size));
        final image = await decodeImageFromList(icon.byteData);
        expect(image.width, (MoveraVehicleMarker.box * 3).round());
        expect(image.height, image.width);
        // The ring: about 1.3 x the arrow's width (34 of 52 drawing units).
        final arrowWidth = 34 / 52 * MoveraVehicleMarker.size;
        expect(MoveraVehicleMarker.ringSize / arrowWidth, closeTo(1.3, .05));
      });

      test(
        'the ring sits centred under the arrow base, soft and grey',
        () async {
          const box = MoveraVehicleMarker.box;
          final at = await _pixels(MoveraVehicleMarker.paintMarker, box);
          final centre = Offset(
            MoveraVehicleMarker.anchor.dx * box,
            MoveraVehicleMarker.anchor.dy * box,
          );
          final r = MoveraVehicleMarker.ringSize / 2;
          // Beside the arrow's base and under its notch, inside the ring:
          // translucent grey.
          for (final d in [
            Offset(-r + 3, 0),
            Offset(r - 3, 0),
            const Offset(0, 8),
            const Offset(0, 12),
          ]) {
            final p = at(
              (centre.dx + d.dx).round(),
              (centre.dy + d.dy).round(),
            );
            expect(p.a, inInclusiveRange(.12, .35), reason: 'soft grey at $d');
            expect((p.r - p.b).abs(), lessThan(.1), reason: 'grey, not blue');
          }
          // The edge fades out: just outside the ring nothing is drawn.
          expect(at((centre.dx - r - 2).round(), centre.dy.round()).a, 0);
          expect(at(1, 1).a, 0);
          expect(at(box.round() - 2, box.round() - 2).a, 0);
          // The arrow's blue face is over the ring's centre line.
          final face = at(centre.dx.round(), (centre.dy - 6).round());
          expect(face.a, 1);
          expect(face.b, greaterThan(face.r));
        },
      );

      test('flat blue face, white outline, clear around it', () async {
        // Drawn in its 52-unit design box so the pixel spots stay fixed.
        final at = await _pixels(MoveraVehicleMarker.paintArrow, 52);
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

      testWidgets('CustomGoogleMap shows one billboard of the same size at '
          'every zoom, and no halo marker', (tester) async {
        final maps = GoogleMapsFlutterPlatform.instance;
        GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
        addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
        final icon = await tester.runAsync(MoveraVehicleMarker.createIcon);
        const other = Marker(markerId: MarkerId('pickup'), rotation: 40);
        await tester.pumpWidget(
          MaterialApp(
            home: CustomGoogleMap(
              initialPosition: const CameraPosition(
                target: LatLng(59.33, 18.06),
                zoom: 11,
              ),
              markers: {
                _own(0, icon: icon),
                other,
              },
            ),
          ),
        );
        await tester.pump();
        GoogleMap map() => tester.widget<GoogleMap>(find.byType(GoogleMap));
        Marker driver() =>
            map().markers.singleWhere((m) => m.markerId.value == 'driver');
        double width() => (driver().icon as BytesMapBitmap).width!;
        expect(
          map().markers.map((m) => m.markerId.value),
          unorderedEquals(['driver', 'pickup']),
        );
        expect(driver().flat, isFalse);
        expect(driver().anchor, MoveraVehicleMarker.anchor);
        final zoomedOut = width();
        expect(zoomedOut, MoveraVehicleMarker.box);
        // A zoom or tilt alone (inside one map style band) never rebuilds
        // the markers.
        final before = map().markers;
        map().onCameraMove!(
          const CameraPosition(
            target: LatLng(59.33, 18.06),
            zoom: 12,
            tilt: 30,
          ),
        );
        await tester.pump();
        expect(identical(map().markers, before), isTrue);
        map().onCameraMove!(
          const CameraPosition(
            target: LatLng(59.33, 18.06),
            zoom: 18,
            tilt: 67.5,
          ),
        );
        await tester.pump();
        expect(width(), zoomedOut);
        expect(
          map().markers.map((m) => m.markerId.value),
          unorderedEquals(['driver', 'pickup']),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('CustomGoogleMap turns the billboard by the map bearing '
          'only, tilt or not, without churning on small turns', (tester) async {
        final maps = GoogleMapsFlutterPlatform.instance;
        GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
        addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
        final icon = await tester.runAsync(MoveraVehicleMarker.createIcon);
        const other = Marker(markerId: MarkerId('pickup'), rotation: 40);
        await tester.pumpWidget(
          MaterialApp(
            home: CustomGoogleMap(
              initialPosition: const CameraPosition(
                target: LatLng(59.33, 18.06),
                zoom: 15,
                bearing: 30,
                tilt: 60,
              ),
              markers: {
                _own(90, icon: icon),
                other,
              },
            ),
          ),
        );
        await tester.pump();
        GoogleMap map() => tester.widget<GoogleMap>(find.byType(GoogleMap));
        Marker marker(String id) =>
            map().markers.singleWhere((m) => m.markerId.value == id);
        expect(marker('driver').rotation, closeTo(60, 1e-9));
        expect(marker('pickup').rotation, 40);

        // A course across a tilted north-up view: the heading itself, not
        // leaned by the tilt (that turned the arrow off the road).
        map().onCameraMove!(
          const CameraPosition(
            target: LatLng(59.33, 18.06),
            zoom: 15,
            bearing: 0,
            tilt: 60,
          ),
        );
        await tester.pump();
        expect(marker('driver').rotation, closeTo(90, 1e-9));
        await tester.pumpWidget(
          MaterialApp(
            home: CustomGoogleMap(
              initialPosition: const CameraPosition(
                target: LatLng(59.33, 18.06),
                zoom: 15,
                bearing: 0,
                tilt: 60,
              ),
              markers: {
                _own(45, icon: icon),
                other,
              },
            ),
          ),
        );
        await tester.pump();
        expect(marker('driver').rotation, closeTo(45, 1e-9));

        // Heading-up and tilted: points straight up.
        map().onCameraMove!(
          const CameraPosition(
            target: LatLng(59.33, 18.06),
            zoom: 15,
            bearing: 45,
            tilt: 58,
          ),
        );
        await tester.pump();
        expect(marker('driver').rotation, closeTo(0, 1e-9));
        // A half-degree camera wobble does not rebuild the markers.
        final before = map().markers;
        map().onCameraMove!(
          const CameraPosition(
            target: LatLng(59.33, 18.06),
            zoom: 15,
            bearing: 45.5,
            tilt: 58,
          ),
        );
        await tester.pump();
        expect(identical(map().markers, before), isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    },
  );
}

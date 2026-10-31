import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/widgets/custom_google_map.dart';
import 'package:movera/widgets/movera_vehicle_marker.dart';

import '../../integration_test/headless_map_platform.dart';

/// Owner 2026-10-31 (Rules plan/driver-pin/SPEC.md): the driver's own
/// position is a teal navigation arrowhead with a notch at its back, a
/// darker teal inner edge, a thin white outline and a soft shadow, about
/// 18 x 21 pt seen from above, in perspective with a mint-grey thickness on
/// a tilted map, ONE screen size at every zoom and tilt ("same in all zoom
/// steps"), pointing along the heading whatever the map's bearing, over a
/// grey halo of 60 pt on screen at every zoom.

/// The longest distance between two of [points].
double _diameter(List<Offset> points) {
  var most = 0.0;
  for (final a in points) {
    for (final b in points) {
      most = (a - b).distance > most ? (a - b).distance : most;
    }
  }
  return most;
}

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

/// The arrow for [rotation] and [tilt] drawn centred in a [size] square at
/// 1x; its pixels by offset from the centre.
Future<Color Function(double dx, double dy)> _arrow({
  double rotation = 0,
  double tilt = 0,
  int size = 80,
}) async {
  final recorder = ui.PictureRecorder();
  MoveraVehicleMarker.paint(
    Canvas(recorder),
    Offset(size / 2, size / 2),
    rotation: rotation,
    tilt: tilt,
  );
  final image = await recorder.endRecording().toImage(size, size);
  final data = (await image.toByteData())!;
  return (double dx, double dy) {
    final x = (size / 2 + dx).floor(), y = (size / 2 + dy).floor();
    final i = (y * size + x) * 4;
    return Color.fromARGB(
      data.getUint8(i + 3),
      data.getUint8(i),
      data.getUint8(i + 1),
      data.getUint8(i + 2),
    );
  };
}

int _rgb(Color c) =>
    ((c.r * 255).round() << 16) |
    ((c.g * 255).round() << 8) |
    (c.b * 255).round();

/// Colour distance, 0..255 per channel.
double _off(Color a, Color b) =>
    [
      (a.r - b.r).abs(),
      (a.g - b.g).abs(),
      (a.b - b.b).abs(),
    ].reduce((x, y) => x > y ? x : y) *
    255;

void main() {
  tearDown(MoveraVehicleMarker.debugReset);

  group('the shape and colours', () {
    test('about 18 x 21 pt seen from above, centred on the position', () {
      final flat = MoveraVehicleMarker.layers(rotation: 0, tilt: 0).bounds;
      expect(flat.width, closeTo(18, .75));
      expect(flat.height, closeTo(21, .75));
      expect(flat.center.dx, closeTo(0, .1));
      expect(flat.center.dy, closeTo(0, .1));
      expect(
        MoveraVehicleMarker.layers(rotation: 0, tilt: 0).wallBottom,
        isEmpty,
        reason: 'seen from above: no thickness',
      );
    });

    test('a notch at its back, between two rounded wings', () {
      final outline = MoveraVehicleMarker.outlinePoints(0);
      double maxY(bool Function(Offset) where) =>
          outline.where(where).map((p) => p.dy).reduce((a, b) => a > b ? a : b);
      final back = maxY((p) => p.dx.abs() > 5);
      final middle = maxY((p) => p.dx.abs() < .2);
      expect(back - middle, greaterThan(1.5), reason: 'the back is notched');
      // Rounded tip: no point at the raw corner (0, -12).
      final tip = outline.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
      expect(tip, greaterThan(-11.5));
    });

    test('teal face, darker inner edge, white outline, soft shadow', () async {
      final at = await _arrow();
      expect(_off(at(0, 2), MoveraVehicleMarker.fill), lessThan(3));
      expect(_rgb(MoveraVehicleMarker.fill), 0x00A8C0);
      expect(_rgb(MoveraVehicleMarker.innerEdge), 0x0090A8);
      // Walk left from the face across the left edge (y = 6, near the
      // back): teal, then the darker edge, then the white outline, then the
      // shadow, then nothing.
      final row = [for (var x = 0.0; x > -16; x -= .5) at(x, 6)];
      final edge = row.indexWhere(
        (c) => _off(c, MoveraVehicleMarker.innerEdge) < 12,
      );
      final rim = row.indexWhere((c) => c.r > .9 && c.g > .9 && c.b > .9);
      expect(edge, greaterThan(0), reason: 'darker teal inner edge');
      expect(rim, greaterThan(edge), reason: 'white outline outside it');
      // Past the outline's soft edge: the see-through shadow.
      final outside = row.sublist(rim).indexWhere((c) => c.a < .5);
      final shadow = row[rim + outside + 1];
      expect(shadow.a, inExclusiveRange(0, .3), reason: 'soft shadow');
      expect(shadow.r, lessThan(.3), reason: 'dark shadow');
      expect(at(-39, -39).a, 0);
    });

    test('tilted: in perspective, with a mint-grey thickness', () async {
      // Pointing across a fully tilted map: no longer than seen from above.
      final across = MoveraVehicleMarker.layers(rotation: 90, tilt: 67.5);
      final flatLong = _diameter(
        MoveraVehicleMarker.layers(rotation: 0, tilt: 0).outline,
      );
      expect(_diameter(across.outline), closeTo(flatLong, .05));
      // Pointing up it: foreshortened, in perspective.
      expect(
        MoveraVehicleMarker.layers(
          rotation: 0,
          tilt: 67.5,
        ).outline.map((p) => p.dy).reduce((a, b) => a > b ? a : b),
        lessThan(8),
      );
      final top = across.outline
          .map((p) => p.dy)
          .reduce((a, b) => a > b ? a : b);
      final bottom = across.wallBottom
          .map((p) => p.dy)
          .reduce((a, b) => a > b ? a : b);
      expect(bottom - top, inInclusiveRange(3, 4.5), reason: '3-4 pt thick');
      // Its wall under the face is pale mint-grey.
      // Pointing up the screen: under its back notch, just above the
      // wall's foot.
      final at = await _arrow(tilt: 67.5);
      final up = MoveraVehicleMarker.layers(rotation: 0, tilt: 67.5);
      final foot = up.wallBottom
          .where((p) => p.dx.abs() < 1.5)
          .map((p) => p.dy)
          .reduce((a, b) => a > b ? a : b);
      final wall = at(0, foot - 1.2);
      expect(wall.a, 1);
      expect(_off(wall, MoveraVehicleMarker.wallTop), lessThan(30));
      expect(wall.g, greaterThan(wall.r), reason: 'mint, not plain grey');
    });

    test('one screen size at every tilt and rotation: the long side never '
        'changes', () {
      final flatLong = _diameter(
        MoveraVehicleMarker.layers(rotation: 0, tilt: 0).outline,
      );
      expect(flatLong, closeTo(MoveraVehicleMarker.longSide, 1e-9));
      // Tip to wing of the 18 x 21 pt arrow.
      expect(flatLong, closeTo(22, 1));
      for (final rotation in [0.0, 30.0, 90.0, 135.0, 270.0]) {
        for (final tilt in [0.0, 10.0, 28.9, 45.0, 57.9, 67.5]) {
          final layers = MoveraVehicleMarker.layers(
            rotation: rotation,
            tilt: tilt,
          );
          expect(
            _diameter(layers.outline),
            closeTo(flatLong, .05),
            reason: 'rotation $rotation, tilt $tilt',
          );
          // The whole picture (with its thickness) stays about that size.
          final box = layers.bounds;
          expect(
            box.longestSide,
            lessThan(flatLong + 4),
            reason: 'rotation $rotation, tilt $tilt',
          );
        }
      }
    });

    test('drawn at the device pixel ratio, centred', () async {
      for (final density in [1.0, 2.0, 3.0]) {
        final png = await MoveraVehicleMarker.png(density: density);
        final image = await decodeImageFromList(png!);
        expect(image.width, (MoveraVehicleMarker.box * density).round());
        expect(image.height, image.width);
      }
      expect(MoveraVehicleMarker.anchor, const Offset(.5, .5));
      final icon = await MoveraVehicleMarker.createIcon() as BytesMapBitmap;
      expect(icon.width, MoveraVehicleMarker.box);
      expect(icon.height, MoveraVehicleMarker.box);
      final image = await decodeImageFromList(icon.byteData);
      expect(
        image.width,
        (MoveraVehicleMarker.box * MoveraVehicleMarker.devicePixelRatio)
            .round(),
      );
    });
  });

  group('rotation', () {
    test('screen rotation is the heading minus the map bearing', () {
      double r(double h, double b) => MoveraVehicleMarker.screenRotation(h, b);
      expect(r(90, 90), closeTo(0, 1e-9));
      expect(r(135, 0), closeTo(135, 1e-9));
      expect(r(90, 30), closeTo(60, 1e-9));
      expect(r(10, 30), closeTo(340, 1e-9));
      expect(r(-10, 0), closeTo(350, 1e-9));
    });

    test('seen from above: one flat picture turned to the heading, so '
        'Maps turns it with the map bearing', () {
      for (final bearing in [0.0, 30.0, 200.0]) {
        final v = MoveraVehicleMarker.view(
          heading: 135,
          bearing: bearing,
          tilt: 0,
        );
        expect(v.flat, isTrue);
        expect(v.markerRotation, 135);
        expect(v.rotation, 0);
      }
    });

    test('tilted: the heading less the bearing drawn into the picture', () {
      final v = MoveraVehicleMarker.view(heading: 90, bearing: 30, tilt: 60);
      expect(v.flat, isFalse);
      expect(v.markerRotation, 0);
      expect(v.rotation, 60);
      expect(v.tilt, 60);
      // Heading-up: straight up.
      expect(
        MoveraVehicleMarker.view(heading: 45, bearing: 45, tilt: 58).rotation,
        0,
      );
      // A half-degree wobble is the same picture.
      expect(
        MoveraVehicleMarker.view(heading: 45, bearing: 45.5, tilt: 58.4),
        MoveraVehicleMarker.view(heading: 45, bearing: 45, tilt: 58),
      );
    });

    test('the tip points along the rotation', () async {
      for (final (rotation, tip, side) in [
        (0.0, const Offset(0, -6), const Offset(6, 0)),
        (90.0, const Offset(6, 0), const Offset(0, -6)),
        (180.0, const Offset(0, 6), const Offset(-6, 0)),
        (270.0, const Offset(-6, 0), const Offset(0, 6)),
      ]) {
        final at = await _arrow(rotation: rotation);
        expect(
          _off(at(tip.dx, tip.dy), MoveraVehicleMarker.fill),
          lessThan(3),
          reason: 'teal at the tip, rotation $rotation',
        );
        expect(
          _off(at(side.dx, side.dy), MoveraVehicleMarker.fill),
          greaterThan(20),
          reason: 'not teal beside the tip, rotation $rotation',
        );
      }
    });
  });

  group('halo', () {
    test('one 60 pt see-through grey disc, no border', () async {
      expect(MoveraVehicleMarker.haloRadius, 60);
      expect(MoveraVehicleMarker.haloBox, 120);
      final png = await MoveraVehicleMarker.haloPng(density: 1);
      final image = await decodeImageFromList(png!);
      expect(image.width, 120);
      final data = (await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      ))!;
      Color at(int x, int y) {
        final i = (y * 120 + x) * 4;
        return Color.fromARGB(
          data.getUint8(i + 3),
          data.getUint8(i),
          data.getUint8(i + 1),
          data.getUint8(i + 2),
        );
      }

      final middle = at(60, 60);
      expect(middle.a, closeTo(.35, .01));
      // Straight (not premultiplied) colour of the halo: #7797A8.
      expect(
        _off(middle.withValues(alpha: 1), MoveraVehicleMarker.halo),
        lessThan(4),
      );
      expect(at(60, 3).a, closeTo(.35, .01), reason: 'flat up to its edge');
      expect(at(2, 2).a, 0, reason: 'a circle: nothing in the corner');
    });
  });

  group('pictures', () {
    test(
      'never a Google pin: a transparent pixel until the arrow is drawn',
      () async {
        final placeholder = MoveraVehicleMarker.placeholder as BytesMapBitmap;
        expect(placeholder.width, 1);
        final image = await decodeImageFromList(placeholder.byteData);
        expect([image.width, image.height], [1, 1]);
        final data = (await image.toByteData())!;
        expect(data.getUint8(3), 0, reason: 'fully transparent');
      },
    );

    test(
      'at most 64 tilted pictures are kept, least recently used first',
      () async {
        PositionArrowView v(double heading) =>
            MoveraVehicleMarker.view(heading: heading, bearing: 0, tilt: 60);
        final first = v(0);
        await MoveraVehicleMarker.makeIcon(first);
        for (var h = 2.0; h < 2 * 80; h += 2) {
          await MoveraVehicleMarker.makeIcon(v(h));
          // Keep the first one in use.
          expect(MoveraVehicleMarker.iconFor(first), isNotNull);
        }
        expect(
          MoveraVehicleMarker.debugKeptPictures,
          MoveraVehicleMarker.keptPictures,
        );
        expect(MoveraVehicleMarker.iconFor(first), isNotNull, reason: 'in use');
        expect(MoveraVehicleMarker.iconFor(v(2)), isNull, reason: 'evicted');
      },
    );

    test('the pictures around the one shown are drawn ahead', () {
      final view = MoveraVehicleMarker.view(heading: 90, bearing: 0, tilt: 60);
      final around = MoveraVehicleMarker.neighbours(view);
      expect(
        around.map((n) => n.key),
        containsAll(['88/60', '92/60', '84/60', '96/60', '90/57', '90/63']),
      );
      expect(around.map((n) => n.key), isNot(contains(view.key)));
      expect(around.length, lessThan(MoveraVehicleMarker.keptPictures));
      expect(
        MoveraVehicleMarker.neighbours(
          MoveraVehicleMarker.view(heading: 0, bearing: 0, tilt: 0),
        ),
        isEmpty,
      );
    });
  });

  group('on the map (phones)', () {
    late GoogleMapsFlutterPlatform maps;
    setUp(() {
      maps = GoogleMapsFlutterPlatform.instance;
      GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    });
    tearDown(() => GoogleMapsFlutterPlatform.instance = maps);

    GoogleMap map(WidgetTester tester) =>
        tester.widget<GoogleMap>(find.byType(GoogleMap));
    Marker driver(WidgetTester tester) =>
        map(tester).markers.singleWhere((m) => m.markerId.value == 'driver');
    Marker? halo(WidgetTester tester) => map(tester).markers
        .where((m) => m.markerId.value == MoveraVehicleMarker.haloId)
        .firstOrNull;

    Future<void> move(
      WidgetTester tester,
      CameraPosition camera, {
      double heading = 0,
    }) async {
      map(tester).onCameraMove!(camera);
      await tester.pump();
      // Let a new picture finish drawing.
      final view = MoveraVehicleMarker.view(
        heading: heading,
        bearing: camera.bearing,
        tilt: camera.tilt,
      );
      await tester.runAsync(() async {
        await MoveraVehicleMarker.makeIcon(view);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
    }

    testWidgets('the same size at every zoom; flat and centred from above', (
      tester,
    ) async {
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
              _own(30, icon: icon),
              other,
            },
          ),
        ),
      );
      await tester.pump();
      expect(
        map(tester).markers.map((m) => m.markerId.value),
        unorderedEquals(['driver', 'pickup']),
      );
      expect(driver(tester).flat, isTrue);
      expect(driver(tester).rotation, 30);
      expect(driver(tester).anchor, const Offset(.5, .5));
      expect(identical(driver(tester).icon, icon), isTrue);
      for (final zoom in [5.0, 9.0, 11.9]) {
        await move(
          tester,
          CameraPosition(target: const LatLng(59.33, 18.06), zoom: zoom),
          heading: 30,
        );
        expect(identical(driver(tester).icon, icon), isTrue, reason: '$zoom');
      }
      // Tilted: a picture of the same box at every zoom.
      final sizes = <double>{};
      for (final zoom in [15.5, 17.0, 19.0]) {
        await move(
          tester,
          CameraPosition(
            target: const LatLng(59.33, 18.06),
            zoom: zoom,
            tilt: 67.5,
          ),
          heading: 30,
        );
        final tilted = driver(tester).icon as BytesMapBitmap;
        sizes
          ..add(tilted.width!)
          ..add(tilted.height!);
        expect(driver(tester).flat, isFalse);
      }
      expect(sizes, {MoveraVehicleMarker.box});
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('keeps pointing along the heading as the map turns', (
      tester,
    ) async {
      final icon = await tester.runAsync(MoveraVehicleMarker.createIcon);
      await tester.pumpWidget(
        MaterialApp(
          home: CustomGoogleMap(
            initialPosition: const CameraPosition(
              target: LatLng(59.33, 18.06),
              zoom: 11,
              bearing: 30,
            ),
            markers: {_own(90, icon: icon)},
          ),
        ),
      );
      await tester.pump();
      // From above: flat, turned by the compass heading; Maps turns a flat
      // marker with the map.
      expect(driver(tester).flat, isTrue);
      expect(driver(tester).rotation, 90);
      // Tilted, map turned 30: the picture is drawn turned 60 on screen.
      await move(
        tester,
        const CameraPosition(
          target: LatLng(59.33, 18.06),
          zoom: 16,
          bearing: 30,
          tilt: 60,
        ),
        heading: 90,
      );
      final at60 = MoveraVehicleMarker.iconFor(
        MoveraVehicleMarker.view(heading: 90, bearing: 30, tilt: 60),
      );
      expect(at60, isNotNull);
      expect(identical(driver(tester).icon, at60), isTrue);
      expect(driver(tester).rotation, 0);
      expect(driver(tester).flat, isFalse);
      // Heading-up: straight up.
      await move(
        tester,
        const CameraPosition(
          target: LatLng(59.33, 18.06),
          zoom: 16,
          bearing: 90,
          tilt: 60,
        ),
        heading: 90,
      );
      final up = MoveraVehicleMarker.iconFor(
        MoveraVehicleMarker.view(heading: 90, bearing: 90, tilt: 60),
      );
      expect(identical(driver(tester).icon, up), isTrue);
      // A half-degree camera wobble does not rebuild the markers.
      final before = map(tester).markers;
      map(tester).onCameraMove!(
        const CameraPosition(
          target: LatLng(59.33, 18.06),
          zoom: 16,
          bearing: 90.5,
          tilt: 60.3,
        ),
      );
      await tester.pump();
      expect(identical(map(tester).markers, before), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a grey halo under the position: one screen-facing 60 pt '
        'picture at every zoom and tilt, not tappable', (tester) async {
      final icon = await tester.runAsync(MoveraVehicleMarker.createIcon);
      final haloIcon = await tester.runAsync(
        MoveraVehicleMarker.createHaloIcon,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CustomGoogleMap(
            initialPosition: const CameraPosition(
              target: LatLng(59.33, 18.06),
              zoom: 18,
            ),
            markers: {_own(0, icon: icon)},
          ),
        ),
      );
      await tester.pump();
      final first = halo(tester)!;
      expect(identical(first.icon, haloIcon), isTrue);
      expect((first.icon as BytesMapBitmap).width, 120);
      expect(first.position, const LatLng(59.33, 18.06));
      expect(first.anchor, const Offset(.5, .5));
      expect(first.flat, isFalse, reason: 'faces the screen: a circle');
      expect(first.consumeTapEvents, isTrue, reason: 'taps do nothing');
      expect(first.zIndexInt, driver(tester).zIndexInt - 1);
      expect(map(tester).circles, isEmpty, reason: 'no ground circle');
      for (final camera in const [
        CameraPosition(target: LatLng(59.33, 18.06), zoom: 14),
        CameraPosition(target: LatLng(59.33, 18.06), zoom: 17, tilt: 60),
        CameraPosition(target: LatLng(59.33, 18.06), zoom: 19, tilt: 67.5),
      ]) {
        await move(tester, camera);
        expect(halo(tester), first, reason: '$camera');
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('while a tilted picture is drawn, the flat arrow stands in, '
        'turned by the heading: never the wrong way', (tester) async {
      final icon = await tester.runAsync(MoveraVehicleMarker.createIcon);
      await tester.pumpWidget(
        MaterialApp(
          home: CustomGoogleMap(
            initialPosition: const CameraPosition(
              target: LatLng(59.33, 18.06),
              zoom: 16,
              bearing: 10,
              tilt: 60,
            ),
            markers: {_own(130, icon: icon)},
          ),
        ),
      );
      await tester.pump();
      // No tilted picture yet for 130 - 10 = 120.
      expect(driver(tester).flat, isTrue);
      expect(driver(tester).rotation, 130);
      expect(identical(driver(tester).icon, icon), isTrue);
      await tester.runAsync(() async {
        await MoveraVehicleMarker.makeIcon(
          MoveraVehicleMarker.view(heading: 130, bearing: 10, tilt: 60),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      expect(driver(tester).flat, isFalse);
      expect(driver(tester).rotation, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}

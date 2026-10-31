import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/location/own_position_accuracy.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'web_map_bitmap.dart';

/// How the own position arrow goes to the map for one camera: its picture
/// (rotation on screen and tilt, both rounded to a bucket), whether it is a
/// flat marker, and the marker rotation.
@immutable
class PositionArrowView {
  const PositionArrowView._({
    required this.flat,
    required this.rotation,
    required this.tilt,
    required this.markerRotation,
  });

  /// True on a map seen from above: one picture pointing up, laid flat on
  /// the map and turned to the compass heading, so Maps turns it with the
  /// map's bearing on the same frame.
  final bool flat;

  /// The picture's rotation on the screen (degrees, clockwise), baked in.
  final double rotation;

  /// The camera tilt the picture is drawn for (degrees).
  final double tilt;

  /// The marker's own rotation: the heading when [flat], else 0.
  final double markerRotation;

  /// The cache key of the picture.
  String get key => '${rotation.round()}/${tilt.round()}';

  @override
  bool operator ==(Object other) =>
      other is PositionArrowView &&
      other.flat == flat &&
      other.rotation == rotation &&
      other.tilt == tilt &&
      other.markerRotation == markerRotation;

  @override
  int get hashCode => Object.hash(flat, rotation, tilt, markerRotation);
}

/// The driver's own position on every driver map (Home, going to pickup,
/// on trip): a teal navigation arrowhead (owner 2026-10-31, Rules
/// plan/driver-pin/SPEC.md).
///
/// - A rounded arrowhead with a notch at its back, all corners rounded,
///   teal #00A8C0 with a darker teal inner edge #0090A8, a thin white
///   outline (#F0FAFA, 1.5 pt) and a soft dark shadow (blur ~3 pt, 25 %).
/// - About 18 x 21 pt on a map seen from above, the same size at every
///   zoom (a screen-fixed marker, drawn at the device pixel ratio).
/// - On a tilted map it lies on the road in perspective, with a pale
///   mint-grey thickness (#C8E0E0 top to #B0CCCC bottom) and its shadow
///   under it; at the full driving tilt it is about 39 x 21 pt on screen
///   when it points across the screen.
/// - It points along the driver's heading, and keeps pointing there when
///   the map turns ([view]).
/// - Under it, a flat see-through grey halo for the GPS accuracy, kept
///   between [haloMinRadius] and [haloMaxRadius] points on screen
///   ([haloRadiusMeters]); no border, no pulse.
///
/// Phones get a bitmap per (rotation, tilt) bucket; web/driver_map_camera.js
/// draws the same geometry as native Maps symbols ([webCameraTag]); keep the
/// numbers in step.
class MoveraVehicleMarker {
  const MoveraVehicleMarker._();

  /// Web: the marker title by which web/driver_map_camera.js knows the own
  /// car (and draws its arrow and halo); it strips the title and the raster
  /// icon, so neither is ever shown.
  static const String webCameraTag = 'Driver camera vehicle';

  /// The own car's marker title: [webCameraTag] on the web (driver group
  /// 3: a translated title made the web map show the car's raster picture
  /// in a broken image box), "Your car" elsewhere.
  static String get ownTitle => kIsWeb ? webCameraTag : tr.mapYourCar;

  // ---- Colours (SPEC) ----

  /// The arrow's teal face.
  static const Color fill = Color(0xFF00A8C0);

  /// The darker teal band just inside the outline.
  static const Color innerEdge = Color(0xFF0090A8);

  /// The thin white (very light cyan) outline.
  static const Color outline = Color(0xFFF0FAFA);

  /// The tilted arrow's thickness: top and bottom of its side wall.
  static const Color wallTop = Color(0xFFC8E0E0);
  static const Color wallBottom = Color(0xFFB0CCCC);

  /// The soft dark shadow, 25 %.
  static const Color shadow = Color(0x40000000);

  /// The accuracy halo: grey-blue at 35 % (reads #CBD6DC on a light map).
  static const Color halo = Color(0xFF7797A8);
  static const double haloOpacity = .35;

  // ---- Sizes (points) ----

  /// The outline's width outside the inner edge.
  static const double outlineWidth = 1.5;

  /// The darker inner edge's width.
  static const double innerEdgeWidth = 1;

  /// The shadow's blur.
  static const double shadowBlur = 3;

  /// The picture's square box; the arrow's centre is the box's centre (the
  /// marker's anchor), with room for the largest tilted arrow and shadow.
  static const double box = 64;

  /// The marker anchor: the arrow's centre.
  static const Offset anchor = Offset(.5, .5);

  /// The halo's radius on screen stays between these (points).
  static const double haloMinRadius = 60;
  static const double haloMaxRadius = 110;

  /// The steepest driver map tilt (DriverCameraPolicy.maxTilt).
  static const double maxTilt = 67.5;

  /// A map tilted less than this is drawn as seen from above.
  static const double flatTilt = 1;

  /// How much larger the arrow lies on a fully tilted map (39 / 21 pt).
  static const double tiltGrowth = .86;

  /// Rotation and tilt buckets of the phone bitmaps (degrees).
  static const double rotationStep = 2;
  static const double tiltStep = 3;

  // The arrowhead pointing up, centred on (0, 0), before rounding: tip,
  // right wing, back notch, left wing (points). With the 1.5 pt outline
  // it is about 18 x 21 pt.
  static const List<Offset> _raw = [
    Offset(0, -12),
    Offset(8.9, 10),
    Offset(0, 7.4),
    Offset(-8.9, 10),
  ];
  static const List<bool> _convex = [true, true, false, true];
  static const double _cornerRadius = 1.8;
  static const double _notchRadius = 2.5;

  /// How much larger the arrow lies on the map at [tilt].
  static double scaleForTilt(double tilt) =>
      1 + tiltGrowth * (tilt.clamp(0, maxTilt) / maxTilt);

  /// The arrow's thickness (height above the road) at [tilt]: 3.5 pt on
  /// screen at the full tilt.
  static double thickness(double tilt) => 2.05 * scaleForTilt(tilt);

  /// The arrow's outline, pointing up and centred on (0, 0), grown by
  /// [offset] points (negative: shrunk), its corners rounded.
  static List<Offset> outlinePoints(double offset, {int arcSteps = 6}) {
    final grown = _offsetPolygon(_raw, offset);
    final points = <Offset>[];
    for (var i = 0; i < grown.length; i++) {
      final radius = _convex[i]
          ? _cornerRadius + offset
          : math.max(_notchRadius - offset, .05);
      points.addAll(
        _fillet(
          grown[(i - 1 + grown.length) % grown.length],
          grown[i],
          grown[(i + 1) % grown.length],
          math.max(radius, .05),
          arcSteps,
        ),
      );
    }
    return points;
  }

  /// [point] of the arrow (pointing up, centred on (0, 0)) on screen, with
  /// the arrow turned [rotation] degrees clockwise, lying on a map tilted
  /// [tilt] degrees, at [height] points above the road.
  static Offset project(
    Offset point, {
    required double rotation,
    required double tilt,
    double height = 0,
  }) {
    final s = scaleForTilt(tilt);
    final r = rotation * math.pi / 180;
    final t = tilt.clamp(0, 89) * math.pi / 180;
    final x = point.dx * s, y = point.dy * s;
    final sx = x * math.cos(r) - y * math.sin(r);
    final sy = x * math.sin(r) + y * math.cos(r);
    return Offset(sx, sy * math.cos(t) - height * math.sin(t));
  }

  /// The arrow's layers on screen, around the marker's anchor.
  static PositionArrowLayers layers({
    required double rotation,
    required double tilt,
  }) {
    final tilted = tilt >= flatTilt;
    final h = tilted ? thickness(tilt) : 0.0;
    List<Offset> at(double offset, double height) => [
      for (final p in outlinePoints(offset))
        project(p, rotation: rotation, tilt: tilt, height: height),
    ];
    final rim = at(outlineWidth, h);
    return PositionArrowLayers(
      shadow: [
        for (final p in at(outlineWidth + .5, 0)) p + Offset(0, tilted ? 1 : 0),
      ],
      wallBottom: tilted ? at(outlineWidth, 0) : const [],
      wallTop: tilted ? rim : const [],
      outline: rim,
      edge: at(0, h),
      face: at(-innerEdgeWidth, h),
    );
  }

  /// Paints the arrow for [rotation] (degrees clockwise on screen) and
  /// [tilt] with its centre at [centre].
  static void paint(
    Canvas canvas,
    Offset centre, {
    double rotation = 0,
    double tilt = 0,
  }) {
    final l = layers(rotation: rotation, tilt: tilt);
    Path path(List<Offset> points) =>
        Path()..addPolygon([for (final p in points) p + centre], true);
    canvas.drawPath(
      path(l.shadow),
      Paint()
        ..color = shadow
        ..maskFilter = const ui.MaskFilter.blur(
          ui.BlurStyle.normal,
          shadowBlur / 2,
        ),
    );
    if (l.wallBottom.isNotEmpty) {
      // The road outline and one quad per edge up to the top, all wound
      // the same way so the non-zero fill is their union.
      final wall = Path()..fillType = PathFillType.nonZero;
      final turn = _area(l.wallBottom).sign;
      wall.addPath(path(l.wallBottom), Offset.zero);
      final n = l.wallBottom.length;
      for (var i = 0; i < n; i++) {
        final j = (i + 1) % n;
        final quad = [
          l.wallTop[i],
          l.wallTop[j],
          l.wallBottom[j],
          l.wallBottom[i],
        ];
        wall.addPath(
          path(_area(quad).sign == turn ? quad : quad.reversed.toList()),
          Offset.zero,
        );
      }
      final top = l.wallTop.map((p) => p.dy).reduce(math.min) + centre.dy;
      final bottom = l.wallBottom.map((p) => p.dy).reduce(math.max) + centre.dy;
      canvas.drawPath(
        wall,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(centre.dx, top),
            Offset(centre.dx, bottom),
            const [wallTop, wallBottom],
          ),
      );
    }
    canvas
      ..drawPath(path(l.outline), Paint()..color = outline)
      ..drawPath(path(l.edge), Paint()..color = innerEdge)
      ..drawPath(path(l.face), Paint()..color = fill);
  }

  /// The arrow's picture for [heading] (compass degrees) on a map turned to
  /// [bearing] and tilted [tilt] degrees.
  static PositionArrowView view({
    required double heading,
    required double bearing,
    required double tilt,
  }) {
    if (tilt < flatTilt) {
      return PositionArrowView._(
        flat: true,
        rotation: 0,
        tilt: 0,
        markerRotation: _normal(heading),
      );
    }
    final rotation = _normal(
      (screenRotation(heading, bearing) / rotationStep).round() * rotationStep,
    );
    final t = math.min(
      maxTilt,
      math.max(tiltStep, (tilt / tiltStep).round() * tiltStep),
    );
    return PositionArrowView._(
      flat: false,
      rotation: rotation,
      tilt: t,
      markerRotation: 0,
    );
  }

  /// The rotation the arrow needs on screen to point along [heading]
  /// (compass degrees, 0 north, clockwise) on a map turned to [bearing].
  static double screenRotation(double heading, double bearing) =>
      _normal(heading - bearing);

  static double _normal(double degrees) => (degrees % 360 + 360) % 360;

  /// The halo's radius in metres: the fix's [accuracyMeters], kept between
  /// [haloMinRadius] and [haloMaxRadius] points on screen at [zoom] and
  /// [latitude] (Google's world is 256 points wide at zoom 0).
  static double haloRadiusMeters({
    required double? accuracyMeters,
    required double latitude,
    required double zoom,
  }) {
    final lat = latitude.clamp(-85.0, 85.0) * math.pi / 180;
    final perPoint = 156543.03392 * math.cos(lat) / math.pow(2, zoom);
    final accuracy =
        accuracyMeters != null && accuracyMeters.isFinite && accuracyMeters > 0
        ? accuracyMeters
        : 0.0;
    return accuracy.clamp(haloMinRadius * perPoint, haloMaxRadius * perPoint);
  }

  /// The latest GPS accuracy of the driver's own position (metres), for
  /// the halo; null when unknown (the halo then keeps its smallest size).
  static ValueNotifier<double?> get accuracyMeters =>
      OwnPositionAccuracy.meters;

  /// The pixel density the pictures are drawn at: the device's.
  static double get devicePixelRatio {
    final views = ui.PlatformDispatcher.instance.views;
    final ratio = views.isEmpty ? 3.0 : views.first.devicePixelRatio;
    return ratio.isFinite && ratio > 0 ? ratio.clamp(1.0, 4.0) : 3.0;
  }

  static BitmapDescriptor? _icon;

  /// The flat arrow's icon, ready once [createIcon] has completed.
  static BitmapDescriptor? get icon => _icon;

  /// The flat arrow (pointing up, seen from above) as a marker icon, made
  /// once. Phones: CustomGoogleMap swaps in the tilted pictures; web: the
  /// map adapter draws the arrow itself and never shows this picture.
  static Future<BitmapDescriptor> createIcon() async {
    if (_icon != null) return _icon!;
    final png = await _png(rotation: 0, tilt: 0);
    if (png == null) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
    }
    // Web: one URL for the picture, not a new Blob URL per push
    // (driver-u174).
    return _icon ??=
        WebMapBitmaps.of(png, width: box, height: box) ??
        BitmapDescriptor.bytes(png, width: box, height: box);
  }

  static final Map<String, BitmapDescriptor> _views = {};
  static final Map<String, Future<BitmapDescriptor?>> _making = {};

  /// The picture for [view], if it was made already.
  static BitmapDescriptor? iconFor(PositionArrowView view) =>
      view.flat ? _icon : _views[view.key];

  /// Makes the picture for [view] (once).
  static Future<BitmapDescriptor?> makeIcon(PositionArrowView view) {
    if (view.flat) return createIcon();
    final ready = _views[view.key];
    if (ready != null) return SynchronousFuture(ready);
    return _making[view.key] ??= _png(rotation: view.rotation, tilt: view.tilt)
        .then((png) {
          _making.remove(view.key);
          if (png == null) return null;
          return _views[view.key] = BitmapDescriptor.bytes(
            png,
            width: box,
            height: box,
          );
        });
  }

  /// Tests: forgets every picture made.
  @visibleForTesting
  static void debugReset() {
    _icon = null;
    _views.clear();
    _making.clear();
    accuracyMeters.value = null;
  }

  /// The arrow drawn in the [box] square at [density] pixels per point.
  static Future<Uint8List?> png({
    double rotation = 0,
    double tilt = 0,
    double? density,
  }) => _png(rotation: rotation, tilt: tilt, density: density);

  static Future<Uint8List?> _png({
    required double rotation,
    required double tilt,
    double? density,
  }) async {
    final ratio = density ?? devicePixelRatio;
    final pixels = (box * ratio).round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(ratio);
    paint(
      canvas,
      const Offset(box / 2, box / 2),
      rotation: rotation,
      tilt: tilt,
    );
    final image = await recorder.endRecording().toImage(pixels, pixels);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }

  // Twice the signed area of [points].
  static double _area(List<Offset> points) {
    var area = 0.0;
    for (var i = 0; i < points.length; i++) {
      final a = points[i], b = points[(i + 1) % points.length];
      area += a.dx * b.dy - b.dx * a.dy;
    }
    return area;
  }

  // Each edge moved [d] outwards; the new corners where they meet.
  static List<Offset> _offsetPolygon(List<Offset> points, double d) {
    final n = points.length;
    final sign = _area(points) > 0 ? 1.0 : -1.0;
    final lines = <(Offset, Offset)>[];
    for (var i = 0; i < n; i++) {
      final a = points[i], b = points[(i + 1) % n];
      final dir = b - a;
      final normal = Offset(sign * dir.dy, -sign * dir.dx) / dir.distance;
      lines.add((a + normal * d, dir));
    }
    return [
      for (var i = 0; i < n; i++) _meet(lines[(i - 1 + n) % n], lines[i]),
    ];
  }

  static Offset _meet((Offset, Offset) l1, (Offset, Offset) l2) {
    final (p1, d1) = l1;
    final (p2, d2) = l2;
    final den = d1.dx * d2.dy - d1.dy * d2.dx;
    final t = ((p2.dx - p1.dx) * d2.dy - (p2.dy - p1.dy) * d2.dx) / den;
    return p1 + d1 * t;
  }

  // The corner [v] (between [p] and [q]) rounded with [radius].
  static List<Offset> _fillet(
    Offset p,
    Offset v,
    Offset q,
    double radius,
    int steps,
  ) {
    final a = (p - v) / (p - v).distance;
    final b = (q - v) / (q - v).distance;
    final cos = (a.dx * b.dx + a.dy * b.dy).clamp(-1.0, 1.0);
    final half = math.acos(cos) / 2;
    final along = radius / math.tan(half);
    final t1 = v + a * along, t2 = v + b * along;
    final mid = (a + b) / (a + b).distance;
    final c = v + mid * (radius / math.sin(half));
    final a1 = math.atan2(t1.dy - c.dy, t1.dx - c.dx);
    final a2 = math.atan2(t2.dy - c.dy, t2.dx - c.dx);
    final sweep = (a2 - a1 + math.pi) % (2 * math.pi) - math.pi;
    return [
      for (var k = 0; k <= steps; k++)
        c +
            Offset(
                  math.cos(a1 + sweep * k / steps),
                  math.sin(a1 + sweep * k / steps),
                ) *
                radius,
    ];
  }
}

/// The arrow's layers on screen (points around the marker's anchor), from
/// bottom to top.
@immutable
class PositionArrowLayers {
  const PositionArrowLayers({
    required this.shadow,
    required this.wallBottom,
    required this.wallTop,
    required this.outline,
    required this.edge,
    required this.face,
  });

  /// The soft shadow on the road.
  final List<Offset> shadow;

  /// The tilted arrow's side wall: its outline on the road and on top
  /// (empty when seen from above).
  final List<Offset> wallBottom;
  final List<Offset> wallTop;

  /// The white outline, the darker inner edge and the teal face.
  final List<Offset> outline;
  final List<Offset> edge;
  final List<Offset> face;

  /// The box around the arrow itself (outline and wall, no shadow).
  Rect get bounds {
    final all = [...outline, ...wallBottom];
    var r = Rect.fromPoints(all.first, all.first);
    for (final p in all) {
      r = r.expandToInclude(Rect.fromPoints(p, p));
    }
    return r;
  }
}

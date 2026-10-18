import 'dart:math' as math;
import 'dart:ui';

import 'package:movera/core/geo/geo_point.dart';

/// One point the camera must show, with how far its drawing reaches
/// around it on screen (a pin with its time chip), in logical pixels.
class RouteFitPoint {
  const RouteFitPoint(
    this.point, {
    this.left = 0,
    this.right = 0,
    this.up = 0,
    this.down = 0,
  });

  final GeoPoint point;
  final double left;
  final double right;
  final double up;
  final double down;
}

/// Where the camera goes so a whole route fits: its target and zoom.
class RouteCameraFit {
  const RouteCameraFit(this.target, this.zoom);

  final GeoPoint target;
  final double zoom;

  /// Practically the same camera: no need to move again.
  bool closeTo(RouteCameraFit other) {
    if ((zoom - other.zoom).abs() > 0.04) return false;
    // Within about two screen pixels at this zoom.
    final scale = 256 * math.pow(2, zoom).toDouble();
    final a = _world(target), b = _world(other.target);
    return ((a.dx - b.dx) * scale).abs() < 2 &&
        ((a.dy - b.dy) * scale).abs() < 2;
  }
}

/// Web Mercator, 0..1 across the world.
Offset _world(GeoPoint p) {
  final lat = p.latitude.clamp(-85.0, 85.0) * math.pi / 180;
  return Offset(
    (p.longitude + 180) / 360,
    (1 - math.log(math.tan(lat) + 1 / math.cos(lat)) / math.pi) / 2,
  );
}

GeoPoint _geo(Offset w) {
  final n = math.pi - 2 * math.pi * w.dy;
  final lat = 180 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
  return GeoPoint(lat, w.dx * 360 - 180);
}

/// Screen position of [point] for [fit] when the camera target sits at
/// [targetAt] on screen.
Offset routeFitProject(RouteCameraFit fit, Offset targetAt, GeoPoint point) {
  final scale = 256 * math.pow(2, fit.zoom).toDouble();
  final t = _world(fit.target), p = _world(point);
  return targetAt + (p - t) * scale;
}

/// The camera that shows every one of [points] (and what is drawn around
/// them) inside [free], the map area no island, sheet or orb covers. The
/// zoom follows the route's size: a short trip comes close, a long one
/// zooms out. [targetAt] is where the map puts its camera target on
/// screen (the middle of the view, or of the map's padded area).
RouteCameraFit? fitRouteCamera({
  required List<RouteFitPoint> points,
  required Rect free,
  required Offset targetAt,
  double minZoom = 3,
  double maxZoom = 17,
}) {
  if (points.isEmpty || free.width <= 0 || free.height <= 0) return null;
  final world = [for (final p in points) _world(p.point)];
  ({double left, double right, double top, double bottom}) extent(
    double scale,
  ) {
    var left = double.infinity, right = -double.infinity;
    var top = double.infinity, bottom = -double.infinity;
    for (var i = 0; i < points.length; i++) {
      final x = world[i].dx * scale, y = world[i].dy * scale;
      left = math.min(left, x - points[i].left);
      right = math.max(right, x + points[i].right);
      top = math.min(top, y - points[i].up);
      bottom = math.max(bottom, y + points[i].down);
    }
    return (left: left, right: right, top: top, bottom: bottom);
  }

  bool fits(double zoom) {
    final e = extent(256 * math.pow(2, zoom).toDouble());
    return e.right - e.left <= free.width && e.bottom - e.top <= free.height;
  }

  // The largest zoom that still fits; the width grows with the zoom.
  var low = minZoom, high = maxZoom;
  if (fits(high)) {
    low = high;
  } else {
    for (var i = 0; i < 40; i++) {
      final mid = (low + high) / 2;
      if (fits(mid)) {
        low = mid;
      } else {
        high = mid;
      }
    }
  }
  final zoom = low;
  final scale = 256 * math.pow(2, zoom).toDouble();
  final e = extent(scale);
  // The drawing's middle goes to the free area's middle.
  final middle = Offset((e.left + e.right) / 2, (e.top + e.bottom) / 2);
  final target = middle + (targetAt - free.center);
  return RouteCameraFit(_geo(target / scale), zoom);
}

/// The part of [points] (a route, pickup first) from [from] to [to],
/// both fractions of its length: the moving highlight on an offer line.
List<GeoPoint> routeSlice(List<GeoPoint> points, double from, double to) {
  if (points.length < 2 || to <= from) return const <GeoPoint>[];
  final cumulative = <double>[0];
  for (var i = 1; i < points.length; i++) {
    cumulative.add(cumulative.last + _meters(points[i - 1], points[i]));
  }
  final total = cumulative.last;
  if (total <= 0) return const <GeoPoint>[];
  final start = from.clamp(0.0, 1.0) * total;
  final end = to.clamp(0.0, 1.0) * total;
  GeoPoint at(double d) {
    var i = 1;
    while (i < cumulative.length - 1 && cumulative[i] < d) {
      i++;
    }
    final span = cumulative[i] - cumulative[i - 1];
    final t = span <= 0 ? 0.0 : (d - cumulative[i - 1]) / span;
    final a = points[i - 1], b = points[i];
    return GeoPoint(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  return <GeoPoint>[
    at(start),
    for (var i = 1; i < points.length - 1; i++)
      if (cumulative[i] > start && cumulative[i] < end) points[i],
    at(end),
  ];
}

double _meters(GeoPoint a, GeoPoint b) {
  final lat = (a.latitude + b.latitude) / 2 * math.pi / 180;
  final dx = (b.longitude - a.longitude) * math.cos(lat) * 111320;
  final dy = (b.latitude - a.latitude) * 110540;
  return math.sqrt(dx * dx + dy * dy);
}

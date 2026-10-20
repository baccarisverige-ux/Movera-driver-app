import 'package:movera/core/l10n/driver_l10n.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/widgets/route_mark_pins.dart';

/// R14-1: the marks of an offer's route on the Home map, for every offer
/// (Reservation, Exclusive and Radar): the Reservation details map's
/// labelled pins for pickup and drop-off (a dark bubble with a small title
/// and a bold value over a green or black dot), and a small white circle
/// with a dark ring on the road for each stop, without a label.
///
/// - Reservation: "Pickup" / "23:05", "Drop-off" / "23:24" (clock times).
/// - Exclusive and Radar: "Pickup" / "4 min" (the drive there),
///   "Drop-off" / "19 min" (the trip itself).
class OfferRouteMarks {
  const OfferRouteMarks._();

  static String get pickupTitle => tr.pickup;
  static String get dropoffTitle => tr.dropOff;

  /// Movera green of the offer sheets (the orb's ring and glow).
  static const Color green = Color(0xFF5FB87D);

  /// The stop circle's diameter and ring, in logical pixels: smaller than
  /// the pickup and drop-off marks.
  static const double stopSize = 14;
  static const double _stopRing = 2.5;
  static const double _stopMargin = 2; // room for the shadow
  static const Color stopRing = RouteMarkPins.ink;
  static const double _ratio = 3;

  /// "7 min": never "0 min".
  static String minutes(int value) => '${math.max(1, value)} min';

  static String titleOf(RouteMarkKind kind) =>
      kind == RouteMarkKind.pickup ? pickupTitle : dropoffTitle;

  /// Logical size of the pickup or drop-off pin showing [value].
  static Size pinSize(RouteMarkKind kind, String value) =>
      RouteMarkPins.labelledSize(titleOf(kind), value);

  /// The mark's centre inside the pin, as a marker anchor.
  static Offset pinAnchor(RouteMarkKind kind, String value) =>
      RouteMarkPins.labelledAnchor(titleOf(kind), value);

  /// Logical size of the stop bitmap (the circle plus its shadow room).
  static const Size stopBitmapSize =
      Size(stopSize + _stopMargin * 2, stopSize + _stopMargin * 2);

  /// The stop circle centred on [center].
  static void paintStop(Canvas canvas, Offset center) {
    const r = stopSize / 2;
    canvas
      ..drawCircle(
        center.translate(0, 0.6),
        r,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.25)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 1.2),
      )
      ..drawCircle(center, r, Paint()..color = stopRing)
      ..drawCircle(center, r - _stopRing, Paint()..color = Colors.white);
  }

  static final Map<String, BitmapDescriptor> _cache = {};

  /// Clears the bitmap cache (tests painting with another font).
  @visibleForTesting
  static void debugClearCache() => _cache.clear();

  /// The pickup or drop-off pin with [value]; cached once painted. A
  /// painting still under way is never shared: if its owner goes away
  /// first (a test ending, a closed zone) a shared future could never
  /// complete, and every later pin would wait on it forever.
  static Future<BitmapDescriptor> pin(RouteMarkKind kind, String value) async {
    final key = '${kind.name}|$value';
    final painted = _cache[key];
    if (painted != null) return painted;
    return _cache[key] =
        await RouteMarkPins.labelled(kind, titleOf(kind), value);
  }

  /// The stop circle's bitmap; cached once painted, like [pin].
  static Future<BitmapDescriptor> stop() async {
    const key = 'stop';
    final painted = _cache[key];
    if (painted != null) return painted;
    return _cache[key] = await _stopBitmap();
  }

  static Future<BitmapDescriptor> _stopBitmap() async {
    const s = stopBitmapSize;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(_ratio);
    paintStop(canvas, s.center(Offset.zero));
    final image = await recorder.endRecording().toImage(
      (s.width * _ratio).ceil(),
      (s.height * _ratio).ceil(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      return BitmapDescriptor.defaultMarker;
    }
    return BitmapDescriptor.bytes(
      data.buffer.asUint8List(),
      imagePixelRatio: _ratio,
    );
  }

  /// The markers: `radar_pickup` and `radar_dropoff` with their values
  /// (also each marker's info title), and `radar_stop_<i>` on each stop.
  static Future<Set<Marker>> markers({
    required LatLng pickup,
    required LatLng dropoff,
    required String pickupValue,
    required String dropoffValue,
    List<LatLng> stops = const <LatLng>[],
  }) async {
    final icons = await Future.wait([
      pin(RouteMarkKind.pickup, pickupValue),
      pin(RouteMarkKind.dropoff, dropoffValue),
      if (stops.isNotEmpty) stop(),
    ]);
    return {
      for (var i = 0; i < stops.length; i++)
        Marker(
          markerId: MarkerId('radar_stop_$i'),
          position: stops[i],
          infoWindow: InfoWindow(title: tr.stopNumber(i + 1)),
          icon: icons[2],
          anchor: const Offset(0.5, 0.5),
          consumeTapEvents: true,
          zIndexInt: 13,
        ),
      Marker(
        markerId: const MarkerId('radar_pickup'),
        position: pickup,
        infoWindow: InfoWindow(title: pickupValue),
        icon: icons[0],
        anchor: pinAnchor(RouteMarkKind.pickup, pickupValue),
        consumeTapEvents: true,
        zIndexInt: 14,
      ),
      Marker(
        markerId: const MarkerId('radar_dropoff'),
        position: dropoff,
        infoWindow: InfoWindow(title: dropoffValue),
        icon: icons[1],
        anchor: pinAnchor(RouteMarkKind.dropoff, dropoffValue),
        consumeTapEvents: true,
        zIndexInt: 14,
      ),
    };
  }
}

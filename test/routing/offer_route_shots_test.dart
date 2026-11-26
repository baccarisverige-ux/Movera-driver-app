import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/routing/offer_routes.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/widgets/driver_route_style.dart';

/// v0.18.168 screenshots for the owner (Rules plan/inspiration-ride-change-
/// 2026-11-20/shots-route-line-driver): the line the Home offer preview gets
/// for an offer Södertälje -> Arlanda with Offer.routePolyline (the road)
/// vs without one on a server with no stored route (the straight line).
/// Google tiles do not draw in a test: a plain background stands in; the
/// line colours are the app's. Opt-in: `OFFER_SHOTS=<dir> flutter test`.
final String? _dir = Platform.environment['OFFER_SHOTS'];

const _pickup = GeoPoint(59.19566, 17.62575); // Södertälje
const _dropoff = GeoPoint(59.65002, 17.93021); // Arlanda

/// A sample road in the shape of a Google answer (E4 north past
/// Stockholm); Google is never called in a test.
const _road = <GeoPoint>[
  _pickup,
  GeoPoint(59.2100, 17.6700),
  GeoPoint(59.2500, 17.7900),
  GeoPoint(59.2900, 17.9200),
  GeoPoint(59.3300, 17.9900),
  GeoPoint(59.3700, 18.0050),
  GeoPoint(59.4200, 17.9700),
  GeoPoint(59.4900, 17.9200),
  GeoPoint(59.5600, 17.9100),
  GeoPoint(59.6200, 17.9300),
  _dropoff,
];

String _encode(List<GeoPoint> points) {
  final out = StringBuffer();
  var lat = 0;
  var lng = 0;
  void value(int v) {
    var x = v < 0 ? ~(v << 1) : v << 1;
    while (x >= 0x20) {
      out.writeCharCode((0x20 | (x & 0x1f)) + 63);
      x >>= 5;
    }
    out.writeCharCode(x + 63);
  }

  for (final p in points) {
    final la = (p.latitude * 1e5).round();
    final ln = (p.longitude * 1e5).round();
    value(la - lat);
    value(ln - lng);
    lat = la;
    lng = ln;
  }
  return out.toString();
}

Map<String, dynamic> _offer(String? line) => {
  'offerId': 'ofr_shot',
  'tripId': 'trp_shot',
  'kind': 'exclusive',
  'status': 'open',
  'version': 1,
  'expiresAt': '2099-01-01T00:00:00Z',
  'fare': {'amountMinor': 90000, 'currency': 'SEK'},
  'driverEarnings': {'amountMinor': 70000, 'currency': 'SEK'},
  'pickup': {'lat': _pickup.latitude, 'lng': _pickup.longitude},
  'dropoff': {'lat': _dropoff.latitude, 'lng': _dropoff.longitude},
  'stops': <Object>[],
  'categoryId': 'economy',
  'paymentMethod': 'cash',
  'pickupEtaSeconds': 60,
  'pickupMeters': 300,
  'tripSeconds': 3600,
  'tripMeters': 60000,
  'routePolyline': ?line,
};

class _Painter extends CustomPainter {
  _Painter(this.points);
  final List<GeoPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    const minLat = 59.16, maxLat = 59.68, minLng = 17.50, maxLng = 18.12;
    Offset at(GeoPoint p) => Offset(
      (p.longitude - minLng) / (maxLng - minLng) * size.width,
      (maxLat - p.latitude) / (maxLat - minLat) * size.height,
    );
    final path = Path()..moveTo(at(points.first).dx, at(points.first).dy);
    for (final p in points.skip(1)) {
      path.lineTo(at(p).dx, at(p).dy);
    }
    final a = at(points.first), b = at(points.last);
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(a, b, [
          DriverRouteStyle.pickupColor,
          DriverRouteStyle.destinationColor,
        ])
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(a, 9, Paint()..color = DriverRouteStyle.pickupColor);
    canvas.drawCircle(b, 9, Paint()..color = DriverRouteStyle.destinationColor);
  }

  @override
  bool shouldRepaint(_Painter old) => old.points != points;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final google in [true, false]) {
    final name = google ? 'offer-google-route' : 'offer-straight-fallback';
    testWidgets(name, skip: _dir == null, (tester) async {
      OfferRoutes.clear();
      OfferWire.parse(_offer(google ? _encode(_road) : null));
      final RoadRoute? kept = OfferRoutes.leg(_pickup, _dropoff);
      // Without a kept road the app asks the server, which answers the
      // straight line through the two points when it has no stored route.
      final points = kept?.points ?? const [_pickup, _dropoff];
      expect(kept != null, google);
      tester.view.physicalSize = const Size(390, 520);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: ColoredBox(color: Color(0xFFEEF1EC)),
                ),
                Positioned.fill(child: CustomPaint(painter: _Painter(points))),
              ],
            ),
          ),
        ),
      );
      final render =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 2);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$_dir/$name.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      });
    });
  }
}

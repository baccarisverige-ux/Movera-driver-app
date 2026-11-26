import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/routing/offer_routes.dart';
import 'package:movera/core/routing/road_route_service.dart';

/// v0.18.168 (contract.json#offerRouteLine, owner 2026-11-26 "Route in
/// driver !!"): the offer preview draws the offer's own Google road
/// (Offer.routePolyline) with no route request; without it, the old one.
String encode(List<GeoPoint> points) {
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

const pickup = GeoPoint(59.19566, 17.62575); // Södertälje
const stop = GeoPoint(59.40000, 17.85000);
const dropoff = GeoPoint(59.65002, 17.93021); // Arlanda
const road = <GeoPoint>[
  pickup,
  GeoPoint(59.25000, 17.70000),
  GeoPoint(59.33000, 17.80000),
  stop,
  GeoPoint(59.52000, 17.90000),
  dropoff,
];

Map<String, dynamic> offer({String? line, bool withStop = false}) => {
  'offerId': 'ofr_169',
  'tripId': 'trp_169',
  'kind': 'exclusive',
  'status': 'open',
  'version': 1,
  'expiresAt': '2099-01-01T00:00:00Z',
  'fare': {'amountMinor': 90000, 'currency': 'SEK'},
  'driverEarnings': {'amountMinor': 70000, 'currency': 'SEK'},
  'pickup': {
    'address': 'Södertälje',
    'lat': pickup.latitude,
    'lng': pickup.longitude,
  },
  'dropoff': {
    'address': 'Arlanda',
    'lat': dropoff.latitude,
    'lng': dropoff.longitude,
  },
  'stops': [
    if (withStop)
      {'address': 'Stop', 'lat': stop.latitude, 'lng': stop.longitude},
  ],
  'categoryId': 'economy',
  'paymentMethod': 'cash',
  'pickupEtaSeconds': 60,
  'pickupMeters': 300,
  'tripSeconds': 3600,
  'tripMeters': 60000,
  'routePolyline': ?line,
};

void main() {
  setUp(OfferRoutes.clear);

  test('decodes Google polylines; a broken line is null', () {
    final points = decodeGooglePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@')!;
    expect(points, hasLength(3));
    expect(points.first.latitude, closeTo(38.5, 1e-9));
    expect(decodeGooglePolyline('_p~iF~ps|U_ulL'), isNull);
  });

  test('an offer with routePolyline: the road service answers it, '
      'no request', () async {
    OfferWire.parse(offer(line: encode(road)));
    final service = RoadRouteService(); // no api: a request would leave
    final route = await service.drivingRoute(
      origin: pickup,
      destination: dropoff,
    );
    expect(route.points.length, road.length);
    expect(route.durationSeconds, closeTo(3600, 1));
    service.dispose();
  });

  test('with a stop: one road leg per stop', () {
    OfferWire.parse(offer(line: encode(road), withStop: true));
    final a = OfferRoutes.leg(pickup, stop)!;
    final b = OfferRoutes.leg(stop, dropoff)!;
    expect(a.points.first, pickup);
    expect(a.points.last, stop);
    expect(b.points.last, dropoff);
    expect(a.points.length + b.points.length, greaterThan(road.length));
    expect(OfferRoutes.leg(pickup, dropoff), isNull);
  });

  test('no routePolyline, or a line of another trip: nothing kept', () {
    OfferWire.parse(offer());
    expect(OfferRoutes.leg(pickup, dropoff), isNull);
    OfferWire.parse(
      offer(line: encode(const [GeoPoint(48.85, 2.35), GeoPoint(48.9, 2.4)])),
    );
    expect(OfferRoutes.leg(pickup, dropoff), isNull);
  });
}

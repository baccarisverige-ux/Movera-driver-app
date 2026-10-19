import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/widgets/offer_route_marks.dart';
import 'package:movera/widgets/route_mark_pins.dart';

// R14-1: Pickup / Drop-off pins with clock times or minutes, a circle on
// each stop.
void main() {
  test('pins carry the values, stops get circles on their points', () async {
    const pickup = LatLng(59.33, 18.06);
    const dropoff = LatLng(59.36, 18.00);
    const stops = [LatLng(59.34, 18.04), LatLng(59.35, 18.02)];
    final markers = await OfferRouteMarks.markers(
      pickup: pickup,
      dropoff: dropoff,
      pickupValue: '23:05',
      dropoffValue: '23:24',
      stops: stops,
    );
    Marker byId(String id) => markers.firstWhere((m) => m.markerId.value == id);
    expect(byId('radar_pickup').position, pickup);
    expect(byId('radar_pickup').infoWindow.title, '23:05');
    expect(byId('radar_dropoff').infoWindow.title, '23:24');
    expect(byId('radar_stop_0').position, stops[0]);
    expect(byId('radar_stop_1').position, stops[1]);
    expect(byId('radar_stop_0').anchor, const Offset(0.5, 0.5));
    expect(markers, hasLength(4));
    expect(
      byId('radar_pickup').anchor,
      RouteMarkPins.labelledAnchor('Pickup', '23:05'),
    );
    expect(OfferRouteMarks.stopSize, lessThan(RouteMarkPins.markSize));
  });

  test('Exclusive and Radar pins say minutes, never 0', () {
    expect(OfferRouteMarks.minutes(4), '4 min');
    expect(OfferRouteMarks.minutes(0), '1 min');
    expect(OfferRouteMarks.titleOf(RouteMarkKind.pickup), 'Pickup');
    expect(OfferRouteMarks.titleOf(RouteMarkKind.dropoff), 'Drop-off');
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/presentation/driver/destination%20mode/destination_confirm.dart';
import 'package:movera/presentation/driver/destination%20mode/destination_picker.dart';
import 'package:movera/presentation/driver/home/components/home_map_layers.dart';
import 'package:movera/widgets/custom_google_map.dart';

const _driver = LatLng(59.3617, 17.9714); // Sundbyberg
const _kista = LatLng(59.4032, 17.9448);

void main() {
  testWidgets(
    'confirm map: arc, car and pin sit on the driver and destination',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(
          home: DestinationConfirmScreen(
            origin: _driver,
            destination: DriverDestinationResult(
              position: _kista,
              address: 'Kista Galleria, Stockholm',
              name: 'Kista centrum',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 1200));

      final map = tester.widget<CustomGoogleMap>(find.byType(CustomGoogleMap));
      Marker marker(String id) =>
          map.markers!.firstWhere((m) => m.markerId.value == id);
      Polyline line(String id) =>
          map.polylines!.firstWhere((p) => p.polylineId.value == id);

      expect(marker('destination-confirm-car').position, _driver);
      expect(marker('destination-confirm-pin').position, _kista);
      expect(line('destination-straight').points, [_driver, _kista]);
      // Owner round 4: the arc is drawn in the Movera route colours, as
      // gradient pieces whose first piece keeps the id; no casing.
      expect(
        map.polylines!.where(
          (p) => p.polylineId.value == 'destination-arc-casing',
        ),
        isEmpty,
      );
      final pieces =
          map.polylines!
              .where(
                (p) =>
                    p.polylineId.value == 'destination-arc' ||
                    p.polylineId.value.startsWith('destination-arc-g'),
              )
              .toList()
            ..sort(
              (a, b) => a.polylineId.value == 'destination-arc'
                  ? -1
                  : b.polylineId.value == 'destination-arc'
                  ? 1
                  : int.parse(
                      a.polylineId.value.split('-g').last,
                    ).compareTo(int.parse(b.polylineId.value.split('-g').last)),
            );
      expect(pieces, hasLength(12));
      final arc = [for (final p in pieces) ...p.points];
      expect(arc.length, greaterThanOrEqualTo(48));
      expect(arc.first, _driver);
      expect(arc.last, _kista);
      // Curved, not the straight line: the middle bulges off the chord.
      final mid = arc[arc.length ~/ 2];
      expect(
        (mid.latitude - (_driver.latitude + _kista.latitude) / 2).abs(),
        greaterThan(0.002),
      );
    },
  );

  test(
    'Home destination mode: one destination pin, no leftover offer stops',
    () {
      final layers = homeMapLayers(
        car: {
          const Marker(
            markerId: MarkerId('driver_location'),
            position: _driver,
          ),
        },
        destinationMode: true,
        destinationMarkers: {destinationModeMarker(_kista, 'Kista Galleria')},
        destinationPolylines: {
          const Polyline(
            polylineId: PolylineId('destination_mode_road_route'),
            points: [_driver, _kista],
          ),
        },
        offerMarkers: {
          const Marker(
            markerId: MarkerId('radar_pickup'),
            position: LatLng(59.33, 18.06),
          ),
          const Marker(
            markerId: MarkerId('radar_dropoff'),
            position: LatLng(59.30, 18.10),
          ),
        },
        offerPolylines: {
          const Polyline(
            polylineId: PolylineId('direct_offer_road_route'),
            points: [_driver, LatLng(59.33, 18.06), LatLng(59.30, 18.10)],
          ),
        },
        offerOnScreen: false,
      );
      expect(layers.markers.map((m) => m.markerId.value).toSet(), {
        'driver_location',
        destinationModeMarkerId,
      });
      expect(layers.polylines.map((p) => p.polylineId.value), [
        'destination_mode_road_route',
      ]);
    },
  );

  test('Home: an offer that is no longer on screen draws no pins or route', () {
    final layers = homeMapLayers(
      car: {
        const Marker(markerId: MarkerId('driver_location'), position: _driver),
      },
      destinationMode: false,
      destinationMarkers: const {},
      destinationPolylines: const {},
      offerMarkers: {
        const Marker(
          markerId: MarkerId('radar_pickup'),
          position: LatLng(59.33, 18.06),
        ),
        const Marker(
          markerId: MarkerId('radar_dropoff'),
          position: LatLng(59.30, 18.10),
        ),
      },
      offerPolylines: {
        const Polyline(
          polylineId: PolylineId('direct_offer_road_route'),
          points: [LatLng(59.33, 18.06), LatLng(59.30, 18.10)],
        ),
      },
      offerOnScreen: false,
    );
    expect(layers.markers.map((m) => m.markerId.value), ['driver_location']);
    expect(layers.polylines, isEmpty);
  });
}

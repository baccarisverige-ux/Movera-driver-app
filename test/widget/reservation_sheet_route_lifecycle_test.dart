import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/home/components/reservation_route_map.dart';

ReservationRequestPreview _request(
  double lat, {
  String time = '07:40',
  int minutes = 19,
  bool stops = false,
}) => ReservationRequestPreview(
  category: 'Comfort',
  fare: '126 kr',
  pickupLabel: 'Pickup today',
  pickupAddress: 'Long pickup address, building 45, entrance B, Stockholm',
  dropoffAddress: 'Long drop-off address, building 68, entrance C, Stockholm',
  pickupTime: time,
  pickupDay: 'Today',
  tripMinutes: minutes,
  tripKm: 9.4,
  pickup: GeoPoint(lat, 18.0),
  dropoff: GeoPoint(lat + .01, 18.01),
  stops: stops
      ? [
          for (var i = 0; i < 6; i++)
            ReservationStop(
              address: 'Stop $i, Stockholm',
              point: GeoPoint(lat, 18.002 + i * .001),
            ),
        ]
      : const [],
);

Widget _map(BuildContext context) => const ColoredBox(color: Colors.grey);

void main() {
  setUp(() {
    final previous = DriverRuntimeConfig.current;
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      simulatedArrival: false,
      externalRouting: false,
      skipAccountActivation: false,
    );
    addTearDown(() => DriverRuntimeConfig.current = previous);
  });

  testWidgets(
    'short enlarged-text map keeps long stop details bounded and scrollable',
    (tester) async {
      tester.view.physicalSize = const Size(568, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final request = _request(59.3, stops: true);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: ReservationRouteMapPage(
            request: request,
            route: Future.value(reservationWaypoints(request)),
            mapBuilder: (context, _) => _map(context),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rect = tester.getRect(
        find.byKey(const ValueKey('reservation-route-details')),
      );
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(320));
      await tester.ensureVisible(find.text(request.dropoffAddress));
      await tester.pumpAndSettle();
      expect(find.text(request.dropoffAddress).hitTestable(), findsOneWidget);
      final address = tester.widget<Text>(find.text(request.dropoffAddress));
      expect(address.maxLines, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'arrival calculation does not normalize malformed times or negative durations',
    () {
      for (final time in ['24:00', '07:90', '-1:20', '07:-1']) {
        expect(_request(59.3, time: time).arrivalTime, time);
      }
      expect(_request(59.3, minutes: -1).arrivalTime, '07:40');
      expect(_request(59.3, time: '23:50', minutes: 25).arrivalTime, '00:15');
    },
  );
}

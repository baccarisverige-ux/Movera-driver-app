import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/routing/road_route_service.dart';
import 'package:movera/core/session/driver_runtime_config.dart';

// Live builds must never call the public OSRM demo host: a RoadRouteService
// built without the server api throws so callers draw the approximate line.
void main() {
  const a = GeoPoint(59.33, 18.06);
  const b = GeoPoint(59.35, 18.10);
  late DriverRuntimeConfig saved;
  setUp(() => saved = DriverRuntimeConfig.current);
  tearDown(() => DriverRuntimeConfig.current = saved);

  test('live config + no api: no request, RoadRouteException', () async {
    DriverRuntimeConfig.current = DriverRuntimeConfig.production;
    final seen = <Uri>[];
    final s = RoadRouteService(
      client: MockClient((r) async {
        seen.add(r.url);
        return http.Response('{}', 500);
      }),
    );
    await expectLater(
      s.drivingRoute(origin: a, destination: b),
      throwsA(isA<RoadRouteException>()),
    );
    expect(seen, isEmpty);
  });

  test('demo config + no api still uses the OSRM host', () async {
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      simulatedArrival: true,
      externalRouting: true,
      skipAccountActivation: true,
    );
    final seen = <Uri>[];
    final s = RoadRouteService(
      client: MockClient((r) async {
        seen.add(r.url);
        return http.Response('{}', 500);
      }),
    );
    try {
      await s.drivingRoute(origin: a, destination: b);
    } catch (_) {}
    expect(seen, isNotEmpty);
  });
}

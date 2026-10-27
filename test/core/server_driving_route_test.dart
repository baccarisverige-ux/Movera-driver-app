import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/navigation/navigation_controller.dart';
import 'package:movera/core/routing/road_route_service.dart';

// Owner decision 2026-10-27 (N2): the live build takes driving routes
// from movera-server (`GET /api/v1/routes/driving/{coordinates}`), not the
// public OSRM demo.

const _origin = GeoPoint(59.3, 18.0);
const _destination = GeoPoint(59.31, 18.02);

final _okBody = jsonEncode({
  'code': 'Ok',
  'routes': [
    {
      'distance': 1500.0,
      'duration': 180.0,
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          [18.0, 59.3],
          [18.02, 59.31],
        ],
      },
      'legs': <Object>[],
    },
  ],
});

ApiClient _api(http.Client client) => ApiClient(
  client: client,
  baseUri: Uri.parse('https://api.movera.test'),
  tokens: MemoryTokenStore()..save(access: 'access-1', refresh: 'r'),
);

void main() {
  test('live routes go to the server with the bearer token', () async {
    final requests = <http.Request>[];
    final routes = RoadRouteService(
      api: _api(
        MockClient((request) async {
          requests.add(request);
          return http.Response(_okBody, 200);
        }),
      ),
    );
    addTearDown(routes.dispose);

    final route = await routes.drivingRoute(
      origin: _origin,
      destination: _destination,
    );

    expect(routes.usesServer, isTrue);
    expect(routes.usesPublicDemoServer, isFalse);
    expect(requests, hasLength(1));
    final uri = requests.single.url;
    expect(uri.host, 'api.movera.test');
    expect(uri.path, '/api/v1/routes/driving/18.0,59.3;18.02,59.31');
    expect(uri.queryParameters, containsPair('geometries', 'geojson'));
    expect(uri.queryParameters, containsPair('overview', 'full'));
    expect(requests.single.headers['Authorization'], 'Bearer access-1');
    expect(uri.host, isNot(RoadRouteService.publicDemoHost));
    expect(route.distanceMeters, 1500);
  });

  test('server NoRoute is a route error', () async {
    final routes = RoadRouteService(
      api: _api(
        MockClient(
          (_) async => http.Response(
            jsonEncode({'code': 'NoRoute', 'routes': <Object>[]}),
            200,
          ),
        ),
      ),
    );
    addTearDown(routes.dispose);
    await expectLater(
      routes.drivingRoute(origin: _origin, destination: _destination),
      throwsA(isA<RoadRouteException>()),
    );
  });

  test('server offline stays a route error', () async {
    final routes = RoadRouteService(
      api: _api(MockClient((_) async => throw http.ClientException('down'))),
    );
    addTearDown(routes.dispose);
    await expectLater(
      routes.drivingRoute(origin: _origin, destination: _destination),
      throwsA(
        isA<RoadRouteException>().having(
          (e) => e.message,
          'message',
          contains('offline'),
        ),
      ),
    );
  });

  test(
    '503 routing_unavailable (no OSRM_URL) shows the honest state',
    () async {
      final answer = Completer<http.Response>();
      final routes = RoadRouteService(
        api: _api(MockClient((_) => answer.future)),
      );
      final navigation = NavigationController(routeRepository: routes);
      addTearDown(() {
        navigation.dispose();
        routes.dispose();
      });
      navigation.setVehicle(
        DriverLocation(
          point: _origin,
          measuredAt: DateTime.now(),
          accuracyMeters: 5,
        ),
      );
      final request = navigation.ensureRoute(
        origin: _origin,
        destination: _destination,
      );
      expect(navigation.routeState, RouteLoadState.loading);
      expect(navigation.status, 'Route updating…');

      answer.complete(
        http.Response(
          jsonEncode({
            'code': 'unavailable',
            'message': 'Navigation routes are not available yet.',
            'reason': 'routing_unavailable',
          }),
          503,
          headers: {'retry-after': '60'},
        ),
      );
      await request;

      expect(navigation.routeState, RouteLoadState.failed);
      expect(navigation.status, 'Route unavailable — retry');
      expect(navigation.route, isNull);
    },
  );
}

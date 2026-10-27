import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/routing/osrm_route_parser.dart';
import 'package:movera/core/routing/route_repository.dart';

class RoadRouteException implements Exception {
  const RoadRouteException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Frontend road-routing adapter.
///
/// With [api] (live builds) routes come from movera-server's OSRM proxy,
/// `GET /api/v1/routes/driving/{coordinates}`, signed like every API call;
/// a 503 `routing_unavailable` (server without `OSRM_URL`) is a route error
/// like any other, so the trip shows "Route unavailable — retry". Without
/// [api] (the demo) the adapter asks the OSRM [host] directly.
class RoadRouteService implements RouteRepository {
  RoadRouteService({
    http.Client? client,
    bool? ownsClient,
    OsrmRouteParser parser = const OsrmRouteParser(),
    this.timeout = const Duration(seconds: 8),
    this.host = defaultHost,
    ApiClient? api,
  }) : _api = api,
       _client = client ?? http.Client(),
       _ownsClient = ownsClient ?? client == null,
       _parser = parser;

  final ApiClient? _api;
  final http.Client _client;
  final bool _ownsClient;
  final OsrmRouteParser _parser;
  final Duration timeout;

  /// OSRM-compatible routing host. Defaults to the public OSRM demo server,
  /// which is acceptable for the demo only: its usage policy excludes
  /// production traffic and it receives driver coordinates. Production builds
  /// must set `--dart-define=MOVERA_ROUTING_HOST=<contracted host>` (see
  /// docs/ROUTING_PROVIDER.md).
  final String host;

  static const defaultHost = String.fromEnvironment(
    'MOVERA_ROUTING_HOST',
    defaultValue: publicDemoHost,
  );
  static const publicDemoHost = 'router.project-osrm.org';

  /// True when routes go to the public demo server.
  bool get usesPublicDemoServer => _api == null && host == publicDemoHost;

  /// True when routes go through movera-server.
  bool get usesServer => _api != null;

  static const _query = <String, String>{
    'overview': 'full',
    'geometries': 'geojson',
    'steps': 'true',
    'annotations': 'false',
    'alternatives': 'false',
  };
  var _closed = false;

  /// Closes the HTTP client only when this service created it.
  void dispose() {
    if (_closed) {
      return;
    }
    _closed = true;
    if (_ownsClient) {
      _client.close();
    }
  }

  @override
  Future<RoadRoute> drivingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async {
    if (_closed) {
      throw const RoadRouteException('Routing is closed.');
    }
    final coordinates =
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}';

    final api = _api;
    if (api != null) {
      return _serverRoute(api, coordinates);
    }
    final uri = Uri.https(host, '/route/v1/driving/$coordinates', _query);

    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(timeout);
    } on TimeoutException {
      throw const RoadRouteException(
        'Routing is taking too long. The trip is still active.',
      );
    } on http.ClientException {
      throw const RoadRouteException(
        'Routing is offline. The trip is still active.',
      );
    }

    if (_closed) {
      throw const RoadRouteException('Routing is closed.');
    }
    if (response.statusCode != 200) {
      throw RoadRouteException(
        'Routing service returned ${response.statusCode}.',
      );
    }

    return _parse(jsonDecode(response.body));
  }

  Future<RoadRoute> _serverRoute(ApiClient api, String coordinates) async {
    final Map<String, dynamic> decoded;
    try {
      decoded = await api
          .get(
            '/api/v1/routes/driving/$coordinates?'
            '${Uri(queryParameters: _query).query}',
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const RoadRouteException(
        'Routing is taking too long. The trip is still active.',
      );
    } on ApiError catch (error) {
      if (error.code == ApiError.timeout) {
        throw const RoadRouteException(
          'Routing is taking too long. The trip is still active.',
        );
      }
      if (error.neverReachedServer) {
        throw const RoadRouteException(
          'Routing is offline. The trip is still active.',
        );
      }
      throw RoadRouteException(
        'Routing service returned ${error.statusCode ?? error.code}.',
      );
    }
    if (_closed) {
      throw const RoadRouteException('Routing is closed.');
    }
    return _parse(decoded);
  }

  RoadRoute _parse(Object? decoded) {
    if (decoded is! Map<String, dynamic> || decoded['code'] != 'Ok') {
      throw const RoadRouteException('No road route was found.');
    }

    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty) {
      throw const RoadRouteException('No road route was found.');
    }

    final route = routes.first;
    if (route is! Map<String, dynamic>) {
      throw const RoadRouteException('Invalid route response.');
    }

    try {
      return _parser.parseRoute(route);
    } on FormatException catch (error) {
      throw RoadRouteException(error.message);
    }
  }
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/routing/road_route_service.dart';

// v0.18.171 (contract.json#googleRoadLines): GET /routes/driving answers
// source google | stored | estimate, code still "Ok". Only "estimate" is
// the approximate (straight) line; no source (older server) is as before.

class _Client extends http.BaseClient {
  _Client(this.body);
  final Map<String, Object?> body;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(body))),
        200,
        headers: const {'content-type': 'application/json'},
      );
}

Map<String, Object?> _answer(String? source) => {
  'code': 'Ok',
  'source': ?source,
  'routes': [
    {
      'distance': 2300.0,
      'duration': 240.0,
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          [18.06, 59.33],
          [18.07, 59.31],
        ],
      },
      'legs': <Object>[],
    },
  ],
};

Future<dynamic> _route(String? source) =>
    RoadRouteService(client: _Client(_answer(source))).drivingRoute(
      origin: const GeoPoint(59.33, 18.06),
      destination: const GeoPoint(59.31, 18.07),
    );

void main() {
  test('estimate is the approximate line', () async {
    final route = await _route('estimate');
    expect(route.source, 'estimate');
    expect(route.approximate, isTrue);
  });

  test('google and stored are road lines', () async {
    for (final source in ['google', 'stored']) {
      final route = await _route(source);
      expect(route.source, source);
      expect(route.approximate, isFalse);
    }
  });

  test('no source (older server) is treated as before', () async {
    final route = await _route(null);
    expect(route.source, isNull);
    expect(route.approximate, isFalse);
  });

  test('an unknown source is not approximate', () async {
    final route = await _route('later');
    expect(route.source, isNull);
    expect(route.approximate, isFalse);
  });
}

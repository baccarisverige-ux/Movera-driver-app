import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';

/// A live build for a test: [LiveDriverServices.instance] answers every
/// request with [answer] (503 by default). Reset it in tearDown.
LiveDriverServices installLive({
  Map<String, Object?>? Function(http.Request request)? answer,
}) {
  final tokens = MemoryTokenStore()..save(access: 'a', refresh: 'r');
  final client = MockClient((request) async {
    final body = answer?.call(request);
    return body == null
        ? http.Response('', 503)
        : http.Response(
            jsonEncode(body),
            200,
            headers: {'content-type': 'application/json'},
          );
  });
  final origin = Uri.parse('https://api.test.movera.se');
  return LiveDriverServices.instance = LiveDriverServices(
    client: client,
    origin: origin,
    tokens: tokens,
    api: ApiClient(client: client, baseUri: origin, tokens: tokens),
    location: FixedGps(),
    locationEvery: const Duration(hours: 1),
  );
}

class FixedGps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() async => DriverLocation(
    point: const GeoPoint(59.3326, 18.0649),
    accuracyMeters: 5,
    measuredAt: DateTime.now(),
  );
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream.empty();
}

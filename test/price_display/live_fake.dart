import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';

/// Price audit 2026-11-14 tests: a live build (a server is set up), so the
/// screens may show only the server's money numbers.
void installLive() {
  final tokens = MemoryTokenStore()..save(access: 'a', refresh: 'r');
  final client = MockClient((_) async => http.Response('{}', 404));
  final origin = Uri.parse('https://api.test.movera.se');
  LiveDriverServices.instance = LiveDriverServices(
    client: client,
    origin: origin,
    tokens: tokens,
    api: ApiClient(client: client, baseUri: origin, tokens: tokens),
    location: _NoGps(),
  );
}

void uninstallLive() => LiveDriverServices.instance = null;

class _NoGps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() async => DriverLocation(
    point: const GeoPoint(59.33, 18.06),
    accuracyMeters: 5,
    measuredAt: DateTime.now(),
  );
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream.empty();
}

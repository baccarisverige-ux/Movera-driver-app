import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/surge/surge_map.dart';

/// `GET /driver/surge-map` (contract v0.7.2 §17, `contract.json#driverSurgeMap`):
/// the zones of the driver's country with a surge now, each as a level
/// and a rectangle. A failure throws, so [SurgeMapController] keeps the
/// last answer.
class ApiSurgeMapSource implements SurgeMapSource {
  ApiSurgeMapSource({required ApiClient api}) : _api = api;

  final ApiClient _api;

  static const path = '/api/v1/driver/surge-map';

  @override
  Future<List<DriverSurgeZone>> fetch() async =>
      surgeZonesFromJson(await _api.get(path));
}

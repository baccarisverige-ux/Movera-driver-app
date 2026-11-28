import 'package:movera/core/destination/destination_search.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/scheduled/preferred_areas.dart';

/// v0.18.172 test doubles: the server's area routes and the address service.
const sodertalje = PreferredArea(
  areaId: 'SE-K-0181',
  name: 'Södertälje',
  kind: 'kommun',
  kindLabel: 'Kommun',
  parentName: 'Stockholms län',
);
const sodermalm = PreferredArea(
  areaId: 'SE-SDO-SODERMALM',
  name: 'Södermalm',
  kind: 'stadsdelsomrade',
  kindLabel: 'Område',
  parentName: 'Stockholm',
);
const solna = PreferredArea(
  areaId: 'SE-K-0184',
  name: 'Solna',
  kind: 'kommun',
  kindLabel: 'Kommun',
  parentName: 'Stockholms län',
);
const sollentuna = PreferredArea(
  areaId: 'SE-K-0163',
  name: 'Sollentuna',
  kind: 'kommun',
  kindLabel: 'Kommun',
  parentName: 'Stockholms län',
);
const kungsholmen = PreferredArea(
  areaId: 'SE-SDO-KUNGSHOLMEN',
  name: 'Kungsholmen',
  kind: 'stadsdelsomrade',
  kindLabel: 'Område',
  parentName: 'Stockholm',
);
const zoneAreas = [sodertalje, sodermalm, solna, sollentuna, kungsholmen];

class FakeAreasApi implements PreferredAreasApi {
  FakeAreasApi({this.saved = const [], this.at});
  List<PreferredArea> saved;
  PreferredArea? at;
  final searches = <String>[];
  final points = <List<double>>[];
  final puts = <List<String>>[];

  @override
  Future<List<PreferredArea>> searchAreas(String query) async {
    searches.add(query);
    if (query.isEmpty) return zoneAreas;
    final q = query.toLowerCase().replaceAll('ö', 'o');
    return [
      for (final a in zoneAreas)
        if (a.name.toLowerCase().replaceAll('ö', 'o').contains(q)) a,
    ];
  }

  @override
  Future<PreferredArea?> areaAt(double lat, double lng) async {
    points.add([lat, lng]);
    return at;
  }

  /// The server's answer to the next saves, in order (none left = saved).
  final refusals = <PreferredAreasRefusal>[];

  @override
  Future<PreferredAreasSave> setPreferredAreas(List<String> areaIds) async {
    puts.add(List.of(areaIds));
    if (refusals.isNotEmpty) {
      return PreferredAreasSave.refused(refusals.removeAt(0));
    }
    saved = [
      for (final id in areaIds)
        zoneAreas.firstWhere((a) => a.areaId == id, orElse: () => sodertalje),
    ];
    return PreferredAreasSave.saved(saved);
  }

  @override
  Future<List<PreferredArea>> loadPreferredAreas() async => saved;
}

class FakeAddresses implements DestinationSearch {
  FakeAddresses({this.located = const GeoPoint(59.1960, 17.6260)});
  final GeoPoint? located;
  final searches = <String>[];
  final resolves = <String>[];

  static const klockarvagen = DestinationPlace(
    id: 'g1',
    name: 'Klockarvägen 37',
    address: 'Klockarvägen 37, 151 61 Södertälje',
    placeId: 'pl1',
  );

  @override
  Future<List<DestinationPlace>> search(String query, {GeoPoint? near}) async {
    searches.add(query);
    return query.toLowerCase().startsWith('klock')
        ? const [klockarvagen]
        : const [];
  }

  @override
  Future<DestinationPlace?> resolve(DestinationPlace place) async {
    resolves.add(place.id);
    if (place.position != null) return place;
    final p = located;
    return p == null ? null : place.located(p);
  }
}

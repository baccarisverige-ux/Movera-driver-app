import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/styles/reference_map_style.dart';

// Mirrors the Maps JavaScript API serialiser (maps-api-v3 map.js, v3.66):
// each rule becomes "s.t:<id>|s.e:<code>|p.<key>:<value>", rules are joined
// with ",", and a result over 1000 characters is replaced by "" (no styling
// at all) with only a console message "Custom style string for ...".
const _featureIds = <String, int>{
  'all': 0,
  'administrative': 1,
  'administrative.country': 17,
  'administrative.province': 18,
  'administrative.locality': 19,
  'administrative.neighborhood': 20,
  'administrative.land_parcel': 21,
  'poi': 2,
  'poi.business': 33,
  'poi.government': 34,
  'poi.school': 35,
  'poi.medical': 36,
  'poi.attraction': 37,
  'poi.place_of_worship': 38,
  'poi.sports_complex': 39,
  'poi.park': 40,
  'road': 3,
  'road.highway': 49,
  'road.highway.controlled_access': 785,
  'road.arterial': 50,
  'road.local': 51,
  'road.local.drivable': 817,
  'road.local.trail': 818,
  'transit': 4,
  'transit.line': 65,
  'transit.line.rail': 1041,
  'transit.line.ferry': 1042,
  'transit.line.transit_layer': 1043,
  'transit.station': 66,
  'transit.station.rail': 1057,
  'transit.station.bus': 1058,
  'transit.station.airport': 1059,
  'transit.station.ferry': 1060,
  'landscape': 5,
  'landscape.man_made': 81,
  'landscape.man_made.building': 1297,
  'landscape.man_made.business_corridor': 1299,
  'landscape.natural': 82,
  'landscape.natural.landcover': 1313,
  'landscape.natural.terrain': 1314,
  'water': 6,
};
const _elementCodes = <String, String>{
  'all': '',
  'geometry': 'g',
  'geometry.fill': 'g.f',
  'geometry.stroke': 'g.s',
  'labels': 'l',
  'labels.icon': 'l.i',
  'labels.text': 'l.t',
  'labels.text.fill': 'l.t.f',
  'labels.text.stroke': 'l.t.s',
};
const _stylerKeys = <String, String>{
  'hue': 'h',
  'saturation': 's',
  'lightness': 'l',
  'gamma': 'g',
  'invert_lightness': 'il',
  'visibility': 'v',
  'color': 'c',
  'weight': 'w',
};

List<Map<String, Object?>> _rules() =>
    (jsonDecode(moveraReferenceMapStyle) as List<Object?>)
        .cast<Map<String, Object?>>();

String _webStyleString(List<Map<String, Object?>> rules) {
  final parts = <String>[];
  for (final rule in rules) {
    final fields = <String>[];
    final feature = rule['featureType'] as String?;
    if (feature != null) {
      expect(_featureIds, contains(feature), reason: 'unknown featureType');
      final id = _featureIds[feature]!;
      if (id != 0) fields.add('s.t:$id');
    }
    final element = rule['elementType'] as String?;
    if (element != null) {
      expect(_elementCodes, contains(element), reason: 'unknown elementType');
      final code = _elementCodes[element]!;
      if (code.isNotEmpty) fields.add('s.e:$code');
    }
    for (final styler
        in (rule['stylers'] as List<Object?>? ?? const [])
            .cast<Map<String, Object?>>()) {
      for (final entry in styler.entries) {
        final key = _stylerKeys[entry.key];
        if (key != null && entry.value != null) {
          fields.add('p.$key:${entry.value}');
          break;
        }
      }
    }
    if (fields.isNotEmpty) parts.add(fields.join('|'));
  }
  return parts.join(',');
}

void main() {
  test('reference map style fits the Maps JavaScript 1000-char limit', () {
    final serialised = _webStyleString(_rules());
    // Leave headroom so a small palette tweak cannot silently disable all
    // web styling (the live site showed Google's default palette at 1051).
    expect(serialised.length, lessThanOrEqualTo(950), reason: serialised);
  });

  test('reference map style has no duplicate selectors', () {
    final seen = <String>{};
    for (final rule in _rules()) {
      final key =
          '${rule['featureType'] ?? 'all'}/'
          '${rule['elementType'] ?? 'all'}';
      expect(seen.add(key), isTrue, reason: 'duplicate rule $key');
    }
  });
}

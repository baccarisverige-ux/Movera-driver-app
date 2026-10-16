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

  test('reference map style applies the 16 Oct 2026 reference palette', () {
    String? colour(String feature, String element) {
      for (final rule in _rules()) {
        if ((rule['featureType'] ?? 'all') == feature &&
            (rule['elementType'] ?? 'all') == element) {
          final stylers = (rule['stylers'] as List<Object?>)
              .cast<Map<String, Object?>>();
          return stylers.first['color'] as String?;
        }
      }
      return null;
    }

    const expected = <String, String>{
      'all/geometry': '#EDF0F5',
      'road/geometry': '#FFFFFF',
      'road.highway/geometry': '#9CA9D4',
      'transit.line/geometry': '#BECAD1',
      'poi.park/geometry': '#B6DEBB',
      'landscape.natural.landcover/geometry': '#B6DEBB',
      'poi.medical/geometry': '#F1E1E1',
      'poi.school/geometry': '#F1E1E1',
      'water/geometry': '#BBD9FB',
      'administrative.locality/labels.text.fill': '#596171',
      'administrative.neighborhood/labels.text.fill': '#8FA2D3',
      'road/labels.text.fill': '#444444',
      'all/labels.text.stroke': '#FFFFFF',
      'poi.park/labels.text.fill': '#478660',
      'all/labels.text.fill': '#576167',
    };
    expected.forEach((selector, hex) {
      final parts = selector.split('/');
      expect(colour(parts[0], parts[1]), hex, reason: selector);
    });
    // Roads set one geometry colour (fill and stroke), so no outline.
    expect(colour('road', 'geometry.stroke'), isNull);
    expect(colour('road.highway', 'geometry.stroke'), isNull);
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

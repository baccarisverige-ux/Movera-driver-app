import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/styles/movera_map_style.dart';

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
    (jsonDecode(moveraMapStyle) as List<Object?>)
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

String? _color(String? feature, String element) {
  for (final rule in _rules()) {
    if (rule['featureType'] == feature && rule['elementType'] == element) {
      for (final styler in (rule['stylers'] as List).cast<Map>()) {
        if (styler['color'] != null) return styler['color'] as String;
      }
    }
  }
  return null;
}

String? _visibility(String feature, [String? element]) {
  for (final rule in _rules()) {
    if (rule['featureType'] == feature && rule['elementType'] == element) {
      for (final styler in (rule['stylers'] as List).cast<Map>()) {
        if (styler['visibility'] != null) return styler['visibility'] as String;
      }
    }
  }
  return null;
}

void main() {
  test('Movera map style fits the Maps JavaScript 1000-char limit', () {
    final serialised = _webStyleString(_rules());
    // Leave headroom so a small palette tweak cannot silently disable all
    // web styling (the live site showed Google's default palette at 1051).
    expect(serialised.length, lessThanOrEqualTo(950), reason: serialised);
  });

  test('Movera map style has no duplicate selectors', () {
    final seen = <String>{};
    for (final rule in _rules()) {
      final key =
          '${rule['featureType'] ?? 'all'}/'
          '${rule['elementType'] ?? 'all'}';
      expect(seen.add(key), isTrue, reason: 'duplicate rule $key');
    }
  });

  test('Movera map style hides POI, transit, neighbourhoods, admin lines', () {
    expect(_visibility('poi'), 'off');
    expect(_visibility('transit'), 'off');
    expect(_visibility('administrative.neighborhood'), 'off');
    expect(_visibility('administrative', 'geometry'), 'off');
    // Parks come back (green areas, green names) but without icons.
    expect(_visibility('poi.park', 'geometry'), 'on');
    expect(_visibility('poi.park', 'labels.text'), 'on');
    expect(_visibility('poi.park', 'labels'), isNull);
    expect(_visibility('poi.park'), isNull);
  });

  test('Movera map style uses the clean v3 palette', () {
    expect(_color(null, 'geometry'), '#FAFCFA');
    expect(_color(null, 'labels.text.fill'), '#575C60');
    expect(_color(null, 'labels.text.stroke'), '#FFFFFF');
    expect(_color('landscape.man_made', 'geometry'), '#E1E4E5');
    expect(_color('poi.park', 'geometry'), '#C8F0CC');
    expect(_color('poi.park', 'labels.text.fill'), '#3D8549');
    expect(_color('water', 'geometry'), '#ADE2FC');
    expect(_color('road', 'geometry'), '#C8CCD0');
    expect(_color('road.arterial', 'geometry'), '#A1A6AB');
    expect(_color('road.highway', 'geometry'), '#8A8F96');
    expect(_color('administrative.locality', 'labels.text.fill'), '#6F8B9D');
  });

  test('Movera map style keeps highway shields', () {
    for (final rule in _rules()) {
      final feature = rule['featureType'] as String? ?? '';
      final element = rule['elementType'] as String?;
      final hidesIcons = (rule['stylers'] as List).any(
        (s) => (s as Map)['visibility'] == 'off',
      );
      expect(
        feature.startsWith('road') &&
            (element == null || element.startsWith('labels')) &&
            hidesIcons,
        isFalse,
        reason: 'road shield rule: $rule',
      );
      expect(feature.isEmpty && element == 'labels.icon', isFalse);
    }
  });
}

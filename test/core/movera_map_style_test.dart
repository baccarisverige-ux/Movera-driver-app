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

List<Map<String, Object?>> _rules([String? style]) =>
    (jsonDecode(style ?? moveraMapStyle) as List<Object?>)
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
    // Every zoom band (far / near / close). Leave headroom so a small
    // palette tweak cannot silently disable all web styling (the live site
    // showed Google's default palette at 1051).
    for (final style in [
      moveraMapStyleFar,
      moveraMapStyleNear,
      moveraMapStyleClose,
    ]) {
      final serialised = _webStyleString(_rules(style));
      expect(serialised.length, lessThanOrEqualTo(950), reason: serialised);
    }
  });

  test('Movera map style has no duplicate selectors', () {
    final seen = <String>{};
    for (final rule in _rules(moveraMapStyleClose)) {
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
    // City-centre business and hospital grounds: pink areas, no labels.
    for (final area in ['poi.business', 'poi.medical']) {
      expect(_visibility(area, 'geometry'), 'on');
      expect(_color(area, 'geometry'), '#F5E0E0');
      expect(_visibility(area), isNull);
      expect(_visibility(area, 'labels'), isNull);
      expect(_visibility(area, 'labels.text'), isNull);
    }
    expect(_visibility('poi.park', 'labels.text'), 'on');
    expect(_visibility('poi.park', 'labels'), isNull);
    expect(_visibility('poi.park'), isNull);
  });

  test('Movera map style uses the measured reference palette', () {
    expect(_color(null, 'geometry'), '#F8FAF8');
    expect(_color(null, 'labels.text.fill'), '#4D4F51');
    expect(_color(null, 'labels.text.stroke'), '#FFFFFF');
    expect(_color('landscape.man_made', 'geometry'), '#DDDEE0');
    expect(_color('poi.park', 'geometry'), '#B6EFC2');
    expect(_color('poi.park', 'labels.text.fill'), '#14793A');
    expect(_color('water', 'geometry'), '#95DFFF');
    expect(_color('road', 'geometry'), '#CACFD2');
    expect(_color('road.arterial', 'geometry'), '#ACB1B6');
    expect(_color('road.highway', 'geometry'), '#ACB1B6');
    expect(_color('administrative.locality', 'labels.text.fill'), '#5E7F90');
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

  test('far and near styles differ only in the park green', () {
    expect(moveraMapStyle, moveraMapStyleNear);
    expect(moveraMapStyleNear, contains('#B6EFC2'));
    expect(moveraMapStyleFar, contains('#D8F5DF'));
    expect(
      moveraMapStyleFar.replaceAll('#D8F5DF', '#B6EFC2'),
      moveraMapStyleNear,
    );
    for (final style in [moveraMapStyleFar, moveraMapStyleNear]) {
      expect(style, contains('#95DFFF'));
    }
  });

  test('zoomed right in the roads get a heavier, bolder edge', () {
    final close = _rules(moveraMapStyleClose);
    double? weight(String road) {
      for (final rule in close) {
        if (rule['featureType'] == road &&
            rule['elementType'] == 'geometry.stroke') {
          final styler = (rule['stylers'] as List).single as Map;
          return (styler['weight'] as num?)?.toDouble();
        }
      }
      return null;
    }

    // Wider by class: local = arterial (darker) < highway; whole numbers
    // for the web plugin (driver-03f).
    expect(weight('road.local'), 2);
    expect(weight('road.arterial'), 2);
    expect(weight('road.highway'), 3);
    // Otherwise the near style: same palette, same park green.
    expect(
      moveraMapStyleClose.replaceAll(moveraCloseRoads, ''),
      moveraMapStyleNear,
    );
    // Zoomed out the SDK's own thin roads stay: no weights.
    for (final style in [moveraMapStyleFar, moveraMapStyleNear]) {
      expect(style, isNot(contains('"weight"')));
    }
  });

  // driver-03f: google_maps_flutter_web 0.5.14+2 turns each styler into a
  // MapStyler with these casts (MapStyler.fromJson); one wrong type throws
  // and the web map is never styled or drawn (grey at zoom 17). Every band
  // must pass the same casts.
  test('every style band passes the web plugin\'s styler casts', () {
    Object? webStyler(Map<String, Object?> json) => (
      json['hue'] as String?,
      json['lightness'] as num?,
      json['saturation'] as num?,
      json['gamma'] as num?,
      json['invert_lightness'] as bool?,
      json['visibility'] as String?,
      json['color'] as String?,
      json['weight'] as int?,
    );
    for (final band in MoveraMapStyleBand.values) {
      for (final rule in _rules(band.style)) {
        expect(rule['featureType'], anyOf(isNull, isA<String>()));
        expect(rule['elementType'], anyOf(isNull, isA<String>()));
        for (final styler in (rule['stylers'] as List<Object?>)) {
          final json = (styler as Map).cast<String, Object?>();
          expect(
            _stylerKeys.keys,
            containsAll(json.keys),
            reason: '$band: only stylers Maps knows',
          );
          expect(
            () => webStyler(json),
            returnsNormally,
            reason: '$band: $json',
          );
        }
      }
    }
    // The bug itself: a fractional weight fails these casts.
    expect(
      () => webStyler({'weight': jsonDecode('2.5')}),
      throwsA(isA<TypeError>()),
    );
  });

  test('style band switches at 12.5 with hysteresis', () {
    expect(MoveraMapStyleBand.of(11), MoveraMapStyleBand.far);
    expect(MoveraMapStyleBand.of(12.49), MoveraMapStyleBand.far);
    expect(MoveraMapStyleBand.of(12.5), MoveraMapStyleBand.near);
    expect(MoveraMapStyleBand.of(15), MoveraMapStyleBand.near);
    expect(MoveraMapStyleBand.of(15.5), MoveraMapStyleBand.close);
    // Far stays far until 12.6; near stays near until 12.4.
    var band = MoveraMapStyleBand.far;
    final seen = <MoveraMapStyleBand>[];
    for (final zoom in <double>[
      12.45,
      12.55,
      12.59,
      12.6,
      12.5,
      12.45,
      12.41,
      12.4,
      12.5,
      12.55,
      double.nan,
      16.0,
    ]) {
      band = band.at(zoom);
      seen.add(band);
    }
    const f = MoveraMapStyleBand.far, n = MoveraMapStyleBand.near;
    const c = MoveraMapStyleBand.close;
    expect(seen, [f, f, f, n, n, n, n, f, f, f, f, c]);
    expect(MoveraMapStyleBand.far.style, moveraMapStyleFar);
    expect(MoveraMapStyleBand.near.style, moveraMapStyleNear);
    expect(MoveraMapStyleBand.close.style, moveraMapStyleClose);
  });

  test('close roads start above every guidance zoom, with hysteresis', () {
    // Guidance stays at 15 and below (turns 15.4, arrival 15.5): driving
    // never swaps the style; the locate view (15) stays near.
    var band = MoveraMapStyleBand.near;
    final seen = <MoveraMapStyleBand>[];
    for (final zoom in <double>[
      15,
      15.4,
      15.5,
      15.59,
      15.6,
      15.5,
      15.41,
      15.4,
      15.5,
      17,
      12,
    ]) {
      band = band.at(zoom);
      seen.add(band);
    }
    const f = MoveraMapStyleBand.far, n = MoveraMapStyleBand.near;
    const c = MoveraMapStyleBand.close;
    expect(seen, [n, n, n, n, c, c, c, n, n, c, f]);
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/surge/surge_map.dart';
import 'package:movera/presentation/driver/home/components/home_map_layers.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File('contracts/$path').readAsStringSync())
        as Map<String, dynamic>;

String _hex(Color colour) =>
    '#${(colour.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Contract v0.7.2 §17: the driver map's colour level per surge multiplier
/// (`fixtures/surge_levels.json`) and its colours
/// (`contract.json#driverSurgeMap.colours`).
void main() {
  final contract = _json('contract.json');
  final map = contract['driverSurgeMap'] as Map<String, dynamic>;

  test('replays fixtures/surge_levels.json', () {
    final cases = (_json('fixtures/surge_levels.json')['cases'] as List)
        .cast<Map<String, dynamic>>();
    expect(cases, isNotEmpty);
    for (final c in cases) {
      final level = SurgeLevel.forMultiplier((c['multiplier'] as num) * 1.0);
      expect(level?.name, c['level'], reason: 'multiplier ${c['multiplier']}');
    }
  });

  test('each level has the colour contract.json#driverSurgeMap names', () {
    final colours = map['colours'] as String;
    expect(surgeLevelColours.keys.toSet(), SurgeLevel.values.toSet());
    for (final level in SurgeLevel.values) {
      final hex = _hex(surgeLevelColours[level]!);
      expect(
        RegExp('${level.name} $hex').hasMatch(colours),
        isTrue,
        reason: '$level should be $hex in "$colours"',
      );
    }
    expect(_hex(surgeLevelColours[SurgeLevel.low]!), '#FFC79E');
    expect(_hex(surgeLevelColours[SurgeLevel.medium]!), '#FF8A3D');
    expect(_hex(surgeLevelColours[SurgeLevel.high]!), '#E5482B');
    expect(colours, contains('40 %'));
    expect(colours, contains('2 px'));
  });

  test('the tip distance is contract.json#driverSurgeMap.tipDistanceKm', () {
    expect(surgeTipDistanceKm, map['tipDistanceKm']);
  });

  test('every wire level is read; nothing else is', () {
    for (final level in SurgeLevel.values) {
      expect(SurgeLevel.fromWire(level.name), level);
    }
    expect(SurgeLevel.fromWire('extreme'), isNull);
    expect(SurgeLevel.fromWire(2.0), isNull);
  });
}

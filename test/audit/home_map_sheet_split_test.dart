import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Home map and sheet presentation sit outside the widget file', () {
    final home = File(
      'lib/presentation/driver/home/home.dart',
    ).readAsStringSync();
    final sheet = File(
      'lib/presentation/driver/home/home_map_sheet.dart',
    ).readAsStringSync();

    expect(home, contains("part 'home_map_sheet.dart';"));
    expect(home, contains('class DriverHome'));
    expect(home, contains('void _goOnline()'));
    expect(home, isNot(contains('Future<void> _startDriverLocation')));
    expect(home, isNot(contains('Widget panelColumn')));
    expect(sheet, contains("part of 'home.dart';"));
    expect(sheet, contains('extension _HomeMapSheet on _DriverHomeState'));
    expect(sheet, contains('Future<void> _startDriverLocation'));
    expect(sheet, contains('Widget panelColumn'));
    expect(sheet, isNot(contains('setState(')));
    // Phase 2: was < 1200 before `dart format` (tall style); same code
    // measured 1198 → 1407 lines, so the limit scales by the same factor.
    expect(home.split('\n').length, lessThan(1410));
  });

  test('Job 9 split: top island sits in its own part, every part < 1500', () {
    final home = File(
      'lib/presentation/driver/home/home.dart',
    ).readAsStringSync();
    final sheet = File(
      'lib/presentation/driver/home/home_map_sheet.dart',
    ).readAsStringSync();
    final island = File(
      'lib/presentation/driver/home/home_map_top_island.dart',
    ).readAsStringSync();
    expect(home, contains("part 'home_map_top_island.dart';"));
    expect(island, contains("part of 'home.dart';"));
    expect(island, contains('extension _HomeMapTopIsland on _DriverHomeState'));
    expect(island, contains('Widget _buildTopIsland(double viewportWidth)'));
    expect(sheet, isNot(contains('Widget _buildTopIsland(')));
    expect(sheet.split('\n').length, lessThan(1500));
    expect(island.split('\n').length, lessThan(1500));
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Wave 5 D5.4: the decision records say what the build does.
String _read(String path) => File(path).readAsStringSync();

void main() {
  test('driver-2: DECISIONS.md names the contract version the copy pins', () {
    final version = RegExp(r'"version": "([\d.]+)"')
        .firstMatch(_read('contracts/contract.json'))!
        .group(1)!;
    final decisions = _read('docs/DECISIONS.md');
    expect(decisions, contains('`contracts/contract.json` (v$version,'));
    expect(decisions, contains('shared Movera contract v$version'));
    expect(decisions, isNot(contains('v0.3.0')));
  });

  test('driver-3: DECISIONS.md describes the live car marker as built', () {
    final decisions = _read('docs/DECISIONS.md');
    final trip = _read('lib/presentation/driver/accept ride/accept_ride.dart');
    expect(trip, contains('Timer.periodic(const Duration(milliseconds: 33)'));
    expect(decisions, isNot(contains('5Hz')));
    expect(decisions, contains('33 ms'));
    expect(decisions, contains('updateMarkers'));
  });

  test('driver-43: DECISIONS.md says the trip takes every web GPS fix', () {
    final decisions = _read('docs/DECISIONS.md');
    final trip =
        _read('lib/presentation/driver/accept ride/accept_ride_trip.dart');
    // The trip takes every fix; a fix costs no rebuild (D-07).
    expect(trip, contains('watchPosition(distanceFilterMeters: 0)'));
    expect(decisions, isNot(contains('GPS filter is 20m')));
    expect(decisions, contains('distanceFilterMeters: 0'));
  });

  test('driver-4: the documented key referrer is the path Pages serves', () {
    final base = RegExp(r'--base-href "(/[^"]+/)"')
        .firstMatch(_read('.github/workflows/deploy-pages.yml'))!
        .group(1)!;
    expect(_read('docs/PRIVACY_SECURITY.md'),
        contains('`https://baccarisverige-ux.github.io$base*`'));
    expect(_read('docs/BASELINE.md'),
        contains('`baccarisverige-ux${base.substring(0, base.length - 1)}`'));
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/navigation/driver_camera_controller.dart';

/// Wave 5 D5.4: the decision records say what the build does.
String _read(String path) => File(path).readAsStringSync();

void main() {
  test('driver-2: DECISIONS.md names the contract version the copy pins', () {
    final version = RegExp(
      r'"version": "([\d.]+)"',
    ).firstMatch(_read('contracts/contract.json'))!.group(1)!;
    final decisions = _read('docs/DECISIONS.md');
    expect(decisions, contains('`contracts/contract.json` (v$version,'));
    expect(decisions, contains('shared Movera contract v$version'));
    expect(decisions, isNot(contains('v0.3.0')));
  });

  test('driver-3: DECISIONS.md describes the live car marker as built', () {
    final decisions = _read('docs/DECISIONS.md');
    // Whitespace-insensitive: `dart format` may wrap the expression.
    final trip = _read(
      'lib/presentation/driver/accept ride/accept_ride.dart',
    ).replaceAll(RegExp(r'\s+'), ' ');
    expect(trip, contains('Timer.periodic(const Duration(milliseconds: 33)'));
    expect(decisions, isNot(contains('5Hz')));
    expect(decisions, contains('33 ms'));
    expect(decisions, contains('updateMarkers'));
  });

  test('driver-43: DECISIONS.md says the trip takes every web GPS fix', () {
    final decisions = _read('docs/DECISIONS.md');
    final trip = _read(
      'lib/presentation/driver/accept ride/accept_ride_trip.dart',
    );
    // The trip takes every fix; a fix costs no rebuild (D-07).
    expect(trip, contains('watchPosition(distanceFilterMeters: 0)'));
    expect(decisions, isNot(contains('GPS filter is 20m')));
    expect(decisions, contains('distanceFilterMeters: 0'));
  });

  test('driver-4: the documented key referrer is the path Pages serves', () {
    // The demo build's base (the live build under /live/ sits below it,
    // so the same referrer covers both).
    final base = RegExp(
      r'--base-href "(/[^"]+/)"[^\n]*MOVERA_DEMO_ARRIVAL',
    ).firstMatch(_read('.github/workflows/deploy-pages.yml'))!.group(1)!;
    expect(base, '/Movera-driver-app/');
    expect(
      _read('docs/PRIVACY_SECURITY.md'),
      contains('`https://baccarisverige-ux.github.io$base*`'),
    );
    expect(
      _read('docs/BASELINE.md'),
      contains('`baccarisverige-ux${base.substring(0, base.length - 1)}`'),
    );
  });

  test('driver-6: the camera doc gives the numbers the camera uses', () {
    final doc = _read('docs/driver-camera-architecture.md');
    String n(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';
    // Whitespace-insensitive: `dart format` may wrap the expression.
    final trip = _read(
      'lib/presentation/driver/accept ride/accept_ride.dart',
    ).replaceAll(RegExp(r'\s+'), ' ');
    expect(trip, contains('DriverCameraMode.following ? .75 : .5'));
    expect(doc, contains('**75% of screen height**'));
    expect(doc, isNot(contains('72%')));
    expect(doc, contains('zoom ${n(DriverCameraPolicy.exploreZoom)}'));
    expect(doc, contains('up to ${n(DriverCameraPolicy.maxTilt)} degrees'));
    expect(
      doc,
      contains(
        '${n(DriverCameraPolicy.zoomForSpeed(0))} at a '
        'standstill',
      ),
    );
    expect(
      doc,
      contains(
        '${n(DriverCameraPolicy.zoomForSpeed(40))} on the '
        'highway',
      ),
    );
    expect(doc, contains('toward ${n(DriverCameraPolicy.turnZoom)}'));
    expect(doc, contains('Last ${n(DriverCameraPolicy.arrivalMeters)} m'));
    expect(doc, contains('${n(DriverCameraPolicy.arrivalTilt)} degrees'));
    // The web verifier checks the anchor the app passes.
    final verifier = _read('tool/verify_driver_map_web.cjs');
    expect(verifier, isNot(contains('.72)')));
    expect(verifier, contains('200, .75)'));
  });
}

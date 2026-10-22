// Wave 5 D5.6: small local fixes, one test per bug.
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/routing/route_instruction.dart';
import 'package:movera/l10n/app_localizations.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/navigation/driver_camera_controller.dart';
import 'package:movera/core/routing/route_repository.dart';

/// Records every pose the camera resolves.
class _SpyPolicy extends DriverCameraPolicy {
  final poses = <DriverCameraPose>[];
  @override
  DriverCameraPose resolve({
    required DriverLocation location,
    RoadRoute? route,
    bool navigating = false,
    bool waiting = false,
    bool immediate = false,
    bool sameFix = false,
  }) {
    final pose = super.resolve(
      location: location,
      route: route,
      navigating: navigating,
      waiting: waiting,
      immediate: immediate,
      sameFix: sameFix,
    );
    poses.add(pose);
    return pose;
  }
}

final _en = lookupAppLocalizations(const Locale('en'));
final _sv = lookupAppLocalizations(const Locale('sv'));

RoadRoute _road(GeoPoint from, GeoPoint to) => RoadRoute(
      points: [from, to],
      distanceMeters: from.distanceMetersTo(to),
      durationSeconds: 600,
    );

void main() {
  test('driver-u5: a keyless iOS release with the key required fails', () {
    ProcessResult gate(Map<String, String> env) => Process.runSync(
          '/bin/sh',
          ['ios/scripts/require_maps_key.sh'],
          environment: {'PATH': '/usr/bin:/bin', ...env},
          includeParentEnvironment: false,
        );
    final keyless = gate({
      'CONFIGURATION': 'Release',
      'MOVERA_REQUIRE_MAPS_KEY': 'true',
      'GOOGLE_MAPS_API_KEY': ' ',
    });
    expect(keyless.exitCode, 1);
    expect('${keyless.stdout}',
        contains('Native release requires GOOGLE_MAPS_API_KEY'));
    expect(
      gate({
        'CONFIGURATION': 'Release',
        'MOVERA_REQUIRE_MAPS_KEY': 'true',
        'GOOGLE_MAPS_API_KEY': 'key',
      }).exitCode,
      0,
    );
    expect(gate({'CONFIGURATION': 'Release'}).exitCode, 0);
    // The Runner target runs it before it builds anything.
    final project =
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(project, contains(r'\"$SRCROOT/scripts/require_maps_key.sh\"'));
    expect(
      RegExp(r'buildPhases = \(\s*(\w+) /\* Require Maps Key \*/,\s*\w+ /\* Run Script \*/')
          .hasMatch(project),
      isTrue,
    );
  });

  test('driver-21: a route refresh does not smooth the same fix twice', () {
    final now = DateTime(2026, 10, 22, 8);
    final policy = _SpyPolicy();
    final camera = DriverCameraController(policy: policy, now: () => now);
    const a = GeoPoint(59.33, 18.06), b = GeoPoint(59.36, 18.06);
    DriverLocation fix(double speed) => DriverLocation(
          point: a,
          speedMetersPerSecond: speed,
          measuredAt: now,
          accuracyMeters: 5,
        );
    camera.update(location: fix(0), route: _road(a, b), navigating: true);
    final fast = fix(30);
    camera.update(location: fast, route: _road(a, b), navigating: true);
    // The trip's route refresh reports the same fix with a new route.
    camera.update(location: fast, route: _road(a, b), navigating: true);
    final once = policy.poses[1], again = policy.poses[2];
    // Before: 14.75 then 14.5, the speed zoom stepped twice for one fix.
    expect(again.zoom, once.zoom);
    expect(again.bearing, once.bearing);
    camera.dispose();
  });

  test('driver-27: a distance is rounded before its unit is picked', () {
    String say(double m) => RouteInstructionCopy.formatDistance(m, _en);
    expect(say(999.4), '999 m');
    expect(say(999.6), '1.0 km'); // before: 1000 m
    expect(say(9949), '9.9 km');
    expect(say(9960), '10 km'); // before: 10.0 km
    expect(RouteInstructionCopy.formatDistance(9960, _sv), '10 km');
  });
}

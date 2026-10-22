// Wave 5 D5.6: small local fixes, one test per bug.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
}

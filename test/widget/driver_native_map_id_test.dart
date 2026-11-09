import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/styles/movera_map_style.dart';
import 'package:movera/widgets/custom_google_map.dart';

import '../../integration_test/headless_map_platform.dart';

/// Owner (2026-11-08): the driver APK did not use the Movera Map ID (his
/// styled cloud map) while the web did. Native maps now take the Map ID from
/// `--dart-define=MOVERA_GOOGLE_MAP_ID`, like the rider app, and every native
/// build workflow passes the DRIVER_MAP_ID variable into it.
void main() {
  Future<GoogleMap> pumpMap(WidgetTester tester, Widget map) async {
    final original = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = original);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: map)));
    await tester.pump();
    return tester.widget<GoogleMap>(find.byType(GoogleMap));
  }

  testWidgets('native map uses the configured Cloud Map ID', (tester) async {
    final map = await pumpMap(
      tester,
      const CustomGoogleMap(
        myLocationEnabled: false,
        cloudMapId: ' 9fdc5d9e56d4a091 ',
      ),
    );
    expect(map.cloudMapId, '9fdc5d9e56d4a091');
    expect(
      map.style,
      isNull,
      reason: 'the cloud style draws the map; Google ignores inline JSON',
    );
  });

  testWidgets('no Map ID configured: the in-app Movera style, as before', (
    tester,
  ) async {
    expect(moveraGoogleMapId, isEmpty, reason: 'tests run without the define');
    final map = await pumpMap(
      tester,
      const CustomGoogleMap(myLocationEnabled: false),
    );
    expect(map.cloudMapId, isNull);
    expect(map.style, moveraMapStyle);
  });

  test('the Map ID define is MOVERA_GOOGLE_MAP_ID', () {
    final source = File(
      'lib/widgets/custom_google_map.dart',
    ).readAsStringSync();
    expect(source, contains("String.fromEnvironment('MOVERA_GOOGLE_MAP_ID')"));
  });

  test('every native build workflow passes DRIVER_MAP_ID as the Map ID', () {
    const define = '--dart-define=MOVERA_GOOGLE_MAP_ID="\${DRIVER_MAP_ID:-}"';
    final apk = File(
      '.github/workflows/android-test-apk.yml',
    ).readAsStringSync();
    expect(apk, contains(r'DRIVER_MAP_ID: ${{ vars.DRIVER_MAP_ID }}'));
    expect(apk, contains("grep -Eq '^[A-Za-z0-9]+\$'"));
    expect(apk, contains('::warning::No DRIVER_MAP_ID'));
    final apkBuilds = 'flutter build apk'.allMatches(apk).length;
    expect(apkBuilds, 1, reason: 'one build() makes both APKs');
    expect(define.allMatches(apk).length, apkBuilds);

    for (final (path, command) in [
      (
        '.github/workflows/drider-ci.yml',
        'MOVERA_ALLOW_DEBUG_SIGNED_PREVIEW=true flutter build apk --release \\',
      ),
      (
        '.github/workflows/drider-ios.yml',
        'flutter build ios --release --no-codesign \\',
      ),
    ]) {
      final lines = File(path).readAsLinesSync();
      final at = lines.indexWhere((line) => line.trim() == command);
      expect(at, isNot(-1), reason: '$path builds the native app');
      expect(lines[at + 1].trim(), define, reason: path);
    }
  });
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/styles/movera_map_style.dart';
import 'package:movera/widgets/custom_google_map.dart';
import 'package:movera/core/navigation/map_double_tap_policy.dart';

import '../../integration_test/headless_map_platform.dart';

void main() {
  test('tap proximity and time threshold reject stale/distant taps', () {
    const at = Duration(seconds: 1);
    const position = Offset(100, 200);
    bool second(Duration next, Offset point) =>
        MapDoubleTapPolicy.isSecondTap(
          previousAt: at,
          previousPosition: position,
          currentAt: next,
          currentPosition: point,
        );
    expect(second(const Duration(milliseconds: 1150), position), isTrue);
    expect(second(const Duration(milliseconds: 1300), position), isTrue);
    expect(second(const Duration(milliseconds: 1301), position), isFalse,
        reason: 'Two taps more than 300 ms apart are unrelated');
    expect(second(const Duration(milliseconds: 999), position), isFalse);
    expect(second(const Duration(milliseconds: 1080), const Offset(200, 200)),
        isFalse, reason: 'Taps at separate marker positions are unrelated');
    expect(MapDoubleTapPolicy.isSecondTap(
      previousAt: null, previousPosition: null,
      currentAt: const Duration(milliseconds: 1200),
      currentPosition: position,
    ), isFalse);
  });

  testWidgets('clean map: Movera style, no "3D unavailable" chip', (
    tester,
  ) async {
    final original = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = original);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: CustomGoogleMap(myLocationEnabled: false)),
    ));
    await tester.pump();
    expect(tester.widget<GoogleMap>(find.byType(GoogleMap)).style,
        moveraMapStyle);
    expect(find.descendant(
      of: find.byType(CustomGoogleMap),
      matching: find.byType(Text),
    ), findsNothing);
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      expect(source, isNot(contains('3D unavailable')), reason: file.path);
      expect(source, isNot(contains('show3DNotice')), reason: file.path);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('no native web zoom buttons while pinch and pan stay enabled',
      (tester) async {
    final original = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = original);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: CustomGoogleMap(myLocationEnabled: false)),
    ));
    await tester.pump();
    final wrapper = tester.widget<CustomGoogleMap>(find.byType(CustomGoogleMap));
    final sdk = tester.widget<GoogleMap>(find.byType(GoogleMap));
    expect(wrapper.webCameraControlEnabled, isFalse);
    expect(sdk.webCameraControlEnabled, isFalse);
    expect(sdk.zoomControlsEnabled, isFalse);
    expect(sdk.zoomGesturesEnabled, isTrue);
    expect(sdk.scrollGesturesEnabled, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('gesture-locked map ignores pan and pinch then restores input',
      (tester) async {
    final original = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = original);
    var claims = 0;
    Widget screen(bool enabled) => MaterialApp(
      home: Scaffold(
        body: CustomGoogleMap(
          key: const ValueKey('gesture-locked-map'),
          myLocationEnabled: false,
          scrollGesturesEnabled: enabled,
          zoomGesturesEnabled: enabled,
          rotateGesturesEnabled: enabled,
          tiltGesturesEnabled: enabled,
          onUserGesture: () => claims++,
        ),
      ),
    );

    await tester.pumpWidget(screen(false));
    await tester.pump();
    final center = tester.getCenter(find.byType(CustomGoogleMap));
    final drag = await tester.startGesture(center);
    await drag.moveBy(const Offset(24, 0));
    await tester.pump();
    await drag.up();
    final first = await tester.startGesture(
      center + const Offset(-20, 0), pointer: 21);
    final second = await tester.startGesture(
      center + const Offset(20, 0), pointer: 22);
    await tester.pump();
    await second.up();
    await first.up();
    expect(claims, 0, reason: 'Disabled gestures cannot pause following');

    await tester.pumpWidget(screen(true));
    await tester.pump();
    final enabledDrag = await tester.startGesture(center);
    await enabledDrag.moveBy(const Offset(30, 0));
    await tester.pump();
    expect(claims, 1, reason: 'Drag works again when map unlocks');
    await enabledDrag.up();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });


  testWidgets('native stationary double-tap yields camera ownership once',
      (tester) async {
    final original = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = original);
    var claims = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomGoogleMap(
          myLocationEnabled: false,
          onUserGesture: () => claims++,
        ),
      ),
    ));
    await tester.pump();
    final center = tester.getCenter(find.byType(CustomGoogleMap));

    await tester.tapAt(center);
    expect(claims, 0, reason: 'One tap must not pause follow');
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tapAt(center);
    expect(claims, 1,
        reason: 'Native two-tap zoom must stop automatic camera reset');
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tapAt(center);
    expect(claims, 1,
        reason: 'Third tap alone cannot report another zoom gesture');
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('two unrelated taps stay quiet and locked zoom stays disabled',
      (tester) async {
    final original = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = original);
    var claims = 0;
    Future<void> show({required bool zoom}) => tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomGoogleMap(
          key: const ValueKey('native-double-tap-map'),
          myLocationEnabled: false,
          zoomGesturesEnabled: zoom,
          onUserGesture: () => claims++,
        ),
      ),
    ));
    await show(zoom: true);
    final center = tester.getCenter(find.byType(CustomGoogleMap));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(center + const Offset(120, 0));
    expect(claims, 0, reason: 'Distant taps do not claim map camera');
    await show(zoom: false);
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(center);
    expect(claims, 0, reason: 'Zoom-locked map does not yield on double-tap');
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('sheet gesture lock clears stale taps and pointer ownership',
      (tester) async {
    final original = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = original);
    var claims = 0;
    Future<void> show(bool enabled) => tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomGoogleMap(
          key: const ValueKey('lock-interruption-map'),
          myLocationEnabled: false,
          scrollGesturesEnabled: enabled,
          zoomGesturesEnabled: enabled,
          rotateGesturesEnabled: enabled,
          tiltGesturesEnabled: enabled,
          onUserGesture: () => claims++,
        ),
      ),
    ));

    await show(true);
    final center = tester.getCenter(find.byType(CustomGoogleMap));
    await tester.tapAt(center);
    await show(false);
    await show(true);
    await tester.tapAt(center);
    expect(claims, 0,
        reason: 'A tap before the sheet locks cannot complete a new double-tap');

    final interrupted = await tester.startGesture(center, pointer: 31);
    await show(false);
    await show(true);
    final fresh = await tester.startGesture(
      center + const Offset(24, 0), pointer: 32);
    expect(claims, 0,
        reason: 'Held pointer before a sheet lock must not become phantom pinch');
    await fresh.up();
    await interrupted.up();

    final a = await tester.startGesture(
      center + const Offset(-20, 0), pointer: 41);
    final b = await tester.startGesture(
      center + const Offset(20, 0), pointer: 42);
    expect(claims, 1,
        reason: 'A fresh pinch after unlocking must still claim the camera');
    await b.up();
    await a.up();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('map tap preserves following while drag and pinch claim camera',
      (tester) async {
    final original = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = original);
    var gestureClaims = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomGoogleMap(
          myLocationEnabled: false,
          onUserGesture: () => gestureClaims++,
        ),
      ),
    ));
    await tester.pump();
    final center = tester.getCenter(find.byType(CustomGoogleMap));

    await tester.tapAt(center);
    await tester.pump();
    expect(gestureClaims, 0,
        reason: 'A tap must not disable navigation follow camera');

    final drag = await tester.startGesture(center);
    await drag.moveBy(const Offset(4, 0));
    await tester.pump();
    expect(gestureClaims, 0,
        reason: 'Finger jitter must not interrupt camera following');
    await drag.moveBy(const Offset(12, 0));
    await tester.pump();
    expect(gestureClaims, 1,
        reason: 'Physical drag releases camera follow ownership');
    await drag.moveBy(const Offset(20, 0));
    await tester.pump();
    expect(gestureClaims, 1,
        reason: 'One drag reports exactly one ownership transition');
    await drag.up();

    final first = await tester.startGesture(
      center + const Offset(-20, 0),
      pointer: 11,
    );
    await tester.pump();
    expect(gestureClaims, 1);
    final second = await tester.startGesture(
      center + const Offset(20, 0),
      pointer: 12,
    );
    await tester.pump();
    expect(gestureClaims, 2,
        reason: 'Two-finger pinch/rotation immediately claims camera');
    await second.up();
    await first.up();

    await tester.tapAt(center);
    await tester.pump();
    expect(gestureClaims, 2, reason: 'A later tap also stays non-gestural');
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}

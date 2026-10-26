import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/trip_occurrence.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';

class _FarAway implements DriverLocationRepository {
  DriverLocation get _fix => DriverLocation(
    point: const GeoPoint(48.8566, 2.3522), // Paris, far from the demo pickup
    measuredAt: DateTime.now(),
    accuracyMeters: 5,
  );

  @override
  Future<DriverLocation> getCurrentPosition() async => _fix;

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      Stream<DriverLocation>.value(_fix);
}

Future<void> _mount(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) =>
          MaterialApp(home: AcceptRide(locationRepository: _FarAway())),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _tapArrived(WidgetTester tester) async {
  final panel = tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel));
  panel.controller!.animatePanelToSnapPoint();
  for (var i = 0; i < 14; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }

  final button = find.byKey(
    const ValueKey<String>('active-ride-arrived-button'),
  );
  await tester.ensureVisible(button);
  await tester.tap(button);
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  final previous = DriverRuntimeConfig.current;
  tearDown(() => DriverRuntimeConfig.current = previous);

  testWidgets('production policy keeps arrival closed far from the pickup', (
    tester,
  ) async {
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      simulatedArrival: false,
      externalRouting: false,
      skipAccountActivation: false,
      liveMapTicker: false,
    );
    await _mount(tester);
    await _tapArrived(tester);
    expect(
      find.byKey(const ValueKey<String>('active-ride-arrived-button')),
      findsOneWidget,
    );
    expect(
      find.text('Move within 100 m of the pickup to arrive.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('demo policy lets the public demo arrive from anywhere', (
    tester,
  ) async {
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      simulatedArrival: true,
      externalRouting: false,
      skipAccountActivation: false,
      liveMapTicker: false,
    );
    await _mount(tester);
    await _tapArrived(tester);
    expect(
      find.byKey(const ValueKey<String>('active-ride-panel-waitingForRider')),
      findsOneWidget,
    );
    expect(find.text('Waiting for Angelica'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('production build constants enforce every gate', () {
    expect(DriverRuntimeConfig.production.simulatedArrival, isFalse);
    expect(DriverRuntimeConfig.production.externalRouting, isTrue);
    expect(DriverRuntimeConfig.production.skipAccountActivation, isFalse);
  });

  test(
    'D-12: release builds enforce the 100 m arrival check unless they are the demo',
    () {
      bool resolve({
        required bool release,
        bool production = false,
        bool? define,
      }) => DriverRuntimeConfig.simulatedArrivalFor(
        releaseBuild: release,
        productionBuild: production,
        demoArrivalDefine: define,
      );
      // Store / APK / iOS / web release without the demo define: gated.
      expect(resolve(release: true), isFalse);
      // The GitHub Pages demo passes MOVERA_DEMO_ARRIVAL=true: free.
      expect(resolve(release: true, define: true), isTrue);
      // Local debug or profile runs stay free unless told otherwise.
      expect(resolve(release: false), isTrue);
      expect(resolve(release: false, define: false), isFalse);
      // A production composition is always gated, even with the demo define.
      expect(resolve(release: true, production: true, define: true), isFalse);
      expect(resolve(release: false, production: true), isFalse);
    },
  );

  test('D-12: only the Pages demo build passes the free-arrival define', () {
    final pages = File('.github/workflows/deploy-pages.yml').readAsStringSync();
    final builds = pages
        .split('\n')
        .where((line) => line.contains('flutter build web'))
        .toList();
    // The demo at the site root takes the define; the live build under
    // /live/ (the test week's server) keeps the real 100 m check.
    final demo = builds.singleWhere(
      (line) => line.contains('--base-href "/Movera-driver-app/"'),
    );
    expect(demo, contains('--dart-define=MOVERA_DEMO_ARRIVAL=true'));
    for (final other in builds.where((line) => line != demo)) {
      expect(other, isNot(contains('MOVERA_DEMO_ARRIVAL')));
    }
    expect(
      pages.split('MOVERA_DEMO_ARRIVAL').length,
      2,
      reason: 'the define appears once, on the demo build',
    );
    final ci = File('.github/workflows/drider-ci.yml').readAsStringSync();
    expect(ci, isNot(contains('MOVERA_DEMO_ARRIVAL=true')));
  });

  test('each accept gets a distinct trip occurrence', () {
    final a = tripOccurrenceId('nearby-1', now: DateTime.utc(2026, 10, 2, 10));
    final b = tripOccurrenceId(
      'nearby-1',
      now: DateTime.utc(2026, 10, 2, 10, 0, 1),
    );
    expect(a, startsWith('nearby-1-'));
    expect(a, isNot(b));
  });

  test('same-tick acceptances never reuse a local trip ID', () {
    final instant = DateTime.utc(2026, 10, 2, 10);
    final ids = <String>{};
    for (var i = 0; i < 100; i++) {
      ids.add(tripOccurrenceId('nearby-1', now: instant));
    }
    expect(ids, hasLength(100));

    final olderClock = instant.subtract(const Duration(seconds: 10));
    final last = tripOccurrenceId('nearby-1', now: olderClock);
    expect(ids.contains(last), isFalse);
    final anotherOffer = tripOccurrenceId('airport-2', now: olderClock);
    expect(anotherOffer, startsWith('airport-2-'));
    expect(anotherOffer, isNot(last));
  });

  test('every accept path uses the occurrence factory', () {
    for (final path in [
      'lib/presentation/driver/ride requests/ride_requests.dart',
      'lib/presentation/driver/home/home_offer_radar.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('tripOccurrenceId('), reason: path);
      expect(source, isNot(contains('tripId: trip.id,')), reason: path);
      expect(source, isNot(contains('tripId: offer.id,')), reason: path);
    }
  });

  test('production code never inspects the binding type', () {
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where(
          (file) => RegExp(
            r'binding\b.*runtimeType|runtimeType\s*\.toString\(\)\s*\.contains',
            caseSensitive: false,
          ).hasMatch(file.readAsStringSync()),
        )
        .map((file) => file.path)
        .toList();
    expect(offenders, isEmpty);
  });

  test('stage enum is unchanged for persisted snapshots', () {
    expect(ActiveRideStage.values.map((s) => s.name), [
      'headingToPickup',
      'waitingForRider',
      'onTrip',
    ]);
  });
}

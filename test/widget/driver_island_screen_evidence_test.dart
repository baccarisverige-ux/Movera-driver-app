import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import '../../integration_test/headless_map_platform.dart';

import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/routing/route_instruction.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/ride%20completed/ride_completed.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Location implements DriverLocationRepository {
  DriverLocation get fix => DriverLocation(
    point: const GeoPoint(59.3293, 18.0686),
    measuredAt: DateTime.now(),
    accuracyMeters: 5,
    speedMetersPerSecond: 8,
  );
  @override
  Future<DriverLocation> getCurrentPosition() async => fix;
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      Stream.value(fix);
}

class _Route implements RouteRepository {
  const _Route(this.type, this.modifier);
  final RouteManeuverType type;
  final String modifier;
  @override
  Future<RoadRoute> drivingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async => RoadRoute(
    points: [origin, const GeoPoint(59.3320, 18.0686), destination],
    distanceMeters: 1200,
    durationSeconds: 180,
    instructions: [
      RouteInstruction(
        type: type,
        modifier: modifier,
        text: 'Navigation',
        distanceMeters: 300,
        maneuverLocation: const GeoPoint(59.3320, 18.0686),
        roadName: 'Sveavägen',
        exitNumber: type == RouteManeuverType.roundabout ? '2' : null,
        exitAngleDegrees: type == RouteManeuverType.roundabout ? 90 : null,
      ),
    ],
  );
}

void main() {
  testWidgets('Capture every trip layout in the real Driver screen', (
    tester,
  ) async {
    final oldMap = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    final old = DriverRuntimeConfig.current;
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      simulatedArrival: true,
      externalRouting: true,
      skipAccountActivation: true,
      liveMapTicker: false,
      reservationPopup: false,
      islandHint: false,
    );
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      DriverRuntimeConfig.current = old;
      GoogleMapsFlutterPlatform.instance = oldMap;
      await tester.binding.setSurfaceSize(null);
    });
    final loader = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await loader.load();
    String? font;
    final root = Platform.environment['FLUTTER_ROOT'];
    if (root != null) {
      final file = File(
        '$root/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
      );
      if (file.existsSync()) {
        await (FontLoader('ScreenProof')..addFont(
              Future.value(ByteData.sublistView(file.readAsBytesSync())),
            ))
            .load();
        font = 'ScreenProof';
      }
    }
    Future<void> capture(String name) async {
      // Dismiss the independent demo radar offer through its real button so
      // the screenshot shows the trip sheet rather than an unrelated offer.
      final deny = find
          .byKey(const ValueKey('on-trip-radar-deny'))
          .hitTestable();
      if (deny.evaluate().isNotEmpty) {
        await tester.tap(deny);
        await tester.pump(const Duration(milliseconds: 300));
      }
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('screen-proof')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/test-evidence/screens/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull, reason: name);
    }

    Future<void> open(Widget page) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: font),
          home: RepaintBoundary(
            key: const ValueKey('screen-proof'),
            child: page,
          ),
        ),
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    AcceptRide ride({
      ActiveRideStage stage = ActiveRideStage.headingToPickup,
      RouteManeuverType type = RouteManeuverType.continueStraight,
      String modifier = 'straight',
      bool near = false,
      bool stop = false,
      bool stopWait = false,
    }) => AcceptRide(
      initialStage: stage,
      riderName: 'Angelica',
      initialWaitSeconds: 155,
      locationRepository: _Location(),
      routeRepository: _Route(type, modifier),
      pickupAddress: 'Köpmangatan 12',
      pickupPosition: near
          ? const LatLng(59.3302, 18.0686)
          : const LatLng(59.3400, 18.0686),
      dropoffAddress: 'Storgatan 8',
      dropoffPosition: near
          ? const LatLng(59.3302, 18.0686)
          : const LatLng(59.3450, 18.0686),
      stopAddresses: stop ? const ['Sveavägen 20'] : const [],
      stopPositions: stop
          ? [
              near
                  ? const LatLng(59.3302, 18.0686)
                  : const LatLng(59.3400, 18.0686),
            ]
          : const [],
      restoredSnapshot: stopWait
          ? const PersistedActiveRide(
              tripId: 'demo-radar-offer',
              stage: ActiveRideStage.onTrip,
              paidStopWait: true,
            )
          : null,
    );
    await open(ride());
    await capture('01-pickup');
    await open(ride());
    await capture('02-straight');
    await open(ride(type: RouteManeuverType.turn, modifier: 'right'));
    await capture('03-right');
    await open(ride(type: RouteManeuverType.roundabout));
    await capture('04-roundabout');
    await open(ride(near: true));
    await capture('05-arrival-pickup');
    await open(ride(stage: ActiveRideStage.waitingForRider));
    await capture('06-waiting-timer');
    for (
      var tick = 0;
      tick < 50 &&
          find.byKey(const ValueKey('island-waiting-name')).evaluate().isEmpty;
      tick++
    ) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pump(const Duration(milliseconds: 700));
    await capture('07-waiting-rider');
    await open(ride(stage: ActiveRideStage.onTrip));
    await capture('08-trip-started');
    await open(
      ride(
        stage: ActiveRideStage.onTrip,
        type: RouteManeuverType.fork,
        modifier: 'left',
      ),
    );
    await capture('09-dropoff');
    await open(ride(stage: ActiveRideStage.onTrip, stop: true, near: true));
    await capture('10-arriving-stop');
    await open(ride(stage: ActiveRideStage.onTrip, stop: true, stopWait: true));
    await capture('10b-stop-timer');
    for (
      var tick = 0;
      tick < 50 &&
          find.byKey(const ValueKey('island-waiting-name')).evaluate().isEmpty;
      tick++
    ) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pump(const Duration(milliseconds: 700));
    await capture('10c-stop-message');
    await open(ride(stage: ActiveRideStage.onTrip, near: true));
    await capture('11-arrival-destination');
    await open(const DriverRideCompleted());
    await capture('12-completed');
    await tester.pumpWidget(const SizedBox());
  });
}

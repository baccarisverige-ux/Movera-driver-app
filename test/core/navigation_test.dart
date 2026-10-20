import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/navigation/navigation_controller.dart';
import 'package:movera/core/navigation/route_progress.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/routing/osrm_route_parser.dart';
import 'package:movera/core/routing/route_instruction.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/presentation/driver/overlays/map_overlay_insets.dart';
import 'package:movera/widgets/movera_sheet_metrics.dart';

void main() {
  test('shortest heading interpolation never spins the long way', () {
    expect(GeoPoint.shortestAngleLerp(10, 350, 1), closeTo(350, 0.001));
    expect(GeoPoint.shortestAngleLerp(350, 10, 1), closeTo(10, 0.001));
    expect(GeoPoint.shortestAngleLerp(0, 180, 0.5), closeTo(90, 0.5));
  });

  test('OSRM parser maps steps into domain instructions', () {
    const parser = OsrmRouteParser();
    final route = parser.parseRoute(<String, dynamic>{
      'distance': 420.0,
      'duration': 96.0,
      'geometry': <String, dynamic>{
        'coordinates': <List<double>>[
          <double>[18.0615, 59.3279],
          <double>[18.0630, 59.3290],
          <double>[18.0649, 59.3326],
        ],
      },
      'legs': <Map<String, dynamic>>[
        <String, dynamic>{
          'steps': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'Sveavägen',
              'distance': 300.0,
              'maneuver': <String, dynamic>{
                'type': 'turn',
                'modifier': 'left',
                'location': <double>[18.0630, 59.3290],
              },
            },
            <String, dynamic>{
              'name': '',
              'distance': 120.0,
              'maneuver': <String, dynamic>{
                'type': 'roundabout',
                'modifier': '',
                'exit': 2,
                'location': <double>[18.0649, 59.3326],
              },
            },
          ],
        },
      ],
    });

    expect(route.points, hasLength(3));
    expect(route.instructions, hasLength(2));
    expect(route.instructions.first.text, 'Turn left onto Sveavägen');
    expect(route.instructions.first.type, RouteManeuverType.turn);
    expect(
      route.instructions.last.text,
      'At roundabout, take exit 2',
    );
  });

  test('route progress advances to the next maneuver after it is passed', () {
    const calculator = RouteProgressCalculator();
    final route = RoadRoute(
      points: const [
        GeoPoint(59.3279, 18.0615),
        GeoPoint(59.3290, 18.0630),
        GeoPoint(59.3326, 18.0649),
      ],
      distanceMeters: 420,
      durationSeconds: 90,
      instructions: const [
        RouteInstruction(
          type: RouteManeuverType.turn,
          modifier: 'left',
          text: 'Turn left',
          distanceMeters: 80,
          maneuverLocation: GeoPoint(59.3290, 18.0630),
          roadName: 'Sveavägen',
        ),
        RouteInstruction(
          type: RouteManeuverType.arrive,
          modifier: '',
          text: 'Arrive at destination',
          distanceMeters: 200,
          maneuverLocation: GeoPoint(59.3326, 18.0649),
        ),
      ],
    );

    final before = calculator.measure(
      route: route,
      position: const GeoPoint(59.32795, 18.0616),
    );
    expect(before.nextInstruction?.type, RouteManeuverType.turn);
    expect(before.offRoute, isFalse);

    final after = calculator.measure(
      route: route,
      position: const GeoPoint(59.3318, 18.0644),
      instructionHint: 0,
    );
    expect(after.nextInstruction?.type, RouteManeuverType.arrive);
  });

  test('navigation keeps the trip and shows retryable route failure', () async {
    final navigation = NavigationController(
      routeRepository: _FailingRouteRepository(),
    );
    navigation.setVehicle(
      const DriverLocation(
        point: GeoPoint(59.3279, 18.0615),
        headingDegrees: 12,
      ),
    );
    await navigation.ensureRoute(
      origin: const GeoPoint(59.3279, 18.0615),
      destination: const GeoPoint(59.3326, 18.0649),
      force: true,
    );

    expect(navigation.route, isNull);
    expect(navigation.snapshot.status, 'Route unavailable — retry');
    expect(navigation.routeState, RouteLoadState.failed);
    expect(navigation.snapshot.banner, isNotNull);
  });

  test('measured stale and inaccurate GPS never moves navigation vehicle', () {
    final navigation = NavigationController(
      routeRepository: _FailingRouteRepository(),
    );
    addTearDown(navigation.dispose);
    final now = DateTime.now();
    const good = GeoPoint(59.3279, 18.0615);
    const wrong = GeoPoint(59.50, 18.3);
    navigation.setVehicle(DriverLocation(
      point: good,
      measuredAt: now,
      accuracyMeters: 5,
    ));
    expect(navigation.snapshot.vehicle, good);

    navigation.keepLastKnown();
    final invalidLocations = [
      DriverLocation(
        point: wrong,
        measuredAt: now.subtract(const Duration(minutes: 4)),
        accuracyMeters: 5,
      ),
      DriverLocation(point: wrong, measuredAt: now, accuracyMeters: 90),
      DriverLocation(
        point: wrong,
        measuredAt: now.add(const Duration(minutes: 1)),
        accuracyMeters: 5,
      ),
      DriverLocation(point: wrong, measuredAt: now),
      DriverLocation(
        point: const GeoPoint(double.nan, 18),
        measuredAt: now,
        accuracyMeters: 5,
      ),
    ];
    for (final invalid in invalidLocations) {
      navigation.setVehicle(invalid);
      expect(navigation.snapshot.vehicle, good);
      expect(navigation.status, 'Location updating…');
    }

    // 25 km away a moment later is a GPS jump until a second fix agrees.
    for (var i = 0; i < 2; i++) {
      navigation.setVehicle(DriverLocation(
        point: wrong,
        measuredAt: DateTime.now(),
        accuracyMeters: 5,
      ));
    }
    expect(navigation.snapshot.vehicle, wrong);
    expect(navigation.status, isNull);
  });

  test('legacy demo vehicle without measurement metadata still renders', () {
    final navigation = NavigationController(
      routeRepository: _FailingRouteRepository(),
    );
    addTearDown(navigation.dispose);
    const demo = GeoPoint(59.33, 18.06);
    navigation.setVehicle(const DriverLocation(point: demo));
    expect(navigation.snapshot.vehicle, demo);
    navigation.setVehicle(const DriverLocation(
      point: GeoPoint(91, 18),
    ));
    expect(navigation.snapshot.vehicle, demo);
  });

  test('fresh stationary GPS clears a previous location warning', () {
    final navigation = NavigationController(
      routeRepository: _FailingRouteRepository(),
    );
    addTearDown(navigation.dispose);
    final fix = DriverLocation(
      point: const GeoPoint(59.3279, 18.0615),
      measuredAt: DateTime.now(),
      accuracyMeters: 5,
    );
    navigation.setVehicle(fix);
    navigation.keepLastKnown();
    expect(navigation.snapshot.status, 'Location updating…');
    navigation.setVehicle(fix); // Same position/heading as before failure.
    expect(navigation.snapshot.status, isNull);
    expect(navigation.snapshot.banner?.status, isNull);
  });

  test('stale GPS cannot clear location warning', () {
    final navigation = NavigationController(
      routeRepository: _FailingRouteRepository(),
    );
    addTearDown(navigation.dispose);
    final point = const GeoPoint(59.3279, 18.0615);
    navigation.setVehicle(DriverLocation(
      point: point,
      measuredAt: DateTime.now(),
      accuracyMeters: 5,
    ));
    navigation.keepLastKnown();
    navigation.setVehicle(DriverLocation(
      point: point,
      measuredAt: DateTime.now().subtract(const Duration(minutes: 2)),
      accuracyMeters: 5,
    ));
    expect(navigation.snapshot.status, 'Location updating…');
  });

  test('waiting stage replaces turn-by-turn copy', () {
    final navigation = NavigationController(
      routeRepository: _FailingRouteRepository(),
    );
    navigation.setStage(ActiveRideStage.waitingForRider);
    expect(navigation.snapshot.banner?.primary, 'Pickup');
    expect(navigation.snapshot.banner?.distanceLabel, 'Waiting for rider');
    expect(navigation.snapshot.waitingAtPickup, isTrue);
  });

  test('navigation banner uses live turn-by-turn copy', () async {
    final navigation = NavigationController(
      routeRepository: _TurnRouteRepository(),
    );
    navigation.setVehicle(
      const DriverLocation(
        point: GeoPoint(59.3279, 18.0615),
        headingDegrees: 12,
      ),
    );
    await navigation.ensureRoute(
      origin: const GeoPoint(59.3279, 18.0615),
      destination: const GeoPoint(59.3326, 18.0649),
      force: true,
    );
    expect(navigation.snapshot.banner?.primary, startsWith('Turn left in'));
    expect(navigation.snapshot.banner?.roadName, 'Sveavägen');
  });

  test('home sheet snaps choose next stop from flick velocity', () {
    const snap = 0.42;
    expect(
      MoveraSheetMetrics.targetPosition(
        position: 0.10,
        velocityPxPerSec: -400,
        snap: snap,
      ),
      snap,
    );
    expect(
      MoveraSheetMetrics.targetPosition(
        position: 0.50,
        velocityPxPerSec: -400,
        snap: snap,
      ),
      1.0,
    );
    expect(
      MoveraSheetMetrics.targetPosition(
        position: 0.80,
        velocityPxPerSec: 400,
        snap: snap,
      ),
      snap,
    );
    expect(
      MoveraSheetMetrics.targetPosition(
        position: 0.12,
        velocityPxPerSec: 10,
        snap: snap,
      ),
      0,
    );
  });

  test('sheet spring is critically damped with no bounce', () {
    expect(MoveraSheetMetrics.collapsedHeight, 108);
    expect(MoveraSheetMetrics.activeCollapsedHeight, 77);
    expect(MoveraSheetMetrics.activeCollapsedTotal(0), 111);
    expect(MoveraSheetMetrics.activeMiddleHeight, 199);
    expect(
      MoveraSheetMetrics.activeSnapPoint(
        collapsed: 111,
        middle: 233,
        expanded: 732,
      ),
      closeTo(0.20, 0.01),
    );
    expect(MoveraSheetMetrics.middleFraction, 0.46);
    expect(MoveraSheetMetrics.expandedFraction, 0.90);
    expect(MoveraSheetMetrics.springMass, 1.0);
    expect(MoveraSheetMetrics.springStiffness, 400);
    expect(MoveraSheetMetrics.springDampingRatio, 1.05);
    expect(MoveraSheetMetrics.spring.damping, greaterThan(38));
  });

  test('live navigation copy matches driver banner examples', () {
    expect(
      RouteInstructionCopy.livePrimary(
        cue: const RouteCue(RouteCueKind.turnLeft),
        meters: 300,
      ),
      'Turn left in 300 m',
    );
    expect(
      RouteInstructionCopy.livePrimary(
        cue: const RouteCue(RouteCueKind.turnRight),
        meters: 150,
      ),
      'Turn right in 150 m',
    );
    expect(
      RouteInstructionCopy.livePrimary(
        cue: const RouteCue(RouteCueKind.continueStraight),
        meters: 1200,
      ),
      'Continue straight 1.2 km',
    );
    expect(
      RouteInstructionCopy.livePrimary(
        cue: const RouteCue(RouteCueKind.roundabout, exit: '2'),
        meters: 80,
      ),
      'Roundabout, exit 2',
    );
    expect(
      RouteInstructionCopy.shortAction(
        type: RouteManeuverType.turn,
        modifier: 'left',
      ),
      'Turn left',
    );
    expect(
      RouteInstructionCopy.shortAction(
        type: RouteManeuverType.roundabout,
        modifier: '',
        exitNumber: '2',
      ),
      'Roundabout, exit 2',
    );
  });

  test('map overlay insets keep fitted routes in the visible map', () {
    final home = MapOverlayInsets.forHome(
      safeTop: 47,
      obscuredBottom: 188,
      hasTopBanner: true,
    );
    expect(home.top, 47 + 68);
    expect(home.bottom, 188 + 18);
    expect(home.boundsPadding, inInclusiveRange(36, 72));

    final ride = MapOverlayInsets.forActiveRide(safeTop: 47);
    expect(ride.top, 47 + 210);
    expect(ride.bottom, MoveraSheetMetrics.activeCollapsedHeight + 10);
    expect(ride.boundsPadding, inInclusiveRange(36, 72));
  });
}

class _FailingRouteRepository implements RouteRepository {
  @override
  Future<RoadRoute> drivingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async {
    throw Exception('offline');
  }
}

class _TurnRouteRepository implements RouteRepository {
  @override
  Future<RoadRoute> drivingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async {
    return RoadRoute(
      points: [
        GeoPoint(origin.latitude, origin.longitude),
        const GeoPoint(59.3290, 18.0630),
        GeoPoint(destination.latitude, destination.longitude),
      ],
      distanceMeters: 420,
      durationSeconds: 90,
      instructions: const [
        RouteInstruction(
          type: RouteManeuverType.turn,
          modifier: 'left',
          text: 'Turn left onto Sveavägen',
          distanceMeters: 300,
          maneuverLocation: GeoPoint(59.3290, 18.0630),
          roadName: 'Sveavägen',
        ),
      ],
    );
  }
}

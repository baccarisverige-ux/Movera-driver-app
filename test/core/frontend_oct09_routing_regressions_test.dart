import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/navigation/route_camera_geometry.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/routing/osrm_route_parser.dart';

Map<String, dynamic> _route({
  Object? coordinates,
  Object? distance = 400,
  Object? duration = 80,
  List<dynamic>? steps,
}) => {
  'geometry': {
    'coordinates':
        coordinates ??
        [
          [18.06, 59.33],
          [18.07, 59.34],
        ],
  },
  'distance': distance,
  'duration': duration,
  'legs': [
    {'steps': steps ?? []},
  ],
};

Map<String, dynamic> _step({
  Object? location,
  Object? distance = 50,
  Object? exit,
}) => {
  'name': 'Main Street',
  'distance': distance,
  'maneuver': {
    'type': 'roundabout',
    'location': location ?? [18.06, 59.33],
    if (exit != null) 'exit': exit,
  },
};

void main() {
  const parser = OsrmRouteParser();

  test('bad route coordinate fails closed instead of drawing shortcuts', () {
    final valid = parser.parseRoute(_route());
    expect(valid.points, const [
      GeoPoint(59.33, 18.06),
      GeoPoint(59.34, 18.07),
    ]);
    for (final invalid in [
      [18.01, double.nan],
      [18.01, 92],
      [181, 59.34],
      [18.02],
      ['bad', 59.32],
    ]) {
      expect(
        () => parser.parseRoute(
          _route(
            coordinates: [
              [18.06, 59.33],
              invalid,
              [18.07, 59.34],
            ],
          ),
        ),
        throwsFormatException,
      );
    }
  });

  test('negative and nonfinite route distances are rejected', () {
    for (final value in [-1, double.nan, double.infinity]) {
      expect(
        () => parser.parseRoute(_route(distance: value)),
        throwsFormatException,
      );
    }
  });

  test('negative and nonfinite route durations are rejected', () {
    for (final value in [-1, double.nan, double.infinity]) {
      expect(
        () => parser.parseRoute(_route(duration: value)),
        throwsFormatException,
      );
    }
  });

  test(
    'invalid maneuver positions cannot appear as navigation instructions',
    () {
      final instructions = parser.parseInstructions(
        _route(
          steps: [
            _step(location: [18, 91]),
            _step(location: [double.nan, 59]),
            _step(location: [18, 59]),
          ],
        ),
      );
      expect(instructions, hasLength(1));
      expect(instructions.single.maneuverLocation, const GeoPoint(59, 18));
    },
  );

  test('invalid maneuver distance is never a negative or NaN callout', () {
    final instructions = parser.parseInstructions(
      _route(
        steps: [
          _step(distance: -2),
          _step(distance: double.nan),
        ],
      ),
    );
    expect(instructions.map((step) => step.distanceMeters), [0, 0]);
  });

  test(
    'only valid positive exit numbers appear on roundabout instructions',
    () {
      final instructions = parser.parseInstructions(
        _route(
          steps: [
            _step(exit: true),
            _step(exit: -1),
            _step(exit: 2.5),
            _step(exit: 3),
          ],
        ),
      );
      expect(instructions.map((i) => i.exitNumber), [null, null, null, '3']);
    },
  );

  test('realtime emit after disposal cannot report a fictitious send', () {
    final bus = MemoryDriverRealtime();
    bus.dispose();
    expect(
      () => bus.emit(tripId: 'ride', kind: DriverRealtimeKind.driverArrived),
      throwsStateError,
    );
  });

  test('realtime subscription rejects a blank trip identifier', () {
    final bus = MemoryDriverRealtime();
    addTearDown(bus.dispose);
    expect(() => bus.subscribe(' '), throwsArgumentError);
    expect(bus.subscribedTripId, isNull);
  });

  test('NaN camera progress does not jump to route finish', () {
    final geometry = RouteCameraGeometry(const [
      GeoPoint(59.33, 18.06),
      GeoPoint(59.34, 18.07),
    ]);
    expect(geometry.at(double.nan), const GeoPoint(59.33, 18.06));
  });

  test('negative remaining progress never duplicates the first endpoint', () {
    const first = GeoPoint(59.33, 18.06);
    const last = GeoPoint(59.34, 18.07);
    final geometry = RouteCameraGeometry(const [first, last]);
    expect(geometry.remaining(-50), const [first, last]);
  });

  test('overrun traveled progress never duplicates the last endpoint', () {
    const first = GeoPoint(59.33, 18.06);
    const last = GeoPoint(59.34, 18.07);
    final geometry = RouteCameraGeometry(const [first, last]);
    expect(geometry.traveled(double.infinity), const [first, last]);
  });
}

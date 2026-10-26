import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/island/trip_island_controller.dart';
import 'package:movera/core/routing/osrm_route_parser.dart';
import 'package:movera/core/routing/route_instruction.dart';

NavigationBannerSymbol symbol(
  RouteManeuverType type,
  String modifier, {
  String side = 'right',
  bool highway = false,
}) => RouteInstructionCopy.symbolFor(
  type: type,
  modifier: modifier,
  drivingSide: side,
  highway: highway,
);

void main() {
  test('symbolFor maps the new OSRM maneuvers', () {
    const t = RouteManeuverType.turn;
    // U-turn sides: explicit, or across the traffic for a bare 'uturn'.
    expect(symbol(t, 'uturn left'), NavigationBannerSymbol.uTurnLeft);
    expect(symbol(t, 'uturn right'), NavigationBannerSymbol.uTurnRight);
    expect(symbol(t, 'uturn'), NavigationBannerSymbol.uTurnLeft);
    expect(symbol(t, 'uturn', side: 'left'), NavigationBannerSymbol.uTurnRight);
    // Fork in town vs highway split.
    const fork = RouteManeuverType.fork;
    expect(symbol(fork, 'slight left'), NavigationBannerSymbol.forkLeft);
    expect(symbol(fork, 'right'), NavigationBannerSymbol.forkRight);
    expect(
      symbol(fork, 'slight left', highway: true),
      NavigationBannerSymbol.keepLeft,
    );
    expect(
      symbol(fork, 'slight right', highway: true),
      NavigationBannerSymbol.keepRight,
    );
    // Ramps on and off.
    expect(
      symbol(RouteManeuverType.onRamp, 'slight right'),
      NavigationBannerSymbol.onRampRight,
    );
    expect(
      symbol(RouteManeuverType.offRamp, 'slight left'),
      NavigationBannerSymbol.exitLeft,
    );
    // Start and side of the destination.
    expect(symbol(RouteManeuverType.depart, ''), NavigationBannerSymbol.depart);
    expect(
      symbol(RouteManeuverType.arrive, 'left'),
      NavigationBannerSymbol.arriveLeft,
    );
    expect(
      symbol(RouteManeuverType.arrive, 'right'),
      NavigationBannerSymbol.arriveRight,
    );
    expect(symbol(RouteManeuverType.arrive, ''), NavigationBannerSymbol.arrive);
    // Roundabouts: U-turn, and clockwise where cars drive on the left.
    expect(
      symbol(RouteManeuverType.roundabout, 'uturn'),
      NavigationBannerSymbol.roundaboutUTurn,
    );
    expect(
      symbol(RouteManeuverType.roundabout, 'right', side: 'left'),
      NavigationBannerSymbol.roundaboutClockwise,
    );
    // End of the road keeps the turn side.
    expect(
      symbol(RouteManeuverType.endOfRoad, 'left'),
      NavigationBannerSymbol.left,
    );
  });

  test('parser reads exit number, shields, lanes, side and toll', () {
    final step = {
      'name': 'Essingeleden',
      'ref': 'E 4;E 20',
      'destinations': 'E 4, 73: Liljeholmen, Södertälje',
      'exits': '165',
      'driving_side': 'right',
      'distance': 400,
      'maneuver': {
        'type': 'off ramp',
        'modifier': 'slight right',
        'location': [18.0, 59.3],
      },
      'intersections': [
        {
          'classes': ['motorway', 'toll'],
          'lanes': [
            {
              'valid': false,
              'indications': ['straight'],
            },
            {
              'valid': false,
              'indications': ['straight'],
            },
            {
              'valid': true,
              'indications': ['slight right'],
            },
            {
              'valid': true,
              'indications': ['slight right'],
            },
          ],
        },
      ],
    };
    final parsed = const OsrmRouteParser().parseInstructions({
      'legs': [
        {
          'steps': [step],
        },
      ],
    }).single;
    expect(parsed.exitRef, '165');
    expect(parsed.toll, isTrue);
    expect(parsed.symbol, NavigationBannerSymbol.exitRight);
    expect(parsed.shields.map((s) => s.label), ['E4', '73']);
    expect(parsed.towards, ['Liljeholmen', 'Södertälje']);
    expect(
      RouteInstructionCopy.shortAction(
        type: parsed.type,
        modifier: parsed.modifier,
        exitRef: parsed.exitRef,
        towards: parsed.towards.first,
      ),
      'Exit 165 · Liljeholmen',
    );
    expect(RouteLane.matter(parsed.lanes), isTrue);
    expect(RouteLane.hint(parsed.lanes), 'Use the 2 right lanes');
  });

  test('road shields: E-roads green, numbered roads blue', () {
    expect(RoadShield.parse('E 4; 73'), const [
      RoadShield('E4', RoadShieldKind.european),
      RoadShield('73', RoadShieldKind.national),
    ]);
    expect(RoadShield.parse('E20, Rv 75'), const [
      RoadShield('E20', RoadShieldKind.european),
      RoadShield('75', RoadShieldKind.national),
    ]);
    // Names are not road numbers.
    expect(RoadShield.parse('Essingeleden'), isEmpty);
  });

  testWidgets('strip messages come only at their moment, max 4 s', (
    tester,
  ) async {
    final strip = TripStripController(clock: () => DateTime(2026, 1, 1, 6));
    addTearDown(strip.dispose);
    // Heading to the pickup: the bags from the booking, once.
    strip.update(const TripStripInput(leg: TripLeg.pickup, bags: 2));
    expect(strip.current.text, 'Rider has 2 bags');
    // Lanes that matter cut in at once and stay ~6 s.
    strip.update(
      const TripStripInput(leg: TripLeg.pickup, bags: 2, laneKey: 'k'),
    );
    expect(strip.current.kind, TripStripKind.lanes);
    await tester.pump(TripStripController.laneTime);
    expect(strip.current, TripStripItem.eta);
    // On the drop-off leg: "Arriving in" once inside ten minutes.
    strip.update(const TripStripInput(leg: TripLeg.dropoff, etaMinutes: 14));
    expect(strip.current, TripStripItem.eta);
    strip.update(const TripStripInput(leg: TripLeg.dropoff, etaMinutes: 10));
    expect(strip.current.text, 'Arriving in 10 min · 06:10');
    await tester.pump(TripStripController.messageTime);
    expect(strip.current, TripStripItem.eta);
    strip.update(const TripStripInput(leg: TripLeg.dropoff, etaMinutes: 9));
    expect(strip.current, TripStripItem.eta, reason: 'Said once per leg.');
    // The ETA grows: traffic.
    strip.update(const TripStripInput(leg: TripLeg.dropoff, etaMinutes: 12));
    expect(strip.current.text, 'Traffic ahead · +3 min');
    // Tucked under the island: nothing plays.
    strip.update(
      const TripStripInput(leg: TripLeg.dropoff, etaMinutes: 12),
      hidden: true,
    );
    expect(strip.current, TripStripItem.eta);
    await tester.pump(const Duration(seconds: 10));
  });
}

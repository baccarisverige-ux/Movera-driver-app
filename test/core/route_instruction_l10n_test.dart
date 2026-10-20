import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/navigation/navigation_controller.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/core/routing/route_instruction.dart';
import 'package:movera/l10n/app_localizations.dart';

/// Turn-by-turn words come from structured data (maneuver type, modifier,
/// road, distance, exit) and only the last step goes through l10n.
///
/// English must read exactly as before the change: [_Legacy] is the old
/// English-only copy, kept here as the reference, and every combination is
/// compared with it. French ("vous") and Swedish ("du") read naturally.
final _en = lookupAppLocalizations(const Locale('en'));
final _fr = lookupAppLocalizations(const Locale('fr'));
final _sv = lookupAppLocalizations(const Locale('sv'));

const _modifiers = [
  '',
  'straight',
  'left',
  'right',
  'slight left',
  'slight right',
  'sharp left',
  'sharp right',
  'uturn',
  'uturn left',
  'uturn right',
];
const _distances = <double>[0, 10, 24.9, 25, 80, 150, 300, 999, 1000, 1200, 9949, 9950, 12400];

RouteLane _lane(bool valid) =>
    RouteLane(indications: const ['straight'], valid: valid);

void main() {
  group('English is unchanged', () {
    test('every maneuver, modifier, exit and flag gives the same words', () {
      var checked = 0;
      for (final type in RouteManeuverType.values) {
        for (final modifier in _modifiers) {
          for (final road in [null, '', 'Sveavägen']) {
            for (final exit in [null, '2']) {
              expect(
                RouteInstructionCopy.build(
                  type: type,
                  modifier: modifier,
                  roadName: road,
                  exitNumber: exit,
                ),
                _Legacy.build(
                  type: type,
                  modifier: modifier,
                  roadName: road,
                  exitNumber: exit,
                ),
                reason: '$type $modifier $road $exit',
              );
            }
          }
          for (final exit in [null, ' ', '3']) {
            for (final ref in [null, '165']) {
              for (final towards in [null, 'Liljeholmen']) {
                for (final flags in [0, 1, 2, 3, 4, 5, 6, 7, 8, 15]) {
                  final highway = flags & 1 != 0;
                  final hasRoad = flags & 2 != 0;
                  final toll = flags & 4 != 0;
                  final tunnel = flags & 8 != 0;
                  final legacy = _Legacy.shortAction(
                    type: type,
                    modifier: modifier,
                    exitNumber: exit,
                    exitRef: ref,
                    towards: towards,
                    highway: highway,
                    hasRoad: hasRoad,
                    toll: toll,
                    tunnel: tunnel,
                  );
                  final cue = RouteInstructionCopy.cue(
                    type: type,
                    modifier: modifier,
                    exitNumber: exit,
                    exitRef: ref,
                    towards: towards,
                    highway: highway,
                    hasRoad: hasRoad,
                    toll: toll,
                    tunnel: tunnel,
                  );
                  expect(cue.label(_en), legacy);
                  for (final meters in _distances) {
                    expect(
                      RouteInstructionCopy.livePrimary(cue: cue, meters: meters),
                      _Legacy.livePrimary(action: legacy, meters: meters),
                      reason: '$cue $meters',
                    );
                    checked++;
                  }
                }
              }
            }
          }
        }
      }
      expect(checked, greaterThan(50000));
    });

    test('distances and lane hints read as before', () {
      for (final meters in _distances) {
        expect(
          RouteInstructionCopy.formatDistance(meters),
          _Legacy.formatDistance(meters),
        );
        final old = _Legacy.formatDistance(meters);
        expect(
          RouteInstructionCopy.toPoint(meters),
          old == 'now' ? old : 'in $old',
        );
      }
      for (var count = 2; count <= 5; count++) {
        for (var mask = 0; mask < 1 << count; mask++) {
          final lanes = [
            for (var i = 0; i < count; i++) _lane(mask & (1 << i) != 0),
          ];
          expect(RouteLane.hint(lanes), _legacyHint(lanes), reason: '$mask');
        }
      }
    });

    test('the island line is the action, or the "now" line at the turn', () {
      const left = RouteCue(RouteCueKind.turnLeft);
      expect(
        RouteInstructionCopy.liveInstruction(cue: left, meters: 300),
        'Turn left',
      );
      expect(
        RouteInstructionCopy.liveInstruction(cue: left, meters: 10),
        'Turn left now',
      );
      const round = RouteCue(RouteCueKind.roundabout, exit: '2');
      expect(
        RouteInstructionCopy.liveInstruction(cue: round, meters: 10),
        'Roundabout, exit 2',
      );
    });
  });

  group('the logic reads the data, not the words', () {
    test('roundabout and onward come from the maneuver kind', () {
      for (final strings in [_en, _fr, _sv]) {
        // A roundabout shows no distance in any language.
        const round = RouteCue(RouteCueKind.roundabout, exit: '2');
        expect(
          RouteInstructionCopy.livePrimary(
            cue: round,
            meters: 300,
            strings: strings,
          ),
          round.label(strings),
        );
        // "now" is decided from the meters, not from the word.
        const left = RouteCue(RouteCueKind.turnLeft);
        expect(
          RouteInstructionCopy.livePrimary(
            cue: left,
            meters: 10,
            strings: strings,
          ),
          strings.navActionNow(left.label(strings)),
        );
        const on = RouteCue(RouteCueKind.continueStraight);
        expect(
          RouteInstructionCopy.livePrimary(
            cue: on,
            meters: 300,
            strings: strings,
          ),
          strings.navActionFor(on.label(strings), '300 m'),
        );
      }
    });

    test('the live banner carries the meters, exit and line apart', () async {
      final navigation = NavigationController(routeRepository: _ExitRoute());
      addTearDown(navigation.dispose);
      const start = GeoPoint(59.3279, 18.0615);
      navigation.setVehicle(const DriverLocation(point: start));
      await navigation.ensureRoute(
        origin: start,
        destination: const GeoPoint(59.3326, 18.0649),
        force: true,
      );
      final banner = navigation.snapshot.banner!;
      expect(banner.exitRef, '165');
      expect(banner.distanceMeters, isNotNull);
      expect(banner.instruction, 'Exit 165 · Liljeholmen');
      expect(banner.primary, startsWith('Exit 165 · Liljeholmen in '));
      expect(banner.towards, 'Södertälje');
    });

    test('route faults are values; the words follow the language', () async {
      final navigation = NavigationController(
        routeRepository: _ExitRoute(fail: true),
      );
      addTearDown(navigation.dispose);
      const start = GeoPoint(59.3279, 18.0615);
      navigation.setVehicle(const DriverLocation(point: start));
      await navigation.ensureRoute(
        origin: start,
        destination: const GeoPoint(59.3326, 18.0649),
        force: true,
      );
      expect(navigation.status, 'Route unavailable — retry');
      expect(NavigationRouteStatus.unavailableRetry.text, navigation.status);
      navigation.keepLastKnown();
      expect(navigation.status, _en.locationUpdatingEllipsis);
    });
  });

  group('French and Swedish', () {
    String fr(RouteCue cue, double meters) =>
        RouteInstructionCopy.livePrimary(cue: cue, meters: meters, strings: _fr);
    String sv(RouteCue cue, double meters) =>
        RouteInstructionCopy.livePrimary(cue: cue, meters: meters, strings: _sv);

    test('live banner lines', () {
      const left = RouteCue(RouteCueKind.turnLeft);
      const on = RouteCue(RouteCueKind.continueStraight);
      const round = RouteCue(RouteCueKind.roundabout, exit: '2');
      const exit = RouteCue(
        RouteCueKind.signedExit,
        exit: '165',
        place: 'Liljeholmen',
      );
      expect(fr(left, 300), 'Tournez à gauche dans 300 m');
      expect(fr(left, 10), 'Tournez à gauche maintenant');
      expect(fr(on, 1200), 'Continuez tout droit sur 1,2 km');
      expect(fr(round, 80), 'Rond-point, sortie 2');
      expect(fr(exit, 700), 'Sortie 165 · Liljeholmen dans 700 m');
      expect(
        fr(const RouteCue(RouteCueKind.keepRight), 12400),
        'Serrez à droite dans 12 km',
      );
      expect(sv(left, 300), 'Sväng vänster om 300 m');
      expect(sv(left, 10), 'Sväng vänster nu');
      expect(sv(on, 1200), 'Fortsätt rakt fram i 1,2 km');
      expect(sv(round, 80), 'Rondell, avfart 2');
      expect(sv(exit, 700), 'Avfart 165 · Liljeholmen om 700 m');
      expect(
        sv(const RouteCue(RouteCueKind.uTurn), 150),
        'U-sväng om 150 m',
      );
    });

    test('whole steps, distances and lanes', () {
      expect(
        RouteInstructionCopy.build(
          type: RouteManeuverType.turn,
          modifier: 'left',
          roadName: 'Rue de Rivoli',
          strings: _fr,
        ),
        'Tournez à gauche sur Rue de Rivoli',
      );
      expect(
        RouteInstructionCopy.build(
          type: RouteManeuverType.roundabout,
          modifier: '',
          exitNumber: '3',
          strings: _fr,
        ),
        'Au rond-point, prenez la sortie 3',
      );
      expect(
        RouteInstructionCopy.build(
          type: RouteManeuverType.turn,
          modifier: 'right',
          roadName: 'Sveavägen',
          strings: _sv,
        ),
        'Sväng höger in på Sveavägen',
      );
      expect(
        RouteInstructionCopy.build(
          type: RouteManeuverType.turn,
          modifier: 'uturn',
          strings: _sv,
        ),
        'Gör en U-sväng',
      );
      expect(RouteInstructionCopy.toPoint(150, _fr), 'dans 150 m');
      expect(RouteInstructionCopy.toPoint(10, _fr), 'maintenant');
      expect(RouteInstructionCopy.toPoint(2500, _sv), 'om 2,5 km');
      final lanes = [_lane(false), _lane(true), _lane(true)];
      expect(RouteLane.hint(lanes, _fr), 'Prenez les 2 voies de droite');
      expect(RouteLane.hint(lanes, _sv), 'Använd de 2 högra körfälten');
      expect(
        RouteLane.hint([_lane(true), _lane(false)], _sv),
        'Använd vänster körfält',
      );
    });

    test('every maneuver has words in each language', () {
      for (final kind in RouteCueKind.values) {
        final cue = RouteCue(kind, exit: '2', place: 'Lyon');
        for (final strings in [_fr, _sv]) {
          final words = cue.label(strings);
          expect(words.trim(), isNotEmpty);
          expect(words, isNot(cue.label(_en)), reason: '$kind');
        }
      }
    });
  });
}

class _ExitRoute implements RouteRepository {
  _ExitRoute({this.fail = false});
  final bool fail;

  @override
  Future<RoadRoute> drivingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async {
    if (fail) throw Exception('offline');
    return RoadRoute(
      points: [origin, const GeoPoint(59.3290, 18.0630), destination],
      distanceMeters: 520,
      durationSeconds: 90,
      instructions: const [
        RouteInstruction(
          type: RouteManeuverType.offRamp,
          modifier: 'right',
          text: '',
          distanceMeters: 300,
          maneuverLocation: GeoPoint(59.3290, 18.0630),
          exitRef: '165',
          destinations: 'E 4: Liljeholmen, Södertälje',
        ),
      ],
    );
  }
}

String _legacyHint(List<RouteLane> lanes) {
    final used = [
      for (var i = 0; i < lanes.length; i++)
        if (lanes[i].valid) i,
    ];
    if (used.isEmpty) return '';
    final n = used.length;
    final side = used.first == 0
        ? 'left'
        : used.last == lanes.length - 1
        ? 'right'
        : 'middle';
    return n == 1 ? 'Use the $side lane' : 'Use the $n $side lanes';
  }

/// The English-only copy as it was before the change (reference only).
class _Legacy {
  const _Legacy._();

  static String formatDistance(double meters) {
    if (meters < 25) {
      return 'now';
    }
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    final km = meters / 1000;
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
  }

  static String build({
    required RouteManeuverType type,
    required String modifier,
    String? roadName,
    String? exitNumber,
  }) {
    final road = (roadName ?? '').trim();
    final onto = road.isEmpty ? '' : ' onto $road';
    switch (type) {
      case RouteManeuverType.arrive:
        return 'Arrive at destination';
      case RouteManeuverType.depart:
        return road.isEmpty ? 'Head out' : 'Head out on $road';
      case RouteManeuverType.continueStraight:
      case RouteManeuverType.newName:
        return road.isEmpty ? 'Continue straight' : 'Continue on $road';
      case RouteManeuverType.roundabout:
      case RouteManeuverType.rotary:
      case RouteManeuverType.roundaboutTurn:
      case RouteManeuverType.exitRoundabout:
      case RouteManeuverType.exitRotary:
        final exit = exitNumber ?? '';
        if (exit.isEmpty) {
          return 'At the roundabout, continue';
        }
        return 'At roundabout, take exit $exit';
      case RouteManeuverType.offRamp:
      case RouteManeuverType.ramp:
        return modifier.contains('left')
            ? 'Take the exit on the left$onto'
            : modifier.contains('right')
            ? 'Take the exit on the right$onto'
            : 'Take the exit$onto';
      case RouteManeuverType.onRamp:
      case RouteManeuverType.merge:
        return modifier.contains('left')
            ? 'Merge left$onto'
            : modifier.contains('right')
            ? 'Merge right$onto'
            : 'Merge$onto';
      case RouteManeuverType.fork:
        return modifier.contains('left')
            ? 'Keep left$onto'
            : modifier.contains('right')
            ? 'Keep right$onto'
            : 'Continue at the fork$onto';
      case RouteManeuverType.endOfRoad:
        return modifier.contains('left')
            ? 'Turn left at the end of the road$onto'
            : modifier.contains('right')
            ? 'Turn right at the end of the road$onto'
            : 'At the end of the road$onto';
      case RouteManeuverType.turn:
      case RouteManeuverType.unknown:
      case RouteManeuverType.notification:
        return _turnLine(modifier, onto);
    }
  }

  static String shortAction({
    required RouteManeuverType type,
    required String modifier,
    String? exitNumber,
    String? exitRef,
    String? towards,
    bool highway = false,
    bool hasRoad = false,
    bool toll = false,
    bool tunnel = false,
  }) {
    final place = (towards ?? '').trim();
    final ref = (exitRef ?? '').trim();
    switch (type) {
      case RouteManeuverType.arrive:
        return 'Arrive';
      case RouteManeuverType.depart:
        return 'Head out';
      case RouteManeuverType.continueStraight:
      case RouteManeuverType.newName:
        if (highway && modifier == 'slight left') return 'Keep left';
        if (highway && modifier == 'slight right') return 'Keep right';
        if (modifier.isEmpty || modifier == 'straight') {
          if (tunnel) return 'Tunnel ahead';
          if (toll) return 'Toll road ahead';
        }
        return 'Continue straight';
      case RouteManeuverType.roundabout:
      case RouteManeuverType.rotary:
      case RouteManeuverType.roundaboutTurn:
      case RouteManeuverType.exitRoundabout:
      case RouteManeuverType.exitRotary:
        final exit = (exitNumber ?? '').trim();
        if (modifier.startsWith('uturn')) {
          return exit.isEmpty ? 'Roundabout, U-turn' : 'Roundabout, U-turn · exit $exit';
        }
        return exit.isEmpty ? 'Roundabout' : 'Roundabout, exit $exit';
      case RouteManeuverType.offRamp:
      case RouteManeuverType.ramp:
        // Signposted exit: "Exit 165 · Liljeholmen".
        if (ref.isNotEmpty) {
          return place.isEmpty ? 'Exit $ref' : 'Exit $ref · $place';
        }
        return modifier.contains('left')
            ? 'Exit left'
            : modifier.contains('right')
            ? 'Exit right'
            : 'Take the exit';
      case RouteManeuverType.onRamp:
        if (hasRoad) return 'Take the ramp onto';
        return modifier.contains('left')
            ? 'Take the ramp on the left'
            : modifier.contains('right')
            ? 'Take the ramp on the right'
            : 'Take the ramp';
      case RouteManeuverType.merge:
        return modifier.contains('left')
            ? 'Merge left'
            : modifier.contains('right')
            ? 'Merge right'
            : 'Merge';
      case RouteManeuverType.fork:
        if (!highway) {
          return modifier.contains('left')
              ? 'At the fork, go left'
              : modifier.contains('right')
              ? 'At the fork, go right'
              : 'Continue at the fork';
        }
        return modifier.contains('left')
            ? 'Keep left'
            : modifier.contains('right')
            ? 'Keep right'
            : 'Continue at the fork';
      case RouteManeuverType.endOfRoad:
        return modifier.contains('left')
            ? 'Turn left'
            : modifier.contains('right')
            ? 'Turn right'
            : 'End of the road';
      case RouteManeuverType.turn:
      case RouteManeuverType.unknown:
      case RouteManeuverType.notification:
        return _shortTurn(modifier);
    }
  }

  static String livePrimary({required String action, required double meters}) {
    final lower = action.toLowerCase();
    if (lower.startsWith('roundabout')) {
      return action;
    }
    final dist = formatDistance(meters);
    if (dist == 'now') {
      return '$action now';
    }
    if (lower.startsWith('continue')) {
      return '$action $dist';
    }
    return '$action in $dist';
  }

  static String _shortTurn(String modifier) {
    switch (modifier) {
      case 'uturn':
      case 'uturn left':
      case 'uturn right':
        return 'U-turn';
      case 'sharp left':
        return 'Turn sharp left';
      case 'sharp right':
        return 'Turn sharp right';
      case 'slight left':
        return 'Turn slight left';
      case 'slight right':
        return 'Turn slight right';
      case 'left':
        return 'Turn left';
      case 'right':
        return 'Turn right';
      case 'straight':
        return 'Continue straight';
      default:
        return 'Continue';
    }
  }

  static String _turnLine(String modifier, String onto) {
    switch (modifier) {
      case 'uturn':
      case 'uturn left':
      case 'uturn right':
        return 'Make a U-turn$onto';
      case 'sharp left':
        return 'Turn sharp left$onto';
      case 'sharp right':
        return 'Turn sharp right$onto';
      case 'slight left':
        return 'Turn slight left$onto';
      case 'slight right':
        return 'Turn slight right$onto';
      case 'left':
        return 'Turn left$onto';
      case 'right':
        return 'Turn right$onto';
      case 'straight':
        return 'Continue straight$onto';
      default:
        return onto.isEmpty ? 'Continue' : 'Continue$onto';
    }
  }

}

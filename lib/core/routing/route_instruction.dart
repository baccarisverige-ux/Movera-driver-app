import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/l10n/driver_l10n.dart';

enum RouteManeuverType {
  turn,
  newName,
  depart,
  arrive,
  merge,
  ramp,
  onRamp,
  offRamp,
  fork,
  endOfRoad,
  continueStraight,
  roundabout,
  rotary,
  roundaboutTurn,
  notification,
  exitRoundabout,
  exitRotary,
  unknown,
}

class RouteInstruction {
  const RouteInstruction({
    required this.type,
    required this.modifier,
    required this.text,
    required this.distanceMeters,
    required this.maneuverLocation,
    this.roadName,
    this.exitNumber,
    this.exitAngleDegrees,
    this.roadRef,
    this.destinations,
    this.exitRef,
    this.lanes = const <RouteLane>[],
    this.drivingSide = 'right',
    this.highway = false,
    this.toll = false,
    this.tunnel = false,
  });

  final RouteManeuverType type;
  final String modifier;
  final String text;
  final double distanceMeters;
  final GeoPoint maneuverLocation;
  final String? roadName;
  final String? exitNumber;

  /// Outgoing road direction relative to entry, when both bearings exist.
  final double? exitAngleDegrees;

  /// Road number(s) of the road after the maneuver ("E 4;E 20", "73").
  final String? roadRef;

  /// Signposted destinations ("E 4: Liljeholmen, Södertälje").
  final String? destinations;

  /// Signposted exit number of a highway exit ("165").
  final String? exitRef;

  /// Lanes at the maneuver, left to right; empty when unknown.
  final List<RouteLane> lanes;

  /// 'right' or 'left' (left-hand traffic: clockwise roundabouts).
  final String drivingSide;

  /// The maneuver happens on or onto a motorway.
  final bool highway;

  /// The road after the maneuver has a toll / runs through a tunnel.
  final bool toll, tunnel;

  /// Shields from the signposted destinations, else from the road number.
  List<RoadShield> get shields {
    final signs = RoadShield.parse(RoadShield.splitDestinations(destinations).$1);
    return signs.isNotEmpty ? signs : RoadShield.parse(roadRef);
  }

  /// Signposted place names, in order.
  List<String> get towards => RoadShield.splitDestinations(destinations).$2;

  NavigationBannerSymbol get symbol => RouteInstructionCopy.symbolFor(
    type: type,
    modifier: modifier,
    drivingSide: drivingSide,
    highway: highway,
    toll: toll,
    tunnel: tunnel,
  );

  bool get isArrival =>
      type == RouteManeuverType.arrive ||
      type == RouteManeuverType.notification && modifier == 'arrive';

  RouteInstruction copyWith({double? distanceMeters, String? text}) {
    return RouteInstruction(
      type: type,
      modifier: modifier,
      text: text ?? this.text,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      maneuverLocation: maneuverLocation,
      roadName: roadName,
      exitNumber: exitNumber,
      exitAngleDegrees: exitAngleDegrees,
      roadRef: roadRef,
      destinations: destinations,
      exitRef: exitRef,
      lanes: lanes,
      drivingSide: drivingSide,
      highway: highway,
      toll: toll,
      tunnel: tunnel,
    );
  }
}

/// One lane at a maneuver: its painted arrows and whether the route uses it.
class RouteLane {
  const RouteLane({required this.indications, required this.valid});

  /// OSRM indications: 'left', 'slight right', 'straight', 'uturn', 'none'…
  final List<String> indications;
  final bool valid;

  /// The arrow drawn on the lane tile. A used lane shows the arrow that
  /// matches the maneuver when it has several.
  NavigationBannerSymbol symbolFor(String modifier) {
    String pick = indications.isEmpty ? 'straight' : indications.first;
    if (valid && indications.contains(modifier)) pick = modifier;
    return switch (pick) {
      'left' || 'sharp left' => NavigationBannerSymbol.left,
      'slight left' => NavigationBannerSymbol.slightLeft,
      'right' || 'sharp right' => NavigationBannerSymbol.right,
      'slight right' => NavigationBannerSymbol.slightRight,
      'uturn' => NavigationBannerSymbol.uTurnLeft,
      _ => NavigationBannerSymbol.straight,
    };
  }

  /// Lanes matter when some, not all, of two or more lanes lead on.
  static bool matter(List<RouteLane> lanes) =>
      lanes.length >= 2 &&
      lanes.any((l) => l.valid) &&
      lanes.any((l) => !l.valid);

  /// "Use the 2 right lanes", "Use the left lane", "Use the middle lane".
  static String hint(List<RouteLane> lanes, [AppLocalizations? strings]) {
    final l = strings ?? tr;
    final used = [
      for (var i = 0; i < lanes.length; i++)
        if (lanes[i].valid) i,
    ];
    if (used.isEmpty) return '';
    final n = used.length;
    if (used.first == 0) return l.navUseLeftLanes(n);
    if (used.last == lanes.length - 1) return l.navUseRightLanes(n);
    return l.navUseMiddleLanes(n);
  }
}

enum RoadShieldKind {
  /// E-roads (E4, E20): green with white text.
  european,

  /// National and county roads (73, 222): blue.
  national,
}

/// A road number drawn as a small sign next to the instruction.
class RoadShield {
  const RoadShield(this.label, this.kind);
  final String label;
  final RoadShieldKind kind;

  static final _european = RegExp(r'^E\s*(\d{1,3})$', caseSensitive: false);
  static final _national = RegExp(
    r'^(?:rv|riksväg|väg|lv|länsväg)?\s*(\d{1,3})$',
    caseSensitive: false,
  );

  /// "E 4;E 20, 73" -> [E4 green, E20 green, 73 blue]. Unknown refs are
  /// skipped, never guessed; at most three signs.
  static List<RoadShield> parse(String? raw) {
    final out = <RoadShield>[];
    for (final part in (raw ?? '').split(RegExp(r'[;,/]'))) {
      final ref = part.trim();
      if (ref.isEmpty) continue;
      final e = _european.firstMatch(ref);
      final n = e == null ? _national.firstMatch(ref) : null;
      final shield = e != null
          ? RoadShield('E${e.group(1)}', RoadShieldKind.european)
          : n != null
          ? RoadShield(n.group(1)!, RoadShieldKind.national)
          : null;
      if (shield != null && !out.any((s) => s.label == shield.label)) {
        out.add(shield);
      }
      if (out.length == 3) break;
    }
    return out;
  }

  /// OSRM destinations "E 4, E 20: Stockholm, Södertälje" -> refs and
  /// place names. Without a colon the whole text is place names.
  static (String?, List<String>) splitDestinations(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return (null, const <String>[]);
    final colon = text.indexOf(':');
    final refs = colon < 0 ? null : text.substring(0, colon);
    final names = (colon < 0 ? text : text.substring(colon + 1))
        .split(',')
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    return (refs, names);
  }

  @override
  bool operator ==(Object other) =>
      other is RoadShield && other.label == label && other.kind == kind;

  @override
  int get hashCode => Object.hash(label, kind);
}

class NavigationBanner {
  const NavigationBanner({
    required this.primary,
    required this.distanceLabel,
    this.instruction,
    this.distanceMeters,
    this.exitRef,
    this.roadName,
    this.symbol = NavigationBannerSymbol.straight,
    this.status,
    this.exitNumber,
    this.exitAngleDegrees,
    this.shields = const <RoadShield>[],
    this.towards,
    this.lanes = const <RouteLane>[],
    this.laneModifier = '',
    this.toll = false,
  });

  final String primary;
  final String distanceLabel;

  /// [primary] without the distance, for the island's line under the
  /// large number; null when [primary] has no distance in it.
  final String? instruction;

  /// Meters behind [distanceLabel]; null when it is a status, not a distance.
  final double? distanceMeters;

  /// Signposted number of the highway exit at the next maneuver.
  final String? exitRef;
  final String? roadName;
  final NavigationBannerSymbol symbol;
  final String? status;
  final String? exitNumber;

  /// Outgoing road direction relative to entry, when both bearings exist.
  final double? exitAngleDegrees;

  /// Road signs shown inline on the second line.
  final List<RoadShield> shields;

  /// "towards Södertälje" place name(s), when signposted.
  final String? towards;

  /// Lanes at the next maneuver, left to right, and its modifier.
  final List<RouteLane> lanes;
  final String laneModifier;

  /// The road after the next maneuver has a toll.
  final bool toll;
}

enum NavigationBannerSymbol {
  left,
  right,
  slightLeft,
  slightRight,
  sharpLeft,
  sharpRight,
  straight,
  uTurn,
  roundabout,
  arrive,

  /// Merge or exit whose side is unknown.
  merge,
  exit,

  /// Merge and exit keep their side, so the arrow points the right way.
  mergeLeft,
  mergeRight,
  exitLeft,
  exitRight,

  /// U-turn with its side: left = counter-clockwise (right-hand traffic).
  uTurnLeft,
  uTurnRight,

  /// Highway split: stay in the left / right branch.
  keepLeft,
  keepRight,

  /// Road fork in town.
  forkLeft,
  forkRight,

  /// Entering a highway on a ramp.
  onRampLeft,
  onRampRight,

  /// Roundabout back the way the driver came.
  roundaboutUTurn,

  /// Roundabout driven clockwise (left-hand traffic countries).
  roundaboutClockwise,

  /// Destination on that side of the road.
  arriveLeft,
  arriveRight,

  /// Start of the trip.
  depart,

  /// Toll road / tunnel ahead (no turn).
  toll,
  tunnel,
}

extension NavigationBannerSymbolX on NavigationBannerSymbol {
  bool get isArrival =>
      this == NavigationBannerSymbol.arrive ||
      this == NavigationBannerSymbol.arriveLeft ||
      this == NavigationBannerSymbol.arriveRight;

  bool get isRoundabout =>
      this == NavigationBannerSymbol.roundabout ||
      this == NavigationBannerSymbol.roundaboutUTurn ||
      this == NavigationBannerSymbol.roundaboutClockwise;

  /// A real turn the driver must make (not straight on, a notice or arrival).
  bool get isManeuver =>
      !isArrival &&
      this != NavigationBannerSymbol.straight &&
      this != NavigationBannerSymbol.depart &&
      this != NavigationBannerSymbol.toll &&
      this != NavigationBannerSymbol.tunnel;
}

extension RouteManeuverTypeX on RouteManeuverType {
  static RouteManeuverType fromOsrm(String? raw) {
    switch (raw) {
      case 'turn':
        return RouteManeuverType.turn;
      case 'new name':
        return RouteManeuverType.newName;
      case 'depart':
        return RouteManeuverType.depart;
      case 'arrive':
        return RouteManeuverType.arrive;
      case 'merge':
        return RouteManeuverType.merge;
      case 'ramp':
        return RouteManeuverType.ramp;
      case 'on ramp':
        return RouteManeuverType.onRamp;
      case 'off ramp':
        return RouteManeuverType.offRamp;
      case 'fork':
        return RouteManeuverType.fork;
      case 'end of road':
        return RouteManeuverType.endOfRoad;
      case 'continue':
        return RouteManeuverType.continueStraight;
      case 'roundabout':
        return RouteManeuverType.roundabout;
      case 'rotary':
        return RouteManeuverType.rotary;
      case 'roundabout turn':
        return RouteManeuverType.roundaboutTurn;
      case 'notification':
        return RouteManeuverType.notification;
      case 'exit roundabout':
        return RouteManeuverType.exitRoundabout;
      case 'exit rotary':
        return RouteManeuverType.exitRotary;
      default:
        return RouteManeuverType.unknown;
    }
  }
}

/// What the driver does at the next maneuver, decided from the route data
/// alone (maneuver type, modifier, exit number, signs). The words come
/// last, in [RouteCue.label], in the driver's language.
enum RouteCueKind {
  arrive,
  headOut,
  keepLeft,
  keepRight,
  tunnelAhead,
  tollAhead,
  continueStraight,

  /// Plain "Continue" (no direction known).
  proceed,
  roundabout,
  roundaboutUTurn,

  /// A signposted highway exit ("Exit 165 · Liljeholmen").
  signedExit,
  exitLeft,
  exitRight,
  takeExit,

  /// On-ramp onto a road whose signs follow the words.
  rampOnto,
  rampLeft,
  rampRight,
  ramp,
  mergeLeft,
  mergeRight,
  merge,
  forkLeft,
  forkRight,
  continueAtFork,
  turnLeft,
  turnRight,
  endOfRoad,
  uTurn,
  sharpLeft,
  sharpRight,
  slightLeft,
  slightRight,
}

/// The next action: its kind plus the exit and place it names.
class RouteCue {
  const RouteCue(this.kind, {this.exit, this.place});

  final RouteCueKind kind;

  /// Roundabout exit number, or the signposted exit for [RouteCueKind.signedExit].
  final String? exit;

  /// First signposted place of a signposted exit.
  final String? place;

  /// A roundabout reads the same at any distance.
  bool get isRoundabout =>
      kind == RouteCueKind.roundabout || kind == RouteCueKind.roundaboutUTurn;

  /// Goes on along the road: "Continue straight 1.2 km", not "in 1.2 km".
  bool get isOnward =>
      kind == RouteCueKind.continueStraight ||
      kind == RouteCueKind.proceed ||
      kind == RouteCueKind.continueAtFork;

  /// The action in the driver's language: "Turn left", "Tournez à gauche".
  String label([AppLocalizations? strings]) {
    final l = strings ?? tr;
    final exit = (this.exit ?? '').trim();
    final place = (this.place ?? '').trim();
    return switch (kind) {
      RouteCueKind.arrive => l.navArrive,
      RouteCueKind.headOut => l.navHeadOut,
      RouteCueKind.keepLeft => l.navKeepLeft,
      RouteCueKind.keepRight => l.navKeepRight,
      RouteCueKind.tunnelAhead => l.navTunnelAhead,
      RouteCueKind.tollAhead => l.navTollRoadAhead,
      RouteCueKind.continueStraight => l.navContinueStraight,
      RouteCueKind.proceed => l.navContinue,
      RouteCueKind.roundabout =>
        exit.isEmpty ? l.navRoundabout : l.navRoundaboutExit(exit),
      RouteCueKind.roundaboutUTurn =>
        exit.isEmpty ? l.navRoundaboutUTurn : l.navRoundaboutUTurnExit(exit),
      RouteCueKind.signedExit =>
        place.isEmpty ? l.navSignedExit(exit) : l.navSignedExitTowards(exit, place),
      RouteCueKind.exitLeft => l.navExitLeft,
      RouteCueKind.exitRight => l.navExitRight,
      RouteCueKind.takeExit => l.navTakeExit,
      RouteCueKind.rampOnto => l.navRampOnto,
      RouteCueKind.rampLeft => l.navRampLeft,
      RouteCueKind.rampRight => l.navRampRight,
      RouteCueKind.ramp => l.navRamp,
      RouteCueKind.mergeLeft => l.navMergeLeft,
      RouteCueKind.mergeRight => l.navMergeRight,
      RouteCueKind.merge => l.navMerge,
      RouteCueKind.forkLeft => l.navForkLeft,
      RouteCueKind.forkRight => l.navForkRight,
      RouteCueKind.continueAtFork => l.navContinueAtFork,
      RouteCueKind.turnLeft => l.navTurnLeft,
      RouteCueKind.turnRight => l.navTurnRight,
      RouteCueKind.endOfRoad => l.navEndOfRoad,
      RouteCueKind.uTurn => l.navUTurn,
      RouteCueKind.sharpLeft => l.navSharpLeft,
      RouteCueKind.sharpRight => l.navSharpRight,
      RouteCueKind.slightLeft => l.navSlightLeft,
      RouteCueKind.slightRight => l.navSlightRight,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is RouteCue &&
      other.kind == kind &&
      other.exit == exit &&
      other.place == place;

  @override
  int get hashCode => Object.hash(kind, exit, place);

  @override
  String toString() => 'RouteCue($kind, exit: $exit, place: $place)';
}

class RouteInstructionCopy {
  const RouteInstructionCopy._();

  /// At the maneuver: the driver acts "now" instead of at a distance.
  static const double nowMeters = 25;

  /// "300 m", "1.2 km" ("1,2 km" in French and Swedish), or "now" under
  /// [nowMeters].
  static String formatDistance(double meters, [AppLocalizations? strings]) {
    final l = strings ?? tr;
    if (meters < nowMeters) {
      return l.navDistanceNow;
    }
    if (meters < 1000) {
      return l.navMeters('${meters.round()}');
    }
    final km = meters / 1000;
    return l.navKilometers(
      km.toStringAsFixed(km < 10 ? 1 : 0).replaceAll('.', l.navDecimalMark),
    );
  }

  /// "in 150 m", or "now" at the point.
  static String toPoint(double meters, [AppLocalizations? strings]) {
    final l = strings ?? tr;
    final distance = formatDistance(meters, l);
    return meters < nowMeters ? distance : l.navInDistance(distance);
  }

  /// The whole step as one line ("Turn left onto Sveavägen").
  static String build({
    required RouteManeuverType type,
    required String modifier,
    String? roadName,
    String? exitNumber,
    AppLocalizations? strings,
  }) {
    final l = strings ?? tr;
    final road = (roadName ?? '').trim();
    String onto(String action) => road.isEmpty ? action : l.navOnto(action, road);
    final left = modifier.contains('left');
    final right = modifier.contains('right');
    switch (type) {
      case RouteManeuverType.arrive:
        return l.navArriveAtDestination;
      case RouteManeuverType.depart:
        return road.isEmpty ? l.navHeadOut : l.navHeadOutOn(road);
      case RouteManeuverType.continueStraight:
      case RouteManeuverType.newName:
        // OSRM "continue" through a bend or turnaround: say the turn, as the
        // arrow shows it (driver-u39).
        final bend = _onwardTurn(modifier);
        if (bend != null) {
          return onto(
            bend.kind == RouteCueKind.uTurn ? l.navMakeUTurn : bend.label(l),
          );
        }
        return road.isEmpty ? l.navContinueStraight : l.navContinueOn(road);
      case RouteManeuverType.roundabout:
      case RouteManeuverType.rotary:
      case RouteManeuverType.roundaboutTurn:
      case RouteManeuverType.exitRoundabout:
      case RouteManeuverType.exitRotary:
        final exit = exitNumber ?? '';
        if (exit.isEmpty) {
          return l.navRoundaboutContinue;
        }
        return l.navRoundaboutTakeExit(exit);
      case RouteManeuverType.offRamp:
      case RouteManeuverType.ramp:
        return onto(
          left
              ? l.navExitOnLeft
              : right
              ? l.navExitOnRight
              : l.navTakeExit,
        );
      case RouteManeuverType.onRamp:
      case RouteManeuverType.merge:
        return onto(
          left
              ? l.navMergeLeft
              : right
              ? l.navMergeRight
              : l.navMerge,
        );
      case RouteManeuverType.fork:
        return onto(
          left
              ? l.navKeepLeft
              : right
              ? l.navKeepRight
              : l.navContinueAtFork,
        );
      case RouteManeuverType.endOfRoad:
        return onto(
          left
              ? l.navEndTurnLeft
              : right
              ? l.navEndTurnRight
              : l.navAtEndOfRoad,
        );
      case RouteManeuverType.turn:
      case RouteManeuverType.unknown:
      case RouteManeuverType.notification:
        final turn = _turn(modifier);
        return onto(
          turn.kind == RouteCueKind.uTurn ? l.navMakeUTurn : turn.label(l),
        );
    }
  }

  /// The next action, from the maneuver data.
  static RouteCue cue({
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
    final left = modifier.contains('left');
    final right = modifier.contains('right');
    switch (type) {
      case RouteManeuverType.arrive:
        return const RouteCue(RouteCueKind.arrive);
      case RouteManeuverType.depart:
        return const RouteCue(RouteCueKind.headOut);
      case RouteManeuverType.continueStraight:
      case RouteManeuverType.newName:
        if (highway && modifier == 'slight left') {
          return const RouteCue(RouteCueKind.keepLeft);
        }
        if (highway && modifier == 'slight right') {
          return const RouteCue(RouteCueKind.keepRight);
        }
        if (modifier.isEmpty || modifier == 'straight') {
          if (tunnel) return const RouteCue(RouteCueKind.tunnelAhead);
          if (toll) return const RouteCue(RouteCueKind.tollAhead);
        }
        return _onwardTurn(modifier) ??
            const RouteCue(RouteCueKind.continueStraight);
      case RouteManeuverType.roundabout:
      case RouteManeuverType.rotary:
      case RouteManeuverType.roundaboutTurn:
      case RouteManeuverType.exitRoundabout:
      case RouteManeuverType.exitRotary:
        final exit = (exitNumber ?? '').trim();
        return RouteCue(
          modifier.startsWith('uturn')
              ? RouteCueKind.roundaboutUTurn
              : RouteCueKind.roundabout,
          exit: exit.isEmpty ? null : exit,
        );
      case RouteManeuverType.offRamp:
      case RouteManeuverType.ramp:
        // Signposted exit: "Exit 165 · Liljeholmen".
        if (ref.isNotEmpty) {
          return RouteCue(
            RouteCueKind.signedExit,
            exit: ref,
            place: place.isEmpty ? null : place,
          );
        }
        return RouteCue(
          left
              ? RouteCueKind.exitLeft
              : right
              ? RouteCueKind.exitRight
              : RouteCueKind.takeExit,
        );
      case RouteManeuverType.onRamp:
        if (hasRoad) return const RouteCue(RouteCueKind.rampOnto);
        return RouteCue(
          left
              ? RouteCueKind.rampLeft
              : right
              ? RouteCueKind.rampRight
              : RouteCueKind.ramp,
        );
      case RouteManeuverType.merge:
        return RouteCue(
          left
              ? RouteCueKind.mergeLeft
              : right
              ? RouteCueKind.mergeRight
              : RouteCueKind.merge,
        );
      case RouteManeuverType.fork:
        if (!highway) {
          return RouteCue(
            left
                ? RouteCueKind.forkLeft
                : right
                ? RouteCueKind.forkRight
                : RouteCueKind.continueAtFork,
          );
        }
        return RouteCue(
          left
              ? RouteCueKind.keepLeft
              : right
              ? RouteCueKind.keepRight
              : RouteCueKind.continueAtFork,
        );
      case RouteManeuverType.endOfRoad:
        return RouteCue(
          left
              ? RouteCueKind.turnLeft
              : right
              ? RouteCueKind.turnRight
              : RouteCueKind.endOfRoad,
        );
      case RouteManeuverType.turn:
      case RouteManeuverType.unknown:
      case RouteManeuverType.notification:
        return _turn(modifier);
    }
  }

  /// [cue] in words.
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
    AppLocalizations? strings,
  }) => cue(
    type: type,
    modifier: modifier,
    exitNumber: exitNumber,
    exitRef: exitRef,
    towards: towards,
    highway: highway,
    hasRoad: hasRoad,
    toll: toll,
    tunnel: tunnel,
  ).label(strings);

  /// "Turn left in 300 m", "Turn left now", "Continue straight 1.2 km";
  /// a roundabout without the distance.
  static String livePrimary({
    required RouteCue cue,
    required double meters,
    AppLocalizations? strings,
  }) {
    final l = strings ?? tr;
    final action = cue.label(l);
    if (cue.isRoundabout) {
      return action;
    }
    if (meters < nowMeters) {
      return l.navActionNow(action);
    }
    final dist = formatDistance(meters, l);
    if (cue.isOnward) {
      return l.navActionFor(action, dist);
    }
    return l.navActionIn(action, dist);
  }

  /// [livePrimary] without the distance, as the island shows it under the
  /// large number: the action, or the "now" line at the maneuver.
  static String liveInstruction({
    required RouteCue cue,
    required double meters,
    AppLocalizations? strings,
  }) => !cue.isRoundabout && meters < nowMeters
      ? livePrimary(cue: cue, meters: meters, strings: strings)
      : cue.label(strings);

  /// The turn cue for a "continue"/"new name" step whose modifier turns
  /// (left, sharp right, uturn…), or null when it goes straight on or the
  /// modifier is unknown. Highway slight left/right is handled by the caller
  /// as keep left/right.
  static RouteCue? _onwardTurn(String modifier) {
    if (modifier.isEmpty || modifier == 'straight') return null;
    final turn = _turn(modifier);
    return turn.kind == RouteCueKind.proceed ? null : turn;
  }

  static RouteCue _turn(String modifier) {
    switch (modifier) {
      case 'uturn':
      case 'uturn left':
      case 'uturn right':
        return const RouteCue(RouteCueKind.uTurn);
      case 'sharp left':
        return const RouteCue(RouteCueKind.sharpLeft);
      case 'sharp right':
        return const RouteCue(RouteCueKind.sharpRight);
      case 'slight left':
        return const RouteCue(RouteCueKind.slightLeft);
      case 'slight right':
        return const RouteCue(RouteCueKind.slightRight);
      case 'left':
        return const RouteCue(RouteCueKind.turnLeft);
      case 'right':
        return const RouteCue(RouteCueKind.turnRight);
      case 'straight':
        return const RouteCue(RouteCueKind.continueStraight);
      default:
        return const RouteCue(RouteCueKind.proceed);
    }
  }

  static NavigationBannerSymbol symbolFor({
    required RouteManeuverType type,
    required String modifier,
    String drivingSide = 'right',
    bool highway = false,
    bool toll = false,
    bool tunnel = false,
  }) {
    // Same side test as the words ("Exit left", "Merge right").
    final left = modifier.contains('left');
    final right = modifier.contains('right');
    final leftHand = drivingSide == 'left';
    if (type == RouteManeuverType.arrive) {
      // OSRM puts the side of the destination in the modifier.
      return left
          ? NavigationBannerSymbol.arriveLeft
          : right
          ? NavigationBannerSymbol.arriveRight
          : NavigationBannerSymbol.arrive;
    }
    if (type == RouteManeuverType.depart) {
      return NavigationBannerSymbol.depart;
    }
    if (type == RouteManeuverType.roundabout ||
        type == RouteManeuverType.rotary ||
        type == RouteManeuverType.exitRoundabout ||
        type == RouteManeuverType.exitRotary ||
        type == RouteManeuverType.roundaboutTurn) {
      if (modifier.startsWith('uturn')) {
        return NavigationBannerSymbol.roundaboutUTurn;
      }
      return leftHand
          ? NavigationBannerSymbol.roundaboutClockwise
          : NavigationBannerSymbol.roundabout;
    }
    if (type == RouteManeuverType.offRamp || type == RouteManeuverType.ramp) {
      return left
          ? NavigationBannerSymbol.exitLeft
          : right
          ? NavigationBannerSymbol.exitRight
          : NavigationBannerSymbol.exit;
    }
    if (type == RouteManeuverType.onRamp) {
      return left
          ? NavigationBannerSymbol.onRampLeft
          : right
          ? NavigationBannerSymbol.onRampRight
          : NavigationBannerSymbol.merge;
    }
    if (type == RouteManeuverType.merge) {
      return left
          ? NavigationBannerSymbol.mergeLeft
          : right
          ? NavigationBannerSymbol.mergeRight
          : NavigationBannerSymbol.merge;
    }
    if (modifier.startsWith('uturn')) {
      // A bare U-turn turns across the traffic: left where cars drive on
      // the right, right where they drive on the left.
      return modifier == 'uturn right' || (modifier == 'uturn' && leftHand)
          ? NavigationBannerSymbol.uTurnRight
          : NavigationBannerSymbol.uTurnLeft;
    }
    if (type == RouteManeuverType.fork) {
      // A highway split reads "keep left"; a fork in town is a fork.
      if (left) {
        return highway
            ? NavigationBannerSymbol.keepLeft
            : NavigationBannerSymbol.forkLeft;
      }
      if (right) {
        return highway
            ? NavigationBannerSymbol.keepRight
            : NavigationBannerSymbol.forkRight;
      }
      return NavigationBannerSymbol.straight;
    }
    final onward =
        type == RouteManeuverType.continueStraight ||
        type == RouteManeuverType.newName;
    if (onward && highway && modifier == 'slight left') {
      return NavigationBannerSymbol.keepLeft;
    }
    if (onward && highway && modifier == 'slight right') {
      return NavigationBannerSymbol.keepRight;
    }
    switch (modifier) {
      case 'sharp left':
        return NavigationBannerSymbol.sharpLeft;
      case 'sharp right':
        return NavigationBannerSymbol.sharpRight;
      case 'slight left':
        return NavigationBannerSymbol.slightLeft;
      case 'slight right':
        return NavigationBannerSymbol.slightRight;
      case 'left':
        return NavigationBannerSymbol.left;
      case 'right':
        return NavigationBannerSymbol.right;
    }
    // Straight on: a tunnel or toll on the road ahead is the news.
    if (tunnel) return NavigationBannerSymbol.tunnel;
    if (toll) return NavigationBannerSymbol.toll;
    return NavigationBannerSymbol.straight;
  }
}

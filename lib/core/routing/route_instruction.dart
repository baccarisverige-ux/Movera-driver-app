import 'package:movera/core/geo/geo_point.dart';

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
  static String hint(List<RouteLane> lanes) {
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

class RouteInstructionCopy {
  const RouteInstructionCopy._();

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

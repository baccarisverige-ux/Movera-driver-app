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
    );
  }
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
  });

  final String primary;
  final String distanceLabel;
  final String? roadName;
  final NavigationBannerSymbol symbol;
  final String? status;
  final String? exitNumber;

  /// Outgoing road direction relative to entry, when both bearings exist.
  final double? exitAngleDegrees;
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
  }) {
    switch (type) {
      case RouteManeuverType.arrive:
        return 'Arrive';
      case RouteManeuverType.depart:
        return 'Head out';
      case RouteManeuverType.continueStraight:
      case RouteManeuverType.newName:
        return 'Continue straight';
      case RouteManeuverType.roundabout:
      case RouteManeuverType.rotary:
      case RouteManeuverType.roundaboutTurn:
      case RouteManeuverType.exitRoundabout:
      case RouteManeuverType.exitRotary:
        final exit = (exitNumber ?? '').trim();
        return exit.isEmpty ? 'Roundabout' : 'Roundabout, exit $exit';
      case RouteManeuverType.offRamp:
      case RouteManeuverType.ramp:
        return modifier.contains('left')
            ? 'Exit left'
            : modifier.contains('right')
            ? 'Exit right'
            : 'Take the exit';
      case RouteManeuverType.onRamp:
      case RouteManeuverType.merge:
        return modifier.contains('left')
            ? 'Merge left'
            : modifier.contains('right')
            ? 'Merge right'
            : 'Merge';
      case RouteManeuverType.fork:
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
  }) {
    if (type == RouteManeuverType.arrive) {
      return NavigationBannerSymbol.arrive;
    }
    if (type == RouteManeuverType.roundabout ||
        type == RouteManeuverType.rotary ||
        type == RouteManeuverType.exitRoundabout ||
        type == RouteManeuverType.exitRotary ||
        type == RouteManeuverType.roundaboutTurn) {
      return NavigationBannerSymbol.roundabout;
    }
    // Same side test as the words ("Exit left", "Merge right").
    final left = modifier.contains('left');
    final right = modifier.contains('right');
    if (type == RouteManeuverType.offRamp || type == RouteManeuverType.ramp) {
      return left
          ? NavigationBannerSymbol.exitLeft
          : right
          ? NavigationBannerSymbol.exitRight
          : NavigationBannerSymbol.exit;
    }
    if (type == RouteManeuverType.merge || type == RouteManeuverType.onRamp) {
      return left
          ? NavigationBannerSymbol.mergeLeft
          : right
          ? NavigationBannerSymbol.mergeRight
          : NavigationBannerSymbol.merge;
    }
    switch (modifier) {
      case 'uturn':
      case 'uturn left':
      case 'uturn right':
        return NavigationBannerSymbol.uTurn;
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
      default:
        return NavigationBannerSymbol.straight;
    }
  }
}

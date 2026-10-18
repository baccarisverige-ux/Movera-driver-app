/// Destination mode and next trips during a trip, as admin sets them per
/// zone (Dispatch › Rules › Destination & next trips; notes R13-9, R13-18).
/// The admin rules file exports them as `driverApp.destinationMode[zoneId]`
/// and `driverApp.nextTrips[zoneId]`. Missing or broken values fall back to
/// the owner defaults: 2 h, 2 per day, 5 km corridor, focus both; next
/// trips within 5 km or 10 min of the final drop-off.
library;

/// Which trips match a destination.
enum DestinationFocus {
  /// Only trips that end near the final destination.
  finalDestination,

  /// Trips along the route that bring the driver closer, not to the
  /// destination itself.
  onTheWay,

  /// Either.
  both,

  /// Both switches off: nothing matches.
  none;

  static DestinationFocus of({required bool finalOn, required bool onTheWayOn}) =>
      finalOn && onTheWayOn
          ? both
          : finalOn
          ? finalDestination
          : onTheWayOn
          ? onTheWay
          : none;
}

/// `driverApp.destinationMode[zoneId]`.
class DestinationModeRules {
  const DestinationModeRules({
    this.enabled = true,
    this.timeLimitOn = true,
    this.timeLimitHours = 2,
    this.dailyLimitOn = true,
    this.destinationsPerDay = 2,
    this.corridorOn = true,
    this.corridorKm = 5,
    this.focusFinalDestinationOn = true,
    this.focusOnTheWayOn = true,
  });

  /// The rules in use. Mirrors the admin defaults until a backend sets it.
  static DestinationModeRules current = const DestinationModeRules();

  /// The whole mode in this zone; off = drivers cannot set a destination.
  final bool enabled;

  /// How long a destination stays active.
  final bool timeLimitOn;
  final double timeLimitHours;

  /// How many destinations one driver can set per day.
  final bool dailyLimitOn;
  final int destinationsPerDay;

  /// A trip's drop-off must be this close to the road route.
  final bool corridorOn;
  final double corridorKm;

  final bool focusFinalDestinationOn;
  final bool focusOnTheWayOn;

  DestinationFocus get focus => DestinationFocus.of(
    finalOn: focusFinalDestinationOn,
    onTheWayOn: focusOnTheWayOn,
  );

  Duration? get timeLimit => timeLimitOn
      ? Duration(minutes: (timeLimitHours * 60).round())
      : null;

  factory DestinationModeRules.fromJson(Object? json) {
    const base = DestinationModeRules();
    if (json is! Map) { return base; }
    // Older exports may carry only the focus word.
    final focus = json['focus'];
    final finalFromFocus = focus is String
        ? focus == 'final' || focus == 'both'
        : base.focusFinalDestinationOn;
    final wayFromFocus = focus is String
        ? focus == 'onTheWay' || focus == 'both'
        : base.focusOnTheWayOn;
    return DestinationModeRules(
      enabled: _bool(json['enabled'], base.enabled),
      timeLimitOn: _bool(json['timeLimitOn'], base.timeLimitOn),
      timeLimitHours: _positive(json['timeLimitHours'], base.timeLimitHours),
      dailyLimitOn: _bool(json['dailyLimitOn'], base.dailyLimitOn),
      destinationsPerDay:
          _positive(json['destinationsPerDay'], 2).round(),
      corridorOn: _bool(json['corridorOn'], base.corridorOn),
      corridorKm: _positive(json['corridorKm'], base.corridorKm),
      focusFinalDestinationOn:
          _bool(json['focusFinalDestinationOn'], finalFromFocus),
      focusOnTheWayOn: _bool(json['focusOnTheWayOn'], wayFromFocus),
    );
  }
}

/// `driverApp.nextTrips[zoneId]`: next-trip offers while driving a rider.
/// Always Exclusive offers and Exclusive reservations only, never Radar
/// trips, and only on the way to the final drop-off.
class NextTripRules {
  const NextTripRules({
    this.offerTypes = const <String>['exclusive', 'exclusiveReservation'],
    this.withinKmOfDropoffOn = true,
    this.withinKmOfDropoff = 5,
    this.withinMinutesOfDropoffOn = true,
    this.withinMinutesOfDropoff = 10,
  });

  /// The rules in use. Mirrors the admin defaults until a backend sets it.
  static NextTripRules current = const NextTripRules();

  final List<String> offerTypes;

  /// Offers start within this many km of the final drop-off.
  final bool withinKmOfDropoffOn;
  final double withinKmOfDropoff;

  /// Offers start within this many minutes of the final drop-off.
  final bool withinMinutesOfDropoffOn;
  final int withinMinutesOfDropoff;

  /// Never Radar trips during a trip, whatever an export says.
  bool get radarOffers => false;
  bool get onlyOnTheWayToFinalDropoff => true;

  /// Both limits off: offers can come on the whole last leg.
  bool get wholeLastLeg => !withinKmOfDropoffOn && !withinMinutesOfDropoffOn;

  factory NextTripRules.fromJson(Object? json) {
    const base = NextTripRules();
    if (json is! Map) { return base; }
    final types = json['offerTypes'];
    return NextTripRules(
      offerTypes: types is List
          ? [
              for (final type in types)
                if (type == 'exclusive' || type == 'exclusiveReservation') type as String,
            ]
          : base.offerTypes,
      withinKmOfDropoffOn:
          _bool(json['withinKmOfDropoffOn'], base.withinKmOfDropoffOn),
      withinKmOfDropoff:
          _positive(json['withinKmOfDropoff'], base.withinKmOfDropoff),
      withinMinutesOfDropoffOn: _bool(
        json['withinMinutesOfDropoffOn'],
        base.withinMinutesOfDropoffOn,
      ),
      withinMinutesOfDropoff:
          _positive(json['withinMinutesOfDropoff'], 10).round(),
    );
  }
}

/// Reads one zone's sets from the admin rules file. [export] is the whole
/// file or just its `driverApp` part.
class DriverTripRulesExport {
  const DriverTripRulesExport._();

  static (DestinationModeRules, NextTripRules) forZone(
    Map<String, dynamic> export,
    String zoneId,
  ) {
    final app = export['driverApp'] is Map ? export['driverApp'] as Map : export;
    Object? zone(String key) {
      final byZone = app[key];
      return byZone is Map ? byZone[zoneId] : null;
    }
    return (
      DestinationModeRules.fromJson(zone('destinationMode')),
      NextTripRules.fromJson(zone('nextTrips')),
    );
  }

  /// Puts one zone's sets in use.
  static void apply(Map<String, dynamic> export, String zoneId) {
    final (destination, nextTrips) = forZone(export, zoneId);
    DestinationModeRules.current = destination;
    NextTripRules.current = nextTrips;
  }
}

bool _bool(Object? value, bool fallback) => value is bool ? value : fallback;

double _positive(Object? value, double fallback) =>
    value is num && value.isFinite && value > 0 ? value.toDouble() : fallback;

/// RideCheck settings as admin sets them (Dispatch › RideCheck). Mock until
/// a backend sends them; driver and rider apps read the same numbers.
class RideCheckAdminConfig {
  const RideCheckAdminConfig({
    this.finishFarFromDropoffKm = defaultFinishFarFromDropoffKm,
    this.longStopMinutes = defaultLongStopMinutes,
    this.on = true,
    this.offRouteKm = defaultOffRouteKm,
  });

  /// Contract v0.18.9 `rideCheck.offRouteKm` (owner G7 decision 2: 2 km).
  static const double defaultOffRouteKm = 2;

  /// `rideCheck.on`: the zone asks "Is everything OK?" at all. Off: the
  /// app's own long stop / off route / far finish checks stay quiet too
  /// (a possible crash still asks: it is the phone's own sensor).
  final bool on;

  /// `rideCheck.offRouteKm`: how far off the route counts as off route.
  final double offRouteKm;

  static const double defaultFinishFarFromDropoffKm = 3;
  static const int defaultLongStopMinutes = 2;

  /// The config in use. Mirrors the admin defaults until a backend sets it.
  static RideCheckAdminConfig current = const RideCheckAdminConfig();

  /// "Finished far from drop-off": when the driver taps Finish more than
  /// this many km from the drop-off, RideCheck starts.
  final double finishFarFromDropoffKm;

  /// "Unexpected long stop": no movement mid-trip for more than this many
  /// minutes starts RideCheck.
  final int longStopMinutes;

  double get finishFarFromDropoffMeters => finishFarFromDropoffKm * 1000;

  RideCheckAdminConfig copyWith({
    double? finishFarFromDropoffKm,
    int? longStopMinutes,
    bool? on,
    double? offRouteKm,
  }) => RideCheckAdminConfig(
    on: on ?? this.on,
    offRouteKm: offRouteKm ?? this.offRouteKm,
    finishFarFromDropoffKm:
        finishFarFromDropoffKm ?? this.finishFarFromDropoffKm,
    longStopMinutes: longStopMinutes ?? this.longStopMinutes,
  );
}

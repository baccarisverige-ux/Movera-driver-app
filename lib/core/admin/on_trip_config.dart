/// Contract v0.18.9 (driver group 7, `contract.json#onTrip`): the zone's
/// on-trip settings the trip screen reads from the published
/// DriverAppConfig. Every number is the admin's per zone (owner rule 16);
/// the defaults are the contract's `configDefaults`.
class OnTripConfig {
  const OnTripConfig({
    this.maxStops = defaultMaxStops,
    this.routeChangeOn = true,
    this.driverCanRefuse = true,
    this.answerSeconds = defaultAnswerSeconds,
  });

  static const int defaultMaxStops = 3;
  static const int defaultAnswerSeconds = 60;

  static OnTripConfig current = const OnTripConfig();

  /// `booking.maxStops` (0–10): the most middle stops a trip may have.
  final int maxStops;

  /// `routeChange.on`: the rider may change the route during the trip.
  final bool routeChangeOn;

  /// `routeChange.driverCanRefuse`: off = a change is applied at once.
  final bool driverCanRefuse;

  /// `routeChange.answerSeconds`: the driver's time to answer.
  final int answerSeconds;

  static OnTripConfig fromJson(Map<dynamic, dynamic> json) {
    final booking = json['booking'];
    final change = json['routeChange'];
    final max = booking is Map ? booking['maxStops'] : null;
    final seconds = change is Map ? change['answerSeconds'] : null;
    return OnTripConfig(
      maxStops: max is int && max >= 0 && max <= 10 ? max : defaultMaxStops,
      routeChangeOn: change is Map ? change['on'] != false : true,
      driverCanRefuse: change is Map
          ? change['driverCanRefuse'] != false
          : true,
      answerSeconds: seconds is int && seconds >= 10 && seconds <= 600
          ? seconds
          : defaultAnswerSeconds,
    );
  }
}

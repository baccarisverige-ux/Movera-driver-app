/// RideCheck settings as admin sets them (Dispatch › RideCheck). Mock until
/// a backend sends them; driver and rider apps read the same numbers.
class RideCheckAdminConfig {
  const RideCheckAdminConfig({
    this.finishFarFromDropoffKm = defaultFinishFarFromDropoffKm,
    this.longStopMinutes = defaultLongStopMinutes,
  });

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
  }) => RideCheckAdminConfig(
    finishFarFromDropoffKm:
        finishFarFromDropoffKm ?? this.finishFarFromDropoffKm,
    longStopMinutes: longStopMinutes ?? this.longStopMinutes,
  );
}

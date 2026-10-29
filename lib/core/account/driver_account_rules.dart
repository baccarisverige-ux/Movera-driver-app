/// Account rules set by admin (Round 3, Q25), per country. The defaults
/// mirror the admin panel; a backend sends the driver's own values later.
/// Document expiry (Q26) follows the server's onboarding settings
/// (contract v0.17.0, `lib/core/onboarding`).
library;

/// Driving and rest (Q25), from Dispatch › country rules: after
/// [workHours] online the driver rests [restHours] before going online
/// again.
class DrivingRestRule {
  const DrivingRestRule({
    this.on = true,
    this.workHours = 12,
    this.restHours = 6,
    this.warnMinutesLeft = const <int>[30, 10],
    this.blockAtLimit = true,
  });

  final bool on;
  final int workHours;
  final int restHours;

  /// Island warnings, in minutes left before the limit.
  final List<int> warnMinutesLeft;

  /// At the limit the driver can't go online until the rest is over.
  final bool blockAtLimit;

  Duration get work => Duration(hours: workHours);
  Duration get rest => Duration(hours: restHours);
}

class DriverAccountRules {
  const DriverAccountRules({
    this.country = 'SE',
    this.rest = const DrivingRestRule(),
  });

  /// The driver's country (Sweden in the demo).
  static DriverAccountRules current = const DriverAccountRules();

  final String country;
  final DrivingRestRule rest;
}

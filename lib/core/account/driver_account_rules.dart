/// Account rules set by admin (Round 3, Q25 and Q26), per country. The
/// defaults mirror the admin panel; a backend sends the driver's own
/// values later.
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

/// Documents that run out (Q26), from Onboarding › document rules.
class DocumentExpiryRule {
  const DocumentExpiryRule({
    this.warnDaysBefore = const <int>[30, 7, 1],
    this.blockOnExpiry = true,
  });

  /// Island and notification warnings, in days before expiry.
  final List<int> warnDaysBefore;

  /// On the expiry day the driver can't go online until admin approves
  /// the new document.
  final bool blockOnExpiry;

  /// The warning step [daysLeft] is in: 5 days left is the 7 day warning.
  /// Null before the first warning and once the document has expired.
  int? warningFor(int daysLeft) {
    if (daysLeft <= 0) { return null; }
    final days = [...warnDaysBefore]..sort();
    for (final day in days) {
      if (daysLeft <= day) { return day; }
    }
    return null;
  }
}

class DriverAccountRules {
  const DriverAccountRules({
    this.country = 'SE',
    this.rest = const DrivingRestRule(),
    this.documents = const DocumentExpiryRule(),
  });

  /// The driver's country (Sweden in the demo).
  static DriverAccountRules current = const DriverAccountRules();

  final String country;
  final DrivingRestRule rest;
  final DocumentExpiryRule documents;
}

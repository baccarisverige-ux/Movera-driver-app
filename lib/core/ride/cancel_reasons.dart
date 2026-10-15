/// Cancel reasons (Round 3, Q21), the same list admin edits per country and
/// language in Dispatch › Cancel reasons. Today the app uses
/// [CancelReasons.current], whose defaults are the app's reasons in
/// English for Sweden; a backend feeds it later.
library;

/// Where a reason is offered.
enum CancelReasonGroup {
  /// The driver, before the trip starts.
  driverBeforeTrip,

  /// The driver, during the trip.
  driverDuringTrip,

  /// The driver, on an accepted scheduled ride.
  scheduled,

  /// The rider.
  rider,
}

class CancelReason {
  const CancelReason({
    required this.code,
    required this.title,
    this.subtitle = '',
    this.counts = true,
  });

  final String code;
  final String title;
  final String subtitle;

  /// False: "Doesn't count". It does not hurt the cancel rate or the
  /// late-cancel rule (e.g. rider no-show, safety, car breakdown).
  final bool counts;
}

class CancelReasons {
  const CancelReasons({
    this.country = 'SE',
    this.language = 'en',
    this.groups = _defaults,
    this.noShow = const CancelReason(
      code: 'rider_no_show',
      title: 'Rider did not arrive',
      subtitle: 'The no-show time has passed and the rider is not here',
      counts: false,
    ),
  });

  /// The reasons in use, for this driver's country and app language.
  static CancelReasons current = const CancelReasons();

  final String country;
  final String language;
  final Map<CancelReasonGroup, List<CancelReason>> groups;

  /// Offered once the no-show time has passed at pickup.
  final CancelReason noShow;

  List<CancelReason> of(CancelReasonGroup group) =>
      groups[group] ?? const <CancelReason>[];

  /// The reason with [code] in any group, or null.
  CancelReason? byCode(String code) {
    if (code == noShow.code) {
      return noShow;
    }
    for (final reasons in groups.values) {
      for (final reason in reasons) {
        if (reason.code == code) {
          return reason;
        }
      }
    }
    return null;
  }

  /// A cancel with [code] counts in the cancel rate (unknown codes do).
  bool counts(String code) => byCode(code)?.counts ?? true;

  static const Map<CancelReasonGroup, List<CancelReason>> _defaults = {
    CancelReasonGroup.driverBeforeTrip: [
      CancelReason(
        code: 'rider_requested_cancel',
        title: 'Rider asked to cancel',
        subtitle: 'The rider doesn’t want to continue',
      ),
      CancelReason(
        code: 'rider_not_at_pickup',
        title: 'Rider not at pickup',
        subtitle: 'You arrived but couldn’t find the rider',
      ),
      CancelReason(
        code: 'unsafe_pickup',
        title: 'Pickup unsafe',
        subtitle: 'You can’t stop there safely',
        counts: false,
      ),
      CancelReason(
        code: 'vehicle_issue_before_start',
        title: 'Vehicle problem',
        subtitle: 'Your car can’t make the trip',
        counts: false,
      ),
      CancelReason(
        code: 'driver_emergency_before_start',
        title: 'Personal emergency',
        subtitle: 'Something urgent came up',
      ),
      CancelReason(
        code: 'other_before_start',
        title: 'Other reason',
        subtitle: 'Something else stops this pickup',
      ),
    ],
    CancelReasonGroup.driverDuringTrip: [
      CancelReason(
        code: 'rider_requested_early_end',
        title: 'Rider asked to end the trip',
        subtitle: 'The rider wants to leave before the destination',
      ),
      CancelReason(
        code: 'safety_concern_on_trip',
        title: 'Safety concern',
        subtitle: 'Continuing the trip may be unsafe',
        counts: false,
      ),
      CancelReason(
        code: 'vehicle_issue_on_trip',
        title: 'Vehicle problem',
        subtitle: 'A vehicle issue makes it unsafe to continue',
        counts: false,
      ),
      CancelReason(
        code: 'accident_or_road_emergency',
        title: 'Accident or road emergency',
        subtitle: 'An incident or emergency prevents continuing',
        counts: false,
      ),
      CancelReason(
        code: 'rider_behavior',
        title: 'Rider behavior',
        subtitle: 'The rider’s behavior requires the trip to end',
      ),
      CancelReason(
        code: 'trip_or_destination_issue',
        title: 'Trip or destination issue',
        subtitle: 'A trip detail or destination problem prevents continuing',
      ),
      CancelReason(
        code: 'other_on_trip',
        title: 'Other reason',
        subtitle: 'Another issue requires the trip to end early',
      ),
    ],
    CancelReasonGroup.scheduled: [
      CancelReason(
        code: 'scheduled_cannot_make_time',
        title: 'I can no longer make the pickup time',
      ),
      CancelReason(
        code: 'scheduled_vehicle_issue',
        title: 'Vehicle issue',
        counts: false,
      ),
      CancelReason(
        code: 'scheduled_personal_emergency',
        title: 'Personal emergency',
      ),
      CancelReason(
        code: 'scheduled_pickup_too_far',
        title: 'Pickup is too far from me',
      ),
      CancelReason(
        code: 'scheduled_trip_details',
        title: 'Trip details no longer work for me',
      ),
      CancelReason(code: 'scheduled_other', title: 'Other reason'),
    ],
    CancelReasonGroup.rider: [
      CancelReason(code: 'rider_changed_plans', title: 'Plans changed'),
      CancelReason(code: 'rider_driver_too_far', title: 'Driver too far away'),
      CancelReason(
        code: 'rider_driver_asked',
        title: 'The driver asked me to cancel',
        counts: false,
      ),
      CancelReason(code: 'rider_other', title: 'Other reason'),
    ],
  };
}

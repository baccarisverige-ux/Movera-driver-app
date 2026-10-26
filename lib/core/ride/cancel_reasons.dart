/// Cancel reasons (Round 3, Q21), the same list admin edits per country and
/// language in Dispatch › Cancel reasons. Today the app uses
/// [CancelReasons.current], whose defaults are the app's reasons in
/// English for Sweden; a backend feeds it later.
library;

import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/ride/cancel_reason_l10n.dart';

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

  /// The driver, cancelling the secured next trip during a trip. The
  /// current trip goes on; the next one goes back to dispatch.
  driverNextTrip,
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

  /// The reasons of [group], in the driver's language ([shown]).
  List<CancelReason> of(CancelReasonGroup group) => [
    for (final reason in groups[group] ?? const <CancelReason>[]) shown(reason),
  ];

  /// The reason with [code] in any group, or null.
  CancelReason? byCode(String code) {
    if (code == noShow.code) {
      return shown(noShow);
    }
    for (final reasons in groups.values) {
      for (final reason in reasons) {
        if (reason.code == code) {
          return shown(reason);
        }
      }
    }
    return null;
  }

  /// [reason] as the driver reads it (Round 4). Admin's list in the app's
  /// language is shown as written. Otherwise a reason the app knows by its
  /// code is shown in the app's language; any other one as written.
  CancelReason shown(CancelReason reason) {
    if (language == DriverAppTexts.language) {
      return reason;
    }
    final strings = tr;
    final title = cancelReasonTitle(strings, reason.code);
    if (title == null) {
      return reason;
    }
    return CancelReason(
      code: reason.code,
      title: title,
      subtitle: reason.subtitle.isEmpty
          ? ''
          : cancelReasonDetail(strings, reason.code) ?? reason.subtitle,
      counts: reason.counts,
    );
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
    CancelReasonGroup.driverNextTrip: [
      CancelReason(
        code: 'next_trip_current_running_late',
        title: 'Current trip is taking longer',
        subtitle: 'You can’t reach the next pickup in time',
      ),
      CancelReason(
        code: 'next_trip_pickup_too_far',
        title: 'Too far from the pickup',
        subtitle: 'The next pickup is further than expected',
      ),
      CancelReason(
        code: 'next_trip_rider_requested',
        title: 'Rider asked me to cancel',
        subtitle: 'The next rider doesn’t want the trip',
      ),
      CancelReason(
        code: 'next_trip_vehicle_issue',
        title: 'Problem with the car',
        subtitle: 'Your car can’t make the next trip',
        counts: false,
      ),
      CancelReason(
        code: 'next_trip_driver_emergency',
        title: 'Personal emergency',
        subtitle: 'Something urgent came up',
      ),
      CancelReason(
        code: 'next_trip_other',
        title: 'Other reason',
        subtitle: 'Something else stops the next trip',
      ),
    ],
    // The rider app's own reasons and codes (CancellationReason there).
    CancelReasonGroup.rider: [
      CancelReason(
        code: 'pickup_incorrect',
        title: 'Pickup point is incorrect',
      ),
      CancelReason(
        code: 'wrong_ride_option',
        title: 'I chose the wrong ride option',
      ),
      CancelReason(
        code: 'requested_by_mistake',
        title: 'I requested the ride by mistake',
      ),
      CancelReason(code: 'wait_too_long', title: 'The wait is taking too long'),
      CancelReason(
        code: 'destination_change',
        title: 'Destination needs to be changed',
      ),
      CancelReason(
        code: 'driver_not_suitable',
        title: 'Driver/ride details are not suitable',
      ),
      CancelReason(code: 'plans_changed', title: 'Plans changed'),
      CancelReason(code: 'something_else', title: 'Something else'),
    ],
  };
}

import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/notifications/driver_notifications.dart';
import 'package:movera/core/ride/cancel_reasons.dart';
import 'package:movera/core/scheduled/reservation_when.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';
import 'package:movera/core/scheduled/scheduled_ride_rules.dart';
import 'package:movera/core/scheduled/smart_gap.dart';
import 'package:movera/core/vehicle/ride_categories.dart';
import 'package:movera/presentation/driver/home/components/home_island_notices.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/components/reservation_route_map.dart';
import 'package:movera/styles/movera_map_palette.dart';
import 'package:movera/widgets/driver_route_style.dart';
import 'package:movera/widgets/led_count_badge.dart';
import 'package:movera/widgets/route_mark_pins.dart';
import 'package:movera/widgets/single_route_entry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/widgets/offer_badges.dart';
import 'package:movera/core/geo/driver_distance.dart';

part 'scheduled_rides_notes.dart';

// Solar line icons (stroke 1.5), tinted to match the surrounding text.
Widget _solar(String asset, Color color, double size) => SvgPicture.asset(
  asset,
  width: size,
  height: size,
  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
);

// A route remains mounted during its reverse transition. A second callback
// must not pop the route underneath it or return a second decision.
void _popScheduledRoute<T>(BuildContext context, [T? result]) {
  if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) {
    return;
  }
  Navigator.of(context).pop<T>(result);
}

class ScheduledRidesScreen extends StatefulWidget {
  const ScheduledRidesScreen({super.key, this.dispatchRepository});

  /// Claims an open reservation before it is accepted: the server gives it
  /// to the first driver (notes R25). Without it the screen decides
  /// locally, as a preview.
  final DispatchRepository? dispatchRepository;

  @override
  State<ScheduledRidesScreen> createState() => _ScheduledRidesScreenState();
}

class _ScheduledRidesScreenState extends State<ScheduledRidesScreen> {
  int _selectedTab = 0;

  /// Requests whose claim is with the server right now.
  final Set<String> _claiming = <String>{};

  late final Listenable _store = Listenable.merge([
    ScheduledRideStore._revision,
    ScheduledRideStore.reminder,
    ScheduledRideStore.backupNote,
  ]);

  @override
  void initState() {
    super.initState();
    _store.addListener(_storeChanged);
  }

  void _storeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _store.removeListener(_storeChanged);
    super.dispose();
  }

  /// Requests this driver can take: clashing ones and every request while
  /// Scheduled rides are paused or off are left out.
  List<_ScheduledRide> get _requests => ScheduledRideStore._visibleRequests;
  List<_ScheduledRide> get _accepted => ScheduledRideStore._accepted;

  /// Notes above the rides: paused or off, clashing rides left out, the
  /// latest reminder, a ride given to a backup driver.
  List<Widget> _notes() {
    final block = ScheduledRideStore.block();
    final reminder = ScheduledRideStore.reminder.value;
    final backup = ScheduledRideStore.backupNote.value;
    final clashing = ScheduledRideStore._clashing;
    return [
      if (block != null) _BlockNotice(block: block),
      if (_selectedTab == 0 && block == null && clashing.isNotEmpty)
        _ScheduledNote(
          key: const ValueKey<String>('scheduled-clash-note'),
          icon: AppAssets.solarCalendarMinimalistic,
          title: tr.schedRidesHidden(clashing.length),
          body:
              tr.schedClashBody(clashing.first.$2.route?.pickupTime ?? ''),
        ),
      if (_selectedTab == 1 && reminder != null)
        _ScheduledNote(
          key: const ValueKey<String>('scheduled-reminder'),
          icon: AppAssets.solarBellBing,
          title: tr.reminder,
          body: reminder,
        ),
      if (_selectedTab == 1 && backup != null)
        _ScheduledNote(
          key: const ValueKey<String>('scheduled-backup-note'),
          icon: AppAssets.solarInfoCircle,
          title: ScheduledRideStore._backupLate
              ? tr.lateEtaReassignedTitle
              : tr.islandGivenToBackup,
          body: backup,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final rides = _selectedTab == 0 ? _requests : _accepted;
    final notes = _notes();
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F6),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Scale the available-height budget with text size so the header
            // scrolls before it crowds the cards into an unusably short strip.
            final compact =
                constraints.maxHeight <
                500 * MediaQuery.textScalerOf(context).scale(13) / 13;
            final list = ListView.separated(
              shrinkWrap: compact,
              physics: compact ? const NeverScrollableScrollPhysics() : null,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              itemCount: rides.length + notes.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                if (index > 0 && index <= notes.length) {
                  return notes[index - 1];
                }
                if (index > notes.length) {
                  index -= notes.length;
                }
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedTab == 0 ? tr.schedAvailableToday : tr.schedUpcoming,
                            style: const TextStyle(
                              color: Color(0xFF6F7B82),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_selectedTab == 0 && _requests.isNotEmpty)
                          LedCountBadge(count: _requests.length),
                      ],
                    ),
                  );
                }
                final ride = rides[index - 1];
                final claiming =
                    ride.id.isNotEmpty && _claiming.contains(ride.id);
                return _ScheduledRideCard(
                  ride: ride,
                  claiming: claiming,
                  onTap: claiming ? null : () => _openRideDetails(ride),
                );
              },
            );
            final content = Column(
              mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
              children: [
                _buildHeader(context),
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    tr.schedPreviewNotBinding,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                _buildTabs(),
                if (compact) list else Expanded(child: list),
              ],
            );
            return compact ? SingleChildScrollView(child: content) : content;
          },
        ),
      ),
    );
  }

  Future<void> _openRideDetails(_ScheduledRide ride) async {
    final action = await pushSingle<_ScheduledRideAction>(
      context,
      MaterialPageRoute(
        builder: (_) => _ScheduledRideDetailsScreen(ride: ride),
      ),
    );

    if (!mounted || action == null) {
      return;
    }

    if (action == _ScheduledRideAction.accepted) {
      // The request may have been answered on Home, or replaced by a new
      // session while this details route was open. Only its current owner can act.
      if (!_requests.contains(ride)) {
        // Its pickup time passed while the details were open (driver-u164).
        if (ScheduledRideStore._pickupPassed(ride)) {
          _notice(tr.islandNoLongerAvailable);
        }
        return;
      }
      if (!await _claim(ride) || !mounted) return;
      if (!ScheduledRideStore._requests.remove(ride)) return;
      _accepted.insert(0, ride.copyWith(accepted: true));
      setState(() => _selectedTab = 1);
      // Requests whose time now clashes leave the list (Q9); the Requests
      // tab says why.
      ScheduledRideStore._changed();
      // Only saved for later: it becomes the trip at its time ("Leave now"
      // by the real clock), never right after Accept.
      final time = ride.route?.pickupTime;
      if (time == null) {
        _notice(tr.islandReservationAccepted);
      } else {
        IslandMessages.show(HomeIslandNotices.reservationAcceptedAt(time));
        _notice(tr.schedAcceptedPickupAt(time));
      }
    } else if (action == _ScheduledRideAction.cancelled ||
        action == _ScheduledRideAction.cancelledNotCounted) {
      if (!_accepted.contains(ride)) return;
      final paused = ScheduledRideStore._cancelAccepted(
        ride,
        counts: action == _ScheduledRideAction.cancelled,
      );
      // Q31, N3: the pause is in Notifications and on the island.
      if (paused) {
        final until = ScheduledRideStore.pausedUntil(ScheduledRideStore._now);
        final feed = DriverNotificationFeed.instance;
        feed.add(DriverNotices.scheduledPaused(
          feed.now,
          until: until == null ? tr.laterLower : _dayMonth(until),
        ));
      }
      // An open reservation goes back out to drivers (notes R24): where it
      // goes follows the admin rule, Radar trips too close to pickup.
      if (ride.id.isNotEmpty && !ride.assigned) {
        widget.dispatchRepository?.releaseReservation(ride.id);
      }
      _notice(tr.schedReservationCancelled);
    }
  }

  /// Asks the server for [ride] when it is an open reservation. True when
  /// this driver got it (or there is no server to ask); lost, it leaves
  /// the list and the driver is told it is no longer available.
  Future<bool> _claim(_ScheduledRide ride) async {
    final dispatch = widget.dispatchRepository;
    if (dispatch == null || ride.id.isEmpty) return true;
    if (!_claiming.add(ride.id)) return false;
    setState(() {});
    ClaimResult result;
    try {
      result = await dispatch.claimOffer(ride.id);
    } catch (_) {
      result = const ClaimResult.networkError();
    }
    _claiming.remove(ride.id);
    if (!mounted) return false;
    setState(() {});
    switch (result.outcome) {
      case ClaimOutcome.success:
        return true;
      case ClaimOutcome.networkError:
        _notice(tr.islandNoConnection);
        return false;
      case ClaimOutcome.alreadyClaimed:
      case ClaimOutcome.expired:
      case ClaimOutcome.unavailable:
        ScheduledRideStore.take(ride.id);
        _notice(tr.islandNoLongerAvailable);
        return false;
    }
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 15),
      child: Row(
        children: [
          IconButton(
            tooltip: tr.back,
            onPressed: () => _popScheduledRoute<void>(context),
            icon: _solar(AppAssets.solarArrowLeft, const Color(0xFF252E3A), 24),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr.scheduledRides,
                  style: TextStyle(
                    color: Color(0xFF252E3A),
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  tr.schedPlanAhead,
                  style: TextStyle(
                    color: Color(0xFF869198),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F5F6),
              borderRadius: BorderRadius.circular(13),
            ),
            alignment: Alignment.center,
            child: _solar(AppAssets.solarCalendar, const Color(0xFF425058), 20),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 15),
      child: Container(
        height: 46 * MediaQuery.textScalerOf(context).scale(13) / 13,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F2F3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [_tabButton(0, tr.schedRequestsTab), _tabButton(1, tr.schedAcceptedTab)],
        ),
      ),
    );
  }

  Widget _tabButton(int index, String label) {
    final selected = _selectedTab == index;
    return Expanded(
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        elevation: selected ? 1 : 0,
        shadowColor: const Color(0xFF1A2730).withValues(alpha: 0.12),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () => setState(() => _selectedTab = index),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? const Color(0xFF252E3A)
                    : const Color(0xFF808B91),
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reservation requests for this app session. Decisions stay while the app
/// runs, so the green dot on Home follows what is still unanswered.
class ScheduledRideStore {
  const ScheduledRideStore._();

  static final List<_ScheduledRide> _requests = _seedRequests();
  static List<_ScheduledRide> _seedRequests() => [
    // The same reservation the Home popup shows later (notes R21). The
    // demo books them relative to now.
    _ScheduledRide.request(DemoReservations.main),
    // No driver near Lidingö: admin raised the fare (Q13). Its time
    // clashes with the first ride (Q9).
    _ScheduledRide.request(
      DemoReservations.clashing,
      window: const Duration(minutes: 10),
      distance: '12 km',
    ),
    // An airport ride, sent to the Home popup after the first.
    if (DemoReservations.airport case final airport?)
      _ScheduledRide.request(airport),
  ];

  static final List<_ScheduledRide> _accepted = _seedAccepted();
  static List<_ScheduledRide> _seedAccepted() => [
    _ScheduledRide(
      price: '184.00 kr',
      time: tr.schedSeedTime(tr.tomorrow, '08:15'),
      category: 'Comfort',
      distance: '9.4 km',
      pickup: 'Södermalm, Stockholm',
      destination: 'Bromma Airport',
      accepted: true,
      route: ReservationRequestPreview(
        category: 'Comfort',
        fare: '184.00 kr',
        rating: '4.90',
        riderName: 'Lars',
        riderTrips: 47,
        pickupLabel: tr.schedPickupTomorrowAt('08:15'),
        pickupAddress: 'Södermalm, Stockholm',
        dropoffAddress: 'Bromma Airport',
        pickupTime: '08:15',
        pickupDay: tr.tomorrow,
        tripMinutes: 20,
        tripKm: 9.4,
        pickup: GeoPoint(59.3134, 18.0727),
        dropoff: GeoPoint(59.3544, 17.9416),
      ).scheduledFor(_tomorrowAt(8, 15)),
    ),
  ];

  /// [hour]:[minute] tomorrow, from now: the seed ride's date stays the
  /// same after midnight (driver-u142).
  static DateTime _tomorrowAt(int hour, int minute) {
    final now = _now;
    return DateTime(now.year, now.month, now.day + 1, hour, minute);
  }

  /// Admin's on/off for this driver. Home sets it from the admin config.
  static ScheduledRidesDriverAccess get driverAccess => _driverAccess;
  static set driverAccess(ScheduledRidesDriverAccess value) {
    _driverAccess = value;
    _changed();
  }

  static ScheduledRidesDriverAccess _driverAccess =
      const ScheduledRidesDriverAccess();

  /// This driver's late cancels, oldest first.
  static final List<DateTime> _lateCancels = <DateTime>[];

  /// Records a late cancel made at [at] (a backend sends the count).
  static void addLateCancel(DateTime at) {
    _recordLateCancel(at);
    _changed();
  }

  /// The pause the late cancels started: set by the cancel that reached
  /// the limit and kept to its end, the date the driver was told. Worked
  /// out again from the period alone, it would end as soon as the first
  /// counted cancel left the period (driver-u163).
  static DateTime? _pauseUntil;

  static void _recordLateCancel(DateTime at) {
    _lateCancels
      ..add(at)
      ..sort();
    final until = _pauseFromPeriod(at);
    final kept = _pauseUntil;
    if (until != null && (kept == null || until.isAfter(kept))) {
      _pauseUntil = until;
    }
  }

  static DateTime get _now => ScheduledClock.instance.now();
  static ScheduledRideRules get _rules => ScheduledRideRules.current;

  /// Why this driver gets no scheduled rides right now, or null.
  static ScheduledRidesBlock? block() {
    final now = _now;
    if (_driverAccess.offAt(now)) {
      return ScheduledRidesBlock(
        byAdmin: true,
        until: _driverAccess.offUntil,
      );
    }
    final until = pausedUntil(now);
    return until == null ? null : ScheduledRidesBlock(until: until);
  }

  /// Too many late cancels: Scheduled rides are paused until then.
  static DateTime? pausedUntil(DateTime now) {
    final kept = _pauseUntil;
    final fromPeriod = _pauseFromPeriod(now);
    final until = kept != null && now.isBefore(kept) ? kept : null;
    if (until == null) return fromPeriod;
    if (fromPeriod == null) return until;
    return fromPeriod.isAfter(until) ? fromPeriod : until;
  }

  /// The pause the late cancels in the period before [now] call for.
  static DateTime? _pauseFromPeriod(DateTime now) {
    final rules = _rules;
    final since = now.subtract(Duration(days: rules.lateCancelPeriodDays));
    final recent = _lateCancels.where((at) => at.isAfter(since)).toList();
    if (recent.length < rules.lateCancelLimit) {
      return null;
    }
    final until = recent.last.add(Duration(days: rules.pauseDays));
    return now.isBefore(until) ? until : null;
  }

  /// Late cancels inside the current period.
  static int lateCancelsInPeriod() {
    final since = _now.subtract(Duration(days: _rules.lateCancelPeriodDays));
    return _lateCancels.where((at) => at.isAfter(since)).length;
  }

  /// A cancel of [ride] now is late: under the admin's hours to pickup.
  static bool isLateCancel(ReservationRequestPreview? ride) {
    final until = freeCancelUntil(ride);
    return until != null && !_now.isBefore(until);
  }

  /// Until when cancelling [ride] is free; null when its time is unknown.
  static DateTime? freeCancelUntil(ReservationRequestPreview? ride) =>
      ride
          ?.pickupAt(_now)
          ?.subtract(Duration(hours: _rules.driverLateCancelHours));

  /// [ride] clashes with an accepted ride: the accepted one, else null.
  static _ScheduledRide? _clashWith(_ScheduledRide ride) {
    final route = ride.route;
    if (route == null || !_rules.removeClashing) {
      return null;
    }
    final now = _now;
    for (final taken in _accepted) {
      final other = taken.route;
      if (other != null &&
          SmartGap.clash(route, other, now: now, rules: _rules)) {
        return taken;
      }
    }
    return null;
  }

  /// Requests this driver can take now: none while blocked, only in the
  /// categories they drive (Q27), none whose time clashes with a ride
  /// they accepted (Q9) and none whose pickup time has passed.
  static List<_ScheduledRide> get _visibleRequests => block() != null
      ? const <_ScheduledRide>[]
      : _requests
          .where((ride) =>
              !_pickupPassed(ride) &&
              DriverCategoryChoice.takes(ride.category) &&
              _clashWith(ride) == null)
          .toList();

  /// [ride]'s pickup time has passed: nobody can take it any more
  /// (driver-u164). False when its time is unknown.
  static bool _pickupPassed(_ScheduledRide ride) {
    final now = _now;
    final at = ride.route?.pickupAt(now);
    return at != null && !at.isAfter(now);
  }

  /// The next pickup time of an open request; Home refreshes the
  /// requests ([refresh]) then, so the dot stops counting it.
  static DateTime? nextRequestPickup() {
    final now = _now;
    DateTime? next;
    for (final ride in _requests) {
      final at = ride.route?.pickupAt(now);
      if (at != null && at.isAfter(now) && (next == null || at.isBefore(next))) {
        next = at;
      }
    }
    return next;
  }

  /// Counts the open requests again: a pickup time passed.
  static void refresh() => _changed();

  /// The driver's categories changed (Q27).
  static void categoriesChanged() => _changed();

  /// Requests left out because they clash with an accepted ride.
  static List<(_ScheduledRide, _ScheduledRide)> get _clashing => [
    for (final ride in _requests)
      if (!_pickupPassed(ride))
        if (_clashWith(ride) case final taken?) (ride, taken),
  ];

  /// Requests the driver has not accepted or declined yet.
  static final ValueNotifier<int> openRequests = ValueNotifier<int>(
    _visibleRequests.length,
  );

  static final ValueNotifier<int> _revision = ValueNotifier<int>(0);

  /// Notifies when anything here changes.
  static ValueListenable<int> get changes => _revision;

  static void _changed() {
    openRequests.value = _visibleRequests.length;
    _revision.value++;
  }

  /// The ride of reservation [id], open or accepted; null when unknown.
  static ReservationRequestPreview? routeOf(String id) {
    if (id.isEmpty) return null;
    for (final ride in [..._requests, ..._accepted]) {
      if (ride.id == id) return ride.route;
    }
    return null;
  }

  /// Whether reservation [id] is still open to take here.
  static bool isOpen(String id) =>
      id.isNotEmpty && _visibleRequests.any((ride) => ride.id == id);

  /// Reservation [id] was taken. By this driver for later ([upcoming]) it
  /// moves to Accepted; taken now (an Exclusive or Radar trip) or by
  /// another driver it only leaves the requests (notes R23).
  static void take(String id, {bool upcoming = false}) {
    final index = _requests.indexWhere((ride) => ride.id == id);
    if (id.isEmpty || index < 0) {
      return;
    }
    final ride = _requests.removeAt(index);
    if (upcoming) {
      _accepted.insert(0, ride.copyWith(accepted: true));
    }
    _changed();
  }

  /// A request answered outside this screen, found by its pickup. Taken
  /// by this driver ([accepted]) it moves to Accepted; otherwise it only
  /// leaves the requests.
  static void answer(String pickup, {required bool accepted}) {
    final index = _requests.indexWhere((ride) => ride.pickup == pickup);
    if (index < 0) {
      return;
    }
    final ride = _requests.removeAt(index);
    if (accepted) {
      _accepted.insert(0, ride.copyWith(accepted: true));
    }
    _changed();
  }

  /// Q29: the driver accepted a ride Movera assigned to them.
  static void acceptAssigned(ReservationRequestPreview ride) {
    if (_accepted.any((item) => identical(item.route, ride))) {
      return;
    }
    _accepted.insert(0, _ScheduledRide.fromRoute(ride, assigned: true));
    _changed();
  }

  /// Accepted rides with a known pickup time, soonest first.
  static List<ReservationRequestPreview> get upcoming {
    final now = _now;
    final rides = [
      for (final ride in _accepted)
        if (ride.route case final route? when route.pickupAt(now) != null)
          route,
    ]..sort((a, b) => a.pickupAt(now)!.compareTo(b.pickupAt(now)!));
    return rides;
  }

  /// "Leave now" put [ride] on screen as the active trip: it leaves
  /// Accepted. False when it was not there.
  static bool start(ReservationRequestPreview ride) =>
      _removeAccepted(ride) != null;

  /// The driver was not on the way in time: [ride] went to a backup
  /// driver (Q10 S3).
  static void giveToBackup(ReservationRequestPreview ride) {
    if (_removeAccepted(ride) == null) {
      return;
    }
    _backupLate = false;
    backupNote.value =
        tr.schedBackupNote(ride.pickupTime);
    _changed();
  }

  /// Late ETA (`reservations.lateEta`): on the way from "Leave now", the
  /// driver would reach the [pickupTime] pickup [lateMinutes] late, so the
  /// ride went to another driver early. The trip already left Accepted at
  /// "Leave now"; one still there with [id] leaves too.
  ///
  /// [reassignTo] is the admin's choice of where the ride goes. The demo
  /// has no backend, so it cannot send the Exclusive offer (or Radar trip)
  /// to another driver: it only keeps the choice in [reassigned] and the
  /// log. A backend makes this decision itself and releases the trip.
  static void reassignLate({
    required String id,
    required String pickupTime,
    required int lateMinutes,
    required LateEtaReassignTo reassignTo,
  }) {
    if (id.isNotEmpty) {
      _accepted.removeWhere((ride) => ride.id == id);
    }
    final note = tr.lateEtaReassignedNote(pickupTime, lateMinutes);
    reassigned.add(ScheduledReassignment(
      id: id,
      pickupTime: pickupTime,
      lateMinutes: lateMinutes,
      reassignTo: reassignTo,
      at: _now,
    ));
    DriverLog.info(
      'Scheduled ride ${id.isEmpty ? pickupTime : id} reassigned '
      '(late ETA, $lateMinutes min late) to ${reassignTo.name}',
      name: 'movera.scheduled',
    );
    _backupLate = true;
    backupNote.value = note;
    _changed();
  }

  /// [backupNote] is about a late ETA, not an offline driver.
  static bool _backupLate = false;

  /// Rides given to another driver for a late ETA, oldest first.
  static final List<ScheduledReassignment> reassigned =
      <ScheduledReassignment>[];

  static _ScheduledRide? _removeAccepted(ReservationRequestPreview ride) {
    final index = _accepted.indexWhere((item) => identical(item.route, ride));
    if (index < 0) {
      return null;
    }
    final removed = _accepted.removeAt(index);
    _changed();
    return removed;
  }

  /// The latest reminder for an accepted ride, shown in Scheduled rides.
  static final ValueNotifier<String?> reminder = ValueNotifier<String?>(null);

  /// Set when a ride went to a backup driver.
  static final ValueNotifier<String?> backupNote = ValueNotifier<String?>(
    null,
  );

  /// R15-7: the rider cancelled reservation [id], which this driver had
  /// accepted. It leaves Accepted and the island says so, with the
  /// driver's cancel [fee] from the backend ("+105 kr", "no fee"; nothing
  /// while not decided). False when no accepted ride has that id.
  static bool riderCancelled(String id, {Money? fee}) {
    final index = _accepted.indexWhere((ride) => ride.id == id && id.isNotEmpty);
    if (index < 0) { return false; }
    final ride = _accepted.removeAt(index);
    IslandMessages.show(HomeIslandNotices.reservationCancelled(
      ride.route?.pickupTime ?? ride.time,
      fee,
    ));
    _changed();
    return true;
  }

  /// The driver cancelled [ride], which they had accepted. A late cancel is
  /// counted (drivers never pay), unless its reason doesn't count
  /// ([counts], Q21); true when it paused Scheduled rides.
  static bool _cancelAccepted(_ScheduledRide ride, {bool counts = true}) {
    final late = counts && isLateCancel(ride.route);
    if (!_accepted.remove(ride)) {
      return false;
    }
    final wasPaused = pausedUntil(_now) != null;
    if (late) {
      _recordLateCancel(_now);
    }
    // An open reservation goes back out to drivers (notes R24).
    if (ride.id.isNotEmpty && !ride.assigned) {
      _requests.insert(0, ride.copyWith(accepted: false));
    }
    _changed();
    return !wasPaused && pausedUntil(_now) != null;
  }

  @visibleForTesting
  static void reset() {
    _requests
      ..clear()
      ..addAll(_seedRequests());
    _accepted
      ..clear()
      ..addAll(_seedAccepted());
    _driverAccess = const ScheduledRidesDriverAccess();
    _lateCancels.clear();
    _pauseUntil = null;
    reminder.value = null;
    backupNote.value = null;
    reassigned.clear();
    _backupLate = false;
    _changed();
  }
}

/// A scheduled ride given to another driver because the driver on the way
/// would reach its pickup too late (`reservations.lateEta`).
class ScheduledReassignment {
  const ScheduledReassignment({
    required this.id,
    required this.pickupTime,
    required this.lateMinutes,
    required this.reassignTo,
    required this.at,
  });

  /// The reservation id; empty for a sample ride.
  final String id;
  final String pickupTime;

  /// How late the driver would have been, past the pickup time.
  final int lateMinutes;

  /// Where the admin sends it; the demo only records it.
  final LateEtaReassignTo reassignTo;
  final DateTime at;
}

/// Why a driver gets no scheduled rides right now.
class ScheduledRidesBlock {
  const ScheduledRidesBlock({this.byAdmin = false, this.until});

  /// Admin turned them off for this driver; otherwise too many late
  /// cancels paused them.
  final bool byAdmin;

  /// Back on at this time; null until admin turns them on.
  final DateTime? until;
}

class _ScheduledRideCard extends StatelessWidget {
  const _ScheduledRideCard({
    required this.ride,
    required this.onTap,
    this.claiming = false,
  });

  final _ScheduledRide ride;
  final VoidCallback? onTap;

  /// Its claim is with the server: tr.islandMatching until the answer comes.
  final bool claiming;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 14, 13),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              ride.price,
                              style: const TextStyle(
                                color: Color(0xFF252E3A),
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            // Admin raised the fare; the price has it.
                            if (ride.route?.fareBoost case final boost?)
                              OfferBadge.boost(
                                boost,
                                key: ValueKey<String>(
                                  'scheduled-boost-${ride.pickup}',
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (claiming)
                        Row(
                          key: ValueKey<String>('scheduled-ride-matching'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.6,
                                color: Color(0xFF4E5A61),
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              tr.islandMatching,
                              style: TextStyle(
                                color: Color(0xFF4E5A61),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        )
                      else
                        _solar(
                          AppAssets.solarAltArrowRight,
                          const Color(0xFFA3ADB2),
                          18,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _solar(
                        AppAssets.solarClockCircle,
                        const Color(0xFF19865C),
                        17,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          ride.when,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF4E5A61),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Flexible(
                        child: _RideMeta(
                          icon: AppAssets.solarCar,
                          label: ride.category,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: _RideMeta(
                          icon: AppAssets.solarRoute,
                          label: ride.distance,
                        ),
                      ),
                      if (ride.assigned) ...[
                        const SizedBox(width: 12),
                        Flexible(
                          child: _RideMeta(
                            icon: AppAssets.solarBolt,
                            label: tr.assignedByMovera,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            _RoutePreview(accepted: ride.accepted),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 17),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Column(
                      children: [
                        Container(
                          height: 14,
                          width: 14,
                          margin: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF2FBE7B),
                              width: 3,
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 27,
                          child: VerticalDivider(
                            color: Color(0xFFCAD2D6),
                            thickness: 1.4,
                          ),
                        ),
                        _solar(
                          AppAssets.solarMapPoint,
                          const Color(0xFFDF5A62),
                          18,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ride.pickup,
                          style: const TextStyle(
                            color: Color(0xFF344047),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          ride.destination,
                          style: const TextStyle(
                            color: Color(0xFF344047),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RideMeta extends StatelessWidget {
  const _RideMeta({required this.icon, required this.label});

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _solar(icon, const Color(0xFF89949B), 15),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF89949B),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _RoutePreview extends StatelessWidget {
  const _RoutePreview({required this.accepted});

  final bool accepted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      width: double.infinity,
      child: CustomPaint(
        painter: _RoutePreviewPainter(accepted: accepted),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: accepted
                  ? const Color(0xFF252E3A)
                  : const Color(0xFF19865C),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1A2730).withValues(alpha: 0.16),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              accepted ? tr.schedAcceptedBadge : tr.scheduled,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoutePreviewPainter extends CustomPainter {
  const _RoutePreviewPainter({required this.accepted});

  final bool accepted;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Movera map colours (MoveraMapPalette): near-white land, grey blocks,
    // a park with a path, water in the corner, grey streets and one darker
    // highway.
    canvas.drawRect(Offset.zero & size, Paint()..color = MoveraMapPalette.land);
    final blocks = Paint()..color = MoveraMapPalette.building;
    for (final block in [
      Rect.fromLTWH(w * 0.03, h * 0.42, w * 0.1, h * 0.18),
      Rect.fromLTWH(w * 0.42, h * 0.12, w * 0.1, h * 0.16),
      Rect.fromLTWH(w * 0.66, h * 0.6, w * 0.12, h * 0.2),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(block, const Radius.circular(2)),
        blocks,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.42, h * 0.56, w * 0.2, h * 0.5),
        const Radius.circular(10),
      ),
      Paint()..color = MoveraMapPalette.park,
    );
    canvas.drawLine(
      Offset(w * 0.45, h * 0.62),
      Offset(w * 0.6, h * 0.98),
      MoveraMapPalette.footpath(1.5),
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.86, -2)
        ..quadraticBezierTo(w * 0.9, h * 0.45, w + 2, h * 0.62)
        ..lineTo(w + 2, -2)
        ..close(),
      Paint()..color = MoveraMapPalette.water,
    );

    final street = MoveraMapPalette.street(3);
    canvas
      ..drawLine(Offset(w * 0.18, -5), Offset(w * 0.36, h + 5), street)
      ..drawLine(Offset(w * 0.72, -5), Offset(w * 0.58, h + 5), street)
      ..drawLine(
        Offset(-5, h * 0.72),
        Offset(w + 5, h * 0.88),
        MoveraMapPalette.mainStreet(3),
      );
    MoveraMapPalette.drawHighway(
      canvas,
      Path()
        ..moveTo(-10, h * 0.28)
        ..quadraticBezierTo(w * 0.28, h * 0.05, w * 0.58, h * 0.38)
        ..quadraticBezierTo(w * 0.78, h * 0.58, w + 12, h * 0.22),
      4,
    );

    final pickup = Offset(w * 0.19, h * 0.70);
    final dropoff = Offset(w * 0.82, h * 0.31);
    DriverRouteStyle.paintOn(
      canvas,
      Path()
        ..moveTo(pickup.dx, pickup.dy)
        ..cubicTo(w * 0.30, h * 0.22, w * 0.64, h * 0.82, dropoff.dx, dropoff.dy),
    );
    RouteMarkPins.paintMark(canvas, pickup, RouteMarkKind.pickup);
    RouteMarkPins.paintMark(canvas, dropoff, RouteMarkKind.dropoff);
  }

  @override
  bool shouldRepaint(covariant _RoutePreviewPainter oldDelegate) {
    return oldDelegate.accepted != accepted;
  }
}

class _ScheduledRide {
  const _ScheduledRide({
    required this.price,
    required this.time,
    required this.category,
    required this.distance,
    required this.pickup,
    required this.destination,
    this.accepted = false,
    this.assigned = false,
    this.route,
    this.window,
  });

  /// An accepted ride built from its route details.
  factory _ScheduledRide.fromRoute(
    ReservationRequestPreview route, {
    bool assigned = false,
  }) => _ScheduledRide(
    price: route.fare,
    time: tr.schedSeedTime(route.pickupDay, route.pickupTime),
    category: route.category,
    distance: driverDistanceKm(route.tripKm),
    pickup: route.pickupAddress,
    destination: route.dropoffAddress,
    accepted: true,
    assigned: assigned,
    route: route,
  );

  /// An open request: "Today, 07:40–07:45", its pickup [window].
  factory _ScheduledRide.request(
    ReservationRequestPreview route, {
    Duration window = const Duration(minutes: 5),
    String? distance,
  }) {
    return _ScheduledRide(
      price: route.fare,
      time: _timeOf(route, route.pickupDay, window),
      window: window,
      category: route.category,
      distance: distance ?? driverDistanceKm(route.tripKm),
      pickup: route.pickupAddress,
      destination: route.dropoffAddress,
      route: route,
    );
  }

  /// "Today, 07:40", with the pickup [window] when there is one:
  /// "Today, 07:40–07:45".
  static String _timeOf(
    ReservationRequestPreview route,
    String day,
    Duration? window,
  ) {
    final start = route.minuteOfDay;
    final time = tr.schedSeedTime(day, route.pickupTime);
    if (start == null || window == null) { return time; }
    final end = (start + window.inMinutes) % (24 * 60);
    String two(int v) => v.toString().padLeft(2, '0');
    return '$time–${two(end ~/ 60)}:${two(end % 60)}';
  }

  /// Movera assigned it to this driver (Q29).
  final bool assigned;

  final String price;

  /// The card's time as written when the ride was booked; see [when].
  final String time;

  /// The pickup window of an open request, else null.
  final Duration? window;

  /// The card's time seen now: a ride booked for a date says "Today"
  /// once its "Tomorrow" has come (driver-u142).
  String get when {
    final route = this.route;
    if (route?.scheduledAt == null) { return time; }
    final day = route!.pickupDayAt(ScheduledRideStore._now);
    return _timeOf(route, ReservationWhen.dayWord(day), window);
  }
  final String category;
  final String distance;
  final String pickup;
  final String destination;
  final bool accepted;

  /// Route details for the full route screen, when known.
  final ReservationRequestPreview? route;

  /// Dispatch id of an open reservation; empty for a sample ride.
  String get id => route?.id ?? '';

  _ScheduledRide copyWith({bool? accepted}) {
    return _ScheduledRide(
      price: price,
      time: time,
      category: category,
      distance: distance,
      pickup: pickup,
      destination: destination,
      accepted: accepted ?? this.accepted,
      assigned: assigned,
      route: route,
      window: window,
    );
  }
}

enum _ScheduledRideAction { accepted, cancelled, cancelledNotCounted }

class _ScheduledRideDetailsScreen extends StatelessWidget {
  const _ScheduledRideDetailsScreen({required this.ride});

  final _ScheduledRide ride;

  static const _ink = Color(0xFF252E3A);
  static const _muted = Color(0xFF7F8A91);
  static const _surface = Color(0xFFF3F5F6);
  static const _green = Color(0xFF19865C);
  static const _red = Color(0xFFC84E58);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: tr.back,
          onPressed: () => _popScheduledRoute<void>(context),
          icon: _solar(AppAssets.solarArrowLeft, _ink, 24),
        ),
        titleSpacing: 0,
        title: Text(
          ride.accepted && ride.id.isEmpty
              ? tr.schedSampleReservation
              : tr.schedReservationDetails,
          style: const TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                children: [
                  _buildHero(),
                  const SizedBox(height: 14),
                  _buildRouteMap(context),
                  const SizedBox(height: 14),
                  _buildRouteCard(),
                  const SizedBox(height: 14),
                  _buildPlanCard(),
                  if (ride.accepted) ...[
                    const SizedBox(height: 14),
                    _buildCommitmentCard(),
                  ],
                ],
              ),
            ),
            _buildBottomAction(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteMap(BuildContext context) {
    final route = ride.route;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 176 * MediaQuery.textScalerOf(context).scale(11) / 11,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _RoutePreviewPainter(accepted: ride.accepted)),
            Positioned(
              left: 14,
              right: 66,
              top: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1A2730).withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _solar(AppAssets.solarRoute, _green, 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        tr.schedIllustrativeRoute,
                        style: TextStyle(
                          color: _ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 14,
              top: 14,
              child: Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1A2730).withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: _solar(AppAssets.solarGps, _ink, 19),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 13,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF24333A).withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    Container(
                      height: 8,
                      width: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF35C487),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        ride.pickup,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _solar(
                        AppAssets.solarArrowRight,
                        const Color(0xFFB9C4C8),
                        14,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        ride.destination,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Container(
                      height: 8,
                      width: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDF5A62),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 14,
              bottom: 61,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${ride.distance} • ${ride.category}',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            // Tapping the map opens the same full route screen as the Home
            // reservation popup (notes R26).
            if (route != null)
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: Semantics(
                    label: tr.schedViewRoute,
                    button: true,
                    child: InkWell(
                      key: const ValueKey<String>('scheduled-route-open'),
                      onTap: () => openReservationRoute(context, route),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: ride.accepted
                                  ? const Color(0xFFE9F4EF)
                                  : const Color(0xFFF0F2F3),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _solar(
                                  ride.accepted
                                      ? AppAssets.solarCheckCircle
                                      : AppAssets.solarClockCircle,
                                  ride.accepted ? _green : _muted,
                                  15,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    ride.accepted
                                        ? tr.schedDemoAccepted
                                        : tr.schedAvailable,
                                    style: TextStyle(
                                      color: ride.accepted ? _green : _muted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          ride.price,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 31,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        if (ride.route?.fareBoost case final boost?)
                          OfferBadge.boost(boost),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      ride.when,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F3),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: _solar(AppAssets.solarCalendarMark, _green, 27),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFFE9ECEE)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _DetailMetric(
                  icon: AppAssets.solarCar,
                  label: tr.rideTypeLabel,
                  value: ride.category,
                ),
              ),
              Container(height: 34, width: 1, color: const Color(0xFFE5E9EB)),
              Expanded(
                child: _DetailMetric(
                  icon: AppAssets.solarRoute,
                  label: tr.trip2,
                  value: ride.distance,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr.route,
            style: TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    Container(
                      height: 14,
                      width: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _green, width: 3),
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 58,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8DEE1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    _solar(
                      AppAssets.solarMapPoint,
                      const Color(0xFFDF5A62),
                      19,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr.pickup,
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ride.pickup,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 27),
                    Text(
                      tr.dropOff,
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ride.destination,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF26343A),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ride.accepted ? tr.schedBeforeThisRide : tr.goodToKnow,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          _PlanRow(
            icon: AppAssets.solarAlarm,
            title: tr.schedBeReadyEarly,
            body: tr.schedGoOnlineMinBefore('${_onlineBefore()}'),
          ),
          const SizedBox(height: 15),
          _PlanRow(
            icon: AppAssets.solarRouting2,
            title: tr.schedTripsOnTheWay,
            body: ScheduledRideRules.current.towardPickupBeforeRide
                ? tr.schedOnlyTripsToward
                : tr.schedStillReceiveRides,
          ),
          const SizedBox(height: 15),
          _PlanRow(
            icon: AppAssets.solarCalendarMinimalistic,
            title: tr.schedPlansChanged,
            body: ride.accepted
                ? tr.schedDriversNeverPay(_freeCancelLine(ride.route))
                : tr.schedLocalPreviewCancel,
          ),
        ],
      ),
    );
  }

  /// Minutes to be online before pickup for this kind of ride (Q10 S4).
  int _onlineBefore() {
    final route = ride.route;
    final rules = ScheduledRideRules.current;
    return route == null
        ? rules.ruleFor(ScheduledRideKind.normal).onlineBeforeMinutes
        : SmartGap.ruleOf(route, rules).onlineBeforeMinutes;
  }

  Widget _buildCommitmentCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1E4CE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _solar(AppAssets.solarBellBing, const Color(0xFF9B6B24), 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr.schedReservedForYou,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  tr.schedKeepInAccepted,
                  style: TextStyle(
                    color: Color(0xFF6F777C),
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: const Color(0xFFE8EBED).withValues(alpha: 0.9),
          ),
        ),
      ),
      child: ride.accepted
          ? SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _showCancelReasons(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  foregroundColor: _red,
                  side: const BorderSide(color: Color(0xFFE7C6C9)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                child: Text(
                  tr.schedCancelReservation,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            )
          : SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    _popScheduledRoute(context, _ScheduledRideAction.accepted),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: _ink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                child: Text(
                  tr.schedAcceptPrice(ride.price),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _showCancelReasons(BuildContext context) async {
    if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final reason = await showModalBottomSheet<CancelReason>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _CancelReasonSheet(ride: ride.route),
    );

    if (reason == null ||
        !context.mounted ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) =>
          _CancelConfirmationSheet(reason: reason, ride: ride.route),
    );

    if (confirmed == true && context.mounted) {
      _popScheduledRoute(
        context,
        reason.counts
            ? _ScheduledRideAction.cancelled
            : _ScheduledRideAction.cancelledNotCounted,
      );
    }
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F3),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: _solar(icon, const Color(0xFF19865C), 18),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF8A959B),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF252E3A),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.icon, required this.title, required this.body});

  final String icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(13),
          ),
          alignment: Alignment.center,
          child: _solar(icon, Colors.white, 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontSize: 11,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CancelReasonSheet extends StatefulWidget {
  const _CancelReasonSheet({this.ride});

  /// The ride being cancelled, for its free-cancel time.
  final ReservationRequestPreview? ride;

  @override
  State<_CancelReasonSheet> createState() => _CancelReasonSheetState();
}

class _CancelReasonSheetState extends State<_CancelReasonSheet> {
  CancelReason? _selected;

  /// Q21: from the admin's list for this country and language.
  List<CancelReason> get _reasons =>
      CancelReasons.current.of(CancelReasonGroup.scheduled);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.84,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFF7F8F8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                height: 4,
                width: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFD3D8DB),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 14, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr.whyAreYouCancellingQuestion,
                            style: TextStyle(
                              color: Color(0xFF252E3A),
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            tr.chooseBestReason,
                            style: TextStyle(
                              color: Color(0xFF7D888E),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: tr.close,
                      onPressed: () => _popScheduledRoute<void>(context),
                      icon: const Icon(Icons.close_rounded),
                      color: const Color(0xFF39444A),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: _CancelRulesBox(ride: widget.ride),
              ),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                itemCount: _reasons.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final reason = _reasons[index];
                  final selected = reason == _selected;
                  return Material(
                    color: selected ? Colors.white : const Color(0xFFF0F2F3),
                    borderRadius: BorderRadius.circular(17),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(17),
                      onTap: () => setState(() => _selected = reason),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF8AB7A3)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              height: 22,
                              width: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected
                                    ? const Color(0xFF19865C)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFF19865C)
                                      : const Color(0xFFAFB8BD),
                                  width: 1.5,
                                ),
                              ),
                              child: selected
                                  ? const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 15,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    reason.title,
                                    style: TextStyle(
                                      color: const Color(0xFF303B42),
                                      fontSize: 13,
                                      fontWeight: selected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                    ),
                                  ),
                                  if (!reason.counts) const _NotCountedTag(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                color: Colors.white,
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _selected == null
                        ? null
                        : () => _popScheduledRoute(context, _selected),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF252E3A),
                      disabledBackgroundColor: const Color(0xFFDCE1E3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    child: Text(
                      tr.navContinue,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CancelConfirmationSheet extends StatelessWidget {
  const _CancelConfirmationSheet({required this.reason, this.ride});

  final CancelReason reason;
  final ReservationRequestPreview? ride;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  height: 4,
                  width: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD3D8DB),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDEF),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.event_busy_rounded,
                  color: Color(0xFFC84E58),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                tr.schedCancelThisReservation,
                style: TextStyle(
                  color: Color(0xFF252E3A),
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                reason.title,
                style: const TextStyle(
                  color: Color(0xFF59656C),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!reason.counts) ...[
                const SizedBox(height: 12),
                Text(
                  tr.schedReasonDoesntCount,
                  key: ValueKey<String>('scheduled-cancel-not-counted'),
                  style: TextStyle(
                    color: Color(0xFF19865C),
                    fontSize: 12.5,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ] else if (ScheduledRideStore.isLateCancel(ride)) ...[
                const SizedBox(height: 12),
                _LateCancelWarning(ride: ride),
              ],
              const SizedBox(height: 8),
              Text(
                tr.schedRemovesSample,
                style: TextStyle(
                  color: Color(0xFF7D888E),
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _popScheduledRoute(context, true),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: const Color(0xFF252E3A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  child: Text(
                    tr.schedCancelReservation,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 9),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => _popScheduledRoute(context, false),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(
                    tr.schedKeepReservation,
                    style: TextStyle(
                      color: Color(0xFF354047),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:movera/core/zones/zone_clock.dart';
import 'package:movera/widgets/movera_dialog_theme.dart';
import 'package:movera/core/location/driver_start_position.dart';

import 'package:movera/core/contracts/category_name_text.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/dispatch/pickup_pay.dart';
import 'package:movera/core/notifications/driver_notifications.dart';
import 'package:movera/core/ride/cancel_reasons.dart';
import 'package:movera/core/scheduled/reservation_when.dart';
import 'package:movera/core/live/live_reservations.dart';
import 'package:movera/core/scheduled/server_reservations.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';
import 'package:movera/core/scheduled/scheduled_ride_rules.dart';
import 'package:movera/core/scheduled/smart_gap.dart';
import 'package:movera/core/vehicle/ride_categories.dart';
import 'package:movera/presentation/driver/home/components/home_island_notices.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/components/reservation_route_map.dart';
import 'package:movera/core/routing/road_route_service.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
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
part 'scheduled_rides_cards.dart';
part 'scheduled_rides_details.dart';
part 'scheduled_rides_cancel.dart';
part 'scheduled_rides_keep.dart';

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

  late final Listenable _store = Listenable.merge([
    ScheduledRideStore._revision,
    ScheduledRideStore.reminder,
    ScheduledRideStore.backupNote,
  ]);

  @override
  void initState() {
    super.initState();
    _store.addListener(_storeChanged);
    // Contract v0.18.17 Book later: on live the lists are the server's.
    if (LiveDriverServices.instance?.reservations case final live?) {
      ScheduledRideStore.keepQuestions.addListener(_askToKeep);
      unawaited(ScheduledRideStore.syncFromServer(live));
    }
  }

  bool _asking = false;

  /// Owner BL-Q6: "Keep it at the new time?" Yes keeps it; No gives it back.
  Future<void> _askToKeep() async {
    final live = LiveDriverServices.instance?.reservations;
    final asks = ScheduledRideStore.keepQuestions.value;
    if (live == null || asks.isEmpty || _asking || !mounted) return;
    _asking = true;
    final ride = asks.first;
    final keep = await askKeepAtNewTime(context, ride);
    _asking = false;
    if (keep == null || !mounted) return;
    final refused = await live.keep(ride.tripId, keep: keep);
    await ScheduledRideStore.syncFromServer(live);
    if (!mounted) return;
    _notice(
      refused == null
          ? (keep
                ? tr.schedKeptAt(ServerReservation.clockOf(ride.scheduledAt))
                : tr.schedGaveBack)
          : refused == ReservationRefusal.network
          ? tr.islandNoConnection
          : tr.islandNoLongerAvailable,
    );
  }

  /// Owner BL-Q4: the driver's home area is where the phone is now.
  Future<void> _setHomeArea() async {
    final services = LiveDriverServices.instance;
    if (services == null) return;
    // Live test MED 5: offline the reporter has no fix yet; the saved or
    // platform position is used then, so the home area still saves.
    final point = await ScheduledRideStore.homeAreaPoint(
      services.reporter.lastKnownPoint,
    );
    if (!mounted) return;
    if (point == null) {
      _notice(tr.schedHomeAreaNoFix);
      return;
    }
    final saved = await services.reservations.setHomeArea(
      point.latitude,
      point.longitude,
    );
    if (mounted) _notice(saved ? tr.schedHomeAreaSaved : tr.islandNoConnection);
  }

  void _storeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _store.removeListener(_storeChanged);
    ScheduledRideStore.keepQuestions.removeListener(_askToKeep);
    super.dispose();
  }

  /// Requests this driver can take: clashing ones and every request while
  /// Scheduled rides are paused or off are left out.
  List<_ScheduledRide> get _requests => ScheduledRideStore._visibleRequests;
  List<_ScheduledRide> get _accepted => ScheduledRideStore._acceptedByPickup;

  /// No listed request is picked up on a later day (driver-u162): the
  /// header says "Available today" only then.
  bool get _requestsAllToday {
    final now = ScheduledRideStore._now;
    return _requests.every((ride) {
      final at = ride.route?.pickupAt(now);
      return at == null || DateUtils.isSameDay(at, now);
    });
  }

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
          body: tr.schedClashBody(clashing.first.$2.route?.pickupTime ?? ''),
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
              itemCount: (rides.isEmpty ? 1 : rides.length) + notes.length + 1,
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
                            _selectedTab == 1
                                ? tr.schedUpcoming
                                : _requestsAllToday
                                ? tr.schedAvailableToday
                                : tr.schedAvailable,
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
                if (rides.isEmpty) {
                  // Nothing to show is said, not left blank (audit R1).
                  return Padding(
                    key: const ValueKey<String>('scheduled-rides-empty'),
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    // Owner: the same empty-state look as the Radar list.
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.event_available_rounded,
                          key: ValueKey<String>('scheduled-rides-empty-icon'),
                          color: Color(0xFF6F7B82),
                          size: 30,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          tr.schedNoneYet,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF6F7B82),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final ride = rides[index - 1];
                final claiming = ScheduledRideStore.claimPending(ride.id);
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
                if (!LiveDriverServices.active)
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
    final session = ScheduledRideStore._session;
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
      // W1 (2026-11-07): the server's list may have been read again while
      // the details were open (new row objects): the same booking by id.
      // Not across a session reset (another driver's list).
      if (session == ScheduledRideStore._session) {
        ride = ScheduledRideStore._sameRequest(ride) ?? ride;
      }
      // The request may have been answered on Home, or replaced by a new
      // session while this details route was open. Only its current owner can act.
      if (!_requests.contains(ride)) {
        // Its pickup time passed while the details were open (driver-u164).
        if (ScheduledRideStore._pickupPassed(ride)) {
          _notice(tr.islandNoLongerAvailable);
        }
        return;
      }
      if (!await _claim(ride)) return;
      // Dispatch gave it to this driver: it moves to Accepted even when
      // the driver left this screen during the claim (driver-94).
      // Requests whose time now clashes leave the list (Q9); the Requests
      // tab says why.
      if (!ScheduledRideStore._acceptRequest(ride, won: true)) return;
      // Only saved for later: it becomes the trip at its time ("Leave now"
      // by the real clock), never right after Accept.
      final time = ride.route?.pickupTime;
      if (time != null) {
        IslandMessages.show(HomeIslandNotices.reservationAcceptedAt(time));
      }
      if (!mounted) return;
      setState(() => _selectedTab = 1);
      _notice(
        time == null
            ? tr.islandReservationAccepted
            : tr.schedAcceptedPickupAt(time),
      );
    } else if (action == _ScheduledRideAction.cancelled) {
      if (!_accepted.contains(ride)) return;
      // Checker M2: on live the server takes it back first; failed, the ride stays and the driver is told.
      if (LiveDriverServices.instance?.reservations case final live?
          when ride.id.isNotEmpty) {
        final given = await live.release(
          ride.id,
          reasonCode: giveBackReasonCode(ScheduledRideStore.lastGiveBackReason),
        );
        ScheduledRideStore.lastGiveBackReason = null;
        if (!given) {
          if (mounted) _notice(tr.schedGiveBackFailed);
          return;
        }
      }
      final paused = ScheduledRideStore._cancelAccepted(ride, counts: true);
      // Q31, N3: the pause is in Notifications and on the island.
      if (paused) {
        final until = ScheduledRideStore.pausedUntil(ScheduledRideStore._now);
        final feed = DriverNotificationFeed.instance;
        feed.add(
          DriverNotices.scheduledPaused(
            feed.now,
            until: () => until == null ? tr.laterLower : _dayMonth(until),
          ),
        );
      }
      // An open reservation goes back out to drivers (notes R24): where it
      // goes follows the admin rule, Radar trips too close to pickup.
      if (LiveDriverServices.active && ride.id.isNotEmpty) {
        // Contract v0.18.17: already taken back by the server above.
      } else if (ride.id.isNotEmpty && !ride.assigned) {
        widget.dispatchRepository?.releaseReservation(ride.id);
      }
      _notice(tr.schedReservationCancelled);
    }
  }

  /// Asks the server for [ride] when it is an open reservation. True when
  /// this driver got it (or there is no server to ask); lost, it leaves
  /// the list and the driver is told it is no longer available. The
  /// answer applies even after this screen closed (driver-94).
  Future<bool> _claim(_ScheduledRide ride) async {
    // Contract v0.18.17: on live the server gives a booked ride to the
    // first driver who taps Accept (`POST /driver/reservations/{id}/accept`).
    if (LiveDriverServices.instance?.reservations case final live?
        when ride.id.isNotEmpty) {
      return _claimOnServer(live, ride);
    }
    final dispatch = widget.dispatchRepository;
    if (dispatch == null || ride.id.isEmpty) return true;
    if (!ScheduledRideStore.beginClaim(ride.id)) return false;
    ClaimResult result;
    try {
      result = await dispatch.claimOffer(ride.id);
    } catch (_) {
      result = const ClaimResult.networkError();
    }
    ScheduledRideStore.endClaim(ride.id);
    switch (result.outcome) {
      case ClaimOutcome.success:
        return true;
      case ClaimOutcome.networkError:
        if (mounted) _notice(tr.islandNoConnection);
        return false;
      case ClaimOutcome.alreadyClaimed:
      case ClaimOutcome.expired:
      case ClaimOutcome.unavailable:
        ScheduledRideStore.take(ride.id);
        if (mounted) _notice(tr.islandNoLongerAvailable);
        return false;
    }
  }

  Future<bool> _claimOnServer(
    LiveReservations live,
    _ScheduledRide ride,
  ) async {
    if (!ScheduledRideStore.beginClaim(ride.id)) return false;
    // Checker M1: the version this driver saw; the server refuses a ride that changed since.
    final refused = await live.accept(
      ride.id,
      version: ScheduledRideStore.serverRow(ride.id)?.version,
    );
    ScheduledRideStore.endClaim(ride.id);
    if (refused == null) return true;
    if (refused == ReservationRefusal.network) {
      if (mounted) _notice(tr.islandNoConnection);
      return false;
    }
    if (refused == ReservationRefusal.changed) {
      // The rider changed it: show the new time and price, the driver decides again.
      await ScheduledRideStore.syncFromServer(live);
      final now = ScheduledRideStore.serverRow(ride.id);
      if (mounted) {
        _notice(
          now == null
              ? tr.islandNoLongerAvailable
              : tr.schedRideChanged(
                  ServerReservation.clockOf(now.scheduledAt),
                  now.earnings.formatted,
                ),
        );
      }
      return false;
    }
    ScheduledRideStore.take(ride.id);
    if (mounted) {
      _notice(
        refused == ReservationRefusal.clash
            ? tr.schedServerClash
            : tr.islandNoLongerAvailable,
      );
    }
    unawaited(ScheduledRideStore.syncFromServer(live));
    return false;
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
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
          if (LiveDriverServices.active)
            IconButton(
              tooltip: tr.schedHomeArea,
              onPressed: _setHomeArea,
              icon: const Icon(Icons.home_outlined, color: Color(0xFF425058)),
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
          children: [
            _tabButton(0, tr.schedRequestsTab),
            _tabButton(1, tr.schedAcceptedTab),
          ],
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

/// A note in Scheduled rides, kept as how to write it so it reads in the
/// driver's language whenever it is shown (driver-u145). [value] is the
/// text now; setting it keeps a fixed text (or none).
class DriverNote extends ChangeNotifier implements ValueListenable<String?> {
  String Function()? _text;
  DateTime? _until;

  /// The note, or null once its [say] `until` has passed (scheduled time).
  @override
  String? get value {
    final until = _until;
    if (until != null && !ScheduledClock.instance.now().isBefore(until)) {
      return null;
    }
    return _text?.call();
  }

  set value(String? text) {
    if (text == null && _text == null) return;
    _text = text == null ? null : () => text;
    _until = null;
    notifyListeners();
  }

  /// The note is now [text], read each time it is shown; it is gone from
  /// [until] on when given.
  void say(String Function() text, {DateTime? until}) {
    _text = text;
    _until = until;
    notifyListeners();
  }
}

/// Reservation requests for this app session. Decisions stay while the app
/// runs, so the green dot on Home follows what is still unanswered.
class ScheduledRideStore {
  const ScheduledRideStore._();

  static final List<_ScheduledRide> _requests = _seedRequests();
  // Audit Phase 1 R1 (S2): a live build shows no sample reservations;
  // the server has no driver reservations to list yet.
  static List<_ScheduledRide> _seedRequests() => LiveDriverServices.active
      ? []
      : [
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
  static List<_ScheduledRide> _seedAccepted() {
    if (LiveDriverServices.active) return [];
    final route = ReservationRequestPreview(
      category: 'Comfort',
      fare: '184,00 kr',
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
    ).scheduledFor(_tomorrowAt(8, 15));
    return [
      _ScheduledRide(
        // The driver's share of the fare (owner decision 2026-10-26).
        price: route.driverPayLabel,
        time: tr.schedSeedTime(tr.tomorrow, '08:15'),
        category: 'Comfort',
        pickup: 'Södermalm, Stockholm',
        destination: 'Bromma Airport',
        accepted: true,
        route: route,
      ),
    ];
  }

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

  /// The zone's reservations switch, for every driver (owner decision 2).
  /// Home sets it from the admin config.
  static bool get zoneEnabled => _zoneEnabled;
  static bool _zoneEnabled = true;

  /// Home takes admin's switches from [config]: the zone's and this
  /// driver's.
  static void applyAdmin(ScheduledRidesAdminConfig config) {
    if (identical(_driverAccess, config.driverAccess) &&
        _zoneEnabled == config.enabled) {
      return;
    }
    _driverAccess = config.driverAccess;
    _zoneEnabled = config.enabled;
    _changed();
  }

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

  /// Why this driver gets no new scheduled rides right now, or null
  /// (owner decision 2): reservations off for the zone, off for this
  /// driver, or paused by late cancels. Admin "on" for this driver skips
  /// the pause while it lasts. Accepted rides are never affected.
  static ScheduledRidesBlock? block() {
    final now = _now;
    if (!_zoneEnabled || !_rules.enabled) {
      return const ScheduledRidesBlock(byAdmin: true, zoneOff: true);
    }
    if (_driverAccess.offAt(now)) {
      return ScheduledRidesBlock(byAdmin: true, until: _driverAccess.until);
    }
    if (_driverAccess.onAt(now)) return null;
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
      ride?.pickupAt(_now)?.subtract(_rules.driverLateCancel);

  /// [ride] clashes with an accepted ride: the accepted one, else null.
  static _ScheduledRide? _clashWith(_ScheduledRide ride) {
    final route = ride.route;
    if (route == null || !_rules.removeClashing) {
      return null;
    }
    final now = _now;
    for (final taken in [..._accepted, ?_driving]) {
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
            .where(
              (ride) =>
                  !_pickupPassed(ride) &&
                  DriverCategoryChoice.takes(ride.category) &&
                  _clashWith(ride) == null,
            )
            .toList();

  /// The open request now shown for [ride]: the same row, or the row
  /// of the same booking after the server's list was read again.
  static _ScheduledRide? _sameRequest(_ScheduledRide ride) {
    for (final open in _visibleRequests) {
      if (identical(open, ride) || (ride.id.isNotEmpty && open.id == ride.id)) {
        return open;
      }
    }
    return null;
  }

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
      if (at != null &&
          at.isAfter(now) &&
          (next == null || at.isBefore(next))) {
        next = at;
      }
    }
    return next;
  }

  /// When the requests' block ends or admin's "on" stops skipping the
  /// late-cancel pause, by time alone; Home refreshes then
  /// (driver-r3-9). Null when nothing ends.
  static DateTime? accessChangeAt() {
    final now = _now;
    final ends = [
      block()?.until,
      if (_driverAccess.onAt(now)) _driverAccess.until,
    ].whereType<DateTime>().where((at) => at.isAfter(now));
    return ends.isEmpty ? null : ends.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  /// Counts the open requests again: a pickup time passed.
  static void refresh() => _changed();

  /// The driver's categories changed (Q27).
  static void categoriesChanged() => _changed();

  /// Requests left out because they clash with an accepted ride; one in
  /// a category the driver does not take is left out anyway (driver-u165).
  static List<(_ScheduledRide, _ScheduledRide)> get _clashing => [
    for (final ride in _requests)
      if (!_pickupPassed(ride) && DriverCategoryChoice.takes(ride.category))
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
    if (_reminderRide case final ride?
        when !_accepted.any((item) => identical(item.route, ride))) {
      _reminderRide = null;
      reminder.value = null;
    }
    openRequests.value = _visibleRequests.length;
    _revision.value++;
  }

  /// Contract v0.18.17 Book later: the open and accepted lists become the
  /// server's (`GET /driver/reservations`). A claim still out keeps its
  /// row. A failed read keeps what is shown.
  static Future<void> syncFromServer(LiveReservations live) async {
    final ServerReservations page;
    try {
      page = await live.load();
    } catch (_) {
      return;
    }
    ReservationRequestPreview preview(ServerReservation r) => r.toPreview(
      dayWord: (at) => _dayWordOf(at, _now),
      pickupLabel: (time) =>
          tr.schedSeedTime(_dayWordOf(r.scheduledAt, _now), time),
    );
    final claiming = _requests
        .where((ride) => _claims.contains(ride.id))
        .toList();
    _requests
      ..clear()
      ..addAll(claiming)
      ..addAll([
        for (final r in page.open)
          if (!claiming.any((ride) => ride.id == r.tripId))
            _ScheduledRide.request(preview(r)),
      ]);
    _accepted
      ..clear()
      ..addAll([
        for (final r in page.accepted) _ScheduledRide.fromRoute(preview(r)),
      ]);
    // Owner BL-Q6: the rider changed a ride this driver holds.
    keepQuestions.value = [
      for (final r in page.accepted)
        if (r.asksToKeep) r,
    ];
    _serverRows
      ..clear()
      ..addAll({
        for (final r in [...page.open, ...page.accepted]) r.tripId: r,
      });
    _changed();
  }

  /// Live test MED 5: where "Set home area here" is. The live fix while
  /// online, else the phone's saved or last known position.
  static Future<GeoPoint?> homeAreaPoint(
    GeoPoint? live, {
    Future<GeoPoint?> Function()? fallback,
  }) async {
    if (live != null && live.isValid) return live;
    try {
      return await (fallback ?? DriverStartPosition.load)();
    } catch (_) {
      return null;
    }
  }

  /// The server's rows by trip id (the version an Accept sends).
  static final Map<String, ServerReservation> _serverRows = {};
  static ServerReservation? serverRow(String id) => _serverRows[id];

  /// Booked rides whose rider changed the time: "Keep it at the new time?".
  static final ValueNotifier<List<ServerReservation>> keepQuestions =
      ValueNotifier(const []);

  /// The reason the driver picked when giving a ride back (sent to the server).
  static String? lastGiveBackReason;

  /// "Today", "Tomorrow" or "5 Nov" for a pickup at [at].
  static String _dayWordOf(DateTime at, DateTime now) {
    // Job 3 / L18: both on the zone's clock, never the phone's.
    final local = zoneWallTime(at);
    now = zoneWallTime(now);
    final days = DateTime.utc(
      local.year,
      local.month,
      local.day,
    ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
    if (days == 0) return tr.today;
    if (days == 1) return tr.tomorrow;
    return '${local.day}/${local.month}';
  }

  /// The ride of reservation [id], open or accepted; null when unknown.
  static ReservationRequestPreview? routeOf(String id) {
    if (id.isEmpty) return null;
    for (final ride in [..._requests, ..._accepted]) {
      if (ride.id == id) return ride.route;
    }
    return null;
  }

  /// driver-r5-45: reservations whose claim is with dispatch, from this
  /// screen or Home's popup. Kept here, not in one screen's State, so a
  /// reopened screen shows "Matching" and no second Accept sends a
  /// duplicate claim.
  static final Set<String> _claims = <String>{};

  static bool claimPending(String id) => id.isNotEmpty && _claims.contains(id);

  /// False when a claim for [id] is already out.
  static bool beginClaim(String id) {
    if (id.isEmpty || !_claims.add(id)) return false;
    _changed();
    return true;
  }

  static void endClaim(String id) {
    if (_claims.remove(id)) _changed();
  }

  /// Whether reservation [id] is still open to take here.
  static bool isOpen(String id) =>
      id.isNotEmpty && _visibleRequests.any((ride) => ride.id == id);

  /// Reservation [id] was taken. By this driver for later ([upcoming]) it
  /// moves to Accepted; taken now (an Exclusive or Radar trip) or by
  /// another driver it only leaves the requests (notes R23).
  static void take(String id, {bool upcoming = false, Money? pickupPay}) {
    final index = _requests.indexWhere((ride) => ride.id == id);
    if (id.isEmpty || index < 0) {
      return;
    }
    final ride = _requests.removeAt(index);
    if (upcoming) {
      _keepPickupPay(id, pickupPay);
      _accepted.insert(
        0,
        ride.copyWith(accepted: true, price: _withPay(ride.price, pickupPay)),
      );
    }
    _changed();
  }

  /// driver-r5-12: the pickup pay an Exclusive card showed for a ride its
  /// Accept only saved for later (an assigned ride, a reservation won
  /// before its Exclusive step), by ride id. "Leave now" opens the trip
  /// with it, as the card promised.
  static final Map<String, Money> _pickupPays = <String, Money>{};

  /// The pickup pay accepted with ride [id]; null for none.
  static Money? acceptedPickupPay(String id) => _pickupPays[id];

  static void _keepPickupPay(String id, Money? pay) {
    if (id.isEmpty) return;
    if (pay == null || pay.minorUnits <= 0) {
      _pickupPays.remove(id);
    } else {
      _pickupPays[id] = pay;
    }
  }

  /// [price] with [pay] in it, as the card showed one total.
  static String _withPay(String price, Money? pay) => pay == null
      ? price
      : PickupPayQuote(
          pay: pay,
          leg: const PickupLeg(km: 0, minutes: 0),
        ).totalOf(price);

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
      _keepPickupPay(ride.id, null);
      _accepted.insert(0, ride.copyWith(accepted: true));
    }
    _changed();
  }

  /// This driver took open request [ride] for later: it moves to
  /// Accepted. False when it is no longer among the requests, unless
  /// dispatch [won] it for this driver: a late "unavailable" for a
  /// duplicate claim may have taken it out meanwhile (driver-r5-45).
  static bool _acceptRequest(_ScheduledRide ride, {bool won = false}) {
    if (!_requests.remove(ride) &&
        (!won ||
            ride.id.isEmpty ||
            _accepted.any((item) => item.id == ride.id))) {
      return false;
    }
    _accepted.insert(0, ride.copyWith(accepted: true));
    _changed();
    return true;
  }

  /// Q29: the driver accepted a ride Movera assigned to them.
  static void acceptAssigned(
    ReservationRequestPreview ride, {
    Money? pickupPay,
  }) {
    if (_accepted.any((item) => identical(item.route, ride))) {
      return;
    }
    _keepPickupPay(ride.id, pickupPay);
    final kept = _ScheduledRide.fromRoute(ride, assigned: true);
    _accepted.insert(0, kept.copyWith(price: _withPay(kept.price, pickupPay)));
    _changed();
  }

  /// Accepted rides with a known pickup time, soonest first.
  /// driver-r5-49: Accepted as the tab lists it under "Upcoming": by
  /// pickup time, rides without one last, newest acceptance first on a tie.
  static List<_ScheduledRide> get _acceptedByPickup {
    final now = _now;
    final order = [for (var i = 0; i < _accepted.length; i++) i];
    DateTime? at(int i) => _accepted[i].route?.pickupAt(now);
    order.sort((a, b) {
      final x = at(a), y = at(b);
      if (x == null || y == null) {
        return x == y ? a - b : (x == null ? 1 : -1);
      }
      final by = x.compareTo(y);
      return by != 0 ? by : a - b;
    });
    return [for (final i in order) _accepted[i]];
  }

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
  /// Accepted. False when it was not there. It still counts in the clash
  /// check while it is driven (driver-r5-42).
  static bool start(ReservationRequestPreview ride) {
    if (!_accepted.any((item) => identical(item.route, ride))) {
      return false;
    }
    // Its pickup fixed to the time it had: a "Today" ride must not move
    // to the next day.
    final at = ride.pickupAt(_now);
    _driving = _ScheduledRide.fromRoute(
      at == null ? ride : ride.scheduledFor(at),
    );
    return _removeAccepted(ride) != null;
  }

  /// The scheduled ride "Leave now" started: requests that clash with it
  /// stay hidden (contract §6.1 hideClashing), as when it was Accepted.
  /// Its time is fixed, so once it is over it clashes with nothing.
  static _ScheduledRide? _driving;

  /// The driver was not on the way in time: [ride] went to a backup
  /// driver (Q10 S3).
  static void giveToBackup(ReservationRequestPreview ride) {
    if (_removeAccepted(ride) == null) {
      return;
    }
    _backupLate = false;
    backupNote.say(
      () => tr.schedBackupNote(ride.pickupTime),
      until: _backupNoteEnds(ride.pickupAt(_now)),
    );
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
    final pickupAt = routeOf(id)?.pickupAt(_now);
    if (id.isNotEmpty) {
      _accepted.removeWhere((ride) => ride.id == id);
    }
    reassigned.add(
      ScheduledReassignment(
        id: id,
        pickupTime: pickupTime,
        lateMinutes: lateMinutes,
        reassignTo: reassignTo,
        at: _now,
      ),
    );
    DriverLog.info(
      'Scheduled ride ${id.isEmpty ? pickupTime : id} reassigned '
      '(late ETA, $lateMinutes min late) to ${reassignTo.name}',
      name: 'movera.scheduled',
    );
    _backupLate = true;
    backupNote.say(
      () => tr.lateEtaReassignedNote(pickupTime, lateMinutes),
      until: _backupNoteEnds(pickupAt),
    );
    _changed();
  }

  /// driver-r5-47: how long the backup / late-ETA note stays: until
  /// [backupNoteLasts] past that ride's pickup (or past now without one),
  /// not for the rest of the session above later rides at the same time.
  static const Duration backupNoteLasts = Duration(hours: 2);
  static DateTime _backupNoteEnds(DateTime? pickupAt) {
    final now = _now;
    final from = pickupAt != null && pickupAt.isAfter(now) ? pickupAt : now;
    return from.add(backupNoteLasts);
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
  static final DriverNote reminder = DriverNote();

  /// The ride [reminder] is about; when it leaves Accepted (cancelled by
  /// the driver or the rider, reassigned) the reminder goes (driver-u166).
  static ReservationRequestPreview? _reminderRide;

  /// Shows [text] as the reminder for accepted [ride], read each time it is
  /// shown so it follows the driver's language.
  static void remind(ReservationRequestPreview ride, String Function() text) {
    _reminderRide = ride;
    reminder.say(text);
  }

  /// Set when a ride went to a backup driver.
  static final DriverNote backupNote = DriverNote();

  /// R15-7: the rider cancelled reservation [id], which this driver had
  /// accepted. It leaves Accepted and the island says so, with the
  /// driver's cancel [fee] from the backend ("+105 kr", "no fee"; nothing
  /// while not decided). False when no accepted ride has that id.
  static bool riderCancelled(String id, {Money? fee}) {
    final index = _accepted.indexWhere(
      (ride) => ride.id == id && id.isNotEmpty,
    );
    if (index < 0) {
      return false;
    }
    final ride = _accepted.removeAt(index);
    IslandMessages.show(
      HomeIslandNotices.reservationCancelled(
        ride.route?.pickupTime ?? ride.time,
        fee,
      ),
    );
    _changed();
    return true;
  }

  /// The driver cancelled [ride], which they had accepted. A late cancel is
  /// counted (drivers never pay); L-c: every give-back counts, whatever the
  /// reason. True when it paused Scheduled rides.
  static bool _cancelAccepted(_ScheduledRide ride, {bool counts = true}) {
    final late = counts && isLateCancel(ride.route);
    if (!_accepted.remove(ride)) {
      return false;
    }
    final wasPaused = _pauseInForce(_now);
    if (late) {
      _recordLateCancel(_now);
    }
    // An open reservation goes back out to drivers (notes R24).
    if (ride.id.isNotEmpty && !ride.assigned) {
      _requests.insert(0, ride.copyWith(accepted: false));
    }
    _changed();
    return !wasPaused && _pauseInForce(_now);
  }

  /// The late-cancel pause holds back rides at [now], as [block] sees
  /// it: never while admin has Scheduled rides on for this driver
  /// (driver-r5-41).
  static bool _pauseInForce(DateTime now) =>
      !_driverAccess.onAt(now) && pausedUntil(now) != null;

  /// Back to a fresh session: logout calls it, so the previous driver's
  /// accepted rides, late cancels and pause, reminder and backup note do
  /// not carry over to the next driver on the device (driver-u167).
  /// L-a Q7 (owner 2026-11-06): at sign-in the list holds no ride yet; no
  /// demo seed and no earlier driver's ride stays. The server's read
  /// ([syncFromServer]) fills it.
  static void clearRides() {
    _requests.clear();
    _accepted.clear();
    _serverRows.clear();
    _claims.clear();
    keepQuestions.value = const [];
    _changed();
  }

  /// W1: counts [reset]s, so a details screen opened before one does not
  /// act on the new session's list.
  static int _session = 0;

  static void reset() {
    _session++;
    _requests
      ..clear()
      ..addAll(_seedRequests());
    _accepted
      ..clear()
      ..addAll(_seedAccepted());
    _driverAccess = const ScheduledRidesDriverAccess();
    _zoneEnabled = true;
    _lateCancels.clear();
    _pauseUntil = null;
    _driving = null;
    _pickupPays.clear();
    reminder.value = null;
    _reminderRide = null;
    backupNote.value = null;
    reassigned.clear();
    _backupLate = false;
    _claims.clear();
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
  const ScheduledRidesBlock({
    this.byAdmin = false,
    this.zoneOff = false,
    this.until,
  });

  /// Admin turned them off for this driver ([zoneOff]: for every driver
  /// in the zone); otherwise too many late cancels paused them.
  final bool byAdmin;
  final bool zoneOff;

  /// Back on at this time; null until admin turns them on.
  final DateTime? until;
}

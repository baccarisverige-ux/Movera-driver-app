import 'package:movera/core/l10n/driver_l10n.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:movera/core/dispatch/trip_occurrence.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/core/geo/geo_point_maps.dart';
import 'package:movera/core/dispatch/demo_dispatch_repository.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/dispatch/pickup_pay.dart';
import 'package:movera/core/admin/pickup_pay_config.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/overlays/trip_status_banner.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:movera/widgets/led_count_badge.dart';
import 'package:movera/widgets/movera_radar_orb.dart';
import 'package:movera/widgets/radar_offer_card.dart';
import 'package:movera/widgets/navigation_transition.dart';

class RideRequests extends StatefulWidget {
  final ValueChanged<bool>? onCloseRides;
  final bool destinationModeActive;
  final String? destinationAddress;
  final LatLng? destinationPosition;
  final DriverSessionController? sessionController;
  final WaybillRepository? waybillRepository;
  final DriverLocationRepository? locationRepository;
  final RouteRepository? routeRepository;
  final DispatchRepository? dispatchRepository;
  final ActiveRideRepository? activeRideRepository;

  /// Trips this driver gets now: before an accepted scheduled ride only
  /// the ones that leave time for it and head toward its pickup; with
  /// cash rides off, no cash trips.
  final bool Function(RideOffer offer)? offerFilter;

  /// R13-9: Home's on-the-way filter in Destination mode; without it the
  /// offer's own flag.
  final bool Function(RideOffer offer)? followsDestination;

  /// That ride's pickup time, e.g. "07:40", while trips head toward it.
  final String? towardPickupTime;

  /// True while a Match is being sent or its won trip is opening: Home's
  /// Back then keeps Radar open, so the claim's answer is not lost.
  final ValueNotifier<bool>? claimPending;

  const RideRequests({
    super.key,
    this.onCloseRides,
    this.destinationModeActive = false,
    this.destinationAddress,
    this.destinationPosition,
    this.sessionController,
    this.waybillRepository,
    this.locationRepository,
    this.routeRepository,
    this.dispatchRepository,
    this.activeRideRepository,
    this.offerFilter,
    this.followsDestination,
    this.towardPickupTime,
    this.claimPending,
  });

  @override
  State<RideRequests> createState() => _RideRequestsState();
}

class _RideRequestsState extends State<RideRequests> {
  // Same look as the Radar offers sheet on Home and the reservation popup.
  static const Color _page = Color(0xFFF4F5F5);
  static const Color _ink = Color(0xFF111614);
  static const Color _muted = Color(0xFF5E6461);
  static const Color _line = Color(0xFFE4E6E5);
  static const Color _green = Color(0xFF19865C);
  static const Color _mint = MoveraRadarOrb.onlineGreen;

  Timer? _matchNoticeTimer;

  /// Opens the trip of a won Match. Its own timer: a banner for another
  /// trip must never cancel it (driver-89).
  Timer? _matchOpenTimer;
  late final DispatchRepository _dispatch;
  late final bool _ownsDispatch;
  StreamSubscription<List<RideOffer>>? _nearbySubscription;
  StreamSubscription<OfferWithdrawal>? _withdrawalSubscription;
  final Map<String, Timer> _claimedRemovalTimers = <String, Timer>{};
  final Map<String, _RadarOfferState> _offerStates =
      <String, _RadarOfferState>{};
  bool _hasNewTripSignal = false;
  bool _hasDispatchSnapshot = false;
  String? _matchingId;

  /// The trip whose Match is being sent (or whose won trip is opening).
  String? get _matchingOfferId => _matchingId;
  set _matchingOfferId(String? id) {
    _matchingId = id;
    widget.claimPending?.value = id != null;
  }

  _RadarMatchNotice? _matchNotice;
  List<RideOffer> _latestDispatchOffers = const <RideOffer>[];

  final List<_RadarTrip> _offers = <_RadarTrip>[];

  /// Why a trip is leaving the list.
  final Map<String, _RadarGone> _goneReasons = <String, _RadarGone>{};

  /// Trips the driver removed with ×.
  final Set<String> _dismissed = <String>{};

  /// Q17: a trip hidden with × comes back after the admin's minutes if it
  /// is still open in Radar. Hiding never counts against the driver.
  final Map<String, Timer> _comeBackTimers = <String, Timer>{};

  void _hide(_RadarTrip trip) {
    // An admin radar group's trip: × is the driver's No (§3.1). It never
    // counts against the driver, like any Radar trip.
    if (trip.source.isRadarGroup) {
      unawaited(_dispatch.declineOffer(trip.id));
    }
    setState(() => _dismissed.add(trip.id));
    _comeBackTimers.remove(trip.id)?.cancel();
    _comeBackTimers[trip.id] = Timer(
      DriverOfferRules.current.hiddenComesBackAfter,
      () {
        _comeBackTimers.remove(trip.id);
        final open = _latestDispatchOffers.any((offer) => offer.id == trip.id);
        if (!mounted || !open || _stateFor(trip.id) != _RadarOfferState.available) {
          return;
        }
        setState(() => _dismissed.remove(trip.id));
      },
    );
  }

  List<_RadarTrip> get _visibleOffers {
    final nearby = _offers.where((offer) {
      if (!offer.isNearby || _dismissed.contains(offer.id)) { return false; }
      // An admin direct assign is an Exclusive offer, not a Radar trip.
      if (offer.source.isAdminDirectAssign) { return false; }
      if (!(widget.offerFilter?.call(offer.source) ?? true)) { return false; }
      if (!widget.destinationModeActive) { return true; }
      return offer.followsDestination;
    }).toList()
      ..sort((a, b) => a.pickupKm.compareTo(b.pickupKm));
    // Every Radar trip, each with its full details.
    return List<_RadarTrip>.unmodifiable(nearby);
  }

  bool _follows(RideOffer offer) =>
      widget.followsDestination?.call(offer) ?? offer.followsDestination;

  _RadarTrip _tripFromOffer(RideOffer offer) {
    return _RadarTrip(
      id: offer.id,
      category: offer.category,
      fare: offer.fareLabel,
      rating: offer.rating,
      pickupMinutes: offer.pickupMinutes,
      pickupKm: offer.pickupKm,
      tripMinutes: offer.tripMinutes,
      tripKm: offer.tripKm,
      pickup: offer.pickup,
      dropoff: offer.dropoff,
      pickupPosition: offer.pickupPosition.toLatLng(),
      dropoffPosition: offer.dropoffPosition.toLatLng(),
      isNearby: offer.isNearby,
      followsDestination: _follows(offer),
      bags: offer.bags,
      payment: offer.payment,
      reservationTime: offer.reservationTime,
      source: offer,
    );
  }

  @override
  void initState() {
    super.initState();
    _ownsDispatch = widget.dispatchRepository == null;
    _dispatch = widget.dispatchRepository ?? DemoDispatchRepository();
    _withdrawalSubscription = _dispatch.watchWithdrawals().listen(_onWithdrawn);
    _nearbySubscription = _dispatch.watchNearbyOffers().listen(_onDispatchOffers);
  }

  /// Dispatch withdrew a trip: when another driver took it (a radar
  /// group's first Accept), it leaves with tr.islandTakenByOther.
  void _onWithdrawn(OfferWithdrawal gone) {
    if (!mounted || gone.reason != OfferGoneReason.claimedElsewhere) { return; }
    for (final trip in _offers.toList()) {
      if (trip.id == gone.offerId && _stateFor(trip.id) == _RadarOfferState.available) {
        final shown = _visibleOffers.any((offer) => offer.id == trip.id);
        _resolveMatchLost(trip, _RadarGone.lostOwnMatch, notice: shown);
      }
    }
  }

  @override
  void dispose() {
    widget.claimPending?.value = false;
    _nearbySubscription?.cancel();
    _withdrawalSubscription?.cancel();
    _matchNoticeTimer?.cancel();
    _matchOpenTimer?.cancel();
    for (final timer in _claimedRemovalTimers.values) {
      timer.cancel();
    }
    for (final timer in _comeBackTimers.values) {
      timer.cancel();
    }
    if (_ownsDispatch) {
      final dispatch = _dispatch;
      if (dispatch is DemoDispatchRepository) {
        dispatch.dispose();
      }
    }
    super.dispose();
  }

  void _onDispatchOffers(List<RideOffer> offers) {
    if (!mounted) { return; }
    _latestDispatchOffers = offers;

    // First emission is the stable snapshot. Later additions wait for Refresh.
    // Removals of still-available cards are remote claims from dispatch.
    if (!_hasDispatchSnapshot) {
      setState(() {
        _hasDispatchSnapshot = true;
        _offers
          ..clear()
          ..addAll(offers.map(_tripFromOffer));
      });
      return;
    }

    final displayedIds = _offers.map((trip) => trip.id).toSet();
    final incomingIds = offers.map((offer) => offer.id).toSet();
    final hasNew = offers.any(
      (offer) => offer.isNearby &&
          !offer.isAdminDirectAssign &&
          !displayedIds.contains(offer.id),
    );
    final disappeared = _offers.where((trip) {
      return !incomingIds.contains(trip.id) &&
          _stateFor(trip.id) == _RadarOfferState.available;
    }).toList();

    if (hasNew && !_hasNewTripSignal) {
      setState(() => _hasNewTripSignal = true);
    }
    for (final trip in disappeared) {
      _markClaimedElsewhere(trip);
    }
  }

  void _refreshFromRadarSignal() {
    if (!_hasNewTripSignal) { return; }

    setState(() {
      final lingering = _offers.where((trip) {
        final state = _stateFor(trip.id);
        return state == _RadarOfferState.claimedElsewhere ||
            state == _RadarOfferState.resolving;
      }).toList();
      final lingeringIds = lingering.map((trip) => trip.id).toSet();
      _offers
        ..clear()
        ..addAll(
          _latestDispatchOffers
              .map(_tripFromOffer)
              .where((trip) => !lingeringIds.contains(trip.id)),
        )
        ..addAll(lingering);
      _hasNewTripSignal = false;
    });
    _dispatch.refreshOffers();
  }

  void _closeRides() {
    // A Match already sent is answered first (its banner covers Back too).
    if (_matchingOfferId != null) { return; }
    final onClose = widget.onCloseRides;
    if (onClose != null) {
      onClose(_visibleOffers.isNotEmpty);
      return;
    }
    // Embedded Radar uses Home's callback. A standalone Radar route must
    // still offer a functional Back action rather than trapping navigation.
    final navigator = Navigator.maybeOf(context);
    if (navigator?.canPop() ?? false) {
      navigator!.pop();
    }
  }

  _RadarOfferState _stateFor(String id) =>
      _offerStates[id] ?? _RadarOfferState.available;

  bool _isOfferStillVisible(_RadarTrip trip) {
    return _offers.any((offer) {
      if (offer.id != trip.id || !offer.isNearby) { return false; }
      if (!widget.destinationModeActive) { return true; }
      return offer.followsDestination;
    });
  }

  void _matchTrip(_RadarTrip trip) {
    // driver-u118: an offline driver (the driving limit, Go offline)
    // claims nothing.
    final session = widget.sessionController;
    if ((session != null && !session.availableForOffers) ||
        !_isOfferStillVisible(trip) ||
        _stateFor(trip.id) != _RadarOfferState.available ||
        _matchingOfferId != null) {
      return;
    }

    // An earlier banner's clear must not take this Match's banner away.
    _matchNoticeTimer?.cancel();
    setState(() {
      _matchingOfferId = trip.id;
      _offerStates[trip.id] = _RadarOfferState.resolving;
      _matchNotice = _RadarMatchNotice(
        type: _RadarMatchNoticeType.matching,
        title: tr.rrMatchingTrip,
        message: tr.rrConfirmingRealTime,
      );
    });

    unawaited(_claimTrip(trip));
  }

  Future<void> _claimTrip(_RadarTrip trip) async {
    ClaimResult result;
    try {
      result = await _dispatch.claimOffer(trip.id);
    } catch (_) {
      result = const ClaimResult.networkError();
    }
    if (!mounted || _matchingOfferId != trip.id) { return; }
    // A reservation taken from Radar, won or lost, leaves Scheduled rides.
    if (trip.reservationTime != null &&
        result.outcome != ClaimOutcome.networkError) {
      ScheduledRideStore.take(trip.id);
    }

    switch (result.outcome) {
      case ClaimOutcome.success:
        _resolveMatchWon(trip);
      case ClaimOutcome.alreadyClaimed:
        _resolveMatchLost(trip, _RadarGone.lostOwnMatch);
      case ClaimOutcome.expired:
      case ClaimOutcome.unavailable:
        _resolveMatchLost(trip, _RadarGone.unavailable);
      case ClaimOutcome.networkError:
        // Nothing was decided; let the driver try again.
        _matchNoticeTimer?.cancel();
        setState(() {
          _matchingOfferId = null;
          _offerStates.remove(trip.id);
          _matchNotice = _RadarMatchNotice(
            type: _RadarMatchNoticeType.error,
            title: tr.rrCouldNotMatch,
            message: tr.rrConnectionInterrupted,
          );
        });
        // It covers Back and Refresh: it clears like the other banners
        // (driver-u161).
        _matchNoticeTimer = Timer(const Duration(milliseconds: 2800), () {
          if (mounted) { setState(() => _matchNotice = null); }
        });
    }
  }

  void _resolveMatchWon(_RadarTrip trip) {
    _matchNoticeTimer?.cancel();

    // Keep the winning Radar frame intact until the active ride has mounted.
    // Clearing/removing the card underneath a long map transition caused a
    // visible disappear/reappear flash on iPhone Safari.
    setState(() {
      _matchingOfferId = trip.id;
      _matchNotice = _RadarMatchNotice(
        type: _RadarMatchNoticeType.success,
        title: tr.islandMatched,
        message: tr.rrAssignedOpening,
      );
    });

    _matchOpenTimer?.cancel();
    _matchOpenTimer = Timer(
      const Duration(milliseconds: 500),
      () {
        if (!mounted) { return; }
        final navigator = Navigator.of(context);
        final rider = trip.source;
        final ride = AcceptRide(
          // X9: the offer and the trip keep their own ids. Until a backend
          // sends the trip id, the demo makes one per accepted occurrence.
          offerId: trip.id,
          tripId: rider.tripId ?? tripOccurrenceId(trip.id),
          dispatchRepository: _dispatch,
          riderName: rider.riderName.isEmpty ? tr.rider : rider.riderName,
          riderRating: double.tryParse(rider.rating) ?? 4.9,
          riderTrips: rider.riderTrips,
          fare: trip.fare,
          paidByCash: RadarOfferView.isCash(trip.payment),
          cashToCollect: rider.cashToCollectLabel,
          driverBonus: rider.driverBonus,
          category: trip.category,
          matchedVia: 'Movera Radar',
          sessionController: widget.sessionController,
          waybillRepository: widget.waybillRepository,
          locationRepository: widget.locationRepository,
          routeRepository: widget.routeRepository,
          activeRideRepository: widget.activeRideRepository,
          pickupAddress: trip.pickup,
          pickupArea: trip.pickup.split(',').last.trim(),
          dropoffAddress: trip.dropoff,
          stopAddresses: [for (final stop in rider.stops) stop.address],
          stopPositions: [for (final stop in rider.stops) stop.point.toLatLng()],
          pickupPosition: trip.pickupPosition,
          dropoffPosition: trip.dropoffPosition,
          pickupKm: trip.pickupKm,
          destinationModeActive: widget.destinationModeActive,
          destinationAddress: widget.destinationAddress,
          destinationPosition: widget.destinationPosition,
        );

        navigator.push(ActiveRideTransition(ride));

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) { return; }
          setState(() {
            _matchingOfferId = null;
            _offers.removeWhere((offer) => offer.id == trip.id);
            _offerStates.remove(trip.id);
            _matchNotice = null;
          });
        });
      },
    );
  }

  void _resolveMatchLost(
    _RadarTrip trip,
    _RadarGone reason, {
    bool notice = true,
  }) {
    // The card fades out; a short banner says why, since this driver
    // tapped Match (or another driver of its radar group took it). While
    // this driver's Match of another trip is with dispatch or opening its
    // won trip, that Match keeps the banner (driver-89).
    final otherMatch = _matchingOfferId != null && _matchingOfferId != trip.id;
    if (!notice || otherMatch) {
      setState(() {
        _offerStates[trip.id] = _RadarOfferState.claimedElsewhere;
        _goneReasons[trip.id] = reason;
      });
      _scheduleClaimedRemoval(trip.id);
      return;
    }
    _matchNoticeTimer?.cancel();
    setState(() {
      if (_matchingOfferId == trip.id) { _matchingOfferId = null; }
      _offerStates[trip.id] = _RadarOfferState.claimedElsewhere;
      _goneReasons[trip.id] = reason;
      _matchNotice = reason == _RadarGone.lostOwnMatch
          ? _RadarMatchNotice(
              type: _RadarMatchNoticeType.error,
              title: tr.islandTakenByOther,
              message: tr.rrAnotherMatchedFirst,
            )
          : _RadarMatchNotice(
              type: _RadarMatchNoticeType.error,
              title: tr.islandNoLongerAvailable,
              message: tr.rrNoLongerOnRadar,
            );
    });
    _matchNoticeTimer = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) { setState(() => _matchNotice = null); }
    });

    _scheduleClaimedRemoval(trip.id);
  }

  /// A trip gone from Radar without a claim of ours. The reason is not
  /// known here (rider cancelled, expired, taken elsewhere…).
  void _markClaimedElsewhere(_RadarTrip trip) {
    if (!_isOfferStillVisible(trip) ||
        _stateFor(trip.id) != _RadarOfferState.available) {
      return;
    }

    setState(() {
      _offerStates[trip.id] = _RadarOfferState.claimedElsewhere;
      _goneReasons[trip.id] = _RadarGone.unavailable;
    });

    _scheduleClaimedRemoval(trip.id);
  }

  void _scheduleClaimedRemoval(String id) {
    _claimedRemovalTimers.remove(id)?.cancel();
    _claimedRemovalTimers[id] = Timer(
      const Duration(milliseconds: 2800),
      () {
        if (!mounted) { return; }
        setState(() {
          _offers.removeWhere((offer) => offer.id == id);
          _offerStates.remove(id);
          _goneReasons.remove(id);
        });
        _claimedRemovalTimers.remove(id);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final offers = _visibleOffers;
    final openCount = offers
        .where((offer) => _stateFor(offer.id) != _RadarOfferState.claimedElsewhere)
        .length;

    return LayoutViewport(
      child: Material(
      color: _page,
      child: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Column(
              children: [
                _header(openCount),
                if (widget.destinationModeActive) _destinationModeBanner(),
                if (widget.towardPickupTime case final time?)
                  _onYourWayBanner(
                    tr.rrTripsTowardPickup(time),
                    key: const ValueKey<String>('radar-schedule-filter'),
                  ),
                Expanded(
                  child: offers.isEmpty
                      ? _emptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                          physics: const BouncingScrollPhysics(),
                          itemCount: offers.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            return _tripCard(offers[index]);
                          },
                        ),
                ),
              ],
            ),
          ),
          if (_matchNotice != null)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: _buildMatchNotice(_matchNotice!),
            ),
        ],
      ),
    ),
    );
  }

  /// Back, the live dot with tr.rrLive, Refresh (only when new trips are
  /// waiting) and the total count.
  Widget _header(int count) {
    final shown = _offers.map((trip) => trip.id).toSet();
    final fresh = _latestDispatchOffers
        .where((offer) =>
            offer.isNearby &&
            !shown.contains(offer.id) &&
            (!widget.destinationModeActive || _follows(offer)))
        .length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFECEEF0))),
      ),
      child: Row(
        children: [
          Material(
            color: Colors.white,
            shape: const CircleBorder(side: BorderSide(color: Color(0xFFECEEF0))),
            child: IconButton(
              tooltip: tr.back,
              onPressed: _closeRides,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              icon: SvgPicture.asset(
                AppAssets.offerBack,
                width: 20,
                height: 20,
                colorFilter: const ColorFilter.mode(_ink, BlendMode.srcIn),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const _LivePulse(),
          const SizedBox(width: 8),
          Text(
            tr.rrLive,
            style: TextStyle(
              color: _ink,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(width: 12),
          // Refresh pill and count shrink together on narrow phones.
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_hasNewTripSignal) ...[
                      Material(
                        color: _ink,
                        shape: const StadiumBorder(),
                        child: InkWell(
                          key: const ValueKey<String>('radar-refresh-new'),
                          onTap: _refreshFromRadarSignal,
                          customBorder: const StadiumBorder(),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SvgPicture.asset(
                                  AppAssets.offerRefresh,
                                  width: 17,
                                  height: 17,
                                  colorFilter:
                                      const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  fresh > 0 ? tr.rrFreshNew(fresh) : tr.rrNew,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: _mint,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    LedCountBadge(
                      key: const ValueKey<String>('radar-live-count'),
                      count: count,
                      label: 'OFFERS',
                      tone: LedCountTone.grey,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _destinationModeBanner() {
    final destination = widget.destinationAddress?.trim();
    final label = destination == null || destination.isEmpty
        ? tr.rrDestinationRoute
        : destination.split(',').first.trim();
    return _onYourWayBanner(
      tr.rrTripsToward(label),
      key: const ValueKey<String>('radar-destination-filter'),
    );
  }

  /// tr.onYourWay and what the trips head toward.
  Widget _onYourWayBanner(String text, {Key? key}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        key: key,
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _ink,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                tr.onYourWay,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tripCard(_RadarTrip trip) {
    final state = _stateFor(trip.id);
    final claimed = state == _RadarOfferState.claimedElsewhere;
    final resolving = state == _RadarOfferState.resolving;
    final blockOtherOffers =
        _matchingOfferId != null && _matchingOfferId != trip.id;
    final card = RadarOfferCard(
      offer: RadarOfferView(
        id: trip.id,
        category: trip.category,
        payment: trip.payment,
        rating: trip.rating,
        fare: trip.fare,
        pickupMinutes: trip.pickupMinutes,
        pickupKm: trip.pickupKm,
        tripMinutes: trip.tripMinutes,
        tripKm: trip.tripKm,
        pickup: trip.pickup,
        dropoff: trip.dropoff,
        bags: trip.bags,
        reservationTime: trip.reservationTime,
        fareBoost: trip.source.fareBoostLabel,
        stops: trip.source.stops.length,
        riderTrips: trip.source.riderTrips,
        priority: trip.source.isPriority,
        driverBonus: WaybillRecord.bonusLabel(trip.source.driverBonus),
        pickupPay: PickupPayCalculator.quote(
          category: trip.category,
          kind: PickupPayOfferKind.forHomeOffer(
            onRadar: true,
            reservation: trip.reservationTime != null,
          ),
          leg: PickupLeg(km: trip.pickupKm, minutes: trip.pickupMinutes),
        ),
      ),
      state: claimed
          ? RadarOfferCardState.taken
          : resolving
          ? RadarOfferCardState.matching
          : RadarOfferCardState.available,
      onMatch: claimed || resolving || blockOtherOffers
          ? null
          : () => _matchTrip(trip),
      onDismiss: claimed || resolving ? null : () => _hide(trip),
    );
    // A trip another driver took fades out of the list.
    return TweenAnimationBuilder<double>(
      key: ValueKey(trip.id),
      tween: Tween<double>(end: claimed ? 0 : 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(opacity: v, child: child),
      child: card,
    );
  }

  Widget _buildMatchNotice(_RadarMatchNotice notice) {
    final isMatching = notice.type == _RadarMatchNoticeType.matching;
    final isSuccess = notice.type == _RadarMatchNoticeType.success;
    final accent = isSuccess
        ? const Color(0xFF2FBE7B)
        : isMatching
            ? const Color(0xFFD99B24)
            : const Color(0xFFC75B62);

    return TripStatusBanner(
      key: const ValueKey<String>('radar-match-notice'),
      title: notice.title,
      subtitle: notice.message,
      accent: accent,
      busy: isMatching,
      leading: isMatching
          ? null
          : Icon(
              isSuccess
                  ? Icons.check_rounded
                  : Icons.person_off_outlined,
              color: accent,
              size: 22,
            ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.radar_rounded, color: _muted, size: 30),
            SizedBox(height: 12),
            Text(
              tr.rrScanningNearby,
              style: TextStyle(
                color: _ink,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6),
            Text(
              tr.rrNewTripsAppear,
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Why a Radar trip is leaving the list.
enum _RadarGone {
  /// This driver tapped Match and another driver won.
  lostOwnMatch,

  /// Expired, cancelled by the rider or gone from Radar for another reason.
  unavailable,
}

enum _RadarOfferState { available, resolving, claimedElsewhere }

enum _RadarMatchNoticeType { matching, success, error }

class _RadarMatchNotice {
  const _RadarMatchNotice({
    required this.type,
    required this.title,
    required this.message,
  });

  final _RadarMatchNoticeType type;
  final String title;
  final String message;
}

class _RadarTrip {
  const _RadarTrip({
    required this.id,
    required this.category,
    required this.fare,
    required this.rating,
    required this.pickupMinutes,
    required this.pickupKm,
    required this.tripMinutes,
    required this.tripKm,
    required this.pickup,
    required this.dropoff,
    required this.pickupPosition,
    required this.dropoffPosition,
    required this.isNearby,
    this.followsDestination = false,
    this.bags = 0,
    this.payment = 'Card',
    this.reservationTime,
    required this.source,
  });

  /// The dispatch offer: rider, stops and fare boost come from it.
  final RideOffer source;

  final int bags;
  final String payment;

  /// A reservation close to pickup: its pickup time.
  final String? reservationTime;

  final String id;
  final String category;
  final String fare;
  final String rating;
  final int pickupMinutes;
  final double pickupKm;
  final int tripMinutes;
  final double tripKm;
  final String pickup;
  final String dropoff;
  final LatLng pickupPosition;
  final LatLng dropoffPosition;
  final bool isNearby;
  final bool followsDestination;
}

/// A small green dot that waves softly: one ring grows and fades, again.
class _LivePulse extends StatefulWidget {
  const _LivePulse();

  @override
  State<_LivePulse> createState() => _LivePulseState();
}

class _LivePulseState extends State<_LivePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey<String>('radar-live-dot'),
      width: 20,
      height: 20,
      child: AnimatedBuilder(
        animation: _wave,
        builder: (context, _) {
          final k = _wave.value;
          final e = 1 - (1 - k) * (1 - k);
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 7 + 12 * e,
                height: 7 + 12 * e,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _RideRequestsState._green.withValues(alpha: 0.32 * (1 - k)),
                ),
              ),
              Container(
                width: 7.5,
                height: 7.5,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _RideRequestsState._green,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

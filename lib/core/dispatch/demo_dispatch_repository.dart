import 'package:movera/core/money/money.dart';
import 'dart:async';

import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/demo_destination_trips.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/demo_trip_drive.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';
import 'package:movera/core/scheduled/scheduled_ride_rules.dart';
import 'package:movera/core/session/driver_runtime_config.dart';

/// The two RideCheck demo trips on Radar, labelled in their pickup. Their
/// ids give them a scripted drive (see [DemoTripDrive.forTrip]).
class DemoRideCheckTrips {
  const DemoRideCheckTrips._();

  static const RideOffer farDropoff = RideOffer(
    id: DemoTripDrive.farDropoffOfferId,
    riderName: 'Leo',
    riderTrips: 27,
    category: 'Movera',
    fare: Money(minorUnits: 16800),
    rating: '4.90',
    pickupMinutes: 2,
    pickupKm: 0.6,
    tripMinutes: 22,
    tripKm: 11.9,
    pickup: 'RideCheck demo: far drop-off · Sveavägen 20, Stockholm',
    dropoff: 'Kista Galleria, Kista',
    pickupPosition: GeoPoint(59.3365, 18.0630),
    dropoffPosition: GeoPoint(59.4032, 17.9445),
    isNearby: true,
    followsDestination: false,
  );

  static const RideOffer longStop = RideOffer(
    id: DemoTripDrive.longStopOfferId,
    riderName: 'Alva',
    riderTrips: 51,
    category: 'Comfort',
    fare: Money(minorUnits: 13240),
    rating: '4.94',
    pickupMinutes: 2,
    pickupKm: 0.5,
    tripMinutes: 18,
    tripKm: 7.2,
    pickup: 'RideCheck demo: long stop · Hornsgatan 100, Stockholm',
    dropoff: 'Solna centrum, Solna',
    pickupPosition: GeoPoint(59.3170, 18.0450),
    dropoffPosition: GeoPoint(59.3599, 18.0002),
    isNearby: true,
    followsDestination: false,
  );
}

/// Admin offers in the demo (contract §3.1, owner Q16/Q18): Movera added
/// money to both, so their fares already include the bonus and their cards
/// carry the red "Priority" badge.
class DemoAdminOffers {
  const DemoAdminOffers._();

  /// A radar group trip (`source: admin`, with a `groupId`): a Radar card.
  static const RideOffer radarGroup = RideOffer(
    id: 'admin-group-1',
    riderName: 'Astrid',
    riderTrips: 38,
    category: 'Comfort',
    // 112,40 kr trip + 40 kr Movera bonus.
    fare: Money(minorUnits: 15240),
    driverBonus: Money(minorUnits: 4000),
    priority: true,
    source: OfferSource.admin,
    groupId: 'demo-radar-group-1',
    rating: '4.92',
    pickupMinutes: 4,
    pickupKm: 1.3,
    tripMinutes: 16,
    tripKm: 9.4,
    pickup: 'Birger Jarlsgatan 12, Stockholm',
    dropoff: 'Liljeholmstorget, Stockholm',
    pickupPosition: GeoPoint(59.3362, 18.0735),
    dropoffPosition: GeoPoint(59.3103, 18.0231),
    isNearby: true,
    followsDestination: false,
  );

  /// A second radar group trip: another driver of the group accepts it
  /// first ([DemoDispatchRepository] `groupRaceDelay` after the demo
  /// starts), so it leaves with "Taken by another driver".
  static const RideOffer radarGroupTaken = RideOffer(
    id: 'admin-group-2',
    riderName: 'Leo',
    riderTrips: 12,
    category: 'Movera',
    // 87,20 kr trip + 25 kr Movera bonus.
    fare: Money(minorUnits: 11220),
    driverBonus: Money(minorUnits: 2500),
    priority: true,
    source: OfferSource.admin,
    groupId: 'demo-radar-group-2',
    rating: '4.81',
    pickupMinutes: 6,
    pickupKm: 2.2,
    tripMinutes: 12,
    tripKm: 6.1,
    pickup: 'Sveavägen 44, Stockholm',
    dropoff: 'Fridhemsplan, Stockholm',
    pickupPosition: GeoPoint(59.3390, 18.0590),
    dropoffPosition: GeoPoint(59.3322, 18.0290),
    isNearby: true,
    followsDestination: false,
  );

  /// A direct assign (`source: admin`, no group): an Exclusive offer.
  static const RideOffer directAssign = RideOffer(
    id: 'admin-assign-1',
    riderName: 'Karim',
    riderTrips: 64,
    category: 'Movera',
    // 98,60 kr trip + 30 kr Movera bonus.
    fare: Money(minorUnits: 12860),
    driverBonus: Money(minorUnits: 3000),
    priority: true,
    source: OfferSource.admin,
    rating: '4.88',
    pickupMinutes: 3,
    pickupKm: 0.8,
    tripMinutes: 14,
    tripKm: 7.9,
    pickup: 'Tegnérgatan 8, Stockholm',
    dropoff: 'Hammarby sjöstad, Stockholm',
    pickupPosition: GeoPoint(59.3378, 18.0570),
    dropoffPosition: GeoPoint(59.3030, 18.1000),
    isNearby: true,
    followsDestination: false,
  );
}

/// Frontend/demo dispatch. A backend implementation replaces this class.
///
/// Snapshot rules the Radar UI already depends on:
/// - nearby-1, nearby-2, nearby-3 are live immediately
/// - nearby-4 and nearby-5 arrive later and wait for an explicit refresh,
///   with the cash demo trips nearby-6 to nearby-10 (R8-4, R9) and the
///   two RideCheck demo trips ([DemoRideCheckTrips])
/// - nearby-2 loses the atomic claim race
/// - nearby-3 is claimed by another driver without this driver tapping Match
/// - open reservations (Scheduled rides, the Home popup) are claimed
///   through the same [claimOffer]: the first claim wins, later ones get
///   [ClaimOutcome.unavailable]; a reservation id equal to [losingOfferId]
///   is won by another driver
/// - untaken reservations join the nearby Radar trips, marked as
///   reservations, [ScheduledRideRules.radarBeforeMinutes] before their
///   pickup on [ScheduledClock.instance]; a cancelled one goes back where
///   [ScheduledRideRules.stepAfterDriverCancel] says, Radar trips included
/// - [assignedRides] are assigned to this driver
///   [ReservationDemoTimings.assignedAfter] after the demo starts (Q29)
class DemoDispatchRepository implements DispatchRepository {
  DemoDispatchRepository({
    Duration claimDelay = const Duration(milliseconds: 1450),
    Duration newOfferDelay = const Duration(seconds: 7),
    Duration? externalClaimDelay,
    this.losingOfferId = 'nearby-2',
    this.externalClaimOfferId = 'nearby-3',
    List<ReservationRequestPreview>? reservations,
    Duration? reservationRadarDelay,
    List<ReservationRequestPreview>? assignedRides,
    Duration assignmentDelay = ReservationDemoTimings.assignedAfter,
    ScheduledClock? clock,
    ScheduledRideRules? rules,
    bool? adminOffers,
    Duration? groupRaceDelay,
  }) : _groupRaceDelay = groupRaceDelay,
       _adminOffers =
           adminOffers ?? DriverRuntimeConfig.current.adminDemoOffers,
       _claimDelay = claimDelay,
       _newOfferDelay = newOfferDelay,
       // Another driver takes a trip soon after Home shows Radar trips,
       // which follow the Exclusive offer's time to accept.
       _externalClaimDelay =
           externalClaimDelay ??
           DriverOfferRules.current.exclusiveAcceptTime +
               const Duration(milliseconds: 4500),
       _reservationRadarDelay = reservationRadarDelay,
       _assignmentDelay = assignmentDelay,
       _clock = clock,
       _rules = rules,
       // The demo's own reservations, booked relative to now.
       assignedRides = assignedRides ?? [DemoReservations.assigned],
       _seedPreviews = {
         for (final reservation
             in reservations ?? DemoReservations.dispatchReservations)
           if (reservation.id.isNotEmpty) reservation.id: reservation,
       } {
    _seedReservations = {
      for (final reservation in _seedPreviews.values)
        reservation.id: RideOffer.reservation(reservation),
    };
    _reservations = Map<String, RideOffer>.of(_seedReservations);
    _offers = _firstOffers();
  }

  /// Q16/Q18 demo: the admin's offers come with the first ones.
  final bool _adminOffers;

  List<RideOffer> _firstOffers() => [
    if (_adminOffers) DemoAdminOffers.radarGroup,
    ..._immediateOffers,
    if (_adminOffers) DemoAdminOffers.radarGroupTaken,
    if (_adminOffers) DemoAdminOffers.directAssign,
  ];

  /// When another driver of [DemoAdminOffers.radarGroupTaken]'s group
  /// accepts it; by default a little after the Radar trips come.
  final Duration? _groupRaceDelay;
  Timer? _groupRaceTimer;

  final StreamController<OfferWithdrawal> _withdrawals =
      StreamController<OfferWithdrawal>.broadcast();

  final Duration _claimDelay;
  final Duration _newOfferDelay;
  final Duration _externalClaimDelay;

  /// A fixed delay instead of the clock for when reservations join Radar.
  final Duration? _reservationRadarDelay;
  final Duration _assignmentDelay;
  final ScheduledClock? _clock;
  final ScheduledRideRules? _rules;
  final String losingOfferId;
  final String externalClaimOfferId;

  /// Rides Movera assigns to this driver in the demo.
  final List<ReservationRequestPreview> assignedRides;

  ScheduledClock get clock => _clock ?? ScheduledClock.instance;
  ScheduledRideRules get rules => _rules ?? ScheduledRideRules.current;

  final StreamController<List<RideOffer>> _nearby =
      StreamController<List<RideOffer>>.broadcast();
  final StreamController<List<RideOffer>> _nextTrip =
      StreamController<List<RideOffer>>.broadcast();

  List<RideOffer> _offers = List<RideOffer>.from(_immediateOffers);
  List<RideOffer> _queued = List<RideOffer>.from(_laterOffers);

  /// Every reservation of this demo, by id, and the ones no driver has
  /// taken yet.
  final Map<String, ReservationRequestPreview> _seedPreviews;
  late final Map<String, RideOffer> _seedReservations;
  late Map<String, RideOffer> _reservations;

  /// Assigned rides not answered yet.
  final Set<String> _openAssignments = <String>{};
  final StreamController<ReservationRequestPreview> _assignments =
      StreamController<ReservationRequestPreview>.broadcast();
  Timer? _assignmentTimer;

  /// When each untaken reservation joins Radar.
  final Map<String, Timer> _radarJoinTimers = <String, Timer>{};

  bool _demoStarted = false;
  int _generation = 0;
  bool _disposed = false;
  Timer? _newOfferTimer;
  Timer? _externalClaimTimer;

  static const List<RideOffer> _immediateOffers = [
    RideOffer(
      id: 'nearby-1',
      riderName: 'Sara',
      riderTrips: 86,
      category: 'Comfort',
      fare: Money(minorUnits: 11102),
      rating: '4.95',
      pickupMinutes: 7,
      pickupKm: 2.1,
      tripMinutes: 15,
      tripKm: 10.5,
      pickup: 'Hantverkargatan 4, Stockholm',
      dropoff: 'Trollesundsvägen 58B, Bandhagen',
      pickupPosition: GeoPoint(59.3295, 18.0475),
      dropoffPosition: GeoPoint(59.2705, 18.0515),
      isNearby: true,
      followsDestination: false,
      bags: 2,
    ),
    RideOffer(
      id: 'nearby-2',
      riderName: 'Johan',
      riderTrips: 203,
      category: 'Movera',
      fare: Money(minorUnits: 9640),
      rating: '4.91',
      pickupMinutes: 5,
      pickupKm: 1.4,
      tripMinutes: 18,
      tripKm: 8.7,
      pickup: 'Klarabergsgatan, Stockholm',
      dropoff: 'Ringvägen, Södermalm',
      pickupPosition: GeoPoint(59.3316, 18.0592),
      dropoffPosition: GeoPoint(59.3125, 18.0750),
      isNearby: true,
      followsDestination: true,
      payment: 'Cash',
    ),
    RideOffer(
      id: 'nearby-3',
      riderName: 'Elin',
      riderTrips: 57,
      category: 'Premium',
      fare: Money(minorUnits: 18460),
      rating: '4.98',
      pickupMinutes: 9,
      pickupKm: 3.6,
      tripMinutes: 22,
      tripKm: 14.2,
      pickup: 'Strandvägen, Stockholm',
      dropoff: 'Solna centrum, Solna',
      pickupPosition: GeoPoint(59.3332, 18.0916),
      dropoffPosition: GeoPoint(59.3599, 18.0002),
      isNearby: true,
      followsDestination: true,
      bags: 1,
      payment: 'Apple Pay',
    ),
  ];

  static const List<RideOffer> _laterOffers = [
    RideOffer(
      id: 'nearby-4',
      riderName: 'Omar',
      riderTrips: 142,
      category: 'Priority',
      fare: Money(minorUnits: 12870),
      rating: '4.93',
      pickupMinutes: 4,
      pickupKm: 1.1,
      tripMinutes: 13,
      tripKm: 7.4,
      pickup: 'Vasagatan, Stockholm',
      dropoff: 'Gärdet, Stockholm',
      pickupPosition: GeoPoint(59.3323, 18.0576),
      dropoffPosition: GeoPoint(59.3417, 18.1004),
      isNearby: true,
      followsDestination: true,
    ),
    RideOffer(
      id: 'nearby-5',
      riderName: 'Lina',
      riderTrips: 31,
      category: 'Electric',
      fare: Money(minorUnits: 13920),
      rating: '4.97',
      pickupMinutes: 8,
      pickupKm: 2.9,
      tripMinutes: 20,
      tripKm: 12.1,
      pickup: 'Odengatan, Stockholm',
      dropoff: 'Liljeholmen, Stockholm',
      pickupPosition: GeoPoint(59.3427, 18.0520),
      dropoffPosition: GeoPoint(59.3105, 18.0232),
      isNearby: true,
      followsDestination: false,
    ),
    // R8-4 demo: cash trips, so "Collect cash" can be tried end to end.
    // The cash is the rider's fare; the driver's money is their share of
    // it (owner decision 2026-10-26). Fare 200 → 150 earnings, cash 250:
    // the driver owes Movera 100.
    RideOffer(
      id: 'nearby-6',
      riderName: 'Noah',
      riderTrips: 18,
      category: 'Movera',
      fare: Money(minorUnits: 20000),
      cashToCollect: Money(minorUnits: 25000),
      rating: '4.89',
      pickupMinutes: 6,
      pickupKm: 1.8,
      tripMinutes: 21,
      tripKm: 13.4,
      pickup: 'Götgatan 30, Stockholm',
      dropoff: 'Kista Galleria, Kista',
      pickupPosition: GeoPoint(59.3150, 18.0726),
      dropoffPosition: GeoPoint(59.4032, 17.9445),
      isNearby: true,
      followsDestination: false,
      payment: 'Cash',
    ),
    // Fare 300 → 225 earnings, cash 200 (a rider promotion): Movera owes
    // the driver 25.
    RideOffer(
      id: 'nearby-7',
      riderName: 'Ida',
      riderTrips: 64,
      category: 'Comfort',
      fare: Money(minorUnits: 30000),
      cashToCollect: Money(minorUnits: 20000),
      rating: '4.96',
      pickupMinutes: 5,
      pickupKm: 1.5,
      tripMinutes: 27,
      tripKm: 19.8,
      pickup: 'Sankt Eriksgatan 50, Stockholm',
      dropoff: 'Nacka Forum, Nacka',
      pickupPosition: GeoPoint(59.3380, 18.0330),
      dropoffPosition: GeoPoint(59.3105, 18.1630),
      isNearby: true,
      followsDestination: false,
      payment: 'Cash',
    ),
    // More cash trips (R9). Fare 158,40 → 118,80 earnings, cash 120: the
    // driver owes Movera 1,20.
    RideOffer(
      id: 'nearby-8',
      riderName: 'Hanna',
      riderTrips: 40,
      category: 'Comfort',
      fare: Money(minorUnits: 15840),
      cashToCollect: Money(minorUnits: 12000),
      rating: '4.92',
      pickupMinutes: 4,
      pickupKm: 1.2,
      tripMinutes: 19,
      tripKm: 9.8,
      pickup: 'Drottninggatan 71, Stockholm',
      dropoff: 'Bromma flygplats, Bromma',
      pickupPosition: GeoPoint(59.3365, 18.0590),
      dropoffPosition: GeoPoint(59.3546, 17.9416),
      isNearby: true,
      followsDestination: false,
      payment: 'Cash',
    ),
    // Fare 214,90 → 161,17 earnings, cash 260: the driver owes Movera 98,83.
    RideOffer(
      id: 'nearby-9',
      riderName: 'Viktor',
      riderTrips: 122,
      category: 'Premium',
      fare: Money(minorUnits: 21490),
      cashToCollect: Money(minorUnits: 26000),
      rating: '4.97',
      pickupMinutes: 7,
      pickupKm: 2.4,
      tripMinutes: 24,
      tripKm: 15.6,
      pickup: 'Karlavägen 60, Stockholm',
      dropoff: 'Täby centrum, Täby',
      pickupPosition: GeoPoint(59.3380, 18.0850),
      dropoffPosition: GeoPoint(59.4439, 18.0687),
      isNearby: true,
      followsDestination: false,
      payment: 'Cash',
    ),
    // Fare 96 → 72 earnings, cash 130: the driver owes Movera 58.
    RideOffer(
      id: 'nearby-10',
      riderName: 'Sofia',
      riderTrips: 9,
      category: 'Priority',
      fare: Money(minorUnits: 9600),
      cashToCollect: Money(minorUnits: 13000),
      rating: '4.86',
      pickupMinutes: 3,
      pickupKm: 0.8,
      tripMinutes: 17,
      tripKm: 8.1,
      pickup: 'Fleminggatan 20, Stockholm',
      dropoff: 'Hammarby sjöstad, Stockholm',
      pickupPosition: GeoPoint(59.3330, 18.0420),
      dropoffPosition: GeoPoint(59.3030, 18.1000),
      isNearby: true,
      followsDestination: false,
      payment: 'Cash',
    ),
    // RideCheck demo trips (R9): normal trips whose GPS is scripted by
    // DemoTripDrive, so the real RideCheck checks open the card.
    // Ends more than admin's km before the drop-off: Finish opens it.
    DemoRideCheckTrips.farDropoff,
    // Stands still mid-trip for more than admin's minutes: it opens.
    DemoRideCheckTrips.longStop,
  ];

  @override
  Stream<List<RideOffer>> watchNearbyOffers({
    bool destinationModeActive = false,
  }) {
    return Stream<List<RideOffer>>.multi((sink) {
      if (_disposed) {
        sink.closeSync();
        return;
      }
      List<RideOffer> snapshot(List<RideOffer> offers) =>
          List<RideOffer>.unmodifiable(
            destinationModeActive
                ? offers.where((offer) => offer.followsDestination)
                : offers,
          );
      final subscription = _nearby.stream.listen(
        (offers) => sink.addSync(snapshot(offers)),
        onError: sink.addErrorSync,
        onDone: sink.closeSync,
      );
      sink.onCancel = subscription.cancel;
      _ensureDemoSchedule();
      // Each listener owns its initial snapshot, even when it subscribes later.
      sink.addSync(snapshot(_offers));
    }, isBroadcast: true);
  }

  @override
  Stream<List<RideOffer>> watchNextTripOffers() {
    return Stream<List<RideOffer>>.multi((sink) {
      if (_disposed) {
        sink.closeSync();
        return;
      }
      final subscription = _nextTrip.stream.listen(
        sink.addSync,
        onError: sink.addErrorSync,
        onDone: sink.closeSync,
      );
      sink.onCancel = subscription.cancel;
      sink.addSync(const <RideOffer>[]);
    }, isBroadcast: true);
  }

  @override
  Future<ClaimResult> claimOffer(String offerId) async {
    if (_disposed) {
      return const ClaimResult.unavailable();
    }
    final generation = _generation;
    await Future<void>.delayed(_claimDelay);
    if (_disposed || generation != _generation) {
      return const ClaimResult.unavailable();
    }
    final reservation = _reservations.remove(offerId);
    if (reservation != null) {
      // One winner: it leaves the open reservations and Radar at once.
      _radarJoinTimers.remove(offerId)?.cancel();
      _removeOffer(offerId);
      return offerId == losingOfferId
          ? const ClaimResult.alreadyClaimed()
          : ClaimResult.success(reservation);
    }
    if (_openAssignments.remove(offerId)) {
      final assigned = assignedRides.firstWhere((ride) => ride.id == offerId);
      return offerId == losingOfferId
          ? const ClaimResult.expired()
          : ClaimResult.success(RideOffer.reservation(assigned));
    }
    RideOffer? offer;
    for (final item in _offers) {
      if (item.id == offerId) {
        offer = item;
        break;
      }
    }
    if (offer == null) {
      return const ClaimResult.unavailable();
    }
    if (offerId == losingOfferId) {
      _removeOffer(offerId);
      return const ClaimResult.alreadyClaimed();
    }
    _removeOffer(offerId);
    return ClaimResult.success(offer);
  }

  /// Contract §3.1 in process: the driver's No leaves the feed at once.
  @override
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async {
    if (_disposed || !_offers.any((offer) => offer.id == offerId)) {
      return false;
    }
    _removeOffer(offerId);
    return true;
  }

  @override
  Stream<OfferWithdrawal> watchWithdrawals() => _withdrawals.stream;

  /// Another driver took [offerId] (a radar group's first Accept): it is
  /// withdrawn with that reason, then leaves the list.
  void withdrawOffer(
    String offerId, {
    OfferGoneReason reason = OfferGoneReason.claimedElsewhere,
  }) {
    if (_disposed || !_offers.any((offer) => offer.id == offerId)) {
      return;
    }
    if (!_withdrawals.isClosed) {
      _withdrawals.add(OfferWithdrawal(offerId: offerId, reason: reason));
    }
    _removeOffer(offerId);
  }

  @override
  void refreshOffers() {
    _emitNearby();
  }

  /// R13-9 demo: trips along the driver's destination route (see
  /// [DemoDestinationTrips]) come first on Radar; they replace any earlier
  /// set.
  void showDestinationTrips(List<RideOffer> trips) {
    if (_disposed) {
      return;
    }
    _offers = [...trips, ..._withoutDestinationTrips()];
    _emitNearby();
  }

  /// Destination mode ended: its demo trips leave Radar.
  void clearDestinationTrips() {
    if (_disposed) {
      return;
    }
    final kept = _withoutDestinationTrips();
    if (kept.length == _offers.length) {
      return;
    }
    _offers = kept;
    _emitNearby();
  }

  List<RideOffer> _withoutDestinationTrips() => [
    for (final offer in _offers)
      if (!offer.id.startsWith(DemoDestinationTrips.idPrefix)) offer,
  ];

  /// A cancelled reservation goes back to the open ones, so Scheduled
  /// rides and the Home popup can offer it again, and to Radar where the
  /// admin rule "After a driver cancels" says: at once when it is that
  /// close to pickup, otherwise at its Radar time.
  @override
  void releaseReservation(String reservationId) {
    final reservation = _seedReservations[reservationId];
    if (_disposed ||
        reservation == null ||
        _reservations.containsKey(reservationId)) {
      return;
    }
    _reservations[reservationId] = reservation;
    final left = _minutesBeforePickup(reservationId);
    final step = left == null
        ? ReservationStep.list
        : rules.stepAfterDriverCancel(
            sinceBookedMinutes: 0,
            beforePickupMinutes: left,
          );
    if (step == ReservationStep.radar) {
      _joinRadar(reservationId);
    } else if (_demoStarted) {
      _scheduleRadarJoin(reservationId);
    }
  }

  @override
  Stream<ReservationRequestPreview> watchAssignments() => _assignments.stream;

  /// Minutes left before [id]'s pickup on the clock; null when unknown.
  int? _minutesBeforePickup(String id) {
    final now = clock.now();
    return _seedPreviews[id]?.untilPickup(now)?.inMinutes;
  }

  /// [id] joins Radar at its Radar step; at once when that has passed.
  void _scheduleRadarJoin(String id) {
    _radarJoinTimers.remove(id)?.cancel();
    final fixed = _reservationRadarDelay;
    final preview = _seedPreviews[id];
    final pickupAt = preview?.pickupAt(clock.now());
    final wait =
        fixed ??
        (pickupAt == null
            ? null
            : clock.realUntil(
                pickupAt.subtract(Duration(minutes: rules.radarBeforeMinutes)),
              ));
    if (wait == null) {
      return;
    }
    _radarJoinTimers[id] = Timer(wait, () {
      _radarJoinTimers.remove(id);
      _joinRadar(id);
    });
  }

  /// Close to pickup: an untaken reservation joins the nearby Radar trips.
  void _joinRadar(String id) {
    final reservation = _reservations[id];
    if (_disposed ||
        reservation == null ||
        _offers.any((offer) => offer.id == id)) {
      return;
    }
    _offers = [..._offers, reservation];
    _emitNearby();
  }

  void _ensureDemoSchedule() {
    if (_disposed || _demoStarted) {
      return;
    }
    _demoStarted = true;
    _newOfferTimer = Timer(_newOfferDelay, _releaseQueuedOffers);
    _externalClaimTimer = Timer(_externalClaimDelay, () {
      _removeOffer(externalClaimOfferId);
    });
    if (_adminOffers) {
      _groupRaceTimer = Timer(
        _groupRaceDelay ?? _externalClaimDelay + const Duration(seconds: 6),
        () => withdrawOffer(DemoAdminOffers.radarGroupTaken.id),
      );
    }
    for (final id in _reservations.keys) {
      _scheduleRadarJoin(id);
    }
    if (assignedRides.isNotEmpty) {
      _assignmentTimer = Timer(_assignmentDelay, () {
        for (final ride in assignedRides) {
          if (_openAssignments.add(ride.id) && !_assignments.isClosed) {
            _assignments.add(ride);
          }
        }
      });
    }
  }

  void _releaseQueuedOffers() {
    if (_queued.isEmpty) {
      return;
    }
    _offers = [..._offers, ..._queued];
    _queued = const <RideOffer>[];
    _emitNearby();
  }

  void _removeOffer(String offerId) {
    final next = _offers.where((item) => item.id != offerId).toList();
    if (next.length == _offers.length) {
      return;
    }
    _offers = next;
    _emitNearby();
  }

  void _emitNearby() {
    if (_nearby.isClosed) {
      return;
    }
    _nearby.add(List<RideOffer>.unmodifiable(_offers));
  }

  /// Returns the demo to its first-launch offer set, for logout/re-entry.
  void reset() {
    if (_disposed) {
      return;
    }
    _generation++;
    _cancelDemoTimers();
    _offers = _firstOffers();
    _queued = List<RideOffer>.from(_laterOffers);
    _reservations = Map<String, RideOffer>.of(_seedReservations);
    _openAssignments.clear();
    _demoStarted = false;
    _emitNearby();
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _generation++;
    _cancelDemoTimers();
    _nearby.close();
    _nextTrip.close();
    _assignments.close();
    _withdrawals.close();
  }

  void _cancelDemoTimers() {
    _newOfferTimer?.cancel();
    _externalClaimTimer?.cancel();
    _groupRaceTimer?.cancel();
    _assignmentTimer?.cancel();
    for (final timer in _radarJoinTimers.values) {
      timer.cancel();
    }
    _radarJoinTimers.clear();
  }
}

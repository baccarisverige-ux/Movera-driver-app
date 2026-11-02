import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/contracts/category_catalog.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/waybill/waybill.dart';

enum ClaimOutcome {
  success,
  alreadyClaimed,
  expired,
  unavailable,
  networkError,
}

/// Who sent an offer (contract `Offer.source`).
enum OfferSource {
  /// Normal dispatch.
  system,

  /// An admin: a direct assign (Exclusive) or a radar group (§3.1).
  admin;

  static OfferSource fromWire(Object? value) =>
      value == 'admin' ? OfferSource.admin : OfferSource.system;
}

/// What kind of offer it is (contract `OfferKind`).
enum OfferKind {
  radar,
  exclusive,
  assigned,
  reservation,
  nextTrip;

  /// Null for a value this build does not know.
  static OfferKind? fromWire(Object? value) => switch (value) {
    'radar' => OfferKind.radar,
    'exclusive' => OfferKind.exclusive,
    'assigned' => OfferKind.assigned,
    'reservation' => OfferKind.reservation,
    'next_trip' => OfferKind.nextTrip,
    _ => null,
  };
}

class RideOffer {
  const RideOffer({
    required this.id,
    this.tripId,
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
    required this.followsDestination,
    this.bags = 0,
    this.payment = 'Card',
    this.reservationTime,
    this.riderName = '',
    this.riderTrips = 0,
    this.stops = const <ReservationStop>[],
    this.fareBoost,
    this.cashToCollect,
    this.driverBonus,
    this.driverEarnings,
    this.pickupPay,
    this.priority = false,
    this.source = OfferSource.system,
    this.groupId,
    this.version = 1,
    this.kind,
    this.expiresAt,
  });

  /// A reservation as a Radar trip. The driver's distance to the pickup is
  /// not known here, so the demo uses a fixed one.
  factory RideOffer.reservation(ReservationRequestPreview reservation) =>
      RideOffer(
        id: reservation.id,
        category: reservation.category,
        fare: _amount(reservation.fare, 'fare')!,
        rating: reservation.rating,
        pickupMinutes: 16,
        pickupKm: 2.1,
        tripMinutes: reservation.tripMinutes,
        tripKm: reservation.tripKm,
        pickup: reservation.pickupAddress,
        dropoff: reservation.dropoffAddress,
        pickupPosition: reservation.pickup,
        dropoffPosition: reservation.dropoff,
        isNearby: true,
        followsDestination: false,
        payment: reservation.paidByCash ? 'Cash' : 'Card',
        reservationTime: reservation.pickupTime,
        riderName: reservation.riderName,
        riderTrips: reservation.riderTrips,
        stops: reservation.stops,
        fareBoost: _amount(reservation.fareBoost, 'fareBoost'),
        cashToCollect: reservation.paidByCash
            ? _amount(reservation.cashToCollect, 'cashToCollect')
            : null,
      );

  /// Reservation previews still carry SEK labels (follow-up); offers do not.
  static Money? _amount(String? label, String field) {
    if (label == null) return null;
    return Money.parseSekLabel(label) ??
        (throw ArgumentError.value(label, field, 'Not a SEK amount'));
  }

  /// The offer (contract `offerId`): what the driver claims.
  final String id;

  /// X9: the trip this offer is for (contract `Offer.tripId`). Realtime,
  /// persistence and receipts key on it, never on [id]. Null until a
  /// backend sends it; the demo then makes one per accepted occurrence.
  final String? tripId;

  /// Display name, e.g. "Movera XL". See [categoryId] for the wire id.
  final String category;

  /// Contract category id (`economy`, `xl`, …) for [category], or null when
  /// the name is not a category.
  String? get categoryId => CategoryCatalog.idForLabel(category);

  /// What the rider pays (contract `Offer.fare`, minor units). Formatted
  /// locally: see [fareLabel]. The driver is never shown it (owner
  /// decision 2026-10-26): the cards, the accepted trip and its history
  /// carry [driverPay]; a cash trip shows it only as the cash to collect
  /// ([riderCash]).
  final Money fare;

  /// Display form of [fare], e.g. `111,02 kr`.
  String get fareLabel => fare.formatted;

  /// The driver's own money for this trip, after Movera's commission
  /// (owner decision 2026-10-26, "price must be after commission that
  /// show to driver"): the server's [driverEarnings] (Movera's bonus in
  /// it); for a demo offer without them, [fare] after the demo's
  /// commission with the [driverBonus] kept whole
  /// ([WaybillPayment.shareOf]), the same number the offer card shows
  /// ([OfferCardDetails.fare]). Pickup pay is added on top of it
  /// (`PickupPayQuote.totalOf`): the driver's total is
  /// `driverEarnings + pickupPay`.
  Money get driverPay =>
      driverEarnings ??
      WaybillPayment.shareOf(
        fare,
        bonus: driverBonus,
        feeRate: DriverOfferRules.current.commissionRate,
      );

  /// Display form of [driverPay], e.g. `83,26 kr`.
  String get driverPayLabel => driverPay.formatted;

  /// On a cash trip, the cash the rider hands over: [cashToCollect] when
  /// dispatch sent one (R8-4), else [fare] without Movera's [driverBonus],
  /// which the rider never pays (driver-u61). The rider's money, not the
  /// driver's ([driverPay]): the trip shows it only as the cash to
  /// collect.
  Money get riderCash => cashToCollect ?? riderCashOf(fare, driverBonus);

  /// Display form of [riderCash], e.g. `112,40 kr`.
  String get riderCashLabel => riderCash.formatted;

  /// [fare] without Movera's [bonus]: [fare] itself when there is no
  /// bonus, it is another currency or larger than the fare.
  static Money riderCashOf(Money fare, Money? bonus) {
    if (bonus == null ||
        bonus.minorUnits <= 0 ||
        bonus.currency != fare.currency ||
        bonus.minorUnits > fare.minorUnits) {
      return fare;
    }
    return fare - bonus;
  }

  final String rating;
  final int pickupMinutes;
  final double pickupKm;
  final int tripMinutes;
  final double tripKm;
  final String pickup;
  final String dropoff;
  final GeoPoint pickupPosition;
  final GeoPoint dropoffPosition;
  final bool isNearby;
  final bool followsDestination;

  /// Bags the rider said they bring; 0 when none.
  final int bags;

  /// How the rider pays, e.g. "Card", "Apple Pay", "Swish".
  final String payment;

  /// Set when the trip is a reservation close to pickup that still needs
  /// a driver: its pickup time, e.g. "07:40". Radar shows it as a
  /// "Reservation" trip, never as Exclusive.
  final String? reservationTime;

  /// The rider's first name and trips, for the trip screen; empty / 0
  /// when not known.
  final String riderName;
  final int riderTrips;

  /// Stops between pickup and drop-off, in driving order.
  final List<ReservationStop> stops;

  /// Admin raised the fare by this much; [fare] already includes it.
  final Money? fareBoost;

  /// Display form of [fareBoost], e.g. `+40 kr`.
  String? get fareBoostLabel {
    final boost = fareBoost;
    return boost == null ? null : '+${boost.formattedShort}';
  }

  /// R8-4: on a cash trip, the cash to take from the rider when it is not
  /// the fare (rider promotions). Null: the fare.
  final Money? cashToCollect;

  /// Display form of [cashToCollect], e.g. `250,00 kr`.
  String? get cashToCollectLabel => cashToCollect?.formatted;

  bool get isReservation => reservationTime != null;

  /// Movera-paid extra for this driver (contract `Offer.driverBonus`, owner
  /// Q16). [fare] already includes it: the driver sees one total.
  final Money? driverBonus;

  /// Contract `Offer.driverEarnings`: the driver's net from the server's
  /// quote engine, [driverBonus] included (driver-r5-1). A net-fare card
  /// shows it instead of a share worked out on the phone; null for demo
  /// offers.
  final Money? driverEarnings;

  /// Contract `Offer.pickupPay`: the server's pickup pay for this offer
  /// (driver-r5-1). When set, cards and accepted terms use it instead of
  /// the local pickup pay rates; null for demo offers.
  final Money? pickupPay;

  /// Contract `Offer.priority`: the card shows the red "Priority" badge.
  final bool priority;

  /// Contract `Offer.source`.
  final OfferSource source;

  /// Contract `Offer.groupId`: the admin's radar group (up to 10 drivers,
  /// first to accept wins). Null for a direct assign.
  final String? groupId;

  /// Q18: the "Priority" badge shows when the offer is marked priority. Admin
  /// marks added money as priority by default and can untick it, so the
  /// money alone never shows the badge (live test 2026-11-02).
  bool get isPriority => priority;

  /// Contract §3.1: an admin direct assign (`source: admin`, no radar
  /// group). It is an Exclusive offer for this driver, never a Radar trip.
  bool get isAdminDirectAssign =>
      source == OfferSource.admin && groupId == null;

  /// Contract §3.1: one of an admin's radar group (`source: admin` with a
  /// `groupId`). A Radar trip: the first driver of the group to accept
  /// wins, and it never counts against the driver (Q45/Q46).
  bool get isRadarGroup => source == OfferSource.admin && groupId != null;

  /// Contract `Offer.kind`; null when dispatch did not send one (the demo).
  final OfferKind? kind;

  /// Contract `Offer.expiresAt`: when the server lets the offer go. Null
  /// when not known; the app's own offer time applies then.
  final DateTime? expiresAt;

  /// An Exclusive offer for this driver alone, answered with Accept or No
  /// through dispatch: an admin direct assign (§3.1), or dispatch's own
  /// `kind: exclusive` / `assigned` offer (§3). Never a Radar trip.
  bool get isExclusive =>
      isAdminDirectAssign ||
      (groupId == null &&
          (kind == OfferKind.exclusive || kind == OfferKind.assigned));

  /// Contract `Offer.version` (≥ 1): sent as `expectedVersion` when the
  /// driver accepts or declines it.
  final int version;
}

/// Why an offer left this driver (contract `OfferEvent` `offer_withdrawn`,
/// `offer.status`).
enum OfferGoneReason {
  /// Another driver accepted first (a radar group, or the admin locked
  /// the trip to someone else: `assignment_locked`).
  claimedElsewhere,

  /// Its time ran out on the server.
  expired,

  /// Dispatch or the admin took it back (rider cancelled, reassigned…).
  withdrawn;

  static OfferGoneReason fromWire(Object? status) => switch (status) {
    'claimed_elsewhere' || 'claimed' => OfferGoneReason.claimedElsewhere,
    'expired' => OfferGoneReason.expired,
    _ => OfferGoneReason.withdrawn,
  };
}

/// An offer that left this driver's feed, and why. Repositories send it
/// before the offer list without it, so screens can say why it went.
class OfferWithdrawal {
  const OfferWithdrawal({
    required this.offerId,
    required this.reason,
    this.tripId,
  });

  final String offerId;
  final String? tripId;
  final OfferGoneReason reason;
}

class ClaimResult {
  const ClaimResult._(this.outcome, {this.offer, this.afterCheck = false});

  const ClaimResult.success(RideOffer offer, {bool afterCheck = false})
    : this._(ClaimOutcome.success, offer: offer, afterCheck: afterCheck);

  const ClaimResult.alreadyClaimed({bool afterCheck = false})
    : this._(ClaimOutcome.alreadyClaimed, afterCheck: afterCheck);
  const ClaimResult.expired({bool afterCheck = false})
    : this._(ClaimOutcome.expired, afterCheck: afterCheck);
  const ClaimResult.unavailable({bool afterCheck = false})
    : this._(ClaimOutcome.unavailable, afterCheck: afterCheck);
  const ClaimResult.networkError() : this._(ClaimOutcome.networkError);

  final ClaimOutcome outcome;
  final RideOffer? offer;

  /// G4 decision 4 (contract v0.18.6 `driverOffers.acceptCheck`): the
  /// Accept's own answer was lost and this result is what
  /// `GET /driver/offers/{offerId}` said afterwards. Not won that way, the
  /// driver sees "Offer no longer available" (not a miss).
  final bool afterCheck;

  bool get isSuccess => outcome == ClaimOutcome.success;
}

/// Dispatch/Radar boundary. UI must not decide an atomic winner.
abstract interface class DispatchRepository {
  Stream<List<RideOffer>> watchNearbyOffers({
    bool destinationModeActive = false,
  });

  Stream<List<RideOffer>> watchNextTripOffers();

  /// Radar trips and open reservations alike: the server gives each one
  /// to the first driver who claims it (`POST /offers/{id}/accept`). Admin
  /// direct assigns and radar-group offers go through it too.
  Future<ClaimResult> claimOffer(String offerId);

  /// The driver said no to [offerId] (`POST /offers/{id}/decline`): an
  /// admin direct assign (Exclusive) or a radar-group trip. True when
  /// dispatch recorded it; false when the offer was already gone or the
  /// network failed (the server then lets it run out).
  Future<bool> declineOffer(String offerId, {String? reasonCode});

  /// Offers withdrawn from this driver (`offer_withdrawn`, and
  /// `assignment_locked` for a trip another driver took), with the
  /// reason. Each comes before the offer list without it.
  Stream<OfferWithdrawal> watchWithdrawals();

  void refreshOffers();

  /// The driver who took reservation [reservationId] cancelled it: it goes
  /// back out to drivers, to the step the admin rule "After a driver
  /// cancels" says (Radar trips too when it is close to pickup).
  void releaseReservation(String reservationId);

  /// Scheduled rides Movera assigns to this driver (Q29). Each needs the
  /// driver's Accept, claimed through [claimOffer], in time.
  Stream<ReservationRequestPreview> watchAssignments();
}

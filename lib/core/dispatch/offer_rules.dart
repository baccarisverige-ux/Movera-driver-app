import 'package:flutter/foundation.dart';
import 'package:movera/core/waybill/waybill.dart';

/// Offer rules the driver app follows, the same ones admin sets per zone in
/// Dispatch (Round 3, Q14–Q18). Today the app uses
/// [DriverOfferRules.current], whose defaults mirror the admin defaults; a
/// backend feeds it later.
class DriverOfferRules {
  const DriverOfferRules({
    this.card = const OfferCardDetails(),
    this.exclusiveReasons = defaultExclusiveReasons,
    this.autoOffline = true,
    this.autoOfflineAfter = defaultAutoOfflineAfter,
    this.hiddenComesBackAfter = const Duration(minutes: 2),
    this.exclusiveWhileDriving = true,
    this.exclusiveWhileDrivingCount = 1,
    this.commissionRate = WaybillPayment.serviceFeeRate,
    this.exclusiveAcceptTime = const Duration(seconds: 15),
    this.radarTime = const Duration(seconds: 15),
  });

  /// The rules in use. Mirrors the admin defaults until a backend sets it.
  static DriverOfferRules current = const DriverOfferRules();

  /// Q46: Exclusive offers missed or declined in a row before the driver
  /// goes offline. The fallback: the zone's `DriverAppConfig` sets its own
  /// number (`offers.autoOffline.missedExclusive`) through
  /// [withAutoOffline] when it is applied.
  static const int defaultAutoOfflineAfter = 3;

  /// Q14: what the offer cards show.
  final OfferCardDetails card;

  /// Q15: why an offer is Exclusive, short texts admin edits and switches.
  final List<ExclusiveReasonRule> exclusiveReasons;

  /// Q16: after this many Exclusive (one-driver) offers in a row not
  /// accepted, the driver goes offline. Radar trips never count.
  final bool autoOffline;
  final int autoOfflineAfter;

  /// Q17: a trip hidden with × in the Live list can come back after this
  /// long, if it is still open there. It never counts against the driver.
  final Duration hiddenComesBackAfter;

  /// Q18: while driving a rider only Exclusive offers come, at most this
  /// many at a time. No Radar trips during a trip.
  final bool exclusiveWhileDriving;
  final int exclusiveWhileDrivingCount;

  /// Movera's share of a fare: the driver's share is the rest, and on a
  /// cash trip this is what the driver owes Movera.
  final double commissionRate;

  /// Dispatch › Exclusive "time to accept": how long an Exclusive offer
  /// waits for Accept, on Home and while driving a rider.
  final Duration exclusiveAcceptTime;

  /// Dispatch › Radar "time on the radar": how long a Radar trip on Home
  /// can be taken before its Match fades.
  final Duration radarTime;

  /// These rules with the zone's auto-offline setting
  /// (`offers.autoOffline`, Q46); everything else unchanged.
  DriverOfferRules withAutoOffline({required bool on, required int after}) =>
      DriverOfferRules(
        card: card,
        exclusiveReasons: exclusiveReasons,
        autoOffline: on,
        autoOfflineAfter: after < 1 ? defaultAutoOfflineAfter : after,
        hiddenComesBackAfter: hiddenComesBackAfter,
        exclusiveWhileDriving: exclusiveWhileDriving,
        exclusiveWhileDrivingCount: exclusiveWhileDrivingCount,
        commissionRate: commissionRate,
        exclusiveAcceptTime: exclusiveAcceptTime,
        radarTime: radarTime,
      );

  /// The text of Exclusive reason [id], or '' when admin switched it off
  /// or it is unknown.
  String reasonText(String id) {
    for (final reason in exclusiveReasons) {
      if (reason.id == id) {
        return reason.on ? reason.text : '';
      }
    }
    return '';
  }
}

/// Q14: each detail on the Radar card, the Exclusive card and the
/// reservation popup, on or off per zone.
class OfferCardDetails {
  const OfferCardDetails({
    this.netFare = false,
    this.pickupAddress = true,
    this.dropoffAreaOnly = false,
    this.stops = true,
    this.riderRating = true,
    this.tripMinutesKm = true,
    this.pickupDistance = true,
    this.badges = true,
  });

  /// The driver's share instead of the full fare.
  final bool netFare;

  /// Where the pickup is. Off: only "Pickup nearby".
  final bool pickupAddress;

  /// Only the area of the drop-off, not the street.
  final bool dropoffAreaOnly;

  /// The number of stops.
  final bool stops;

  /// The rider's rating and trips.
  final bool riderRating;

  /// The trip's minutes and km.
  final bool tripMinutesKm;

  /// How far the pickup is.
  final bool pickupDistance;

  /// Cash, Reservation, bags, fare boost and other extras.
  final bool badges;

  OfferCardDetails copyWith({
    bool? netFare,
    bool? pickupAddress,
    bool? dropoffAreaOnly,
    bool? stops,
    bool? riderRating,
    bool? tripMinutesKm,
    bool? pickupDistance,
    bool? badges,
  }) => OfferCardDetails(
    netFare: netFare ?? this.netFare,
    pickupAddress: pickupAddress ?? this.pickupAddress,
    dropoffAreaOnly: dropoffAreaOnly ?? this.dropoffAreaOnly,
    stops: stops ?? this.stops,
    riderRating: riderRating ?? this.riderRating,
    tripMinutesKm: tripMinutesKm ?? this.tripMinutesKm,
    pickupDistance: pickupDistance ?? this.pickupDistance,
    badges: badges ?? this.badges,
  );

  /// The fare as the card shows it: the full fare, or the driver's share
  /// after Movera's commission. Movera's [bonus] in [full] (Q16) is never
  /// charged commission: the share keeps all of it.
  String fare(String full, {double? commissionRate, String? bonus}) {
    if (!netFare) {
      return full;
    }
    final payment = WaybillPayment.fromFare(
      full,
      feeRate: commissionRate ?? DriverOfferRules.current.commissionRate,
      bonus: bonus,
    );
    return payment?.earnings ?? full;
  }
}

/// One Exclusive reason: a short text admin can edit and switch off.
class ExclusiveReasonRule {
  const ExclusiveReasonRule({
    required this.id,
    required this.text,
    this.on = true,
  });

  final String id;
  final String text;
  final bool on;
}

/// The admin defaults (Q15).
const List<ExclusiveReasonRule> defaultExclusiveReasons = [
  ExclusiveReasonRule(id: 'best-match', text: 'Best match'),
  ExclusiveReasonRule(id: 'favourite', text: "Rider's favourite"),
  ExclusiveReasonRule(id: 'finishing-nearby', text: 'Finishing nearby'),
  ExclusiveReasonRule(id: 'airport-queue', text: 'Airport queue'),
  ExclusiveReasonRule(id: 'pickup-soon', text: 'Pickup soon'),
  ExclusiveReasonRule(id: 'nearby', text: 'Only for you · nearby'),
];

/// The driver's own choices for offers, kept for this app session.
class DriverOfferPreferences {
  const DriverOfferPreferences._();

  /// Q23: cash rides on or off, from the Home sheet. Off: no cash offers.
  static final ValueNotifier<bool> acceptsCash = ValueNotifier<bool>(true);

  @visibleForTesting
  static void reset() {
    acceptsCash.value = true;
    ExclusiveAnswers.instance.reset();
  }
}

/// Q16: Exclusive and other one-driver offers this driver did not accept,
/// in a row. Radar trips never count, here or in the acceptance rate.
class ExclusiveAnswers {
  ExclusiveAnswers._();

  static final ExclusiveAnswers instance = ExclusiveAnswers._();

  int _missedInRow = 0;

  int get missedInRow => _missedInRow;

  /// The driver accepted one: the row starts again.
  void accepted() => _missedInRow = 0;

  /// One went by without Accept (ran out or ×). True when the row reaches
  /// the admin's limit: the driver goes offline.
  bool missed([DriverOfferRules? rules]) {
    final limit = rules ?? DriverOfferRules.current;
    _missedInRow++;
    if (!limit.autoOffline || _missedInRow < limit.autoOfflineAfter) {
      return false;
    }
    _missedInRow = 0;
    return true;
  }

  /// One more missed offer takes the driver offline.
  bool lastBeforeOffline([DriverOfferRules? rules]) {
    final limit = rules ?? DriverOfferRules.current;
    return limit.autoOffline && _missedInRow == limit.autoOfflineAfter - 1;
  }

  void reset() => _missedInRow = 0;
}

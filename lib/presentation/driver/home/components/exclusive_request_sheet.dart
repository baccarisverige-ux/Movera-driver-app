import 'package:flutter/material.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/presentation/driver/home/components/home_offer_sheet.dart';
import 'package:movera/widgets/offer_badges.dart';
import 'package:movera/widgets/pickup_pay_line.dart';
import 'package:movera/widgets/radar_offer_card.dart';

/// The Exclusive offer on Home: the same sheet as the reservation request
/// ([OfferSheetBody]), with no picture and no blue. Category and cash
/// chips, the fare (pickup pay and boost included), the trip minutes,
/// pickup with its minutes and drop-off with the trip distance, and a
/// grey pill counting down "Exclusive for you · 12 s". The grey radar orb
/// on the sheet's top edge accepts.
class ExclusiveRequestSheet extends StatelessWidget {
  const ExclusiveRequestSheet({
    super.key,
    required this.offer,
    required this.secondsLeft,
    this.reservation = false,
    this.reservationTime,
    this.onYourWay = false,
    this.details,
    this.lead = defaultLead,
  });

  final RadarOfferView offer;

  /// Seconds left to accept, on the pill.
  final int secondsLeft;

  /// A reservation close to pickup with no driver yet, and its time.
  final bool reservation;
  final String? reservationTime;

  /// Destination mode is on and the trip goes the driver's way.
  final bool onYourWay;

  /// Which details show (Q14); the admin's choice by default.
  final OfferCardDetails? details;

  /// The pill's words before the seconds: "Exclusive for you", or
  /// "Assigned by Movera" for a ride Movera assigned (Q29).
  final String lead;

  static const String defaultLead = 'Exclusive for you';
  static const String _prefix = 'exclusive';

  /// "Exclusive for you · 12 s".
  static String pillLabel(int seconds, [String lead = defaultLead]) =>
      '$lead · ${seconds < 0 ? 0 : seconds} s';

  @override
  Widget build(BuildContext context) {
    final show = details ?? DriverOfferRules.current.card;
    // The fare with any pickup pay added: one total.
    final (whole, rest) = OfferSheetBody.fareParts(offer.shownFare(show));
    final pickupPlace = show.pickupAddress
        ? RadarOfferView.street(offer.pickup)
        : driverText(DriverTexts.offerPickupNearby);
    final dropoffPlace = show.dropoffAreaOnly
        ? RadarOfferView.area(offer.dropoff)
        : RadarOfferView.street(offer.dropoff);
    final id = offer.id;
    return OfferSheetBody(
      keyPrefix: _prefix,
      bodyKey: ValueKey<String>('exclusive-offer-card-$id'),
      category: offer.category,
      chips: [
        // Q18: admin's priority or added money; the fare has it.
        if (offer.priority)
          OfferBadge.priority(
            key: ValueKey<String>('exclusive-offer-priority-$id'),
          ),
        if (show.badges && offer.cash)
          OfferBadge.cash(key: ValueKey<String>('exclusive-offer-cash-$id')),
        if (show.badges && reservation)
          OfferBadge.reservation(
            reservationTime,
            key: ValueKey<String>('exclusive-offer-reservation-$id'),
          ),
        // Admin raised the fare (Q13); the price has it.
        if (offer.fareBoost case final boost? when show.badges)
          OfferBadge.boost(
            boost,
            key: ValueKey<String>('exclusive-offer-boost-$id'),
          ),
        if (onYourWay) OfferBadge.note(driverText(DriverTexts.offerOnYourWay)),
      ],
      fareWhole: whole,
      fareRest: rest,
      trip: show.tripMinutesKm ? '${offer.tripMinutes} min trip' : null,
      // "incl. … pickup" under the total, when admin shows it.
      underFare: PickupPayLine(
        quote: offer.pickupPay,
        padding: const EdgeInsets.only(top: 4),
      ),
      pickup: OfferSheetStop(
        place: pickupPlace,
        pickup: true,
        trailing: '${offer.pickupMinutes} min',
      ),
      stops: show.stops && offer.stops > 0 ? offer.stopsLabel : null,
      dropoff: OfferSheetStop(
        place: dropoffPlace,
        pickup: false,
        trailing: show.tripMinutesKm ? OfferSheetBody.km(offer.tripKm) : null,
      ),
      pillIcon: AppAssets.solarCheckCircle,
      pillLabel: pillLabel(secondsLeft, lead),
      pillKey: 'timer',
    );
  }
}

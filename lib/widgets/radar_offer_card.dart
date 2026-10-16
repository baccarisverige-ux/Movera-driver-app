import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/dispatch/pickup_pay.dart';
import 'package:movera/widgets/offer_badges.dart';
import 'package:movera/widgets/pickup_pay_line.dart';

/// What a Radar offer card shows. The same card is used on Home (the deck
/// above the radar) and in the full-screen Live list.
class RadarOfferView {
  const RadarOfferView({
    required this.id,
    required this.category,
    required this.payment,
    required this.rating,
    required this.fare,
    required this.pickupMinutes,
    required this.pickupKm,
    required this.tripMinutes,
    required this.tripKm,
    required this.pickup,
    required this.dropoff,
    this.bags = 0,
    this.reservationTime,
    this.fareBoost,
    this.stops = 0,
    this.riderTrips = 0,
    this.pickupPay,
  });

  final String id;
  final String category;

  /// How the rider pays, e.g. "Card", "Apple Pay" or "Cash". The card only
  /// says it when it is cash (see [cash]).
  final String payment;
  final String rating;
  final String fare;
  final int pickupMinutes;
  final double pickupKm;
  final int tripMinutes;
  final double tripKm;
  final String pickup;
  final String dropoff;
  final int bags;

  /// A reservation close to pickup that joined the Radar trips: its pickup
  /// time, e.g. "07:40". The card then shows a "Reservation" badge, and
  /// never "Exclusive" (notes E5).
  final String? reservationTime;

  /// Admin raised the fare because no driver was near the pickup, e.g.
  /// "+40 kr". [fare] is already the new fare (Q13).
  final String? fareBoost;

  /// Stops between pickup and drop-off.
  final int stops;

  /// The rider's trips; 0 when not known.
  final int riderTrips;

  /// Pickup pay worked out when the offer shows; null for none.
  final PickupPayQuote? pickupPay;

  /// The fare as the card shows it ([OfferCardDetails.fare]) with the
  /// pickup pay added: one total.
  String shownFare(OfferCardDetails show) {
    final base = show.fare(fare);
    return pickupPay?.totalOf(base) ?? base;
  }

  /// The rider pays cash in the car (not paid in the app).
  bool get cash => isCash(payment);

  static bool isCash(String payment) => payment.trim().toLowerCase() == 'cash';

  /// "Hantverkargatan 4, Stockholm" → "Stockholm".
  static String area(String address) {
    final parts = address.split(',');
    final last = parts.last.trim();
    return last.isEmpty ? address.trim() : last;
  }

  /// "Hantverkargatan 4, Stockholm" → "Hantverkargatan 4".
  static String street(String address) {
    final first = address.split(',').first.trim();
    return first.isEmpty ? address.trim() : first;
  }

  /// "1 stop", "2 stops"; '' with none.
  String get stopsLabel =>
      stops <= 0 ? '' : '$stops stop${stops == 1 ? '' : 's'}';

  /// "4.95" or, with the trips known, "4.95 · 86 trips".
  String get ratingLabel =>
      riderTrips > 0 ? '$rating · $riderTrips trips' : rating;
}

enum RadarOfferCardState { available, matching, expired, taken }

/// Pure white card with a fine black outline: category badge, a
/// Reservation badge for a reservation, a Cash badge only when the rider
/// pays cash, bags, rating; big price and pickup
/// time; then pickup → drop-off and Route + Match.
class RadarOfferCard extends StatelessWidget {
  const RadarOfferCard({
    super.key,
    required this.offer,
    this.state = RadarOfferCardState.available,
    this.onMatch,
    this.onRoute,
    this.onDismiss,
    this.details,
  });

  final RadarOfferView offer;

  /// Which details show (Q14); the admin's choice by default.
  final OfferCardDetails? details;
  final RadarOfferCardState state;
  final VoidCallback? onMatch;
  final VoidCallback? onRoute;

  /// Shows the × in the header (full-screen list only).
  final VoidCallback? onDismiss;

  static const Color ink = Color(0xFF111518);
  static const Color muted = Color(0xFF7C868D);
  static const Color label = Color(0xFF8A9399);
  /// Offer cards are pure white; the header keeps only its hairline.
  static const Color headerTint = Colors.white;

  Widget _icon(String asset, double size, Color color) => SvgPicture.asset(
    asset,
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );

  @override
  Widget build(BuildContext context) {
    final show = details ?? DriverOfferRules.current.card;
    final fare = offer.shownFare(show);
    final comma = fare.indexOf(',');
    final whole = comma > 0 ? fare.substring(0, comma) : fare;
    final rest = comma > 0 ? fare.substring(comma) : '';
    final matching = state == RadarOfferCardState.matching;
    final enabled = state == RadarOfferCardState.available && onMatch != null;

    final header = Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 18, 18),
      decoration: const BoxDecoration(
        color: headerTint,
        border: Border(bottom: BorderSide(color: Color(0xFFE6E8EA))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Payment shows only when it is cash; narrow phones wrap the
              // badges instead of cutting them.
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      key: ValueKey<String>('radar-offer-category-${offer.id}'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: ink),
                      ),
                      child: Text(
                        offer.category,
                        style: const TextStyle(
                          color: ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (show.badges && offer.reservationTime != null)
                      OfferBadge.reservation(
                        offer.reservationTime,
                        key: ValueKey<String>(
                          'radar-offer-reservation-${offer.id}',
                        ),
                      ),
                    if (show.badges && offer.cash)
                      OfferBadge.cash(
                        key: ValueKey<String>('radar-offer-cash-${offer.id}'),
                      ),
                    if (offer.fareBoost case final boost? when show.badges)
                      OfferBadge.boost(
                        boost,
                        key: ValueKey<String>('radar-offer-boost-${offer.id}'),
                      ),
                    // The rider's trips, next to the badges so the header
                    // still fits a narrow phone.
                    if (show.riderRating && offer.riderTrips > 0)
                      Text(
                        '${offer.riderTrips} trips',
                        key: ValueKey<String>('radar-offer-trips-${offer.id}'),
                        style: const TextStyle(
                          color: Color(0xFF3A444B),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (show.badges && offer.bags > 0)
                      Row(
                        key: ValueKey<String>('radar-offer-bags-${offer.id}'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _icon(AppAssets.offerBags, 15, const Color(0xFF3A444B)),
                          const SizedBox(width: 4),
                          Text(
                            '${offer.bags}',
                            style: const TextStyle(
                              color: Color(0xFF3A444B),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (show.riderRating) ...[
              const SizedBox(width: 8),
              Container(
                key: ValueKey<String>('radar-offer-rating-${offer.id}'),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: const Color(0xFFECEEF0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _icon(AppAssets.offerStar, 12, ink),
                    const SizedBox(width: 5),
                    Text(
                      offer.rating,
                      style: const TextStyle(
                        color: ink,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              ],
              if (onDismiss != null) ...[
                const SizedBox(width: 6),
                Material(
                  color: Colors.white,
                  shape: const CircleBorder(
                    side: BorderSide(color: Color(0xFFE3E6E8)),
                  ),
                  child: InkWell(
                    key: ValueKey<String>('radar-offer-dismiss-${offer.id}'),
                    customBorder: const CircleBorder(),
                    onTap: onDismiss,
                    child: const SizedBox(
                      width: 30,
                      height: 30,
                      child: Icon(
                        Icons.close_rounded,
                        size: 17,
                        color: Color(0xFF5F6B72),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (show.netFare)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                driverText(DriverTexts.offerYourShare).toUpperCase(),
                key: const ValueKey<String>('radar-offer-net-fare'),
                style: const TextStyle(
                  color: label,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: whole,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 42,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.8,
                    ),
                    children: [
                      TextSpan(
                        text: rest,
                        style: const TextStyle(
                          color: label,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    driverText(DriverTexts.offerPickup).toUpperCase(),
                    style: const TextStyle(
                      color: label,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${offer.pickupMinutes} min',
                    style: const TextStyle(
                      color: ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          PickupPayLine(quote: offer.pickupPay),
        ],
      ),
    );

    Widget stop(String place, String detail) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          place,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: ink,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          detail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: muted, fontSize: 12.5),
        ),
      ],
    );

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              Positioned(
                left: 3,
                top: 6,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ink, width: 2.5),
                  ),
                ),
              ),
              Positioned(
                left: 8,
                top: 22,
                bottom: 24,
                child: Container(width: 1.5, color: const Color(0xFFD9DDE0)),
              ),
              Positioned(
                left: 3,
                bottom: 8,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: ink,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    stop(
                      show.pickupAddress
                          ? RadarOfferView.street(offer.pickup)
                          : driverText(DriverTexts.offerPickupNearby),
                      show.pickupDistance
                          ? driverText(DriverTexts.offerKmAway, {
                              'km': offer.pickupKm.toStringAsFixed(1),
                            })
                          : driverText(DriverTexts.offerPickup),
                    ),
                    const SizedBox(height: 14),
                    stop(
                      RadarOfferView.area(offer.dropoff),
                      [
                        if (show.tripMinutesKm)
                          driverText(DriverTexts.offerTripLength, {
                            'minutes': offer.tripMinutes,
                            'km': offer.tripKm.toStringAsFixed(1),
                          }),
                        if (show.stops && offer.stops > 0) offer.stopsLabel,
                      ].join(' · ').ifEmpty(driverText(DriverTexts.offerDropoff)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (onRoute != null) ...[
                Material(
                  color: const Color(0xFFF2F3F5),
                  borderRadius: BorderRadius.circular(17),
                  child: InkWell(
                    key: ValueKey<String>('radar-route-${offer.id}'),
                    borderRadius: BorderRadius.circular(17),
                    onTap: matching ? null : onRoute,
                    child: SizedBox(
                      width: 54,
                      height: 54,
                      child: Center(
                        child: _icon(AppAssets.offerRoute, 22, ink),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: FilledButton(
                    key: ValueKey<String>('radar-match-${offer.id}'),
                    onPressed: enabled ? onMatch : null,
                    style: FilledButton.styleFrom(
                      elevation: 0,
                      backgroundColor: ink,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          state == RadarOfferCardState.expired
                          ? ink.withValues(alpha: 0.28)
                          : const Color(0xFFD9DEDF),
                      disabledForegroundColor:
                          state == RadarOfferCardState.expired
                          ? Colors.white
                          : const Color(0xFF727E83),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    child: matching
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF727E83),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                driverText(DriverTexts.offerMatching),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            driverText(DriverTexts.offerMatch),
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Container(
      key: ValueKey<String>('radar-offer-card-${offer.id}'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: ink),
        boxShadow: const [
          BoxShadow(
            color: Color(0x290A0E10),
            blurRadius: 40,
            offset: Offset(0, 18),
          ),
          BoxShadow(
            color: Color(0x0F0A0E10),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [header, body],
        ),
      ),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/dispatch/exclusive_reasons.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/widgets/offer_badges.dart';
import 'package:movera/widgets/radar_offer_card.dart';

/// An Exclusive offer on Home: a trip offered to this driver only, a
/// reservation close to pickup that still has no driver, or a scheduled
/// ride Movera assigned to this driver. Same look as the
/// Radar cards, a little bigger: soft grey header with the badges, the
/// black "Exclusive" mark and its reason, the price and pickup time; then
/// pickup → drop-off and Route + Accept, whose darker part shrinks with the
/// time left.
class ExclusiveOfferCard extends StatelessWidget {
  const ExclusiveOfferCard({
    super.key,
    required this.offer,
    required this.lifetime,
    this.onAccept,
    this.onRoute,
    this.onDismiss,
    this.reservation = false,
    this.reservationTime,
    this.onYourWay = false,
    this.reason,
    this.details,
  });

  /// Which details show (Q14); the admin's choice by default.
  final OfferCardDetails? details;

  /// The short reason next to the "Exclusive" mark, from the offer; see
  /// [ExclusiveReasons].
  final String? reason;

  final RadarOfferView offer;

  /// How long the offer stays; Accept counts it down.
  final Duration lifetime;
  final VoidCallback? onAccept;
  final VoidCallback? onRoute;

  /// The × top-right: hides the offer.
  final VoidCallback? onDismiss;

  /// A reservation close to pickup with no driver yet.
  final bool reservation;

  /// Its pickup time, e.g. "07:40".
  final String? reservationTime;

  /// Destination mode is on and the trip goes the driver's way.
  final bool onYourWay;

  static const Color ink = RadarOfferCard.ink;
  static const Color muted = RadarOfferCard.muted;
  static const Color label = RadarOfferCard.label;
  static const Color headerTint = RadarOfferCard.headerTint;

  Widget _icon(String asset, double size, Color color, {String? semantics}) =>
      SvgPicture.asset(
        asset,
        width: size,
        height: size,
        semanticsLabel: semantics,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );

  @override
  Widget build(BuildContext context) {
    final show = details ?? DriverOfferRules.current.card;
    final fare = show.fare(offer.fare);
    final comma = fare.indexOf(',');
    final whole = comma > 0 ? fare.substring(0, comma) : fare;
    final rest = comma > 0 ? fare.substring(comma) : '';
    final why = reason ?? ExclusiveReasons.defaultFor(reservation: reservation);
    const detailStyle = TextStyle(
      color: Color(0xFF3A444B),
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
    );

    final header = Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 18),
      decoration: const BoxDecoration(
        color: headerTint,
        border: Border(bottom: BorderSide(color: Color(0xFFE6E8EA))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 7,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OfferBadge.category(
                      offer.category,
                      key: ValueKey<String>(
                        'exclusive-offer-category-${offer.id}',
                      ),
                    ),
                    if (show.badges && reservation)
                      OfferBadge.reservation(
                        reservationTime,
                        key: ValueKey<String>(
                          'exclusive-offer-reservation-${offer.id}',
                        ),
                      ),
                    if (show.badges && offer.cash)
                      OfferBadge.cash(
                        key: ValueKey<String>(
                          'exclusive-offer-cash-${offer.id}',
                        ),
                      ),
                    if (offer.fareBoost case final boost? when show.badges)
                      OfferBadge.boost(
                        boost,
                        key: ValueKey<String>(
                          'exclusive-offer-boost-${offer.id}',
                        ),
                      ),
                    if (onYourWay) const OfferBadge.note('On your way'),
                  ],
                ),
              ),
              if (onDismiss != null) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Hide offer',
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(
                      side: BorderSide(color: Color(0xFFE3E6E8)),
                    ),
                    child: InkWell(
                      key: const ValueKey<String>('direct-offer-dismiss'),
                      customBorder: const CircleBorder(),
                      onTap: onDismiss,
                      child: const SizedBox(
                        width: 32,
                        height: 32,
                        child: Icon(
                          Icons.close_rounded,
                          size: 17,
                          color: Color(0xFF5F6B72),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OfferBadge.exclusive(
                key: ValueKey<String>('exclusive-offer-mark-${offer.id}'),
              ),
              const SizedBox(width: 8),
              if (why.isNotEmpty)
              Flexible(
                child: Text(
                  why,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF5F6B72),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (show.netFare)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text(
                'YOUR SHARE',
                key: ValueKey<String>('exclusive-offer-net-fare'),
                style: TextStyle(
                  color: label,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
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
                      fontSize: 44,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.8,
                    ),
                    children: [
                      TextSpan(
                        text: rest,
                        style: const TextStyle(
                          color: label,
                          fontSize: 21,
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
                  const Text(
                    'PICKUP',
                    style: TextStyle(
                      color: label,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${offer.pickupMinutes} min',
                    style: const TextStyle(
                      color: ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (show.riderRating || (show.badges && offer.bags > 0))
            const SizedBox(height: 10),
          Row(
            children: [
              if (show.riderRating) ...[
                _icon(AppAssets.offerStar, 13, const Color(0xFF3A444B)),
                const SizedBox(width: 4),
                Text(
                  offer.ratingLabel,
                  key: ValueKey<String>('exclusive-offer-rating-${offer.id}'),
                  style: detailStyle,
                ),
              ],
              if (show.badges && offer.bags > 0) ...[
                const SizedBox(width: 12),
                Row(
                  key: ValueKey<String>('exclusive-offer-bags-${offer.id}'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _icon(AppAssets.offerBags, 13, const Color(0xFF3A444B)),
                    const SizedBox(width: 4),
                    Text('${offer.bags}', style: detailStyle),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );

    Widget marker({required bool dropoff}) => Container(
      width: 11,
      height: 11,
      decoration: dropoff
          ? BoxDecoration(color: ink, borderRadius: BorderRadius.circular(3))
          : BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: ink, width: 2.5),
            ),
    );

    // Street in bold with its area under it; time and distance on the
    // right. The pickup's line runs down to the drop-off square.
    Widget stop({
      required bool dropoff,
      required String address,
      required String value,
      required String detail,
    }) {
      final hidden = !dropoff && !show.pickupAddress;
      final areaOnly = dropoff && show.dropoffAreaOnly;
      final place = hidden
          ? 'Pickup nearby'
          : areaOnly
          ? RadarOfferView.area(address)
          : RadarOfferView.street(address);
      final area = hidden || areaOnly ? '' : RadarOfferView.area(address);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: marker(dropoff: dropoff),
                ),
                if (!dropoff) ...[
                  const SizedBox(height: 5),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 7.75),
                      child: Container(
                        width: 1.5,
                        color: const Color(0xFFD9DDE0),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: dropoff ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (area.isNotEmpty && area != place) ...[
                    const SizedBox(height: 2),
                    Text(
                      area,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: muted, fontSize: 12.5),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (value.isNotEmpty || detail.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: const TextStyle(color: muted, fontSize: 12.5),
              ),
            ],
          ),
        ],
      );
    }

    final accept = FilledButton(
      onPressed: onAccept,
      clipBehavior: Clip.antiAlias,
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: const Color(0xFF2A2F33),
        foregroundColor: Colors.white,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      ),
      // The time left is the darker part of the button; it shrinks to
      // the left, with the seconds next to "Accept".
      child: TweenAnimationBuilder<double>(
        key: ValueKey<String>('direct-offer-countdown-${offer.id}'),
        tween: Tween<double>(begin: 1, end: 0),
        duration: lifetime,
        builder: (context, remaining, child) {
          final seconds = (remaining * lifetime.inMilliseconds / 1000).ceil();
          return Stack(
            fit: StackFit.expand,
            children: [
              FractionallySizedBox(
                key: const ValueKey<String>('direct-offer-countdown-fill'),
                alignment: Alignment.centerLeft,
                widthFactor: remaining,
                child: const ColoredBox(color: ink),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Accept',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      ' · ',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${seconds}s',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: stop(
              dropoff: false,
              address: offer.pickup,
              value: '${offer.pickupMinutes} min',
              detail: show.pickupDistance
                  ? '${offer.pickupKm.toStringAsFixed(1)} km away'
                  : '',
            ),
          ),
          stop(
            dropoff: true,
            address: offer.dropoff,
            value: show.tripMinutesKm ? '${offer.tripMinutes} min' : '',
            detail: [
              if (show.tripMinutesKm) '${offer.tripKm.toStringAsFixed(1)} km ride',
              if (show.stops && offer.stops > 0) offer.stopsLabel,
            ].join(' · '),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: TextButton(
                  key: const ValueKey<String>('direct-offer-route'),
                  onPressed: onRoute,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(56, 56),
                    backgroundColor: const Color(0xFFF2F3F5),
                    foregroundColor: ink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  child: _icon(
                    AppAssets.offerRoute,
                    22,
                    ink,
                    semantics: 'Route',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: SizedBox(height: 56, child: accept)),
            ],
          ),
        ],
      ),
    );

    return Container(
      key: ValueKey<String>('exclusive-offer-card-${offer.id}'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: ink),
        boxShadow: const [
          BoxShadow(
            color: Color(0x300A0E10),
            blurRadius: 44,
            offset: Offset(0, 24),
          ),
          BoxShadow(
            color: Color(0x120A0E10),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [header, body],
        ),
      ),
    );
  }
}

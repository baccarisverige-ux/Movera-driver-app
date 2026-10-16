import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/dispatch/exclusive_reasons.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/widgets/offer_badges.dart';
import 'package:movera/widgets/radar_offer_card.dart';

/// An Exclusive offer on Home: a trip offered to this driver only, a
/// reservation close to pickup that still has no driver, or a scheduled
/// ride Movera assigned to this driver.
///
/// The card is the top of the Home sheet while the offer is live: pure
/// white, a rounded top with a thin black contour, and its bottom
/// ([bottomInset]) running behind the dock. It has no Accept: the blue
/// radar in the dock is the Accept, ringed by the time left. The card
/// shows the blue "Exclusive" tag and the ride type, the price, one grey
/// line with the reason and the pickup minutes, pickup → drop-off and a
/// quiet "View route".
class ExclusiveOfferCard extends StatelessWidget {
  const ExclusiveOfferCard({
    super.key,
    required this.offer,
    this.onRoute,
    this.onDismiss,
    this.reservation = false,
    this.reservationTime,
    this.onYourWay = false,
    this.reason,
    this.details,
    this.bottomInset = 22,
    this.maxContentHeight,
  });

  /// Which details show (Q14); the admin's choice by default.
  final OfferCardDetails? details;

  /// Why it is Exclusive, from the offer; see [ExclusiveReasons].
  final String? reason;

  final RadarOfferView offer;

  /// "View route": the route preview on the map.
  final VoidCallback? onRoute;

  /// The × top-right: hides the offer.
  final VoidCallback? onDismiss;

  /// A reservation close to pickup with no driver yet.
  final bool reservation;

  /// Its pickup time, e.g. "07:40".
  final String? reservationTime;

  /// Destination mode is on and the trip goes the driver's way.
  final bool onYourWay;

  /// Space under the content: on Home the part behind the dock and radar.
  final double bottomInset;

  /// On a short phone the content scrolls above this height.
  final double? maxContentHeight;

  static const Color ink = RadarOfferCard.ink;
  static const Color blue = Color(0xFF1769E8);
  static const Color blueTint = Color(0xFFEAF1FD);
  static const Color fareGrey = Color(0xFFA2AAB0);
  static const Color lineGrey = Color(0xFF5B656C);
  static const Color stopGrey = Color(0xFF8B949A);
  static const Color hairline = Color(0xFFEEF0F1);
  static const Color soft = Color(0xFFF2F4F5);

  Widget _icon(String asset, double size, Color color, {String? semantics}) =>
      SvgPicture.asset(
        asset,
        width: size,
        height: size,
        semanticsLabel: semantics,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );

  Widget _tag({
    required Key key,
    required String label,
    required String icon,
    required Color background,
    required Color foreground,
  }) => Container(
    key: key,
    padding: const EdgeInsets.fromLTRB(7, 5, 9, 5),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _icon(icon, 14, foreground),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  /// Grey soft circle with a drawn ×.
  Widget _hide() {
    Widget bar(double angle) => Transform.rotate(
      angle: angle,
      child: Container(
        width: 12,
        height: 1.6,
        decoration: BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
    return Tooltip(
      message: driverText(DriverTexts.offerHide),
      child: Material(
        color: soft,
        shape: const CircleBorder(),
        child: InkWell(
          key: const ValueKey<String>('direct-offer-dismiss'),
          customBorder: const CircleBorder(),
          onTap: onDismiss,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Stack(
              alignment: Alignment.center,
              children: [bar(0.785398), bar(-0.785398)],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final show = details ?? DriverOfferRules.current.card;
    final fare = show.fare(offer.fare);
    final comma = fare.indexOf(',');
    final whole = comma > 0 ? fare.substring(0, comma) : fare;
    final rest = comma > 0 ? fare.substring(comma) : '';
    var why = reason ?? ExclusiveReasons.defaultFor(reservation: reservation);
    // The line says how near the pickup is, so "nearby" goes.
    const nearby = ' · nearby';
    if (why.endsWith(nearby)) {
      why = why.substring(0, why.length - nearby.length);
    }

    final header = Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _tag(
                key: ValueKey<String>('exclusive-offer-mark-${offer.id}'),
                label: 'Exclusive',
                icon: AppAssets.solarBolt,
                background: blueTint,
                foreground: blue,
              ),
              _tag(
                key: ValueKey<String>('exclusive-offer-category-${offer.id}'),
                label: offer.category,
                icon: AppAssets.solarUser,
                background: ink,
                foreground: Colors.white,
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
                  key: ValueKey<String>('exclusive-offer-cash-${offer.id}'),
                ),
              if (offer.fareBoost case final boost? when show.badges)
                OfferBadge.boost(
                  boost,
                  key: ValueKey<String>('exclusive-offer-boost-${offer.id}'),
                ),
              if (onYourWay)
                OfferBadge.note(driverText(DriverTexts.offerOnYourWay)),
            ],
          ),
        ),
        if (onDismiss != null) ...[const SizedBox(width: 8), _hide()],
      ],
    );

    const detailStyle = TextStyle(
      color: ink,
      fontSize: 14,
      fontWeight: FontWeight.w700,
    );
    final price = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (show.netFare)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    driverText(DriverTexts.offerYourShare).toUpperCase(),
                    key: const ValueKey<String>('exclusive-offer-net-fare'),
                    style: const TextStyle(
                      color: RadarOfferCard.label,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              Text.rich(
                TextSpan(
                  text: whole,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 46,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -2,
                  ),
                  children: [
                    TextSpan(
                      text: rest,
                      style: const TextStyle(
                        color: fareGrey,
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
              ),
            ],
          ),
        ),
        if (show.riderRating)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              key: ValueKey<String>('exclusive-offer-rating-${offer.id}'),
              mainAxisSize: MainAxisSize.min,
              children: [
                _icon(AppAssets.offerStar, 15, ink),
                const SizedBox(width: 4),
                Text(offer.ratingLabel, style: detailStyle),
              ],
            ),
          ),
        if (show.badges && offer.bags > 0)
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 4),
            child: Row(
              key: ValueKey<String>('exclusive-offer-bags-${offer.id}'),
              mainAxisSize: MainAxisSize.min,
              children: [
                _icon(AppAssets.offerBags, 15, ink),
                const SizedBox(width: 4),
                Text('${offer.bags}', style: detailStyle),
              ],
            ),
          ),
      ],
    );

    // "Only for you · pickup 4 min away", the minutes in bold.
    final minutes = '${offer.pickupMinutes} min';
    final line = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: why.isEmpty ? 'Pickup ' : '$why · pickup '),
          TextSpan(
            text: minutes,
            style: const TextStyle(color: ink, fontWeight: FontWeight.w600),
          ),
          const TextSpan(text: ' away'),
        ],
      ),
      key: ValueKey<String>('exclusive-offer-line-${offer.id}'),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: lineGrey,
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
      ),
    );

    Widget dot({required bool dropoff}) => Container(
      width: 10,
      height: 10,
      decoration: dropoff
          ? BoxDecoration(color: ink, borderRadius: BorderRadius.circular(2.5))
          : BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: ink, width: 2.2),
            ),
    );

    // Place over its city; time and km on the right. A thin line runs
    // from the pickup's circle down to the drop-off's square.
    Widget stop({
      required bool dropoff,
      required String address,
      required String value,
      required String detail,
    }) {
      final hidden = !dropoff && !show.pickupAddress;
      final areaOnly = dropoff && show.dropoffAreaOnly;
      final place = hidden
          ? driverText(DriverTexts.offerPickupNearby)
          : areaOnly
          ? RadarOfferView.area(address)
          : RadarOfferView.street(address);
      final area = hidden || areaOnly ? '' : RadarOfferView.area(address);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                SizedBox(height: dropoff ? 3 : 5),
                dot(dropoff: dropoff),
                if (!dropoff)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.only(top: 3),
                      color: const Color(0xFFE1E4E6),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(6, 0, 10, dropoff ? 4 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (area.isNotEmpty && area != place) ...[
                    const SizedBox(height: 2),
                    Text(
                      area,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: stopGrey,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (value.isNotEmpty || detail.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (value.isNotEmpty)
                    Text(
                      value,
                      style: const TextStyle(
                        color: ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (detail.isNotEmpty)
                    Text(
                      detail,
                      style: const TextStyle(
                        color: stopGrey,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
        ],
      );
    }

    final stops = Container(
      padding: const EdgeInsets.only(top: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: stop(
              dropoff: false,
              address: offer.pickup,
              value: minutes,
              detail: show.pickupDistance
                  ? '${offer.pickupKm.toStringAsFixed(1)} km'
                  : '',
            ),
          ),
          IntrinsicHeight(
            child: stop(
              dropoff: true,
              address: offer.dropoff,
              value: show.tripMinutesKm ? '${offer.tripMinutes} min' : '',
              detail: [
                if (show.tripMinutesKm) '${offer.tripKm.toStringAsFixed(1)} km',
                if (show.stops && offer.stops > 0) offer.stopsLabel,
              ].join(' · '),
            ),
          ),
        ],
      ),
    );

    final viewRoute = SizedBox(
      height: 48,
      child: TextButton(
        key: const ValueKey<String>('direct-offer-route'),
        onPressed: onRoute,
        style: TextButton.styleFrom(
          elevation: 0,
          backgroundColor: soft,
          foregroundColor: ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _icon(AppAssets.offerRoute, 17, ink),
            const SizedBox(width: 7),
            Text(
              driverText(DriverTexts.offerViewRoute),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: 22),
        price,
        const SizedBox(height: 8),
        line,
        const SizedBox(height: 18),
        stops,
        const SizedBox(height: 6),
        viewRoute,
      ],
    );
    final maxHeight = maxContentHeight;
    if (maxHeight != null) {
      content = ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: content,
        ),
      );
    }

    return Container(
      key: ValueKey<String>('exclusive-offer-card-${offer.id}'),
      padding: EdgeInsets.fromLTRB(22, 24, 22, bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.fromBorderSide(BorderSide(color: ink)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 26,
            offset: Offset(0, -10),
          ),
        ],
      ),
      child: content,
    );
  }
}

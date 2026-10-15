import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';

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
  });

  final String id;
  final String category;
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

  /// "Hantverkargatan 4, Stockholm" → "Stockholm".
  static String area(String address) {
    final parts = address.split(',');
    final last = parts.last.trim();
    return last.isEmpty ? address.trim() : last;
  }
}

enum RadarOfferCardState { available, matching, expired, taken }

/// Soft grey header with a fine black outline: category badge, payment,
/// bags, rating; big price and pickup time; then pickup → drop-off and
/// Route + Match.
class RadarOfferCard extends StatelessWidget {
  const RadarOfferCard({
    super.key,
    required this.offer,
    this.state = RadarOfferCardState.available,
    this.onMatch,
    this.onRoute,
    this.onDismiss,
  });

  final RadarOfferView offer;
  final RadarOfferCardState state;
  final VoidCallback? onMatch;
  final VoidCallback? onRoute;

  /// Shows the × in the header (full-screen list only).
  final VoidCallback? onDismiss;

  static const Color ink = Color(0xFF111518);
  static const Color muted = Color(0xFF7C868D);
  static const Color label = Color(0xFF8A9399);
  static const Color headerTint = Color(0xFFF5F6F7);

  Widget _icon(String asset, double size, Color color) => SvgPicture.asset(
        asset,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );

  @override
  Widget build(BuildContext context) {
    final comma = offer.fare.indexOf(',');
    final whole = comma > 0 ? offer.fare.substring(0, comma) : offer.fare;
    final rest = comma > 0 ? offer.fare.substring(comma) : '';
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
              Container(
                key: ValueKey<String>('radar-offer-category-${offer.id}'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  offer.payment.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: label,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              if (offer.bags > 0) ...[
                const SizedBox(width: 8),
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
              const Spacer(),
              Container(
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
                  const Text(
                    'PICKUP',
                    style: TextStyle(
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
                      RadarOfferView.area(offer.pickup),
                      '${offer.pickupKm.toStringAsFixed(1)} km away',
                    ),
                    const SizedBox(height: 14),
                    stop(
                      RadarOfferView.area(offer.dropoff),
                      '${offer.tripMinutes} min trip · ${offer.tripKm.toStringAsFixed(1)} km',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
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
                    child: Center(child: _icon(AppAssets.offerRoute, 22, ink)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
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
                      disabledBackgroundColor: state ==
                              RadarOfferCardState.expired
                          ? ink.withValues(alpha: 0.28)
                          : const Color(0xFFD9DEDF),
                      disabledForegroundColor: state ==
                              RadarOfferCardState.expired
                          ? Colors.white
                          : const Color(0xFF727E83),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    child: matching
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF727E83),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Matching…',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'Match',
                            style: TextStyle(
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

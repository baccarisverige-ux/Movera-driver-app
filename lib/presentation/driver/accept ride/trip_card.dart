import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';

/// One point of a [TripCard]: a small mark, a short label ("Pickup · 4 min")
/// and the address under it.
class TripCardPoint {
  const TripCardPoint({
    required this.label,
    required this.address,
    required this.color,
    this.square = false,
  });

  final String label;
  final String address;
  final Color color;

  /// Drop-off is a small square; pickup and stops are dots.
  final bool square;
}

/// The trip sheet's light-grey trip card, the same for the current trip
/// and a secured next trip: title, fare and •••, the trip's points, then
/// "Comfort · Nils" with a Waybill link.
class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.title,
    required this.fare,
    required this.points,
    required this.footer,
    required this.onMore,
    required this.moreKey,
    this.moreTooltip = 'Trip options',
    this.onWaybill,
    this.waybillKey,
  });

  final String title;
  final String fare;
  final List<TripCardPoint> points;
  final String footer;
  final VoidCallback onMore;
  final Key moreKey;
  final String moreTooltip;

  /// Null hides the Waybill link (no waybill yet).
  final VoidCallback? onWaybill;
  final Key? waybillKey;

  /// #F1F2F4 made 27% lighter, for both cards.
  static const Color fill = Color(0xFFF5F6F7);
  static const Color ink = Color(0xFF15191E);
  static const Color muted = Color(0xFF8A9298);
  static const Color pickupGreen = Color(0xFF5FB87D);
  static const Color stopGrey = Color(0xFFB4BBC1);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                fare,
                style: const TextStyle(
                  color: ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 2),
              Tooltip(
                message: moreTooltip,
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    key: moreKey,
                    onTap: onMore,
                    customBorder: const CircleBorder(),
                    child: SizedBox.square(
                      dimension: 36,
                      child: Center(
                        child: SvgPicture.asset(
                          AppAssets.solarMenuDots,
                          width: 20,
                          height: 20,
                          colorFilter: const ColorFilter.mode(
                            ink,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < points.length; i++) ...[
            if (i > 0) const SizedBox(height: 9),
            _PointRow(point: points[i]),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  footer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (onWaybill != null)
                TextButton.icon(
                  key: waybillKey,
                  onPressed: onWaybill,
                  icon: SvgPicture.asset(
                    AppAssets.solarDocumentText,
                    width: 17,
                    height: 17,
                    colorFilter: const ColorFilter.mode(ink, BlendMode.srcIn),
                  ),
                  label: const Text(
                    'Waybill',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: ink,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                  ),
                )
              else
                const SizedBox(height: 40),
            ],
          ),
        ],
      ),
    );
  }
}

class _PointRow extends StatelessWidget {
  const _PointRow({required this.point});

  final TripCardPoint point;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: point.color,
              shape: point.square ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: point.square ? BorderRadius.circular(1.5) : null,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  point.label,
                  style: const TextStyle(
                    color: TripCard.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  point.address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TripCard.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A round light-grey button with a Solar icon, for call and chat.
class TripRoundButton extends StatelessWidget {
  const TripRoundButton({
    super.key,
    required this.asset,
    required this.tooltip,
    required this.onTap,
  });

  final String asset;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFFF1F2F4),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: 44,
            child: Center(
              child: SvgPicture.asset(
                asset,
                width: 22,
                height: 22,
                colorFilter: const ColorFilter.mode(
                  TripCard.ink,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

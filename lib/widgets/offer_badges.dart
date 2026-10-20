import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';

/// A small pill on the Radar and Exclusive offer cards: the ride type, the
/// Cash note, a reservation time, a fare boost, the red "Priority" mark or
/// the black "Exclusive" mark.
class OfferBadge extends StatelessWidget {
  const OfferBadge({
    super.key,
    required this.label,
    this.icon,
    this.background = Colors.white,
    this.foreground = _ink,
    this.border = _ink,
    this.vertical = 3,
    this.iconColor,
  });

  /// The ride type, e.g. "Comfort": white with a fine black outline.
  const OfferBadge.category(this.label, {super.key, this.vertical = 3})
    : icon = null,
      iconColor = null,
      background = Colors.white,
      foreground = _ink,
      border = _ink;

  /// The rider pays cash in the car. Shown only then: card, Apple Pay or
  /// wallet show nothing. R10-11: light grey with ink text and a green
  /// money icon, like dollar bills.
  const OfferBadge.cash({super.key, this.vertical = 3})
    : label = 'Cash',
      icon = AppAssets.solarWadOfMoney,
      background = cashBackground,
      foreground = _ink,
      border = cashBorder,
      iconColor = cashGreen;

  /// A reservation, with its pickup time when known: "Reservation · 07:40".
  OfferBadge.reservation(String? time, {super.key, this.vertical = 3})
    : label = time == null || time.isEmpty
          ? 'Reservation'
          : 'Reservation · $time',
      icon = AppAssets.solarCalendar,
      iconColor = null,
      background = Colors.white,
      foreground = _grey,
      border = _greyLine;

  /// Admin raised the fare because no driver was near the pickup, e.g.
  /// "+40 kr". Movera pays it from its commission; the fare shown already
  /// includes it.
  const OfferBadge.boost(this.label, {super.key, this.vertical = 3})
    : icon = AppAssets.solarRoundArrowUp,
      iconColor = null,
      background = const Color(0xFFE8F6EE),
      foreground = const Color(0xFF136B47),
      border = const Color(0xFFBFE3CF);

  /// Q18: admin made the trip a priority or added Movera-paid money to
  /// it. Red with white text; the fare shown already has the money in it.
  const OfferBadge.priority({super.key, this.vertical = 3})
    : label = 'Priority',
      icon = null,
      iconColor = null,
      background = priorityRed,
      foreground = Colors.white,
      border = priorityRed;

  /// The Priority badge's red.
  static const Color priorityRed = Color(0xFFD92D20);

  /// A quiet outlined note, e.g. "On your way".
  const OfferBadge.note(this.label, {super.key, this.vertical = 3})
    : icon = null,
      iconColor = null,
      background = Colors.white,
      foreground = _grey,
      border = _greyLine;

  /// The black "Exclusive" mark with a bolt.
  const OfferBadge.exclusive({super.key, this.vertical = 4})
    : label = 'Exclusive',
      icon = AppAssets.solarBolt,
      iconColor = null,
      background = _ink,
      foreground = Colors.white,
      border = _ink;

  static const Color _ink = Color(0xFF111518);
  static const Color _grey = Color(0xFF3A444B);
  static const Color _greyLine = Color(0xFFD5D9DC);

  /// R10-11: the Cash chip's grey fill, outline and money green.
  static const Color cashBackground = Color(0xFFEEF0F2);
  static const Color cashBorder = Color(0xFFE1E4E8);
  static const Color cashGreen = Color(0xFF2E9E5B);

  final String label;

  /// A Solar icon asset drawn before the label.
  final String? icon;
  final Color background;
  final Color foreground;
  final Color border;
  final double vertical;

  /// The icon's colour; [foreground] when null.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final asset = icon;
    return Container(
      padding: EdgeInsets.fromLTRB(
        asset == null ? 10 : 8,
        vertical,
        10,
        vertical,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (asset != null) ...[
            SvgPicture.asset(
              asset,
              width: 13,
              height: 13,
              colorFilter: ColorFilter.mode(
                iconColor ?? foreground,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

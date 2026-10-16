import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/dispatch/pickup_pay.dart';

/// The small grey line under an offer's total when admin shows the pickup
/// pay: "incl. 21,60 kr pickup · 4.2 km · 9 min". Nothing when admin shows
/// one total only, or there is no pickup pay.
class PickupPayLine extends StatelessWidget {
  const PickupPayLine({
    super.key,
    required this.quote,
    this.padding = const EdgeInsets.only(top: 8),
  });

  final PickupPayQuote? quote;
  final EdgeInsetsGeometry padding;

  static const Color _grey = Color(0xFF6B757C);

  @override
  Widget build(BuildContext context) {
    final line = quote?.line;
    if (line == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            AppAssets.solarRouting2,
            width: 13,
            height: 13,
            colorFilter: const ColorFilter.mode(_grey, BlendMode.srcIn),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              line,
              key: const ValueKey<String>('offer-pickup-pay-line'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _grey,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

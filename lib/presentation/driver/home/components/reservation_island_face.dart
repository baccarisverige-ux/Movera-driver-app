import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';

const TextStyle _whenStyle = TextStyle(
  color: Colors.white,
  fontSize: 15,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.1,
);
const TextStyle _kindStyle = TextStyle(
  color: Color(0xFF9FB0BD),
  fontSize: 14,
  fontWeight: FontWeight.w600,
);

/// A reservation request up on Home, on the island: a small calendar,
/// "Today 06:35" and a grey "· Reservation".
class DigitalReservationFace extends StatelessWidget {
  const DigitalReservationFace({super.key, required this.when});

  /// "Today 06:35", "Tomorrow 06:35" or "Mon 20 Oct 06:35".
  final String when;

  static const String kind = 'Reservation';
  static const double _icon = 18;
  static const double _gap = 8;

  /// "Today 06:35": the pickup day ("Today", "Tomorrow" or its short
  /// date) and time.
  static String whenOf(ReservationRequestPreview request) {
    final day = request.pickupDay.trim();
    final lower = day.toLowerCase();
    final shown = lower == 'today'
        ? 'Today'
        : lower == 'tomorrow'
        ? 'Tomorrow'
        : day;
    return shown.isEmpty ? request.pickupTime : '$shown ${request.pickupTime}';
  }

  static TextSpan _span(String when) => TextSpan(children: [
    TextSpan(text: when, style: _whenStyle),
    const TextSpan(text: ' · $kind', style: _kindStyle),
  ]);

  /// Width the face needs: icon, gap and words.
  static double widthFor(BuildContext context, String when) {
    final painter = TextPainter(
      text: _span(when),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return _icon + _gap + painter.width + 4;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            AppAssets.solarCalendar,
            key: const ValueKey<String>('island-reservation-icon'),
            width: _icon,
            height: _icon,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
          const SizedBox(width: _gap),
          Flexible(
            child: Text.rich(
              _span(when),
              key: const ValueKey<String>('island-reservation'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

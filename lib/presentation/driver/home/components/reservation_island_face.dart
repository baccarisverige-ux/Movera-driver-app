import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/scheduled/reservation_when.dart';

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
/// when it is ("Today 13:45", "In 2 h · 15:45") and a grey
/// "· Reservation".
class DigitalReservationFace extends StatelessWidget {
  const DigitalReservationFace({super.key, required this.when});

  /// "In 2 h · 15:45", "Today 13:45", "Tomorrow 11:55", "Saturday 14:33"
  /// or "19-10 11:44".
  final String when;

  static String get kind => tr.reservation;
  static const double _icon = 18;
  static const double _gap = 8;

  /// "In 2 h · 15:45", "Today 13:45", "Saturday 14:33": the same words
  /// as the sheet's when-button, with the time added when it is soon.
  static String whenOf(ReservationRequestPreview request, DateTime now) =>
      ReservationWhen.ofRequest(request, now).island;

  static TextSpan _span(String when) => TextSpan(
    children: [
      TextSpan(text: when, style: _whenStyle),
      TextSpan(text: ' · $kind', style: _kindStyle),
    ],
  );

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
  Widget build(BuildContext context) => _IslandOfferFace(
    icon: AppAssets.solarCalendar,
    iconKey: const ValueKey<String>('island-reservation-icon'),
    textKey: const ValueKey<String>('island-reservation'),
    span: _span(when),
  );
}

/// The Exclusive offer up on Home, on the island: a check circle, a bold
/// white "Exclusive" and a grey "· Pickup 4 min", like the reservation.
class DigitalExclusiveFace extends StatelessWidget {
  const DigitalExclusiveFace({super.key, required this.pickupMinutes});

  final int pickupMinutes;

  static String get title => tr.exclusive;

  static TextSpan _span(int minutes) => TextSpan(
    children: [
      TextSpan(text: title, style: _whenStyle),
      TextSpan(text: tr.pickupMinutesMin(minutes), style: _kindStyle),
    ],
  );

  /// Width the face needs: icon, gap and words.
  static double widthFor(BuildContext context, int pickupMinutes) {
    final painter = TextPainter(
      text: _span(pickupMinutes),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return DigitalReservationFace._icon +
        DigitalReservationFace._gap +
        painter.width +
        4;
  }

  @override
  Widget build(BuildContext context) => _IslandOfferFace(
    icon: AppAssets.solarCheckCircle,
    iconKey: const ValueKey<String>('island-exclusive-icon'),
    textKey: const ValueKey<String>('island-exclusive'),
    span: _span(pickupMinutes),
  );
}

/// Radar offers open on Home, on the island (owner N1, live test
/// 2026-10-26): a small target icon, a bold white "1 offer" and a grey
/// "· radar". The whole middle opens the full-screen radar; the menu and
/// the destination search beside it keep their own jobs. It stays while
/// offers remain, also after the radar is closed, and goes on its own
/// when none is left.
class DigitalRadarOffersFace extends StatelessWidget {
  const DigitalRadarOffersFace({super.key, required this.count});

  /// Every Radar trip open right now (the deck and the rest).
  final int count;

  /// The words, in the driver's language ("1 offer · radar").
  static String title(int count) => tr.islandRadarOffers(count);

  static TextSpan _span(int count) {
    final text = title(count);
    final split = text.indexOf(' · ');
    if (split < 0) return TextSpan(text: text, style: _whenStyle);
    return TextSpan(
      children: [
        TextSpan(text: text.substring(0, split), style: _whenStyle),
        TextSpan(text: text.substring(split), style: _kindStyle),
      ],
    );
  }

  /// Width the face needs: icon, gap and words.
  static double widthFor(BuildContext context, int count) {
    final painter = TextPainter(
      text: _span(count),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return DigitalReservationFace._icon +
        DigitalReservationFace._gap +
        painter.width +
        4;
  }

  @override
  Widget build(BuildContext context) => _IslandOfferFace(
    icon: AppAssets.solarGps,
    iconKey: const ValueKey<String>('island-radar-offers-icon'),
    textKey: const ValueKey<String>('island-radar-offers'),
    span: _span(count),
  );
}

/// A white Solar icon, then one line of words.
class _IslandOfferFace extends StatelessWidget {
  const _IslandOfferFace({
    required this.icon,
    required this.iconKey,
    required this.textKey,
    required this.span,
  });

  final String icon;
  final Key iconKey;
  final Key textKey;
  final TextSpan span;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            icon,
            key: iconKey,
            width: DigitalReservationFace._icon,
            height: DigitalReservationFace._icon,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
          const SizedBox(width: DigitalReservationFace._gap),
          Flexible(
            child: Text.rich(
              span,
              key: textKey,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

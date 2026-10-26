import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/dispatch/pickup_pay.dart';
import 'package:movera/core/scheduled/reservation_when.dart';
import 'package:movera/core/scheduled/scheduled_ride_rules.dart';
import 'package:movera/core/scheduled/smart_gap.dart';
import 'package:movera/presentation/driver/home/components/home_offer_sheet.dart';
import 'package:movera/widgets/movera_radar_orb.dart';
import 'package:movera/widgets/offer_badges.dart';
import 'package:movera/widgets/radar_offer_card.dart';

/// The accent colour drawn in the flat picture files; replaced at render
/// time by the reservation orb's ink. The other greys stay as drawn.
const Color reservationPictureAccent = Color(0xFF4A555E);

/// Replaces the pictures' accent with [accent] while the SVG is parsed.
@immutable
class ReservationAccentMapper extends ColorMapper {
  const ReservationAccentMapper(this.accent);

  final Color accent;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    if (color.toARGB32() | 0xFF000000 != reservationPictureAccent.toARGB32()) {
      return color;
    }
    // Keeps the drawn opacity.
    return accent.withValues(alpha: color.a * accent.a);
  }

  @override
  bool operator ==(Object other) =>
      other is ReservationAccentMapper && other.accent == accent;

  @override
  int get hashCode => accent.hashCode;
}

/// The flat picture on the reservation sheet, right of the fare.
enum ReservationPicture {
  /// A booked calendar with ticks.
  booked,

  /// A woman beside a big calendar.
  calendar,

  /// A plane and a traveller with a bag.
  airport;

  /// Airport rides (pickup or drop-off at an airport) get the plane and
  /// the traveller; the others switch between [booked] and [calendar] by
  /// [order], their place among the requests shown.
  static ReservationPicture forRequest(
    ReservationRequestPreview request, {
    int order = 0,
  }) {
    final kind = SmartGap.kindOf(request, ScheduledRideRules.current);
    if (kind == ScheduledRideKind.airport) return airport;
    return order.isEven ? booked : calendar;
  }
}

/// The reservation request on Home (notes R11–R26, design A): the Home
/// sheet rises to about 40 % of the screen with every detail inside it and
/// no map (the Home map shows the route). The radar orb, the Accept, sits
/// centred on the sheet's top edge, half over the map; a small down arrow
/// top-right takes the request off Home. The motion is [HomeOfferSheet]'s,
/// shared with the Exclusive offer.
class HomeReservationSheet extends StatelessWidget {
  const HomeReservationSheet({
    super.key,
    required this.request,
    required this.visible,
    this.orb,
    this.onDecline,
    this.onShown,
    this.onSettled,
    this.onLeaving,
    this.onHidden,
    this.clock,
    this.position = 1,
    this.count = 1,
    this.picture,
    this.pickupPay,
    this.heightFactor = 0.4,
    this.maxHeight = double.infinity,
  });

  /// The reservation to show; null takes the sheet down.
  final ReservationRequestPreview? request;
  final bool visible;

  /// The radar orb on the top edge: tapping it accepts.
  final Widget? orb;

  /// The down arrow: the sheet goes down; the reservation stays open in
  /// Scheduled rides. Null while a claim is deciding.
  final VoidCallback? onDecline;

  /// See [HomeOfferSheet.onShown], [HomeOfferSheet.onSettled],
  /// [HomeOfferSheet.onLeaving] and [HomeOfferSheet.onHidden].
  final VoidCallback? onShown;
  final VoidCallback? onSettled;
  final VoidCallback? onLeaving;
  final VoidCallback? onHidden;
  final DateTime Function()? clock;

  /// "2 of 2": this request's place among the ones waiting.
  final int position;
  final int count;

  /// The picture right of the fare; by default from the request.
  final ReservationPicture? picture;

  /// Pickup pay added to the price: only for an exclusive reservation.
  /// The Home popup leaves this null.
  final PickupPayQuote? pickupPay;

  /// The sheet's height as a part of the screen; taller content grows it
  /// up to [maxHeight], then scrolls.
  final double heightFactor;
  final double maxHeight;

  /// The orb on the top edge: the Home radar's size.
  static const double orbSize = HomeOfferSheet.orbSize;

  /// Once it may show, the sheet waits this long before it rises, so the
  /// driver sees Radar go live first (and its green flash fade).
  static const Duration riseDelay = HomeOfferSheet.defaultRiseDelay;

  /// The rise: slide up and fade in.
  static const Duration riseDuration = HomeOfferSheet.riseDuration;

  /// Going: the route fades out first, then the sheet slides down.
  static const Duration routeFadeOut = HomeOfferSheet.routeFadeOut;
  static const Duration sinkDuration = HomeOfferSheet.sinkDuration;

  /// From the request going until the sheet is removed.
  static const Duration leaveDuration = HomeOfferSheet.leaveDuration;

  @override
  Widget build(BuildContext context) {
    final request = this.request;
    return HomeOfferSheet(
      id: request?.id,
      visible: visible,
      content: request == null
          ? null
          : (context) => ReservationRequestSheet(
              request: request,
              clock: clock,
              position: position,
              count: count,
              picture: picture,
              pickupPay: pickupPay,
            ),
      orb: orb,
      onDecline: onDecline,
      onShown: onShown,
      onSettled: onSettled,
      onLeaving: onLeaving,
      onHidden: onHidden,
      heightFactor: heightFactor,
      maxHeight: maxHeight,
      sheetKey: const ValueKey<String>('home-reservation-sheet'),
      closeKey: const ValueKey<String>('reservation-hide'),
      closeLabel: tr.hideReservationRequest,
    );
  }
}

/// Content of the reservation request: category and payment chips with
/// "2 of 2", the big fare with the trip minutes and a picture beside it,
/// pickup (with its time) and drop-off (with the trip distance), and a
/// grey button saying when the ride is. The radar accepts.
class ReservationRequestSheet extends StatelessWidget {
  const ReservationRequestSheet({
    super.key,
    required this.request,
    this.clock,
    this.details,
    this.position = 1,
    this.count = 1,
    this.picture,
    this.pickupPay,
  });

  final ReservationRequestPreview request;

  /// Which details show (Q14); the admin's choice by default.
  final OfferCardDetails? details;

  /// Now, for when the ride is; defaults to [DateTime.now].
  final DateTime Function()? clock;

  /// "2 of 2"; hidden while only one waits.
  final int position;
  final int count;

  /// The picture right of the fare; by default from the request and its
  /// place ([position]).
  final ReservationPicture? picture;

  /// Pickup pay added to the price: only for an exclusive reservation
  /// (`PickupPayOfferKind.exclusiveReservation`).
  final PickupPayQuote? pickupPay;

  /// The picture's size beside the fare.
  static const Size pictureSize = Size(98, 75);

  OfferCardDetails get _show => details ?? DriverOfferRules.current.card;

  /// "95,06 kr" → "95" and ",06 kr", for the grey decimals. The amount is
  /// the driver's share of the ride's fare, never the fare itself (owner
  /// decision 2026-10-26; [ReservationRequestPreview.driverPayLabel]).
  (String, String) _fareParts() {
    final base = _show.fare(request.fareLabel);
    // One total, like the Radar and Exclusive cards.
    return OfferSheetBody.fareParts(pickupPay?.totalOf(base) ?? base);
  }

  String get _pickupPlace => _show.pickupAddress
      ? RadarOfferView.street(request.pickupAddress)
      : RadarOfferView.area(request.pickupAddress);

  String get _dropoffPlace => _show.dropoffAreaOnly
      ? RadarOfferView.area(request.dropoffAddress)
      : RadarOfferView.street(request.dropoffAddress);

  @override
  Widget build(BuildContext context) {
    final (whole, rest) = _fareParts();
    final when = ReservationWhen.ofRequest(request, (clock ?? DateTime.now)());
    final shownPicture =
        picture ?? ReservationPicture.forRequest(request, order: position - 1);
    return OfferSheetBody(
      keyPrefix: 'reservation',
      category: request.category,
      chips: [
        // Payment only when the rider pays cash (notes R2).
        if (_show.badges && request.paidByCash)
          OfferSheetBody.cashChip('reservation'),
        // Admin raised the fare (Q13); the price has it.
        if (request.fareBoost case final boost? when _show.badges)
          OfferBadge.boost(
            boost,
            key: const ValueKey<String>('reservation-boost'),
          ),
      ],
      position: position,
      count: count,
      fareWhole: whole,
      fareRest: rest,
      trip: _show.tripMinutesKm
          ? tr.tripMinutesMinTrip(request.tripMinutes)
          : null,
      picture: _ReservationPictureView(picture: shownPicture),
      pictureSize: pictureSize,
      pickup: OfferSheetStop(
        place: _pickupPlace,
        pickup: true,
        trailing: request.pickupTime,
      ),
      stops: _show.stops && request.stops.isNotEmpty
          ? (request.stops.length == 1
                ? tr.n1Stop
                : '${request.stops.length} stops')
          : null,
      dropoff: OfferSheetStop(
        place: _dropoffPlace,
        pickup: false,
        trailing: _show.tripMinutesKm
            ? OfferSheetBody.km(request.tripKm)
            : null,
      ),
      // When the ride is, in a light grey pill.
      pillIcon: AppAssets.solarCalendar,
      pillLabel: when.label,
      pillKey: 'when',
      pillSemantics: tr.pickupWhenLabel(when.label),
    );
  }
}

/// The flat picture right of the fare. Airport rides combine the plane
/// (top left) with the traveller walking with a bag (bottom right).
class _ReservationPictureView extends StatelessWidget {
  const _ReservationPictureView({required this.picture});

  final ReservationPicture picture;

  /// Drawn in place of [reservationPictureAccent]: the orb's ink.
  static const ReservationAccentMapper _colors = ReservationAccentMapper(
    MoveraRadarOrb.reserveInk,
  );

  @override
  Widget build(BuildContext context) {
    final key = ValueKey<String>('reservation-picture-${picture.name}');
    return KeyedSubtree(
      key: const ValueKey<String>('reservation-picture'),
      child: switch (picture) {
        ReservationPicture.booked => SvgPicture.asset(
          AppAssets.reservationBooked,
          key: key,
          fit: BoxFit.contain,
          colorMapper: _colors,
        ),
        ReservationPicture.calendar => SvgPicture.asset(
          AppAssets.reservationCalendar,
          key: key,
          fit: BoxFit.contain,
          colorMapper: _colors,
        ),
        ReservationPicture.airport => LayoutBuilder(
          key: key,
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  width: w * 0.6,
                  height: h * 0.48,
                  child: SvgPicture.asset(
                    AppAssets.reservationAircraft,
                    fit: BoxFit.contain,
                    colorMapper: _colors,
                  ),
                ),
                Positioned(
                  left: w * 0.5,
                  top: h * 0.22,
                  width: w * 0.5,
                  height: h * 0.78,
                  child: SvgPicture.asset(
                    AppAssets.reservationTraveller,
                    fit: BoxFit.contain,
                    colorMapper: _colors,
                  ),
                ),
              ],
            );
          },
        ),
      },
    );
  }
}

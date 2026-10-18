import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/dispatch/pickup_pay.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/scheduled/reservation_when.dart';
import 'package:movera/core/scheduled/scheduled_ride_rules.dart';
import 'package:movera/core/scheduled/smart_gap.dart';
import 'package:movera/widgets/movera_radar_orb.dart';
import 'package:movera/widgets/offer_badges.dart';
import 'package:movera/widgets/offer_route_pins.dart';
import 'package:movera/widgets/radar_offer_card.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

const Color _ink = Color(0xFF111518);
const Color _text = Color(0xFF5D646C);
const Color _label = Color(0xFF8A9399);
const Color _hairline = Color(0xFFEEF0F2);
const Color _softFill = Color(0xFFF1F2F4);

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
    if (color.toARGB32() | 0xFF000000 !=
        reservationPictureAccent.toARGB32()) {
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
/// top-right takes the request off Home.
///
/// It rises smoothly from the bottom while [visible] (slide up and fade
/// in); when it goes, [onLeaving] lets the map's route fade first, then it
/// slides down under the Home sheet and [onHidden] follows.
class HomeReservationSheet extends StatefulWidget {
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

  /// Called each time the sheet is nearly up (Accept works from then).
  final VoidCallback? onShown;

  /// Called once the sheet has settled at the top: the map's route fades
  /// in from then.
  final VoidCallback? onSettled;

  /// Called as soon as the sheet is to go: the map's route fades out
  /// during [routeFadeOut], then the sheet slides down.
  final VoidCallback? onLeaving;

  /// Called once the sheet is down and removed.
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
  static const double orbSize = 104;

  /// Once it may show, the sheet waits this long before it rises, so the
  /// driver sees Radar go live first (and its green flash fade).
  static const Duration riseDelay = Duration(milliseconds: 1000);

  /// The rise: slide up and fade in.
  static const Duration riseDuration = Duration(milliseconds: 400);

  /// Going: the route fades out first, then the sheet slides down.
  static const Duration routeFadeOut = Duration(milliseconds: 200);
  static const Duration sinkDuration = Duration(milliseconds: 350);

  /// From the request going until the sheet is removed.
  static const Duration leaveDuration = Duration(milliseconds: 550);

  @override
  State<HomeReservationSheet> createState() => _HomeReservationSheetState();
}

class _HomeReservationSheetState extends State<HomeReservationSheet>
    with SingleTickerProviderStateMixin {
  /// 0 hidden below the screen, 1 up; already eased.
  late final AnimationController _rise = AnimationController(vsync: this);

  /// What is on screen; kept while the sheet goes down.
  ReservationRequestPreview? _shown;

  /// The sheet should be (or is going) up.
  bool _up = false;

  /// Going down: the route fades, then the slide; [_shown] stays.
  bool _leaving = false;
  Timer? _riseTimer;
  Timer? _leaveTimer;

  /// Counts each rise or leave, so a stale animation end does nothing.
  int _run = 0;

  /// [HomeReservationSheet.onShown] ran for this rise.
  bool _told = false;

  /// How far up the sheet is when the radar becomes its Accept.
  static const double _nearlyUp = 0.82;

  bool get _wantUp => widget.visible && widget.request != null;

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    _rise.addListener(_tellWhenNearlyUp);
    _sync();
  }

  void _tellWhenNearlyUp() {
    if (_told || !_up || _leaving || _rise.value < _nearlyUp) return;
    _told = true;
    widget.onShown?.call();
  }

  @override
  void didUpdateWidget(HomeReservationSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  /// Called from [initState] or [didUpdateWidget], so a build follows.
  void _sync() {
    final request = widget.request;
    if (_wantUp && request != null) {
      if (_leaving) {
        // The same request back while going: it comes up again. Another
        // one waits until this one is down.
        if (_shown?.id == request.id) _comeBack();
        return;
      }
      _shown = request;
      if (!_up) {
        _up = true;
        _riseTimer?.cancel();
        _riseTimer = Timer(HomeReservationSheet.riseDelay, _riseNow);
      }
    } else if (_up && !_leaving) {
      _leave();
    }
  }

  void _riseNow() {
    if (!mounted || !_up || _leaving) return;
    final run = ++_run;
    if (_reduceMotion) {
      _rise.value = 1;
      _settled(run);
      return;
    }
    _rise
        .animateTo(
          1,
          duration: HomeReservationSheet.riseDuration,
          curve: Curves.easeOutCubic,
        )
        .whenCompleteOrCancel(() => _settled(run));
  }

  void _settled(int run) {
    if (!mounted || run != _run || !_up || _leaving || _rise.value < 1) {
      return;
    }
    if (!_told) {
      _told = true;
      widget.onShown?.call();
    }
    widget.onSettled?.call();
  }

  void _comeBack() {
    _leaving = false;
    _leaveTimer?.cancel();
    _riseNow();
  }

  /// The route fades first, then the sheet slides down; then it is gone.
  void _leave() {
    _riseTimer?.cancel();
    _told = false;
    final run = ++_run;
    if (_rise.value <= 0 || _reduceMotion) {
      // Never came up, or no motion: gone at once.
      _rise.stop();
      _rise.value = 0;
      _up = false;
      _shown = null;
      widget.onLeaving?.call();
      final onHidden = widget.onHidden;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _up) return;
        onHidden?.call();
      });
      return;
    }
    _leaving = true;
    _rise.stop();
    widget.onLeaving?.call();
    _leaveTimer?.cancel();
    _leaveTimer = Timer(HomeReservationSheet.routeFadeOut, () {
      if (!mounted || run != _run) return;
      _rise
          .animateTo(
            0,
            duration: HomeReservationSheet.sinkDuration,
            curve: Curves.easeInCubic,
          )
          .whenCompleteOrCancel(() => _down(run));
    });
  }

  void _down(int run) {
    if (!mounted || run != _run || !_leaving) return;
    setState(() {
      _leaving = false;
      _up = false;
      _shown = null;
      // A request that came while this one went rises now.
      _sync();
    });
    widget.onHidden?.call();
  }

  @override
  void dispose() {
    _riseTimer?.cancel();
    _leaveTimer?.cancel();
    _rise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final request = _shown;
    if (request == null) return const SizedBox.shrink();
    final screen = MediaQuery.sizeOf(context).height;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    const half = HomeReservationSheet.orbSize / 2;
    final minHeight = screen * widget.heightFactor;
    // Opaque to touches: nothing under the sheet (dock, map) gets them.
    final sheet = PointerInterceptor(
      child: Listener(
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          key: const ValueKey<String>('home-reservation-sheet'),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 20,
                offset: Offset(0, -6),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: minHeight,
              maxHeight: widget.maxHeight < minHeight
                  ? minHeight
                  : widget.maxHeight,
            ),
            child: Stack(
              children: [
                SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  // The orb's lower half sits on the top of the sheet.
                  padding: EdgeInsets.only(
                    top: half + 4,
                    bottom: safeBottom + 16,
                  ),
                  child: ReservationRequestSheet(
                    request: request,
                    clock: widget.clock,
                    position: widget.position,
                    count: widget.count,
                    picture: widget.picture,
                    pickupPay: widget.pickupPay,
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 18,
                  child: ReservationCloseArrow(onTap: widget.onDecline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final orb = widget.orb;
    // The orb's upper half stands over the map: the layer starts there, so
    // all of the orb takes taps. Beside it the map stays free.
    final layer = Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(padding: const EdgeInsets.only(top: half), child: sheet),
        if (orb != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: HomeReservationSheet.orbSize,
            child: Center(child: PointerInterceptor(child: orb)),
          ),
      ],
    );
    return AnimatedBuilder(
      animation: _rise,
      child: layer,
      builder: (context, child) {
        final t = _rise.value.clamp(0.0, 1.0);
        if (t <= 0 && !_up) return const SizedBox.shrink();
        return FractionalTranslation(
          // Hidden: the whole layer is below the screen edge.
          translation: Offset(0, 1 - t),
          child: Opacity(
            // Fully there a little before the slide ends.
            opacity: (t * 1.4).clamp(0.0, 1.0),
            child: IgnorePointer(ignoring: _leaving, child: child),
          ),
        );
      },
    );
  }
}

/// The small down arrow top-right of the sheet: back to Home, the request
/// stays in Scheduled rides. Null [onTap] while a claim is deciding.
class ReservationCloseArrow extends StatelessWidget {
  const ReservationCloseArrow({super.key, this.onTap});

  final VoidCallback? onTap;

  static const double size = 34;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: 'Hide reservation request',
      excludeSemantics: true,
      child: Material(
        color: _softFill,
        shape: const CircleBorder(),
        child: InkWell(
          key: const ValueKey<String>('reservation-hide'),
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: SvgPicture.asset(
                AppAssets.solarAltArrowDown,
                width: 18,
                height: 18,
                colorFilter: ColorFilter.mode(
                  onTap == null ? const Color(0xFFA2AAB0) : _ink,
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

  /// "126,75 kr" → "126" and ",75 kr", for the grey decimals.
  (String, String) _fareParts() {
    final base = _show.fare(
      Money.parseSekLabel(request.fare)?.formatted ?? request.fare,
    );
    // One total, like the Radar and Exclusive cards.
    final fare = pickupPay?.totalOf(base) ?? base;
    final comma = fare.lastIndexOf(',');
    return comma > 0
        ? (fare.substring(0, comma), fare.substring(comma))
        : (fare, '');
  }

  String get _pickupPlace => _show.pickupAddress
      ? RadarOfferView.street(request.pickupAddress)
      : RadarOfferView.area(request.pickupAddress);

  String get _dropoffPlace => _show.dropoffAreaOnly
      ? RadarOfferView.area(request.dropoffAddress)
      : RadarOfferView.street(request.dropoffAddress);

  static String _km(double km) => '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';

  @override
  Widget build(BuildContext context) {
    final (whole, rest) = _fareParts();
    final when = ReservationWhen.ofRequest(
      request,
      (clock ?? DateTime.now)(),
    );
    final shownPicture =
        picture ?? ReservationPicture.forRequest(request, order: position - 1);
    return DefaultTextStyle.merge(
      // Tight lines like the design, not the theme's body line height.
      style: const TextStyle(height: 1.2),
      // White and opaque to touches, like the sheet it sits on.
      child: ColoredBox(
        key: const ValueKey<String>('reservation-popup'),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _categoryChip(),
                        // Payment only when the rider pays cash (notes R2).
                        if (_show.badges && request.paidByCash)
                          const OfferBadge.cash(
                            key: ValueKey<String>('reservation-cash'),
                          ),
                        // Admin raised the fare (Q13); the price has it.
                        if (request.fareBoost case final boost?
                            when _show.badges)
                          OfferBadge.boost(
                            boost,
                            key: const ValueKey<String>('reservation-boost'),
                          ),
                      ],
                    ),
                  ),
                  if (count > 1) ...[
                    const SizedBox(width: 10),
                    Text(
                      '$position of $count',
                      key: const ValueKey<String>('reservation-count'),
                      maxLines: 1,
                      style: const TextStyle(
                        color: _label,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    // Clear of the picture's right edge below.
                    const SizedBox(width: 24),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text.rich(
                            key: const ValueKey<String>('reservation-fare'),
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: whole,
                                  style: const TextStyle(
                                    color: _ink,
                                    fontSize: 34,
                                    height: 1.1,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1,
                                  ),
                                ),
                                TextSpan(
                                  text: rest,
                                  style: const TextStyle(
                                    color: _label,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_show.tripMinutesKm) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${request.tripMinutes} min trip',
                            key: const ValueKey<String>('reservation-trip'),
                            maxLines: 1,
                            style: const TextStyle(color: _text, fontSize: 14),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox.fromSize(
                    size: pictureSize,
                    child: ExcludeSemantics(
                      child: _ReservationPictureView(picture: shownPicture),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, thickness: 1, color: _hairline),
              const SizedBox(height: 10),
              _place(
                const _StopMark.pickup(),
                _pickupPlace,
                'reservation-pickup',
                trailing: request.pickupTime,
              ),
              if (_show.stops && request.stops.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 22, bottom: 2),
                  child: Text(
                    request.stops.length == 1
                        ? '1 stop'
                        : '${request.stops.length} stops',
                    key: const ValueKey<String>('reservation-stops'),
                    style: const TextStyle(color: _label, fontSize: 12.5),
                  ),
                ),
              _place(
                const _StopMark.dropoff(),
                _dropoffPlace,
                'reservation-dropoff',
                trailing: _show.tripMinutesKm ? _km(request.tripKm) : null,
              ),
              const SizedBox(height: 12),
              _whenButton(when.label),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        request.category,
        key: const ValueKey<String>('reservation-category'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _place(Widget mark, String place, String key, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        key: ValueKey<String>(key),
        children: [
          SizedBox(width: 12, child: Center(child: mark)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              place,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _ink, fontSize: 15),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            Text(
              trailing,
              key: ValueKey<String>('$key-trailing'),
              maxLines: 1,
              style: const TextStyle(
                color: _ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// When the ride is, in a light grey pill; only shows, never taps.
  Widget _whenButton(String label) {
    return Semantics(
      label: 'Pickup $label',
      excludeSemantics: true,
      child: Container(
        key: const ValueKey<String>('reservation-when'),
        height: 50,
        decoration: BoxDecoration(
          color: _softFill,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              AppAssets.solarCalendar,
              key: const ValueKey<String>('reservation-when-icon'),
              width: 18,
              height: 18,
              colorFilter: const ColorFilter.mode(_ink, BlendMode.srcIn),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                key: const ValueKey<String>('reservation-when-text'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
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

/// Pickup: a green dot with a soft ring; drop-off: a black square. The
/// same marks as the pins on the map.
class _StopMark extends StatelessWidget {
  const _StopMark.pickup() : _pickup = true;
  const _StopMark.dropoff() : _pickup = false;

  final bool _pickup;

  @override
  Widget build(BuildContext context) {
    if (!_pickup) {
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: _ink,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: OfferRoutePins.green,
        shape: BoxShape.circle,
        // A white ring, then a faint green one (painted first, under it).
        boxShadow: [
          BoxShadow(
            color: OfferRoutePins.green.withValues(alpha: 0.33),
            spreadRadius: 4,
          ),
          const BoxShadow(color: Colors.white, spreadRadius: 3),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/dispatch/pickup_pay.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/routing/road_route_service.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/core/scheduled/scheduled_ride_rules.dart';
import 'package:movera/core/scheduled/smart_gap.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/home/components/reservation_route_map.dart';
import 'package:movera/widgets/movera_radar_orb.dart';
import 'package:movera/widgets/offer_badges.dart';
import 'package:movera/widgets/radar_offer_card.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

const Color _ink = Color(0xFF0F1214);
const Color _text = Color(0xFF5B656C);
const Color _label = Color(0xFF8B949A);
const Color _decimals = Color(0xFFA2AAB0);
const Color _soft = Color(0xFFF2F4F5);
const Color _cardLine = Color(0xFFE6E9EB);
const Color _hairline = Color(0xFFEEF0F1);

/// The radar orb's colour while a reservation is up (the dark Accept orb
/// in the dock). The pictures' accent always follows it.
const Color reservationAcceptOrbColor = MoveraRadarOrb.reserveInk;

/// The accent colour drawn in the flat picture files; replaced at render
/// time by the orb's colour. The other greys stay as drawn.
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

/// How dark the map gets behind the reservation.
const double reservationBarrierOpacity = 0.44;

Widget _solar(String asset, double size, [Color color = _ink]) =>
    SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );

/// The flat picture on the reservation card.
enum ReservationPicture {
  /// A booked calendar with ticks.
  booked,

  /// A woman beside a big calendar.
  calendar,

  /// A plane seen from the front and a traveller with a bag.
  airport;

  /// Airport rides (pickup or drop-off at an airport) get the plane and
  /// the traveller; the others switch between [booked] and [calendar] by
  /// [order], the number of normal rides shown before this one.
  static ReservationPicture forRequest(
    ReservationRequestPreview request, {
    int order = 0,
  }) {
    final kind = SmartGap.kindOf(request, ScheduledRideRules.current);
    if (kind == ScheduledRideKind.airport) return airport;
    return order.isEven ? booked : calendar;
  }
}

/// The reservation request on Home (notes R11–R26): an extension of the
/// Home sheet, full width with rounded top corners and a fine black
/// contour, over the dimmed map. It sits behind the dock and rises out
/// from under it with a short spring while [visible]; it goes back down
/// when it is not. View details grows it to full height.
///
/// Its bottom stays behind the dock, so the dock and the radar (the
/// Accept button while it shows) keep their place under the content.
class HomeReservationSheet extends StatefulWidget {
  const HomeReservationSheet({
    super.key,
    required this.request,
    required this.visible,
    this.onHide,
    this.onShown,
    this.onHidden,
    this.mapBuilder,
    this.routes,
    this.clock,
    this.position = 1,
    this.count = 1,
    this.picture,
    this.accent = reservationAcceptOrbColor,
    this.pickupPay,
    this.bottomInset = 178,
    this.maxContentHeight = double.infinity,
    this.fullContentHeight,
  });

  /// The reservation to show; null takes the sheet down.
  final ReservationRequestPreview? request;
  final bool visible;

  /// The ×: only hides the sheet; the reservation stays open in
  /// Scheduled rides. Null while a claim is deciding.
  final VoidCallback? onHide;

  /// Called each time the sheet is nearly up (the radar turns into its
  /// Accept then, as the sheet settles), and after a frame once it starts
  /// to go down.
  final VoidCallback? onShown;
  final VoidCallback? onHidden;

  /// Replaces the live maps, for tests and previews.
  final WidgetBuilder? mapBuilder;
  final RouteRepository? routes;
  final DateTime Function()? clock;

  /// "1 of 2": this request's place among the ones waiting.
  final int position;
  final int count;

  /// The card's picture; by default from the ride.
  final ReservationPicture? picture;

  /// The pictures' accent: the colour of the radar orb in the dock.
  final Color accent;

  /// Pickup pay added to the price: only for an exclusive reservation
  /// (`PickupPayOfferKind.exclusiveReservation`). A normal reservation
  /// sent from the Scheduled rides list never gets it, so the Home popup
  /// leaves this null.
  final PickupPayQuote? pickupPay;

  /// Space under the content, from the screen bottom: the dock and the
  /// radar orb sit there.
  final double bottomInset;

  /// Taller content (many stops, large text) scrolls inside the sheet.
  final double maxContentHeight;

  /// Height of the details view; [maxContentHeight] when null.
  final double? fullContentHeight;

  /// Once it may show, the sheet waits this long before it rises, so the
  /// driver sees Radar go live first (and its green flash fade).
  static const Duration riseDelay = Duration(milliseconds: 1000);

  @override
  State<HomeReservationSheet> createState() => _HomeReservationSheetState();
}

class _HomeReservationSheetState extends State<HomeReservationSheet>
    with SingleTickerProviderStateMixin {
  /// 0 hidden under the dock, 1 up; the spring passes 1 a little.
  late final AnimationController _rise = AnimationController.unbounded(
    vsync: this,
  );

  /// Short spring with a slight overshoot.
  static final SpringDescription _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 260,
    ratio: 0.76,
  );

  /// What is on screen; kept while the sheet goes down.
  ReservationRequestPreview? _shown;
  bool _up = false;
  Timer? _riseTimer;

  /// The details view is open: the sheet stands at full height.
  bool _details = false;

  /// [HomeReservationSheet.onShown] ran for this rise.
  bool _told = false;

  /// How far up the sheet is when the radar becomes its Accept.
  static const double _nearlyUp = 0.82;

  bool get _wantUp => widget.visible && widget.request != null;

  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    _rise.addListener(_tellWhenNearlyUp);
    _sync();
  }

  void _tellWhenNearlyUp() {
    if (_told || !_up || _rise.value < _nearlyUp) return;
    _told = true;
    widget.onShown?.call();
  }

  @override
  void didUpdateWidget(HomeReservationSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (_wantUp) {
      if (!identical(_shown, widget.request)) _details = false;
      _shown = widget.request;
      if (!_up) {
        _up = true;
        _riseTimer?.cancel();
        _riseTimer = Timer(HomeReservationSheet.riseDelay, _riseNow);
      }
    } else if (_up) {
      _up = false;
      _told = false;
      _riseTimer?.cancel();
      _sink();
      final onHidden = widget.onHidden;
      if (onHidden != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_up) onHidden();
        });
      }
    }
  }

  void _riseNow() {
    if (!mounted || !_up) return;
    if (_reduceMotion) {
      _rise.value = 1;
      return;
    }
    _rise.animateWith(
      SpringSimulation(_spring, _rise.value, 1, _rise.velocity),
    );
  }

  /// Called from [didUpdateWidget], so a build follows anyway.
  void _sink() {
    void drop() {
      if (mounted && !_up) {
        setState(() {
          _shown = null;
          _details = false;
        });
      }
    }

    if (_rise.value <= 0 || _reduceMotion) {
      _rise.stop();
      _rise.value = 0;
      _shown = null;
      _details = false;
      return;
    }
    _rise
        .animateTo(
          0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInCubic,
        )
        .whenCompleteOrCancel(drop);
  }

  @override
  void dispose() {
    _riseTimer?.cancel();
    _rise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final request = _shown;
    if (request == null) return const SizedBox.shrink();
    final full = widget.fullContentHeight ?? widget.maxContentHeight;
    final sheet = PointerInterceptor(
      child: DecoratedBox(
        key: const ValueKey<String>('home-reservation-sheet'),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: _ink),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 28,
              offset: Offset(0, -10),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: widget.bottomInset),
          child: AnimatedSize(
            duration: _reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: _details ? full : widget.maxContentHeight,
              ),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ReservationRequestSheet(
                  request: request,
                  onHide: widget.onHide,
                  mapBuilder: widget.mapBuilder,
                  routes: widget.routes,
                  clock: widget.clock,
                  position: widget.position,
                  count: widget.count,
                  picture: widget.picture,
                  accent: widget.accent,
                  pickupPay: widget.pickupPay,
                  detailsHeight: full.isFinite ? full : null,
                  onDetailsChanged: (open) {
                    if (mounted && _details != open) {
                      setState(() => _details = open);
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return AnimatedBuilder(
      animation: _rise,
      child: sheet,
      builder: (context, child) {
        if (_rise.value <= 0 && !_up) return const SizedBox.shrink();
        final dim = _rise.value.clamp(0.0, 1.0) * reservationBarrierOpacity;
        return Stack(
          fit: StackFit.expand,
          children: [
            // The map behind is dimmed; a tap there does nothing (only
            // the × hides the reservation).
            PointerInterceptor(
              child: GestureDetector(
                key: const ValueKey<String>('home-reservation-barrier'),
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: ColoredBox(color: Colors.black.withValues(alpha: dim)),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionalTranslation(
                // Hidden: the whole sheet is below the screen edge, under
                // the dock. Up: its top edge stands above the dock.
                translation: Offset(0, 1 - _rise.value),
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Content of the reservation request: the title and "1 of 2", one card
/// (category, big price, pickup time, from → to and a flat picture) and
/// View details, which opens the route, the stops and the trip numbers.
/// No Accept or Decline buttons: the radar accepts, the × only hides.
class ReservationRequestSheet extends StatefulWidget {
  const ReservationRequestSheet({
    super.key,
    required this.request,
    this.onHide,
    this.mapBuilder,
    this.routes,
    this.clock,
    this.details,
    this.position = 1,
    this.count = 1,
    this.picture,
    this.accent = reservationAcceptOrbColor,
    this.pickupPay,
    this.showDetails = false,
    this.detailsHeight,
    this.onDetailsChanged,
  });

  final ReservationRequestPreview request;

  /// Which details show (Q14); the admin's choice by default.
  final OfferCardDetails? details;

  /// The ×; null shows it disabled.
  final VoidCallback? onHide;

  /// Replaces the live maps (details and full route), for tests and
  /// previews.
  final WidgetBuilder? mapBuilder;

  /// Road routing; defaults to [RoadRouteService].
  final RouteRepository? routes;

  /// Now, for the time left until pickup; defaults to [DateTime.now].
  final DateTime Function()? clock;

  /// "1 of 2" under the title; hidden while only one request waits.
  final int position;
  final int count;

  /// The card's picture; by default from the ride.
  final ReservationPicture? picture;

  /// The pictures' accent: the colour of the radar orb in the dock.
  final Color accent;

  /// Pickup pay added to the price: only for an exclusive reservation
  /// (`PickupPayOfferKind.exclusiveReservation`). A normal reservation
  /// sent from the Scheduled rides list never gets it, so the Home popup
  /// leaves this null.
  final PickupPayQuote? pickupPay;

  /// Opens on the details view (route, stops, trip numbers).
  final bool showDetails;

  /// Height of the details view; its own height when null.
  final double? detailsHeight;

  /// The details view opened or closed.
  final ValueChanged<bool>? onDetailsChanged;

  @override
  State<ReservationRequestSheet> createState() =>
      _ReservationRequestSheetState();
}

class _ReservationRequestSheetState extends State<ReservationRequestSheet> {
  ReservationRequestPreview get request => widget.request;
  OfferCardDetails get _show => widget.details ?? DriverOfferRules.current.card;
  RoadRouteService? _ownRoutes;
  late Future<List<GeoPoint>> _route;
  late bool _details = widget.showDetails;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  void _loadRoute() {
    _ownRoutes?.dispose();
    _ownRoutes = null;
    final routes =
        widget.routes ??
        (DriverRuntimeConfig.current.externalRouting
            ? _ownRoutes = RoadRouteService()
            : null);
    _route = loadReservationRoute(request, routes);
  }

  @override
  void didUpdateWidget(ReservationRequestSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request != widget.request ||
        oldWidget.routes != widget.routes) {
      _loadRoute();
    }
    if (!identical(oldWidget.request, widget.request) &&
        widget.request.id != oldWidget.request.id) {
      _details = widget.showDetails;
    }
  }

  @override
  void dispose() {
    _ownRoutes?.dispose();
    super.dispose();
  }

  void _openDetails(bool open) {
    if (!mounted || _details == open) return;
    setState(() => _details = open);
    widget.onDetailsChanged?.call(open);
  }

  /// The full route screen that already exists (notes R26), unchanged.
  void _openRouteMap() {
    if (!mounted) return;
    final mapBuilder = widget.mapBuilder;
    openReservationRoute(
      context,
      request,
      route: _route,
      mapBuilder: mapBuilder == null
          ? null
          : (context, _) => mapBuilder(context),
    );
  }

  /// "126,75 kr" → "126" and ",75 kr", for the grey decimals.
  (String, String) _fareParts() {
    final base = _show.fare(
      Money.parseSekLabel(request.fare)?.formatted ?? request.fare,
    );
    // One total, like the Radar and Exclusive cards.
    final fare = widget.pickupPay?.totalOf(base) ?? base;
    final comma = fare.lastIndexOf(',');
    return comma > 0
        ? (fare.substring(0, comma), fare.substring(comma))
        : (fare, '');
  }

  /// "in 3 h 20 min", "in 1 day"; null once the pickup time is unknown or
  /// has passed.
  String? _inLabel() {
    final left = request.untilPickup((widget.clock ?? DateTime.now)());
    if (left == null) return null;
    // Whole minutes, rounded up: 1 h 32 min 40 s reads "1 h 33 min".
    final total = (left.inSeconds + 59) ~/ 60;
    final days = total ~/ (24 * 60);
    if (days > 0) return 'in $days day${days == 1 ? '' : 's'}';
    final hours = total ~/ 60;
    final minutes = total % 60;
    final when = hours > 0
        ? (minutes > 0 ? '$hours h $minutes min' : '$hours h')
        : '$minutes min';
    return 'in $when';
  }

  /// "today 19:30"; another day keeps its own name.
  String get _whenLabel {
    final day = request.pickupDay.trim();
    final lower = day.toLowerCase();
    final shown = lower == 'today' || lower == 'tomorrow' ? lower : day;
    return shown.isEmpty ? request.pickupTime : '$shown ${request.pickupTime}';
  }

  String get _pickupShort => _short(_show.pickupAddress
      ? RadarOfferView.street(request.pickupAddress)
      : RadarOfferView.area(request.pickupAddress));

  String get _dropoffShort => _short(_show.dropoffAreaOnly
      ? RadarOfferView.area(request.dropoffAddress)
      : RadarOfferView.street(request.dropoffAddress));

  /// Short place names for the card: "Arlanda Terminal 5" → "Arlanda T5".
  static String _short(String place) =>
      place.replaceAllMapped(RegExp(r'\bTerminal (\w+)'), (m) => 'T${m[1]}');

  static String _km(double km) => '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';

  @override
  Widget build(BuildContext context) {
    // Tight lines like the design, not the theme's body line height.
    return DefaultTextStyle.merge(
      style: const TextStyle(height: 1.2),
      child: _details ? _detailsView(context) : _popup(),
    );
  }

  // The popup ---------------------------------------------------------------

  Widget _popup() {
    return Stack(
      key: const ValueKey<String>('reservation-popup'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _title(),
              const SizedBox(height: 22),
              _card(),
              const SizedBox(height: 14),
              _viewDetailsButton(),
            ],
          ),
        ),
        Positioned(right: 18, top: 18, child: _hideButton()),
      ],
    );
  }

  Widget _title() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Text(
            driverText(DriverTexts.offerNewReservation),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _ink,
              fontSize: 24,
              height: 1.15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.7,
            ),
          ),
          if (widget.count > 1) ...[
            const SizedBox(height: 8),
            Text(
              '${widget.position} of ${widget.count}',
              key: const ValueKey<String>('reservation-counter'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _label,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _hideButton() {
    final onHide = widget.onHide;
    return Tooltip(
      message: 'Hide',
      child: Semantics(
        label: 'Hide reservation request',
        button: true,
        enabled: onHide != null,
        child: Material(
          color: _soft,
          shape: const CircleBorder(),
          child: InkWell(
            key: const ValueKey<String>('reservation-hide'),
            customBorder: const CircleBorder(),
            onTap: onHide,
            child: SizedBox(
              width: 32,
              height: 32,
              child: Center(
                child: _solar(
                  AppAssets.solarClose,
                  17,
                  onHide == null ? const Color(0xFFB7BEC3) : _ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card() {
    final (whole, rest) = _fareParts();
    final inLabel = _inLabel();
    return LayoutBuilder(
      builder: (context, constraints) {
        // Narrow phones give the picture less room, so the price keeps its.
        final pictureWidth = (constraints.maxWidth * 0.42).clamp(84.0, 130.0);
        return Container(
          key: const ValueKey<String>('reservation-card'),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _cardLine, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                right: 12,
                top: 14,
                width: pictureWidth,
                height: pictureWidth * 100 / 130,
                child: ExcludeSemantics(
                  child: _ReservationPictureView(
                    picture: widget.picture ??
                        ReservationPicture.forRequest(request),
                    accent: widget.accent,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(right: pictureWidth * 0.5),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _categoryLabel(),
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
                    const SizedBox(height: 30),
                    Padding(
                      padding: EdgeInsets.only(right: pictureWidth * 0.35),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text.rich(
                          key: const ValueKey<String>('reservation-fare'),
                          TextSpan(
                            children: [
                              TextSpan(
                                text: whole,
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 46,
                                  height: 1,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -2,
                                ),
                              ),
                              TextSpan(
                                text: rest,
                                style: const TextStyle(
                                  color: _decimals,
                                  fontSize: 23,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text.rich(
                      key: const ValueKey<String>('reservation-when'),
                      TextSpan(
                        style: const TextStyle(
                          color: _text,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                        ),
                        children: [
                          const TextSpan(text: 'Pickup '),
                          TextSpan(
                            text: _whenLabel,
                            style: const TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (inLabel != null) TextSpan(text: ' · $inLabel'),
                        ],
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, thickness: 1, color: _hairline),
                    const SizedBox(height: 12),
                    _fromTo(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _categoryLabel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 5, 9, 5),
      decoration: BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _solar(AppAssets.solarUser, 13, Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              request.category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "○ Gamla vägen — ■ Solna centrum".
  Widget _fromTo() {
    const style = TextStyle(
      color: Color(0xFF3A444B),
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
    return Row(
      key: const ValueKey<String>('reservation-from-to'),
      children: [
        const _StopDot.pickup(size: 7),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            _pickupShort,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const SizedBox(width: 8),
        Container(width: 16, height: 1.5, color: const Color(0xFFC9CED2)),
        const SizedBox(width: 8),
        const _StopDot.dropoff(size: 7),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            _dropoffShort,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }

  Widget _viewDetailsButton() {
    return Semantics(
      button: true,
      child: Material(
        color: _soft,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: const ValueKey<String>('reservation-view-details'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openDetails(true),
          child: SizedBox(
            height: 52,
            child: Center(
              child: Text(
                driverText(DriverTexts.offerViewDetails),
                style: const TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // The details view --------------------------------------------------------

  Widget _detailsView(BuildContext context) {
    final height = widget.detailsHeight;
    final body = <Widget>[
      _routeMap(context, height == null ? 200 : null),
      const SizedBox(height: 14),
      _stops(),
      if (_show.tripMinutesKm || _show.stops) ...[
        const SizedBox(height: 14),
        _stats(),
      ],
    ];
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
      child: _detailsHeader(),
    );
    if (height == null) {
      return Column(
        key: const ValueKey<String>('reservation-details'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: body,
            ),
          ),
        ],
      );
    }
    // Full height: the map takes the room the stops leave; long content
    // scrolls.
    return SizedBox(
      key: const ValueKey<String>('reservation-details'),
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final mapHeight = (constraints.maxHeight * 0.45).clamp(
                  120.0,
                  240.0,
                );
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _routeMap(context, mapHeight),
                      ...body.skip(1),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsHeader() {
    final (whole, rest) = _fareParts();
    final inLabel = _inLabel();
    final subtitle = [
      ?inLabel,
      request.category,
      if (_show.netFare) driverText(DriverTexts.offerYourShare),
    ].join(' · ');
    return Row(
      children: [
        Semantics(
          label: 'Back to the reservation',
          button: true,
          child: Material(
            color: _soft,
            shape: const CircleBorder(),
            child: InkWell(
              key: const ValueKey<String>('reservation-details-back'),
              customBorder: const CircleBorder(),
              onTap: () => _openDetails(false),
              child: SizedBox(
                width: 34,
                height: 34,
                child: Center(child: _solar(AppAssets.solarAltArrowLeft, 18)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${request.pickupDay}, ${request.pickupTime}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _label,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text.rich(
          key: const ValueKey<String>('reservation-details-fare'),
          TextSpan(
            children: [
              TextSpan(
                text: whole,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 26,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              TextSpan(
                text: rest,
                style: const TextStyle(
                  color: _decimals,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The grey route map; a tap opens the full route screen (R26).
  Widget _routeMap(BuildContext context, double? height) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: height ?? 200,
        child: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: ColorFiltered(
                colorFilter: const ColorFilter.matrix(_greyscale),
                child: (widget.mapBuilder ?? _liveMap)(context),
              ),
            ),
            Positioned.fill(
              child: PointerInterceptor(
                child: Material(
                  type: MaterialType.transparency,
                  child: Semantics(
                    label: 'View reservation route',
                    button: true,
                    child: InkWell(
                      key: const ValueKey<String>('reservation-map-open'),
                      onTap: _openRouteMap,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const List<double> _greyscale = <double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  Widget _stops() {
    final show = _show;
    final stops = show.stops ? request.stops : const <ReservationStop>[];
    final eta = request.estimatedArrival;
    final rows = <_StopRowData>[
      _StopRowData(
        dot: const _StopDot.pickup(size: 10),
        label: driverText(DriverTexts.offerPickup).toUpperCase(),
        address: show.pickupAddress
            ? request.pickupAddress
            : RadarOfferView.area(request.pickupAddress),
        trailing: request.pickupTime,
      ),
      for (var i = 0; i < stops.length; i++)
        _StopRowData(
          dot: const _StopDot.stop(),
          label: stops.length == 1 ? 'STOP' : 'STOP ${i + 1}',
          address: stops[i].address,
          quiet: true,
        ),
      _StopRowData(
        dot: const _StopDot.dropoff(size: 10),
        label: driverText(DriverTexts.offerDropoff).toUpperCase(),
        address: show.dropoffAreaOnly
            ? RadarOfferView.area(request.dropoffAddress)
            : request.dropoffAddress,
        trailing: eta == null ? null : '~$eta',
        mutedTrailing: true,
      ),
    ];
    return Column(
      key: const ValueKey<String>('reservation-stops'),
      children: [
        for (var i = 0; i < rows.length; i++)
          _stopRow(rows[i], first: i == 0, last: i == rows.length - 1),
      ],
    );
  }

  Widget _stopRow(_StopRowData row, {required bool first, required bool last}) {
    // The dot sits on the address line; one line runs through the dots.
    const dotY = 27.0;
    const line = Color(0xFFE1E4E6);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 20,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                if (!first)
                  const Positioned(
                    top: 0,
                    height: dotY,
                    child: SizedBox(
                      width: 1.5,
                      child: ColoredBox(color: line),
                    ),
                  ),
                if (!last)
                  const Positioned(
                    top: dotY,
                    bottom: 0,
                    child: SizedBox(
                      width: 1.5,
                      child: ColoredBox(color: line),
                    ),
                  ),
                Positioned(
                  top: dotY - 5,
                  height: 10,
                  child: Center(child: row.dot),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 0, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.label,
                    style: const TextStyle(
                      color: _label,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    row.address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _ink,
                      fontSize: 15.5,
                      fontWeight: row.quiet ? FontWeight.w500 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (row.trailing case final trailing?) ...[
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 19),
              child: Text(
                trailing,
                style: TextStyle(
                  color: row.mutedTrailing ? _label : _ink,
                  fontSize: 13.5,
                  fontWeight: row.mutedTrailing
                      ? FontWeight.w600
                      : FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// TRIP / DISTANCE / STOPS.
  Widget _stats() {
    final cells = <(String, String)>[
      if (_show.tripMinutesKm) ('TRIP', '${request.tripMinutes} min'),
      if (_show.tripMinutesKm) ('DISTANCE', _km(request.tripKm)),
      if (_show.stops) ('STOPS', '${request.stops.length}'),
    ];
    return Container(
      key: const ValueKey<String>('reservation-stats'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _hairline),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cells.length; i++)
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: i == 0
                        ? null
                        : const Border(left: BorderSide(color: _hairline)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cells[i].$1,
                          maxLines: 1,
                          style: const TextStyle(
                            color: _label,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          cells[i].$2,
                          maxLines: 1,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _liveMap(BuildContext context) {
    return FutureBuilder<List<GeoPoint>>(
      key: ValueKey(_route),
      future: _route,
      initialData: reservationWaypoints(request),
      builder: (context, snapshot) => ReservationRouteMap(
        request: request,
        route: snapshot.data ?? reservationWaypoints(request),
        fitPadding: 22,
        show3DNotice: false,
      ),
    );
  }
}

class _StopRowData {
  const _StopRowData({
    required this.dot,
    required this.label,
    required this.address,
    this.trailing,
    this.quiet = false,
    this.mutedTrailing = false,
  });

  final Widget dot;
  final String label;
  final String address;
  final String? trailing;
  final bool quiet;
  final bool mutedTrailing;
}

/// The flat picture top-right of the card. Airport rides combine the
/// plane (top left) with the traveller walking with a bag (bottom right).
class _ReservationPictureView extends StatelessWidget {
  const _ReservationPictureView({required this.picture, required this.accent});

  final ReservationPicture picture;

  /// Drawn in place of [reservationPictureAccent].
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final key = ValueKey<String>('reservation-picture-${picture.name}');
    final colors = ReservationAccentMapper(accent);
    return KeyedSubtree(
      key: const ValueKey<String>('reservation-picture'),
      child: switch (picture) {
        ReservationPicture.booked => SvgPicture.asset(
          AppAssets.reservationBooked,
          key: key,
          fit: BoxFit.contain,
          colorMapper: colors,
        ),
        ReservationPicture.calendar => SvgPicture.asset(
          AppAssets.reservationCalendar,
          key: key,
          fit: BoxFit.contain,
          colorMapper: colors,
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
                    colorMapper: colors,
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
                    colorMapper: colors,
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

/// Small dot before each stop: pickup ring, grey stop ring, drop-off square.
class _StopDot extends StatelessWidget {
  const _StopDot.pickup({this.size = 9}) : _kind = 0;
  const _StopDot.stop() : _kind = 1, size = 7;
  const _StopDot.dropoff({this.size = 9}) : _kind = 2;

  final int _kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return switch (_kind) {
      0 => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: _ink, width: size >= 10 ? 2.2 : 2),
        ),
      ),
      1 => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: _decimals, width: 2),
        ),
      ),
      _ => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _ink,
          borderRadius: BorderRadius.circular(size >= 10 ? 2.5 : 2),
        ),
      ),
    };
  }
}

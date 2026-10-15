import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/routing/road_route_service.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/home/components/reservation_route_map.dart';
import 'package:movera/widgets/offer_badges.dart';
import 'package:movera/widgets/radar_offer_card.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

const Color _ink = Color(0xFF111518);
const Color _text = Color(0xFF3A444B);
const Color _label = Color(0xFF8A9399);
const Color _muted = Color(0xFF7C868D);
const Color _hairline = Color(0xFFF0F1F2);

Widget _solar(String asset, double size, [Color color = _ink]) =>
    SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );

/// The reservation request on Home (notes R11–R26): an extension of the
/// Home sheet, full width with rounded top corners and a fine black
/// contour. It sits behind the dock and rises out from under it with a
/// short spring while [visible]; it goes back down when it is not.
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
    this.bottomInset = 178,
    this.maxContentHeight = double.infinity,
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

  /// Space under the content, from the screen bottom: the dock and the
  /// radar orb sit there.
  final double bottomInset;

  /// Taller content (many stops, large text) scrolls inside the sheet.
  final double maxContentHeight;

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
      if (mounted && !_up) setState(() => _shown = null);
    }

    if (_rise.value <= 0 || _reduceMotion) {
      _rise.stop();
      _rise.value = 0;
      _shown = null;
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
    final sheet = PointerInterceptor(
      child: DecoratedBox(
        key: const ValueKey<String>('home-reservation-sheet'),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.maxContentHeight),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ReservationRequestSheet(
                request: request,
                onHide: widget.onHide,
                mapBuilder: widget.mapBuilder,
                routes: widget.routes,
                clock: widget.clock,
              ),
            ),
          ),
        ),
      ),
    );
    return AnimatedBuilder(
      animation: _rise,
      child: sheet,
      builder: (context, child) => _rise.value <= 0 && !_up
          ? const SizedBox.shrink()
          : FractionalTranslation(
              // Hidden: the whole sheet is below the screen edge, under
              // the dock. Up: its top edge stands above the dock.
              translation: Offset(0, 1 - _rise.value),
              child: child,
            ),
    );
  }
}

/// Content of the reservation request: title and picture, Comfort badge
/// and pickup day, price and ride, the real route map and the stops. No
/// Accept or Decline buttons: the radar accepts, the × only hides.
class ReservationRequestSheet extends StatefulWidget {
  const ReservationRequestSheet({
    super.key,
    required this.request,
    this.onHide,
    this.mapBuilder,
    this.routes,
    this.clock,
    this.details,
  });

  final ReservationRequestPreview request;

  /// Which details show (Q14); the admin's choice by default.
  final OfferCardDetails? details;

  /// The ×; null shows it disabled.
  final VoidCallback? onHide;

  /// Replaces the live maps (card and full route), for tests and previews.
  final WidgetBuilder? mapBuilder;

  /// Road routing; defaults to [RoadRouteService].
  final RouteRepository? routes;

  /// Now, for the time left until pickup; defaults to [DateTime.now].
  final DateTime Function()? clock;

  @override
  State<ReservationRequestSheet> createState() =>
      _ReservationRequestSheetState();
}

class _ReservationRequestSheetState extends State<ReservationRequestSheet> {
  ReservationRequestPreview get request => widget.request;
  OfferCardDetails get _show => widget.details ?? DriverOfferRules.current.card;
  RoadRouteService? _ownRoutes;
  late Future<List<GeoPoint>> _route;

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
  }

  @override
  void dispose() {
    _ownRoutes?.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    // Tight lines like the design, not the theme's body line height.
    return DefaultTextStyle.merge(
      style: const TextStyle(height: 1.2),
      child: Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              const SizedBox(height: 12),
              _priceRow(),
              const SizedBox(height: 12),
              _routeCard(context),
              const SizedBox(height: 6),
              _stops(),
            ],
          ),
        ),
        Positioned(right: 14, top: 14, child: _hideButton()),
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
          color: Colors.white,
          shape: const CircleBorder(side: BorderSide(color: Color(0xFFE3E6E8))),
          child: InkWell(
            key: const ValueKey<String>('reservation-hide'),
            customBorder: const CircleBorder(),
            onTap: onHide,
            child: SizedBox(
              width: 34,
              height: 34,
              child: Icon(
                Icons.close_rounded,
                size: 19,
                color: onHide == null ? const Color(0xFFB7BEC3) : _ink,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.only(right: 40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RESERVATION REQUEST',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _label,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Your next ride',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 26,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _categoryBadge(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _solar(AppAssets.solarCalendar, 15),
                        const SizedBox(width: 5),
                        Text(
                          '${request.pickupDay}, ${request.pickupTime}',
                          style: const TextStyle(
                            color: _text,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    // Payment only when the rider pays cash (notes R2).
                    if (_show.badges && request.paidByCash)
                      const OfferBadge.cash(
                        key: ValueKey<String>('reservation-cash'),
                      ),
                    // Admin raised the fare (Q13); the price has it.
                    if (request.fareBoost case final boost? when _show.badges)
                      OfferBadge.boost(
                        boost,
                        key: const ValueKey<String>('reservation-boost'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: ExcludeSemantics(
              child: SvgPicture.asset(
                AppAssets.orderRide,
                key: const ValueKey<String>('reservation-picture'),
                width: 96,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryBadge() {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 3, 10, 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _ink),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _solar(AppAssets.solarUser, 13),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              request.category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "126,75 kr" → "126" and ",75 kr", for the grey decimals.
  (String, String) _fareParts() {
    final fare = _show.fare(
      Money.parseSekLabel(request.fare)?.formatted ?? request.fare,
    );
    final comma = fare.lastIndexOf(',');
    return comma > 0
        ? (fare.substring(0, comma), fare.substring(comma))
        : (fare, '');
  }

  /// "Fare · in 1 h 33 min"; just "Fare" once the pickup time is unknown
  /// or has passed.
  String _fareLine() {
    final left = request.untilPickup((widget.clock ?? DateTime.now)());
    final what = _show.netFare ? 'Your share' : 'Fare';
    if (left == null) return what;
    // Whole minutes, rounded up: 1 h 32 min 40 s reads "1 h 33 min".
    final total = (left.inSeconds + 59) ~/ 60;
    final hours = total ~/ 60;
    final minutes = total % 60;
    final when = hours > 0
        ? (minutes > 0 ? '$hours h $minutes min' : '$hours h')
        : '$minutes min';
    return '$what · in $when';
  }

  static String _km(double km) => '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';

  Widget _priceRow() {
    final (whole, rest) = _fareParts();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
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
                          fontSize: 28,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                      TextSpan(
                        text: rest,
                        style: const TextStyle(
                          color: _label,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _fareLine(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 12.5),
              ),
            ],
          ),
        ),
        if (_show.tripMinutesKm) ...[
          const SizedBox(width: 8),
          _rideFact(AppAssets.solarClockCircle, '${request.tripMinutes} min'),
          const SizedBox(width: 10),
          _rideFact(AppAssets.solarRoute, _km(request.tripKm)),
        ],
      ],
    );
  }

  Widget _rideFact(String icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _solar(icon, 15),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            color: _text,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _routeCard(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 124,
        child: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(child: (widget.mapBuilder ?? _liveMap)(context)),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x0F000000)),
                ),
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
            const Positioned(
              right: 6,
              top: 6,
              child: IgnorePointer(child: _ViewRouteChip()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stops() {
    final show = _show;
    final stops = show.stops ? request.stops : const <ReservationStop>[];
    final eta = request.estimatedArrival;
    final rows = <Widget>[
      _stopRow(
        dot: const _StopDot.pickup(),
        label: 'PICKUP',
        address: show.pickupAddress
            ? request.pickupAddress
            : RadarOfferView.area(request.pickupAddress),
        trailing: request.pickupTime,
      ),
      for (var i = 0; i < stops.length; i++)
        _stopRow(
          dot: const _StopDot.stop(),
          label: stops.length == 1 ? 'STOP' : 'STOP ${i + 1}',
          address: stops[i].address,
          trailing: i == 0
              ? '${stops.length} stop${stops.length == 1 ? '' : 's'}'
              : null,
          quiet: true,
        ),
      _stopRow(
        dot: const _StopDot.dropoff(),
        label: 'DROP-OFF',
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
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 1, thickness: 1, color: _hairline),
          rows[i],
        ],
      ],
    );
  }

  Widget _stopRow({
    required Widget dot,
    required String label,
    required String address,
    String? trailing,
    bool quiet = false,
    bool mutedTrailing = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 22, child: Align(alignment: Alignment.centerLeft, child: dot)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _label,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 14.5,
                    fontWeight: quiet ? FontWeight.w500 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Text(
              trailing,
              style: TextStyle(
                color: quiet || mutedTrailing ? _label : _text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
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
        // Keeps the route clear of the "View route" chip.
        padding: const EdgeInsets.only(top: 26),
        fitPadding: 18,
        show3DNotice: false,
      ),
    );
  }
}

class _ViewRouteChip extends StatelessWidget {
  const _ViewRouteChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _solar(AppAssets.solarRoute, 12),
          const SizedBox(width: 4),
          const Text(
            'View route',
            style: TextStyle(
              color: _ink,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small dot before each stop: pickup ring, grey stop ring, drop-off square.
class _StopDot extends StatelessWidget {
  const _StopDot.pickup() : _kind = 0;
  const _StopDot.stop() : _kind = 1;
  const _StopDot.dropoff() : _kind = 2;

  final int _kind;

  @override
  Widget build(BuildContext context) {
    return switch (_kind) {
      0 => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: _ink, width: 2),
        ),
      ),
      1 => Padding(
        padding: const EdgeInsets.only(left: 1),
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF9AA3A9), width: 2),
          ),
        ),
      ),
      _ => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: _ink,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    };
  }
}

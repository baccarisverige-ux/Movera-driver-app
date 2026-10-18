import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/dispatch/pickup_pay.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/widgets/offer_badges.dart';
import 'package:movera/widgets/offer_route_pins.dart';
import 'package:movera/widgets/radar_offer_card.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

const Color _ink = Color(0xFF111518);
const Color _text = Color(0xFF5D646C);
const Color _label = Color(0xFF8A9399);
const Color _hairline = Color(0xFFEEF0F2);
const Color _declineFill = Color(0xFFF1F2F4);

/// The reservation request on Home (notes R11–R26, design A): the Home
/// sheet rises to about 40 % of the screen with every detail inside it and
/// no map (the Home map shows the route). The radar orb, the Accept, sits
/// centred on the sheet's top edge, half over the map. It rises from the
/// bottom with a short spring while [visible] and goes back down when not.
class HomeReservationSheet extends StatefulWidget {
  const HomeReservationSheet({
    super.key,
    required this.request,
    required this.visible,
    this.orb,
    this.onDecline,
    this.onShown,
    this.onHidden,
    this.clock,
    this.position = 1,
    this.count = 1,
    this.pickupPay,
    this.heightFactor = 0.4,
    this.maxHeight = double.infinity,
  });

  /// The reservation to show; null takes the sheet down.
  final ReservationRequestPreview? request;
  final bool visible;

  /// The radar orb on the top edge: tapping it accepts.
  final Widget? orb;

  /// Decline: the sheet goes down; the reservation stays open in
  /// Scheduled rides. Null while a claim is deciding.
  final VoidCallback? onDecline;

  /// Called each time the sheet is nearly up (Accept works from then),
  /// and after a frame once it starts to go down.
  final VoidCallback? onShown;
  final VoidCallback? onHidden;
  final DateTime Function()? clock;

  /// "2 of 2": this request's place among the ones waiting.
  final int position;
  final int count;

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

  @override
  State<HomeReservationSheet> createState() => _HomeReservationSheetState();
}

class _HomeReservationSheetState extends State<HomeReservationSheet>
    with SingleTickerProviderStateMixin {
  /// 0 hidden below the screen, 1 up; the spring passes 1 a little.
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

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

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
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              // The orb's lower half sits on the top of the sheet.
              padding: EdgeInsets.only(top: half + 4, bottom: safeBottom + 16),
              child: ReservationRequestSheet(
                request: request,
                onDecline: widget.onDecline,
                clock: widget.clock,
                position: widget.position,
                count: widget.count,
                pickupPay: widget.pickupPay,
              ),
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
        // White under the sheet while the spring passes the top.
        const Positioned(
          left: 0,
          right: 0,
          bottom: -60,
          height: 60,
          child: IgnorePointer(child: ColoredBox(color: Colors.white)),
        ),
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
        if (_rise.value <= 0 && !_up) return const SizedBox.shrink();
        return FractionalTranslation(
          // Hidden: the whole layer is below the screen edge.
          translation: Offset(0, 1 - _rise.value),
          child: child,
        );
      },
    );
  }
}

/// Content of the reservation request: category and payment chips with
/// "New reservation · 2 of 2", the big fare, the pickup time with the trip
/// numbers, pickup and drop-off, and Decline. The radar accepts.
class ReservationRequestSheet extends StatelessWidget {
  const ReservationRequestSheet({
    super.key,
    required this.request,
    this.onDecline,
    this.clock,
    this.details,
    this.position = 1,
    this.count = 1,
    this.pickupPay,
  });

  final ReservationRequestPreview request;

  /// Which details show (Q14); the admin's choice by default.
  final OfferCardDetails? details;

  /// Decline; null shows it disabled.
  final VoidCallback? onDecline;

  /// Now, for the time left until pickup; defaults to [DateTime.now].
  final DateTime Function()? clock;

  /// "2 of 2" after "New reservation"; hidden while only one waits.
  final int position;
  final int count;

  /// Pickup pay added to the price: only for an exclusive reservation
  /// (`PickupPayOfferKind.exclusiveReservation`).
  final PickupPayQuote? pickupPay;

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

  /// "in 3 h 20 min", "in 1 day"; null once the pickup time is unknown or
  /// has passed.
  String? _inLabel() {
    final left = request.untilPickup((clock ?? DateTime.now)());
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
    final inLabel = _inLabel();
    final title = driverText(DriverTexts.offerNewReservation);
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
                  Flexible(
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
                  const SizedBox(width: 10),
                  Text(
                    count > 1 ? '$title · $position of $count' : title,
                    key: const ValueKey<String>('reservation-title'),
                    maxLines: 1,
                    style: const TextStyle(
                      color: _label,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
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
              ),
              const SizedBox(height: 4),
              Text.rich(
                key: const ValueKey<String>('reservation-when'),
                TextSpan(
                  style: const TextStyle(color: _text, fontSize: 14),
                  children: [
                    const TextSpan(text: 'Pickup '),
                    TextSpan(
                      text: _whenLabel,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (inLabel != null) TextSpan(text: ' · $inLabel'),
                    if (_show.tripMinutesKm)
                      TextSpan(
                        text: ' · ${_km(request.tripKm)}'
                            ' · ${request.tripMinutes} min',
                      ),
                  ],
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 1, color: _hairline),
              const SizedBox(height: 10),
              _place(const _StopMark.pickup(), _pickupPlace, 'reservation-pickup'),
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
              ),
              const SizedBox(height: 12),
              _declineButton(),
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

  Widget _place(Widget mark, String place, String key) {
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
        ],
      ),
    );
  }

  Widget _declineButton() {
    final onTap = onDecline;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: 'Decline reservation request',
      excludeSemantics: true,
      child: Material(
        color: _declineFill,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: const ValueKey<String>('reservation-decline'),
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: SizedBox(
            height: 50,
            child: Center(
              child: Text(
                'Decline',
                style: TextStyle(
                  color: onTap == null ? const Color(0xFFA2AAB0) : _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
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

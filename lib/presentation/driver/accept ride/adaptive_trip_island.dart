import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:movera/core/island/trip_island_controller.dart';

import 'island_icons.dart';
import 'island_waiting_motion.dart';

import 'package:movera/core/routing/route_instruction.dart';
import 'package:movera/core/safety/ride_check_l10n.dart';
import 'package:movera/core/safety/ride_check.dart';
import 'package:movera/presentation/driver/accept%20ride/ride_check_card.dart';
import 'package:movera/presentation/driver/accept%20ride/navigation_instruction_banner.dart';
import 'package:movera/presentation/driver/accept%20ride/trip_island.dart';
import 'package:movera/presentation/driver/accept%20ride/island_morph.dart';
import 'package:movera/presentation/driver/home/components/island_side_hit_slop.dart';

/// Trip information has one surface. Touch temporarily reveals the original
/// island; inactivity returns to the live face without changing trip state.
class AdaptiveTripIsland extends StatefulWidget {
  const AdaptiveTripIsland({
    super.key,
    this.banner,
    required this.status,
    required this.address,
    required this.detail,
    required this.eta,
    this.arrival,
    this.arrived = false,
    required this.progress,
    this.waitingSeconds,
    this.paidSeconds,
    this.waitingAtStop = false,
    this.navigationStatus,
    this.reroutes = 0,
    required this.waitingMessage,
    this.paidWait = false,
    this.paidByCash = false,
    required this.lastTripLabel,
    this.radarVisible = false,
    this.radarOn = false,
    required this.onRadar,
    required this.onMenu,
    required this.onSearch,
    required this.onHistory,
    required this.onRoute,
    required this.onSafety,
    required this.onWait,
    this.rideCheck = false,
    this.onRideCheckDemo,
    this.pointKind,
    this.pointLabel,
    this.bags = 0,
    this.nextTripFare,
    this.sheetPosition,
    this.sheetRaisedAt = 1,
  });

  /// The point the trip heads to now and its label ("Stop 1").
  final ArrivalPointKind? pointKind;
  final String? pointLabel;

  /// Bags from the booking; said once while heading to the pickup.
  final int bags;

  /// Fare of a secured next trip; said once right after it is secured.
  final String? nextTripFare;

  /// The trip sheet's position (0 down .. 1 full). Above [sheetRaisedAt]
  /// the strip tucks under the island.
  final ValueListenable<double>? sheetPosition;
  final double sheetRaisedAt;

  /// Height of the lighter strip under the route island.
  static const stripHeight = 34.0;

  /// Arriving this close (or there): the strip tucks under the island.
  static const tuckWithinMeters = 60.0;

  /// A Ride check is open: the island turns into its pulsing pill and the
  /// card grows from there (see [RideCheckLayer]).
  final bool rideCheck;

  /// Demo tools: opens the Ride check card for a trigger.
  final ValueChanged<RideCheckTrigger>? onRideCheckDemo;

  final NavigationBanner? banner;
  final String status, address, detail, eta, waitingMessage, lastTripLabel;
  final String? arrival;
  final double progress;
  final int? waitingSeconds, paidSeconds;
  final bool waitingAtStop;
  final String? navigationStatus;

  /// Completed reroutes, see [TripIslandInput.reroutes].
  final int reroutes;
  final bool paidWait, paidByCash, arrived;

  /// Radar on/off during the trip: in the long-press tools sheet only
  /// (the island has no radar button).
  final bool radarVisible, radarOn;
  final VoidCallback onRadar,
      onMenu,
      onSearch,
      onHistory,
      onRoute,
      onSafety,
      onWait;

  /// Home draws its island here: just under the clock and camera.
  static double islandTop(BuildContext context) =>
      math.max(MediaQuery.paddingOf(context).top - 4, 10.0);

  /// Width of the route island; never wider than the screen allows.
  static const routeWidth = 366.0;

  /// Height of the route island: top information plus the darker strip.
  static const routeHeight = 124.0;

  @override
  State<AdaptiveTripIsland> createState() => _AdaptiveTripIslandState();
}

class _AdaptiveTripIslandState extends State<AdaptiveTripIsland>
    with SingleTickerProviderStateMixin {
  late final TripIslandController _controller;
  final _strip = TripStripController();

  /// 0 strip shown .. 1 strip tucked under the island.
  late final AnimationController _tuck = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  bool _tuckTarget = false;
  bool _sheetRaised = false;
  String? _tuckFace;
  TripIslandInput get _input => TripIslandInput(
    status: widget.status,
    address: widget.address,
    waitingMessage: widget.waitingMessage,
    banner: widget.banner,
    arrival: widget.arrival,
    arrived: widget.arrived,
    waitingSeconds: widget.waitingSeconds,
    paidSeconds: widget.paidSeconds,
    paidWait: widget.paidWait,
    waitingAtStop: widget.waitingAtStop,
    navigationStatus: widget.navigationStatus,
    reroutes: widget.reroutes,
  );
  void _changed() {
    if (mounted) setState(() {});
  }

  void _faceChanged() {
    _syncTuck();
    _changed();
  }

  @override
  void initState() {
    super.initState();
    _controller = TripIslandController(_input);
    _sheetRaised = _raised;
    _syncTuck();
    // Listen only after the first sync: no rebuild requests in initState.
    _controller.addListener(_faceChanged);
    _strip.addListener(_changed);
    _tuck.addListener(_changed);
    widget.sheetPosition?.addListener(_sheetMoved);
  }

  @override
  void didUpdateWidget(AdaptiveTripIsland oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sheetPosition != widget.sheetPosition) {
      oldWidget.sheetPosition?.removeListener(_sheetMoved);
      widget.sheetPosition?.addListener(_sheetMoved);
    }
    _sheetRaised = _raised;
    _controller.update(_input);
    _syncTuck();
  }

  @override
  void dispose() {
    widget.sheetPosition?.removeListener(_sheetMoved);
    _controller.removeListener(_faceChanged);
    _controller.dispose();
    _strip.dispose();
    _tuck.dispose();
    super.dispose();
  }

  bool get _raised =>
      (widget.sheetPosition?.value ?? 0) > widget.sheetRaisedAt;

  void _sheetMoved() {
    final raised = _raised;
    if (raised == _sheetRaised) return;
    _sheetRaised = raised;
    _syncTuck();
  }

  bool get _routeFace {
    final kind = _controller.face.kind;
    return !widget.rideCheck &&
        !_controller.defaultFace &&
        (kind == TripIslandKind.guidance || kind == TripIslandKind.arrival);
  }

  String get _faceIdentity => widget.rideCheck
      ? 'ride-check'
      : _controller.defaultFace
      ? 'default'
      : _controller.face.identity;

  /// Meters to the point while arriving, from the live instruction.
  double? get _arrivalMeters {
    final meters = widget.banner?.distanceMeters;
    if (meters != null) return meters;
    final parts = _distanceParts(widget.banner?.distanceLabel);
    final value = double.tryParse(parts?.$1.replaceAll(',', '.') ?? '');
    if (parts == null || value == null) return null;
    return parts.$2 == 'km' ? value * 1000 : value;
  }

  /// The strip hides under the island only when arriving at the point or
  /// while the driver has the trip sheet slid up.
  void _syncTuck() {
    final face = _controller.face;
    final meters = _arrivalMeters;
    final arriving =
        face.kind == TripIslandKind.arrival &&
        (widget.arrived ||
            (widget.banner?.symbol.isArrival == true &&
                meters != null &&
                meters <= AdaptiveTripIsland.tuckWithinMeters));
    final target = _routeFace && (arriving || _sheetRaised);
    final identity = _faceIdentity;
    final sameFace = identity == _tuckFace;
    _tuckFace = identity;
    _strip.update(_stripInput, hidden: target);
    if (target == _tuckTarget) return;
    _tuckTarget = target;
    if (!sameFace || MediaQuery.maybeDisableAnimationsOf(context) == true) {
      // A new face morphs on its own; only the same face slides the strip.
      _tuck.value = target ? 1 : 0;
    } else {
      _tuck.animateTo(
        target ? 1 : 0,
        curve: target ? Curves.easeInCubic : Curves.easeOutCubic,
      );
    }
  }

  TripStripInput get _stripInput {
    final b = widget.banner;
    final leg = switch (widget.pointKind) {
      ArrivalPointKind.pickup => TripLeg.pickup,
      ArrivalPointKind.stop => TripLeg.stop,
      ArrivalPointKind.destination => TripLeg.dropoff,
      null => null,
    };
    final lanes = b?.lanes ?? const <RouteLane>[];
    return TripStripInput(
      leg: leg,
      stopLabel: leg == TripLeg.stop ? widget.pointLabel : null,
      etaMinutes: int.tryParse(
        RegExp(r'^(\d+)\s*min').firstMatch(widget.eta)?.group(1) ?? '',
      ),
      bags: widget.bags,
      nextTripFare: widget.nextTripFare,
      pickupSide: b?.symbol == NavigationBannerSymbol.arriveLeft
          ? 'left'
          : b?.symbol == NavigationBannerSymbol.arriveRight
          ? 'right'
          : null,
      // A toll the island already shows as the cue needs no message.
      toll: (b?.toll ?? false) && b?.symbol != NavigationBannerSymbol.toll,
      laneKey: !_routeFace || !RouteLane.matter(lanes)
          ? null
          : [
              b!.symbol.name,
              b.roadName,
              b.exitNumber,
              for (final l in lanes) l.valid ? 'u' : 'o',
            ].join('-'),
    );
  }

  static const _blue = Color(0xFF58A6FF);
  static const _lavender = Color(0xFFBDA6F5);
  static const _muted = Color(0xFFB8C0CC);

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      12,
      AdaptiveTripIsland.islandTop(context),
      12,
      0,
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final presentation = _controller.face;
        final waiting =
            presentation.kind == TripIslandKind.waitingTimer ||
            presentation.kind == TripIslandKind.waitingMessage;
        final waitingMessage =
            presentation.kind == TripIslandKind.waitingMessage;
        final title = presentation.title;
        final subtitle = presentation.subtitle;
        final accent = presentation.kind == TripIslandKind.status
            ? const Color(0xFFF2B86B)
            : waiting
            ? (widget.waitingAtStop ? const Color(0xFFF2B86B) : _lavender)
            : presentation.kind == TripIslandKind.arrival
            ? const Color(0xFFFF818B)
            : _blue;
        final scale = MediaQuery.textScalerOf(context);
        final heading = DefaultTextStyle.of(context).style.merge(
          TextStyle(
            color: Colors.white,
            fontSize: waiting ? (waitingMessage ? 12.5 : 18) : 12.5,
            fontWeight: FontWeight.w600,
            height: 1.05,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
        double measure(String text, TextStyle style) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: Directionality.of(context),
            textScaler: scale,
          )..layout();
          return painter.width;
        }

        // Never smaller than the Home island.
        final home = Size(
          math.min(available, TripIslandGeometry.width),
          TripIslandGeometry.height,
        );
        final route =
            !_controller.defaultFace &&
            (presentation.kind == TripIslandKind.guidance ||
                presentation.kind == TripIslandKind.arrival);
        Size size;
        double? radius;
        Widget content;
        if (widget.rideCheck) {
          size = RideCheckPillFace.sizeFor(available);
          content = const RideCheckPillFace();
        } else if (_controller.defaultFace) {
          size = home;
          content = TripIsland(
            key: const ValueKey('trip-default-island'),
            lastTripLabel: widget.lastTripLabel,
            onMenu: widget.onMenu,
            onSearch: widget.onSearch,
            onHistory: widget.onHistory,
          );
        } else if (route) {
          size = Size(
            math.min(available, AdaptiveTripIsland.routeWidth),
            AdaptiveTripIsland.routeHeight -
                AdaptiveTripIsland.stripHeight * _tuck.value,
          );
          radius = 26;
          content = _routeIsland(presentation, size);
        } else {
          // A message sizes the island to its words; the height stays Home's.
          final measuredTitle = waiting && !waitingMessage
              ? '${'8' * math.max(2, (widget.waitingSeconds! ~/ 60).toString().length)}:88'
              : title;
          final desired =
              math.max(
                measure(measuredTitle, heading),
                measure(subtitle, const TextStyle(fontSize: 9)),
              ) +
              84;
          size = Size(
            desired.clamp(home.width, available).toDouble(),
            home.height,
          );
          content = Padding(
            key: ValueKey(
              waiting ? 'trip-waiting-island' : 'trip-status-island',
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: waiting
                            ? Icon(
                                Icons.timer_outlined,
                                color: accent,
                                size: 22,
                              )
                            : Tooltip(
                                message: tr.tripRouteAndOptions,
                                child: InkWell(
                                  onTap: widget.onRoute,
                                  borderRadius: BorderRadius.circular(20),
                                  child: SizedBox(
                                    height: 28,
                                    child: Icon(
                                      Icons.info_outline_rounded,
                                      color: accent,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: waiting && !waitingMessage
                            ? InkWell(
                                key: const ValueKey('island-waiting-timer'),
                                onTap: widget.onWait,
                                child: _message(
                                  title,
                                  subtitle,
                                  heading,
                                  clock: true,
                                ),
                              )
                            : KeyedSubtree(
                                key: waiting
                                    ? const ValueKey('island-waiting-name')
                                    : null,
                                child: _message(title, subtitle, heading),
                              ),
                      ),
                      // Symmetric slots keep text at the island's true center.
                      const SizedBox(width: 30),
                    ],
                  ),
                ),
                const SizedBox(height: 1),
                if (waiting)
                  IslandWaitingLane(color: accent)
                else
                  const SizedBox(height: 3),
              ],
            ),
          );
        }
        final face = widget.rideCheck
            ? 'ride-check'
            : _controller.defaultFace
            ? 'default'
            : presentation.identity;
        // UI-12: menu and search (on the Home-like face) take touches in a
        // 48 x 48 box; the island paints exactly as before.
        final sides = _controller.defaultFace && !widget.rideCheck;
        return Align(
          alignment: Alignment.topCenter,
          heightFactor: 1,
          child: IslandSideHitSlop(
            target: IslandSideHitSlop.minTarget,
            // Room below for the touch boxes; only on that face, so the
            // other faces keep their exact size.
            growth: EdgeInsets.only(
              bottom: sides
                  ? math.max(0.0, IslandSideHitSlop.minTarget - size.height)
                  : 0,
            ),
            child: Listener(
            onPointerDown: (_) => _controller.hold(),
            onPointerUp: (_) => _controller.release(),
            onPointerCancel: (_) => _controller.release(),
            child: GestureDetector(
              onLongPress: waiting || widget.rideCheck ? null : _showTools,
              child: IslandMorph(
                size: size,
                radius: radius,
                // The Home island draws its own shell: no double outline.
                shell: widget.rideCheck || !_controller.defaultFace,
                face: face,
                followSize: route,
                reducedMotion: MediaQuery.disableAnimationsOf(context),
                child: content,
              ),
            ),
          ),
          ),
        );
      },
    ),
  );

  static final _distanceText = RegExp(
    r'(?:\s*·\s*|\s+in\s+|\s+)?(\d+(?:[.,]\d+)?)\s?(km|m)\b',
    caseSensitive: false,
  );

  /// The large number from the banner's meters: 300 -> ("300", "m"),
  /// 1200 -> ("1.2", "km") ("1,2" in French and Swedish), under 25 m
  /// ("Now", null). Without meters, read from the label.
  static (String, String?)? _bannerDistance(NavigationBanner? banner) {
    final meters = banner?.distanceMeters;
    if (meters == null || !meters.isFinite) {
      return _distanceParts(banner?.distanceLabel);
    }
    if (meters < RouteInstructionCopy.nowMeters) return (tr.now, null);
    if (meters < 1000) return ('${meters.round()}', 'm');
    final km = meters / 1000;
    return (
      km.toStringAsFixed(km < 10 ? 1 : 0).replaceAll('.', tr.navDecimalMark),
      'km',
    );
  }

  /// "300 m" -> ("300", "m"); "now" -> ("Now", null).
  static (String, String?)? _distanceParts(String? text) {
    if (text == null) return null;
    if (RegExp(r'^\s*now\s*$', caseSensitive: false).hasMatch(text)) {
      return (tr.now, null);
    }
    final match = _distanceText.firstMatch(text);
    if (match == null) return null;
    return (match.group(1)!, match.group(2)!.toLowerCase());
  }

  /// Route island: top information (cue, large distance, instruction,
  /// street) and the lighter strip with the arrival time and progress.
  /// The strip slides up under the top part as it tucks.
  Widget _routeIsland(TripIslandFace face, Size size) {
    final live = widget.banner;
    final arrival = face.kind == TripIslandKind.arrival;
    // The large number is the distance to the next maneuver, or to the
    // point itself while arriving; never the whole route. At the point
    // (near it, waiting there) or without a known distance: icon only.
    final distance = arrival
        ? (widget.arrived || live?.symbol.isArrival != true
              ? null
              : _bannerDistance(live))
        : (_bannerDistance(live) ?? _distanceParts(face.title));
    final pin = ArrivingRoadPainter.pinFor(widget.arrival);
    const top = AdaptiveTripIsland.routeHeight - AdaptiveTripIsland.stripHeight;
    final strip = math.max(0.0, size.height - top);
    return SizedBox(
      key: const ValueKey('trip-guidance-island'),
      width: size.width,
      height: size.height,
      child: Column(
        children: [
          SizedBox(
            height: math.min(top, size.height),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 10, 6),
              child: Row(
                children: [
                  Tooltip(
                    message: tr.tripRouteAndOptions,
                    child: InkWell(
                      key: const ValueKey('island-route-cue'),
                      onTap: widget.onRoute,
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: 74,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (arrival)
                              Semantics(
                                label: tr.arrival,
                                child: CustomPaint(
                                  key: const ValueKey('island-arriving-icon'),
                                  size: const Size(46, 34),
                                  painter: ArrivingRoadPainter(pin: pin),
                                ),
                              )
                            else
                              SizedBox(
                                width: 34,
                                height: 34,
                                child: _cue(face, live, Colors.white),
                              ),
                            const SizedBox(height: 2),
                            if (distance != null)
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: distance.$1,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: distance.$2 == null
                                              ? 22
                                              : 25,
                                          fontWeight: FontWeight.w700,
                                          height: 1,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                      if (distance.$2 != null)
                                        TextSpan(
                                          text: distance.$2,
                                          style: const TextStyle(
                                            color: _muted,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                    ],
                                  ),
                                  key: const ValueKey('island-distance'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.2,
                      child: arrival ? _arrivalText() : _guidanceText(face),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // The lighter strip; aligned to its bottom so it slides up under
          // the top part while the island shrinks.
          ClipRect(
            child: SizedBox(
              height: strip,
              child: OverflowBox(
                alignment: Alignment.bottomCenter,
                minHeight: AdaptiveTripIsland.stripHeight,
                maxHeight: AdaptiveTripIsland.stripHeight,
                child: _stripBody(arrival ? pin : _blue),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Instruction without the distance, then the street with road signs.
  Widget _guidanceText(TripIslandFace face) {
    final live = widget.banner;
    final instruction = live?.instruction;
    var title = instruction != null && face.title == live?.primary
        ? instruction
        : face.title
              .replaceAll(_distanceText, '')
              .replaceAll(RegExp(r'\s*·\s*$'), '')
              .trim();
    if (title.isEmpty) title = face.title;
    final road = live?.roadName?.trim() ?? '';
    final shields = live?.shields ?? const <RoadShield>[];
    final towards = live?.towards?.trim() ?? '';
    final parts = [
      for (final part in face.subtitle.split(' · '))
        if (part.isNotEmpty &&
            _distanceParts(part) == null &&
            !title.contains(part))
          part,
      if (road.isNotEmpty &&
          !title.contains(road) &&
          !face.subtitle.contains(road))
        road,
    ];
    // With signs the place reads "towards Södertälje"; the street stays
    // when nothing is signposted.
    final line2 = shields.isNotEmpty && towards.isNotEmpty
        ? tr.navTowards(towards)
        : [...parts, if (towards.isNotEmpty) tr.navTowards(towards)].join(' · ');
    final hasLine2 = line2.isNotEmpty || shields.isNotEmpty;
    return Semantics(
      label: [
        title,
        for (final shield in shields) shield.label,
        if (line2.isNotEmpty) line2,
      ].join(', '),
      excludeSemantics: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: hasLine2 ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          if (hasLine2) ...[
            const SizedBox(height: 3),
            Text.rich(
              TextSpan(
                children: [
                  for (final shield in shields)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: RoadShieldChip(shield),
                    ),
                  TextSpan(text: line2),
                ],
              ),
              maxLines: shields.isEmpty ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.2),
            ),
          ],
        ],
      ),
    );
  }

  /// One small word ("Arriving", "Stop 1"), the address big, the area under.
  Widget _arrivalText() {
    final label = widget.arrival ?? '';
    final word = ArrivingRoadPainter.isStop(label) ? label : tr.arriving;
    final address = widget.address.trim();
    final comma = address.indexOf(',');
    final street = comma < 0 ? address : address.substring(0, comma).trim();
    final area = comma < 0 ? '' : address.substring(comma + 1).trim();
    return Semantics(
      label: [word, address].join(', '),
      excludeSemantics: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            word,
            key: const ValueKey('island-arrival-word'),
            maxLines: 1,
            style: const TextStyle(
              color: _muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            street,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.12,
              letterSpacing: -.2,
            ),
          ),
          if (area.isNotEmpty)
            Text(
              area,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.2),
            ),
        ],
      ),
    );
  }

  /// The strip's content, rotated with a short crossfade and slide.
  Widget _stripBody(Color progressColor) {
    final item = _strip.current;
    final lanes = widget.banner?.lanes ?? const <RouteLane>[];
    final reduced = MediaQuery.disableAnimationsOf(context);
    Widget child;
    if (item.kind == TripStripKind.lanes && lanes.isNotEmpty) {
      child = Row(
        key: ValueKey('strip-lanes-${item.text}'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LaneGuidanceRow(
            lanes: lanes,
            modifier: widget.banner?.laneModifier ?? '',
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              RouteLane.hint(lanes),
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
      );
    } else if (item.kind == TripStripKind.message) {
      child = Center(
        key: ValueKey('strip-message-${item.text}'),
        child: Text(
          item.text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      );
    } else {
      final percent = (widget.progress.clamp(0, 1) * 100).round();
      child = Row(
        key: const ValueKey('strip-eta'),
        children: [
          Text(
            _arrivalLine(),
            style: const TextStyle(
              color: Color(0xFF34D399),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _routeProgress(progressColor, true)),
          const SizedBox(width: 8),
          Text(
            '$percent%',
            style: const TextStyle(
              color: _muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      );
    }
    return Container(
      key: const ValueKey('island-route-strip'),
      height: AdaptiveTripIsland.stripHeight,
      color: const Color(0x14FFFFFF),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedSwitcher(
        duration: reduced ? Duration.zero : const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (current, previous) => Stack(
          fit: StackFit.expand,
          children: [...previous, if (current != null) current],
        ),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, .35),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: child,
      ),
    );
  }

  /// "4 min · 21:18": time left and the clock time of arrival.
  String _arrivalLine() {
    final minutes = RegExp(r'^(\d+)\s*min').firstMatch(widget.eta);
    if (minutes == null) return widget.eta;
    final at = DateTime.now().add(
      Duration(minutes: int.parse(minutes.group(1)!)),
    );
    String two(int v) => v.toString().padLeft(2, '0');
    return '${widget.eta} · ${two(at.hour)}:${two(at.minute)}';
  }

  Widget _message(
    String title,
    String subtitle,
    TextStyle heading, {
    bool clock = false,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      final scaler = MediaQuery.textScalerOf(context);
      final showSubtitle = subtitle.isNotEmpty && scaler.scale(1) <= 1.1;
      final titleHeight = constraints.maxHeight - (showSubtitle ? 10.5 : 0);
      // Geometry remains the default height, including large text settings.
      // Full copy remains available to screen readers and the tooltip.
      var fontSize = math.min(
        heading.fontSize!,
        titleHeight / (scaler.scale(1) * 1.05),
      );
      if (clock) {
        final metrics = TextPainter(
          text: TextSpan(
            text: title,
            style: heading.copyWith(fontSize: fontSize),
          ),
          textDirection: Directionality.of(context),
          textScaler: scaler,
        )..layout();
        if (metrics.width > constraints.maxWidth - 2) {
          fontSize *= math.max(0.0, constraints.maxWidth - 2) / metrics.width;
        }
      }
      return Semantics(
        label: [title, if (subtitle.isNotEmpty) subtitle].join(', '),
        excludeSemantics: true,
        child: Tooltip(
          message: [title, if (subtitle.isNotEmpty) subtitle].join(' · '),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (clock)
                IslandRollingClock(
                  text: title,
                  style: heading.copyWith(fontSize: fontSize),
                )
              else
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: heading.copyWith(fontSize: fontSize),
                ),
              if (showSubtitle) ...[
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 9,
                    height: 1.05,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );

  Widget _cue(TripIslandFace face, NavigationBanner? live, Color accent) {
    // Hand-made banners without the numbers: read the exit from the text.
    final exit =
        live?.exitNumber ??
        live?.exitRef ??
        RegExp(
          r'exit\s+(\d+)',
          caseSensitive: false,
        ).firstMatch(live?.primary ?? '')?.group(1);
    final symbol = live?.symbol;
    return Semantics(
      label:
          exit == null
              ? symbol?.name ?? tr.navToDestination
              : tr.navExitSemantics(symbol?.name ?? tr.navToDestination, exit),
      child: live == null || symbol == null
          ? const Icon(
              Icons.person_outline_rounded,
              color: Colors.white,
              size: 24,
            )
          : symbol.isRoundabout
          ? CustomPaint(
              size: const Size(24, 24),
              painter: RoundaboutCuePainter(
                exitDegrees: symbol == NavigationBannerSymbol.roundaboutUTurn &&
                        live.exitAngleDegrees == null
                    ? 250
                    : RoundaboutCuePainter.degreesFor(
                        exitAngle: live.exitAngleDegrees,
                        exitNumber: exit,
                      ),
                exitNumber: exit,
                color: accent,
                clockwise: symbol == NavigationBannerSymbol.roundaboutClockwise,
                fontFamily: DefaultTextStyle.of(context).style.fontFamily,
              ),
            )
          : CustomPaint(
              size: const Size(24, 24),
              painter: NavigationCuePainter(
                symbol: symbol,
                icon: Icons.navigation_rounded,
                color: accent,
                exitNumber: exit,
                exitAngleDegrees: live.exitAngleDegrees,
                fontFamily: DefaultTextStyle.of(context).style.fontFamily,
              ),
            ),
    );
  }

  Future<void> _showTools() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.alt_route_rounded),
              title: Text(tr.tripRouteAndOptions),
              onTap: () => popOwned(context, 'route'),
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: Text(tr.safetyToolkit),
              onTap: () => popOwned(context, 'safety'),
            ),
            if (widget.radarVisible)
              ListTile(
                leading: const Icon(Icons.radar_rounded),
                title: Text(
                  widget.radarOn
                      ? tr.turnExclusiveOffersOff
                      : tr.turnExclusiveOffersOn,
                ),
                onTap: () => popOwned(context, 'radar'),
              ),
            ListTile(
              leading: Icon(
                widget.paidByCash
                    ? Icons.payments_rounded
                    : Icons.credit_card_rounded,
              ),
              title: Text(
                widget.paidByCash ? tr.cashCollectInCar : tr.paidByCard,
              ),
            ),
            if (widget.onRideCheckDemo != null) ...[
              const Divider(height: 1),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    tr.rideCheckDemo,
                    style: TextStyle(
                      color: Color(0xFF7D898F),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              for (final (trigger, icon) in _rideCheckDemos)
                ListTile(
                  key: ValueKey('ride-check-demo-${trigger.name}'),
                  leading: RideCheckStyle.icon(
                    icon,
                    color: const Color(0xFF45525A),
                  ),
                  title: Text(tr.demoValue(trigger.text.toLowerCase())),
                  onTap: () => popOwned(context, 'ride-check-${trigger.name}'),
                ),
            ],
          ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'route':
        widget.onRoute();
      case 'safety':
        widget.onSafety();
      case 'radar':
        widget.onRadar();
    }
    for (final trigger in RideCheckTrigger.values) {
      if (action == 'ride-check-${trigger.name}') {
        widget.onRideCheckDemo?.call(trigger);
      }
    }
  }

  static final _rideCheckDemos = [
    for (final trigger in RideCheckTrigger.values)
      (trigger, RideCheckStyle.triggerIcon(trigger)),
  ];

  /// Route fraction belongs to the active leg. Waiting uses its own activity lane.
  Widget _routeProgress(Color accent, bool available) => Semantics(
    label: tr.routeProgress,
    value: available
        ? '${(widget.progress.clamp(0, 1) * 100).round()} percent'
        : tr.unavailable,
    child: TweenAnimationBuilder<double>(
      tween: Tween<double>(
        end: available ? widget.progress.clamp(0, 1).toDouble() : 0,
      ),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 350),
      builder: (context, progress, _) => SizedBox(
        height: 12,
        child: Stack(
          alignment: Alignment.centerLeft,
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF2C323B),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Align(
              alignment: Alignment(progress * 2 - 1, 0),
              child: Icon(Icons.navigation_rounded, size: 12, color: accent),
            ),
          ],
        ),
      ),
    ),
  );
}

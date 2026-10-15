import 'package:movera/widgets/owned_route_exit.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:movera/core/island/trip_island_controller.dart';

import 'island_icons.dart';
import 'island_waiting_motion.dart';

import 'package:movera/core/routing/route_instruction.dart';
import 'package:movera/core/safety/ride_check.dart';
import 'package:movera/presentation/driver/accept%20ride/ride_check_card.dart';
import 'package:movera/presentation/driver/accept%20ride/navigation_instruction_banner.dart';
import 'package:movera/presentation/driver/accept%20ride/trip_island.dart';
import 'package:movera/presentation/driver/accept%20ride/island_morph.dart';

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
  });

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

class _AdaptiveTripIslandState extends State<AdaptiveTripIsland> {
  late final TripIslandController _controller;
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

  @override
  void initState() {
    super.initState();
    _controller = TripIslandController(_input)..addListener(_changed);
  }

  @override
  void didUpdateWidget(AdaptiveTripIsland oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.update(_input);
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _controller.dispose();
    super.dispose();
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
            AdaptiveTripIsland.routeHeight,
          );
          radius = 26;
          content = _routeIsland(presentation, accent, size);
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
                                message: 'Trip route and options',
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
        return Align(
          alignment: Alignment.topCenter,
          heightFactor: 1,
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
                reducedMotion: MediaQuery.disableAnimationsOf(context),
                child: content,
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

  /// "300 m" -> ("300", "m"); "now" -> ("Now", null).
  static (String, String?)? _distanceParts(String? text) {
    if (text == null) return null;
    if (RegExp(r'^\s*now\s*$', caseSensitive: false).hasMatch(text)) {
      return ('Now', null);
    }
    final match = _distanceText.firstMatch(text);
    if (match == null) return null;
    return (match.group(1)!, match.group(2)!.toLowerCase());
  }

  /// Route island: top information (cue, large distance, instruction,
  /// street) and a darker strip with the arrival time and progress.
  Widget _routeIsland(TripIslandFace face, Color accent, Size size) {
    final live = widget.banner;
    final arrival = face.kind == TripIslandKind.arrival;
    // The large number is the distance to the next maneuver, or to the
    // point itself while arriving; never the whole route. At the point
    // (near it, waiting there) or without a known distance: icon only.
    final distance = arrival
        ? (widget.arrived || live?.symbol != NavigationBannerSymbol.arrive
              ? null
              : _distanceParts(live?.distanceLabel))
        : (_distanceParts(live?.distanceLabel) ?? _distanceParts(face.title));
    // The instruction without the distance; the distance is shown large.
    var title = face.title
        .replaceAll(_distanceText, '')
        .replaceAll(RegExp(r'\s*·\s*$'), '')
        .trim();
    if (title.isEmpty) title = face.title;
    final road = live?.roadName?.trim() ?? '';
    final line2 = arrival
        ? widget.address
        : [
            for (final part in face.subtitle.split(' · '))
              if (part.isNotEmpty &&
                  _distanceParts(part) == null &&
                  !title.contains(part))
                part,
            if (road.isNotEmpty &&
                !title.contains(road) &&
                !face.subtitle.contains(road))
              road,
          ].join(' · ');
    final percent = (widget.progress.clamp(0, 1) * 100).round();
    return SizedBox(
      key: const ValueKey('trip-guidance-island'),
      width: size.width,
      height: size.height,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 10, 6),
              child: Row(
                children: [
                  Tooltip(
                    message: 'Trip route and options',
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
                            SizedBox(
                              width: 34,
                              height: 34,
                              child: _cue(
                                face,
                                live,
                                Colors.white,
                                arrivalColor: accent,
                              ),
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
                    child: Semantics(
                      label: [title, if (line2.isNotEmpty) line2].join(', '),
                      excludeSemantics: true,
                      child: MediaQuery.withClampedTextScaling(
                        maxScaleFactor: 1.2,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: line2.isEmpty ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                height: 1.15,
                              ),
                            ),
                            if (line2.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                line2,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 12.5,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // The darker strip: arrival time and the leg's progress.
          Container(
            key: const ValueKey('island-route-strip'),
            height: 34,
            color: const Color(0x14FFFFFF),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
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
                Expanded(child: _routeProgress(arrival ? accent : _blue, true)),
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
            ),
          ),
        ],
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

  Widget _cue(
    TripIslandFace face,
    NavigationBanner? live,
    Color accent, {
    Color arrivalColor = const Color(0xFFFF818B),
  }) {
    final arrival = face.kind == TripIslandKind.arrival;
    final exit =
        live?.exitNumber ??
        RegExp(
          r'exit\s+(\d+)',
          caseSensitive: false,
        ).firstMatch(live?.primary ?? '')?.group(1);
    return Semantics(
      label: arrival
          ? 'Arrival'
          : '${live?.symbol.name ?? 'To destination'}${exit == null ? '' : ', exit $exit'}',
      child: arrival
          ? Icon(Icons.location_on_rounded, color: arrivalColor, size: 24)
          : live == null
          ? const Icon(
              Icons.person_outline_rounded,
              color: Colors.white,
              size: 24,
            )
          : live.symbol == NavigationBannerSymbol.roundabout
          ? CustomPaint(
              size: const Size(24, 24),
              painter: RoundaboutCuePainter(
                exitDegrees: RoundaboutCuePainter.degreesFor(
                  exitAngle: live.exitAngleDegrees,
                  exitNumber: exit,
                ),
                exitNumber: exit,
                color: accent,
                fontFamily: DefaultTextStyle.of(context).style.fontFamily,
              ),
            )
          : CustomPaint(
              size: const Size(24, 24),
              painter: NavigationCuePainter(
                symbol: live.symbol,
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
              title: const Text('Trip route and options'),
              onTap: () => popOwned(context, 'route'),
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Safety toolkit'),
              onTap: () => popOwned(context, 'safety'),
            ),
            if (widget.radarVisible)
              ListTile(
                leading: const Icon(Icons.radar_rounded),
                title: Text(
                  widget.radarOn
                      ? 'Turn Exclusive offers off'
                      : 'Turn Exclusive offers on',
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
                widget.paidByCash ? 'Cash: collect in the car' : 'Paid by card',
              ),
            ),
            if (widget.onRideCheckDemo != null) ...[
              const Divider(height: 1),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Ride check demo',
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
                  title: Text('Demo: ${trigger.label.toLowerCase()}'),
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
    label: 'Route progress',
    value: available
        ? '${(widget.progress.clamp(0, 1) * 100).round()} percent'
        : 'Unavailable',
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

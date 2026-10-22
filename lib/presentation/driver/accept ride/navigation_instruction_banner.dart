import 'package:movera/core/geo/driver_distance.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:movera/core/routing/route_instruction.dart';
import 'package:movera/presentation/driver/accept%20ride/waiting_time_sheet.dart';

enum ArrivalPointKind { pickup, stop, destination }

extension ArrivalPointKindVisuals on ArrivalPointKind {
  Color get color => switch (this) {
        ArrivalPointKind.pickup => const Color(0xFF17A673),
        ArrivalPointKind.stop => const Color(0xFF2F80ED),
        ArrivalPointKind.destination => const Color(0xFFE13B2D),
      };
}

/// Top ride tab. Maneuver on the first line, the next stop scrolling beneath it.
class NavigationInstructionBanner extends StatelessWidget {
  const NavigationInstructionBanner({
    super.key,
    this.banner,
    this.etaLabel,
    this.eyebrow = '',
    this.title = '',
    this.detail = '',
    this.address = '',
    this.icon = Icons.near_me_outlined,
    this.arrivalPointKind,
    this.arrivalDistanceMeters,
    this.arrivalLabel = '',
    this.arrivalAddress = '',
    this.arrivalArrived = false,
    this.radarSwitch = false,
    this.radarOn = false,
    this.onRadarToggle,
    this.waitSeconds,
    this.waitPaid = false,
    this.onWaitTap,
  });

  /// Height under the status bar, used to keep the route out from under the tab.
  static const double belowSafeExtent = 154;

  final NavigationBanner? banner;
  final String? etaLabel;
  final String eyebrow;
  final String title;
  final String detail;
  final String address;
  final IconData icon;
  final ArrivalPointKind? arrivalPointKind;
  final double? arrivalDistanceMeters;
  final String arrivalLabel;
  final String arrivalAddress;
  final bool arrivalArrived;
  final bool radarSwitch;
  final bool radarOn;
  final VoidCallback? onRadarToggle;
  final int? waitSeconds;

  /// Stop wait: paid from the first second, see [WaitingClock.paid].
  final bool waitPaid;
  final VoidCallback? onWaitTap;

  @override
  Widget build(BuildContext context) {
    final arrivalKind = arrivalPointKind;
    if (arrivalKind != null) {
      return _ArrivalApproachBanner(
        kind: arrivalKind,
        distanceMeters: arrivalDistanceMeters,
        label: arrivalLabel,
        address: arrivalAddress.trim().isEmpty ? address.trim() : arrivalAddress.trim(),
        arrived: arrivalArrived,
        waitSeconds: waitSeconds,
        waitPaid: waitPaid,
        onWaitTap: onWaitTap,
      );
    }

    final live = banner;
    final hero = live == null || live.primary.isEmpty ? title : live.primary;
    final road = (live?.roadName ?? '').trim();
    final meta = road.isNotEmpty ? road : detail.trim();
    final eta = (etaLabel ?? '').trim();
    final pad = MediaQuery.paddingOf(context);
    final symbol = live?.symbol;

    return Material(
      key: const ValueKey<String>('active-ride-navigation-card'),
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12 + pad.left,
          8 + pad.top,
          12 + pad.right,
          0,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF050505),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0x24FFFFFF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x38000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 64,
                    height: 68,
                    child: Center(
                      child: CustomPaint(
                        size: const Size(50, 54),
                        painter: NavigationCuePainter(symbol: symbol, icon: icon),
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (eyebrow.isNotEmpty) ...[
                          Text(
                            eyebrow.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFB9C0C5),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.35,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          hero,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.55,
                            height: 1.02,
                          ),
                        ),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFC4C9CD),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (waitSeconds != null) ...[
                    const SizedBox(width: 10),
                    WaitingClock(
                      onDark: true,
                      seconds: waitSeconds!,
                      paid: waitPaid,
                      diameter: 50,
                      onTap: onWaitTap,
                    ),
                  ] else if (eta.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Container(
                      constraints: const BoxConstraints(minWidth: 58, maxWidth: 78),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B434D),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: const Color(0x2EFFFFFF)),
                      ),
                      child: Text(
                        eta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (address.trim().isNotEmpty || radarSwitch) ...[
                const SizedBox(height: 11),
                Row(
                  children: [
                    if (address.trim().isNotEmpty)
                      Expanded(
                        child: _NextStopLine(
                          key: ValueKey<String>(address),
                          address: address.trim(),
                        ),
                      ),
                    if (address.trim().isNotEmpty && radarSwitch)
                      const SizedBox(width: 8),
                    if (radarSwitch)
                      _RadarOnOff(
                        on: radarOn,
                        onTap: onRadarToggle,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


class _ArrivalApproachBanner extends StatefulWidget {
  const _ArrivalApproachBanner({
    required this.kind,
    required this.distanceMeters,
    required this.label,
    required this.address,
    required this.arrived,
    required this.waitSeconds,
    required this.waitPaid,
    required this.onWaitTap,
  });

  final ArrivalPointKind kind;
  final double? distanceMeters;
  final String label;
  final String address;
  final bool arrived;
  final int? waitSeconds;
  final bool waitPaid;
  final VoidCallback? onWaitTap;

  @override
  State<_ArrivalApproachBanner> createState() => _ArrivalApproachBannerState();
}

class _ArrivalApproachBannerState extends State<_ArrivalApproachBanner>
    with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _entry.value = 1;
      _pulse.stop();
      _pulse.value = 0.5;
    } else {
      if (!_entry.isCompleted) { _entry.forward(); }
      if (!_pulse.isAnimating) { _pulse.repeat(); }
    }
  }

  @override
  void didUpdateWidget(covariant _ArrivalApproachBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind ||
        oldWidget.label != widget.label ||
        oldWidget.address != widget.address) {
      if (!MediaQuery.disableAnimationsOf(context)) {
        _entry
          ..value = 0
          ..forward();
      }
    }
  }

  @override
  void dispose() {
    _entry.dispose();
    _pulse.dispose();
    super.dispose();
  }

  String get _distanceLabel {
    if (widget.arrived) { return tr.navArrived; }
    final meters = widget.distanceMeters;
    if (meters == null || !meters.isFinite) { return tr.navNear; }
    if (meters < 25) { return tr.navNow; }
    if (meters < 1000) { return '${meters.round()} m'; }
    final km = meters / 1000;
    return '${driverDecimal(km, km < 10 ? 1 : 0)} km';
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final color = widget.kind.color;
    final label = widget.label.trim().isEmpty
        ? switch (widget.kind) {
            ArrivalPointKind.pickup => tr.pickup,
            ArrivalPointKind.stop => tr.stop,
            ArrivalPointKind.destination => tr.destination,
          }
        : widget.label.trim();

    return FadeTransition(
      opacity: CurvedAnimation(parent: _entry, curve: Curves.easeOutCubic),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(-0.045, -0.02),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: _entry, curve: Curves.easeOutCubic),
        ),
        child: Material(
          key: const ValueKey<String>('active-ride-navigation-card'),
          color: Colors.transparent,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              12 + pad.left,
              8 + pad.top,
              12 + pad.right,
              0,
            ),
            child: Container(
              key: const ValueKey<String>('arrival-approach-banner'),
              constraints: const BoxConstraints(minHeight: 118),
              decoration: BoxDecoration(
                color: const Color(0xFF050505),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0x24FFFFFF)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x38000000),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(14, 12, 15, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 82,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _pulse,
                          builder: (context, _) => _ArrivalPointGraphic(
                            kind: widget.kind,
                            color: color,
                            phase: _pulse.value,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _distanceLabel,
                          key: const ValueKey<String>('arrival-distance-label'),
                          maxLines: 1,
                          style: TextStyle(
                            color: widget.arrived ? color : Colors.white,
                            fontSize: widget.arrived ? 11 : 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: widget.arrived ? 0.7 : -0.2,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label.toUpperCase(),
                          key: const ValueKey<String>('arrival-point-label'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.address,
                          key: const ValueKey<String>('arrival-point-address'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.65,
                            height: 1.04,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.waitSeconds != null) ...[
                    const SizedBox(width: 10),
                    WaitingClock(
                      onDark: true,
                      seconds: widget.waitSeconds!,
                      paid: widget.waitPaid,
                      diameter: 48,
                      onTap: widget.onWaitTap,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArrivalPointGraphic extends StatelessWidget {
  const _ArrivalPointGraphic({
    required this.kind,
    required this.color,
    required this.phase,
  });

  final ArrivalPointKind kind;
  final Color color;
  final double phase;

  @override
  Widget build(BuildContext context) {
    final wave = (math.sin(phase * math.pi * 2) + 1) / 2;
    return SizedBox(
      width: 72,
      height: 63,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            left: 14,
            right: 14,
            bottom: 1,
            height: 40,
            child: CustomPaint(
              painter: _ArrivalRoadPainter(
                color: color,
                glow: wave,
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: Transform.scale(
              scale: 0.96 + (wave * 0.06),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 42 + (wave * 10),
                    height: 42 + (wave * 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.08 + (wave * 0.10)),
                    ),
                  ),
                  Icon(
                    Icons.location_on_rounded,
                    key: ValueKey<String>('arrival-pin-${kind.name}'),
                    color: color,
                    size: 38,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrivalRoadPainter extends CustomPainter {
  const _ArrivalRoadPainter({required this.color, required this.glow});

  final Color color;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final road = Path()
      ..moveTo(size.width * 0.36, size.height)
      ..lineTo(size.width * 0.46, size.height * 0.22)
      ..lineTo(size.width * 0.54, size.height * 0.22)
      ..lineTo(size.width * 0.64, size.height)
      ..close();

    canvas.drawPath(
      road,
      Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF7A8086),
    );

    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.34),
      Offset(size.width * 0.5, size.height * 0.93),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.42 + (glow * 0.25))
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.22),
      3.2 + (glow * 1.4),
      Paint()
        ..color = color.withValues(alpha: 0.65 + (glow * 0.35)),
    );
  }

  @override
  bool shouldRepaint(covariant _ArrivalRoadPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.glow != glow;
}

/// Thin navigation cue. Drawn, not a stock flag or turn glyph.
class NavigationCuePainter extends CustomPainter {
  NavigationCuePainter({required this.symbol, required this.icon, this.color = Colors.white, this.exitNumber, this.exitAngleDegrees, this.fontFamily});

  final Color color;
  final String? exitNumber;
  final double? exitAngleDegrees;
  final String? fontFamily;

  final NavigationBannerSymbol? symbol;
  final IconData icon;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 22;
    Offset p(double x, double y) => Offset(x * s, y * s);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.15 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    void arrowHead(Offset tip, double angle) {
      final direction = Offset(math.cos(angle), math.sin(angle));
      final perpendicular = Offset(-direction.dy, direction.dx);
      final base = tip - direction * 5.3 * s;
      final halfWidth = 3.8 * s;
      final head = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(
          (base + perpendicular * halfWidth).dx,
          (base + perpendicular * halfWidth).dy,
        )
        ..lineTo(
          (base - perpendicular * halfWidth).dx,
          (base - perpendicular * halfWidth).dy,
        )
        ..close();
      canvas.drawPath(head, fill);
    }

    void hardTurn({required bool left}) {
      final side = left ? -1.0 : 1.0;
      final path = Path()
        ..moveTo(p(11, 19).dx, p(11, 19).dy)
        ..lineTo(p(11, 12).dx, p(11, 12).dy)
        ..quadraticBezierTo(
          p(11, 7).dx,
          p(11, 7).dy,
          p(11 + 4.6 * side, 7).dx,
          p(7, 7).dy,
        )
        ..lineTo(p(11 + 6.0 * side, 7).dx, p(7, 7).dy);
      canvas.drawPath(path, stroke);
      arrowHead(
        p(11 + 8.1 * side, 7),
        left ? math.pi : 0,
      );
    }

    void slightTurn({required bool left}) {
      final side = left ? -1.0 : 1.0;
      final path = Path()
        ..moveTo(p(11, 19).dx, p(11, 19).dy)
        ..lineTo(p(11, 13).dx, p(11, 13).dy)
        ..quadraticBezierTo(
          p(11, 10).dx,
          p(11, 10).dy,
          p(11 + 2.2 * side, 8.2).dx,
          p(8.2, 8.2).dy,
        )
        ..lineTo(
          p(11 + 5.1 * side, 4.9).dx,
          p(4.9, 4.9).dy,
        );
      canvas.drawPath(path, stroke);
      arrowHead(
        p(11 + 6.25 * side, 3.55),
        left ? -2.3 : -0.84,
      );
    }

    final kind = symbol;
    if (kind == NavigationBannerSymbol.left ||
        kind == NavigationBannerSymbol.sharpLeft) {
      hardTurn(left: true);
      return;
    }
    if (kind == NavigationBannerSymbol.right ||
        kind == NavigationBannerSymbol.sharpRight) {
      hardTurn(left: false);
      return;
    }
    if (kind == NavigationBannerSymbol.slightLeft) {
      slightTurn(left: true);
      return;
    }
    if (kind == NavigationBannerSymbol.slightRight) {
      slightTurn(left: false);
      return;
    }
    // The road not taken, or the road going on: same line, faint.
    final faint = Paint()
      ..color = color.withValues(alpha: color.a * .45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Mirrored shapes: x becomes 22 - x, an angle a becomes pi - a.
    var mirrored = false;
    double x(double v) => mirrored ? 22 - v : v;
    Offset q(double vx, double vy) => p(x(vx), vy);

    if (kind == NavigationBannerSymbol.uTurn ||
        kind == NavigationBannerSymbol.uTurnLeft ||
        kind == NavigationBannerSymbol.uTurnRight) {
      mirrored = kind == NavigationBannerSymbol.uTurnRight;
      final path = Path()
        ..moveTo(q(15, 19).dx, q(15, 19).dy)
        ..lineTo(q(15, 10).dx, q(15, 10).dy)
        ..cubicTo(
          q(15, 5).dx,
          q(15, 5).dy,
          q(7, 5).dx,
          q(7, 5).dy,
          q(7, 10).dx,
          q(7, 10).dy,
        )
        ..lineTo(q(7, 12).dx, q(7, 12).dy);
      canvas.drawPath(path, stroke);
      arrowHead(q(7, 15), math.pi / 2);
      return;
    }
    if (kind == NavigationBannerSymbol.onRampLeft ||
        kind == NavigationBannerSymbol.onRampRight) {
      // The local road goes on, faint; the ramp leaves it and runs up
      // into the highway.
      mirrored = kind == NavigationBannerSymbol.onRampLeft;
      canvas.drawLine(q(7.5, 12.5), q(7.5, 4), faint);
      canvas.drawPath(
        Path()
          ..moveTo(q(7.5, 19).dx, q(7.5, 19).dy)
          ..lineTo(q(7.5, 14.5).dx, q(7.5, 14.5).dy)
          ..cubicTo(
            q(7.5, 11.2).dx,
            q(7.5, 11.2).dy,
            q(14.5, 11.6).dx,
            q(14.5, 11.6).dy,
            q(14.5, 8.6).dx,
            q(14.5, 8.6).dy,
          )
          ..lineTo(q(14.5, 7.4).dx, q(14.5, 7.4).dy),
        stroke,
      );
      arrowHead(q(14.5, 2.9), -math.pi / 2);
      return;
    }
    if (kind == NavigationBannerSymbol.keepLeft ||
        kind == NavigationBannerSymbol.keepRight) {
      // A split: both branches run on; the one not taken is faint.
      mirrored = kind == NavigationBannerSymbol.keepLeft;
      canvas.drawPath(
        Path()
          ..moveTo(q(11, 13.6).dx, q(11, 13.6).dy)
          ..cubicTo(
            q(11, 11.2).dx,
            q(11, 11.2).dy,
            q(6.8, 11.4).dx,
            q(6.8, 11.4).dy,
            q(6.8, 8.6).dx,
            q(6.8, 8.6).dy,
          )
          ..lineTo(q(6.8, 4.6).dx, q(6.8, 4.6).dy),
        faint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(q(11, 19).dx, q(11, 19).dy)
          ..lineTo(q(11, 14).dx, q(11, 14).dy)
          ..cubicTo(
            q(11, 11.2).dx,
            q(11, 11.2).dy,
            q(15.2, 11.4).dx,
            q(15.2, 11.4).dy,
            q(15.2, 8.6).dx,
            q(15.2, 8.6).dy,
          )
          ..lineTo(q(15.2, 7.6).dx, q(15.2, 7.6).dy),
        stroke,
      );
      arrowHead(q(15.2, 3.1), -math.pi / 2);
      return;
    }
    if (kind == NavigationBannerSymbol.forkLeft ||
        kind == NavigationBannerSymbol.forkRight) {
      // Two roads diverge; the slight turn taken, the other faint.
      mirrored = kind == NavigationBannerSymbol.forkLeft;
      canvas.drawPath(
        Path()
          ..moveTo(q(11, 13).dx, q(11, 13).dy)
          ..quadraticBezierTo(
            q(11, 10).dx,
            q(11, 10).dy,
            q(8.8, 8.2).dx,
            q(8.8, 8.2).dy,
          )
          ..lineTo(q(5.2, 4.6).dx, q(5.2, 4.6).dy),
        faint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(q(11, 19).dx, q(11, 19).dy)
          ..lineTo(q(11, 13).dx, q(11, 13).dy)
          ..quadraticBezierTo(
            q(11, 10).dx,
            q(11, 10).dy,
            q(13.2, 8.2).dx,
            q(13.2, 8.2).dy,
          )
          ..lineTo(q(16.1, 4.9).dx, q(16.1, 4.9).dy),
        stroke,
      );
      arrowHead(q(17.25, 3.55), mirrored ? -2.3 : -0.84);
      return;
    }
    if (kind == NavigationBannerSymbol.arriveLeft ||
        kind == NavigationBannerSymbol.arriveRight) {
      // The road runs on (faint past the stop); the arrive marker sits at
      // the side of the road where the destination is.
      mirrored = kind == NavigationBannerSymbol.arriveLeft;
      canvas.drawLine(q(8, 19), q(8, 9), stroke);
      canvas.drawLine(q(8, 9), q(8, 3.5), faint);
      canvas.drawCircle(q(15.6, 9), 4.3 * s, stroke);
      canvas.drawCircle(q(15.6, 9), 1.5 * s, fill);
      canvas.drawLine(q(11.3, 9), q(10, 9), stroke);
      return;
    }
    if (kind == NavigationBannerSymbol.depart) {
      // Start point, then straight on.
      canvas.drawCircle(p(11, 17), 2.4 * s, stroke);
      canvas.drawLine(p(11, 14.4), p(11, 7.5), stroke);
      arrowHead(p(11, 2.6), -math.pi / 2);
      return;
    }
    if (kind == NavigationBannerSymbol.toll) {
      // Gantry over the road with a coin.
      canvas.drawLine(p(3.5, 19), p(3.5, 4.5), stroke);
      canvas.drawLine(p(18.5, 19), p(18.5, 4.5), stroke);
      canvas.drawLine(p(3.5, 4.5), p(18.5, 4.5), stroke);
      canvas.drawCircle(p(11, 12.6), 4.6 * s, stroke);
      final text = TextPainter(
        text: TextSpan(
          text: 'kr',
          style: TextStyle(
            color: color,
            fontSize: 4.9 * s,
            fontWeight: FontWeight.w800,
            fontFamily: fontFamily,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, p(11, 12.5) - Offset(text.width / 2, text.height / 2));
      return;
    }
    if (kind == NavigationBannerSymbol.tunnel) {
      canvas.drawPath(
        Path()
          ..moveTo(p(2.5, 19).dx, p(2.5, 19).dy)
          ..lineTo(p(2.5, 11.5).dx, p(2.5, 11.5).dy)
          ..arcToPoint(p(19.5, 11.5), radius: Radius.circular(8.5 * s))
          ..lineTo(p(19.5, 19).dx, p(19.5, 19).dy),
        stroke,
      );
      canvas.drawLine(p(8.6, 19), p(10, 12.5), faint);
      canvas.drawLine(p(13.4, 19), p(12, 12.5), faint);
      return;
    }
    if (kind == NavigationBannerSymbol.roundabout ||
        kind == NavigationBannerSymbol.roundaboutUTurn ||
        kind == NavigationBannerSymbol.roundaboutClockwise) {
      // Clockwise (left-hand traffic) is the same drawing mirrored; the
      // exit angle is mirrored with it so the arrow still leaves the right
      // way. A roundabout U-turn without an angle goes back.
      final clockwise = kind == NavigationBannerSymbol.roundaboutClockwise;
      var exitAngle =
          exitAngleDegrees ??
          (kind == NavigationBannerSymbol.roundaboutUTurn ? 180.0 : null);
      if (clockwise && exitAngle != null) exitAngle = -exitAngle;
      canvas.save();
      if (clockwise) {
        canvas
          ..translate(size.width, 0)
          ..scale(-1, 1);
      }
      // Three circulation arrows make the roundabout recognizable even at
      // compact sizes. The outgoing arrow still uses the provider's angle.
      final ring = Rect.fromCircle(center: p(10, 11), radius: 6.4 * s);
      for (var i = 0; i < 3; i++) {
        final start = .4 + i * math.pi * 2 / 3;
        const sweep = -1.25;
        canvas.drawArc(ring, start, sweep, false, stroke);
        final end = start + sweep;
        final tip = p(10, 11) + Offset(math.cos(end), math.sin(end)) * 6.4 * s;
        final tangent = end - math.pi / 2;
        final direction = Offset(math.cos(tangent), math.sin(tangent));
        final side = Offset(-direction.dy, direction.dx);
        final base = tip - direction * 3.2 * s;
        canvas.drawPath(
          Path()
            ..moveTo(tip.dx, tip.dy)
            ..lineTo((base + side * 2.1 * s).dx, (base + side * 2.1 * s).dy)
            ..lineTo((base - side * 2.1 * s).dx, (base - side * 2.1 * s).dy)
            ..close(),
          fill,
        );
      }
      canvas.drawLine(p(11, 19), p(11, 15.7), stroke);
      if (exitAngle != null && exitAngle.isFinite) {
        final outgoing = exitAngle * math.pi / 180 - math.pi / 2;
        var sweep = outgoing - math.pi / 2;
        while (sweep >= -0.001) {
          sweep -= math.pi * 2;
        }
        while (sweep < -math.pi * 2) {
          sweep += math.pi * 2;
        }
        canvas.drawArc(
          Rect.fromCircle(center: p(11, 10.5), radius: 5.2 * s),
          math.pi / 2,
          sweep,
          false,
          stroke,
        );
        final direction = Offset(math.cos(outgoing), math.sin(outgoing));
        final center = p(11, 10.5);
        canvas.drawLine(
          center + direction * 5.2 * s,
          center + direction * 8.3 * s,
          stroke,
        );
        arrowHead(center + direction * 9.1 * s, outgoing);
      } else {
        // Unsurveyed exit: circular cue and number without guessing a road.
        canvas.drawArc(
          Rect.fromCircle(center: p(11, 10.5), radius: 5.2 * s),
          .6,
          math.pi * 1.55,
          false,
          stroke,
        );
      }
      canvas.restore();
      if (exitNumber != null) {
        final badge = p(17.2, 4.3);
        canvas.drawCircle(badge, 4.2 * s, fill);
        final text = TextPainter(
          text: TextSpan(
            text: exitNumber,
            style: TextStyle(
              color: Colors.white,
              fontSize: 5.8 * s,
              fontWeight: FontWeight.w800,
              fontFamily: fontFamily,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 7 * s);
        text.paint(canvas, badge - Offset(text.width / 2, text.height / 2));
      }
      return;
    }
    if (kind == NavigationBannerSymbol.merge) {
      canvas.drawLine(p(11, 19), p(11, 7), stroke);
      canvas.drawLine(p(5.7, 14), p(11, 9.2), stroke);
      arrowHead(p(11, 3), -math.pi / 2);
      return;
    }
    // Left is right mirrored: x becomes 22 - x, an angle a becomes pi - a.
    if (kind == NavigationBannerSymbol.mergeLeft ||
        kind == NavigationBannerSymbol.mergeRight) {
      final left = kind == NavigationBannerSymbol.mergeLeft;
      double x(double v) => left ? 22 - v : v;
      // The road being joined, faint; the driver's lane bends into it.
      canvas.drawLine(
        p(x(14.5), 19),
        p(x(14.5), 11.5),
        Paint()
          ..color = color.withValues(alpha: color.a * .45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * s
          ..strokeCap = StrokeCap.round,
      );
      final path = Path()
        ..moveTo(p(x(7.5), 19).dx, p(x(7.5), 19).dy)
        ..lineTo(p(x(7.5), 15.5).dx, p(x(7.5), 15.5).dy)
        ..cubicTo(
          p(x(7.5), 12.4).dx,
          p(x(7.5), 12.4).dy,
          p(x(14.5), 12.6).dx,
          p(x(14.5), 12.6).dy,
          p(x(14.5), 9.6).dx,
          p(x(14.5), 9.6).dy,
        )
        ..lineTo(p(x(14.5), 7.4).dx, p(x(14.5), 7.4).dy);
      canvas.drawPath(path, stroke);
      arrowHead(p(x(14.5), 2.9), -math.pi / 2);
      return;
    }
    if (kind == NavigationBannerSymbol.exit ||
        kind == NavigationBannerSymbol.exitRight ||
        kind == NavigationBannerSymbol.exitLeft) {
      final left = kind == NavigationBannerSymbol.exitLeft;
      double x(double v) => left ? 22 - v : v;
      canvas.drawLine(p(x(8), 19), p(x(8), 6), stroke);
      canvas.drawLine(p(x(8), 12), p(x(15), 6.5), stroke);
      arrowHead(p(x(17.2), 4.8), left ? math.pi + 0.67 : -0.67);
      return;
    }
    if (kind == NavigationBannerSymbol.arrive || icon == Icons.flag_outlined) {
      canvas.drawCircle(p(11, 10), 5.5 * s, stroke);
      canvas.drawCircle(p(11, 10), 1.7 * s, fill);
      canvas.drawLine(p(11, 15.5), p(11, 19), stroke);
      return;
    }
    if (icon == Icons.location_on_outlined) {
      canvas.drawCircle(p(11, 8.5), 3.2 * s, stroke);
      canvas.drawCircle(p(11, 8.5), 1.15 * s, fill);
      canvas.drawLine(p(11, 12), p(11, 19), stroke);
      return;
    }

    canvas.drawLine(p(11, 19), p(11, 7), stroke);
    arrowHead(p(11, 2.6), -math.pi / 2);
  }

  @override
  bool shouldRepaint(covariant NavigationCuePainter oldDelegate) =>
      oldDelegate.symbol != symbol || oldDelegate.icon != icon || oldDelegate.color != color || oldDelegate.exitNumber != exitNumber || oldDelegate.exitAngleDegrees != exitAngleDegrees || oldDelegate.fontFamily != fontFamily;
}

class _NextStopLine extends StatefulWidget {
  const _NextStopLine({super.key, required this.address});

  final String address;

  @override
  State<_NextStopLine> createState() => _NextStopLineState();
}

class _NextStopLineState extends State<_NextStopLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7600),
    )..repeat();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: Color(0xFFF7F8FA),
      fontSize: 14,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    );

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF3B434D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x2EFFFFFF)),
      ),
      child: Row(
        children: [
          Text(
            tr.to,
            style: TextStyle(
              color: Color(0xFFB9C0C5),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final painter = TextPainter(
                  text: TextSpan(text: widget.address, style: style),
                  maxLines: 1,
                  textDirection: TextDirection.ltr,
                )..layout();
                final overflow = painter.width - constraints.maxWidth;
                final travel = overflow > 8 ? overflow + 24 : 0.0;

                return ClipRect(
                  child: AnimatedBuilder(
                    animation: _motion,
                    builder: (context, _) {
                      final phase = _scrollPhase(_motion.value);
                      return Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Transform.translate(
                            offset: Offset(-travel * phase, 0),
                            child: Text(
                              widget.address,
                              maxLines: 1,
                              softWrap: false,
                              style: style,
                            ),
                          ),
                          Positioned(
                            left: (constraints.maxWidth + 36) * phase - 28,
                            bottom: 0,
                            child: Container(
                              width: 28,
                              height: 1.5,
                              color: const Color(0xFFF7F8FA),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

double _scrollPhase(double t) {
  if (t < 0.16) { return 0; }
  if (t > 0.84) { return 1; }
  return Curves.easeInOut.transform((t - 0.16) / 0.68);
}

class _RadarOnOff extends StatefulWidget {
  const _RadarOnOff({required this.on, required this.onTap});

  final bool on;
  final VoidCallback? onTap;

  @override
  State<_RadarOnOff> createState() => _RadarOnOffState();
}

class _RadarOnOffState extends State<_RadarOnOff>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.on) { _pulse.repeat(); }
  }

  @override
  void didUpdateWidget(covariant _RadarOnOff oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.on && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!widget.on && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFFF7F8FA);
    const quiet = Color(0xFFB7BFC4);
    final on = widget.on;
    return Material(
      key: const ValueKey<String>('on-trip-radar-switch'),
      color: const Color(0xFF171A1D),
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (on)
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, _) {
                          return CustomPaint(
                            size: const Size(18, 18),
                            painter: _RadarPulsePainter(_pulse.value),
                          );
                        },
                      ),
                    Icon(
                      on ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                      size: 16,
                      color: on ? ink : quiet,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 28,
                height: 16,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: on ? ink : const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Align(
                  alignment: on ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: on ? Colors.white : quiet,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadarPulsePainter extends CustomPainter {
  _RadarPulsePainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 2; i++) {
      final phase = (t + i * 0.5) % 1;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFF7F8FA).withValues(alpha: (1 - phase) * 0.55);
      canvas.drawCircle(center, 3 + phase * 7, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPulsePainter oldDelegate) =>
      oldDelegate.t != t;
}

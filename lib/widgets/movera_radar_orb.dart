import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared Radar orb used on Home (104px) and on an active trip (smaller).
class MoveraRadarOrb extends StatelessWidget {
  const MoveraRadarOrb({
    super.key,
    required this.title,
    required this.status,
    required this.subtitle,
    this.onTap,
    this.active = false,
    this.loading = false,
    this.offer = false,
    this.pulse = 0,
    this.sweep = 0,
    this.blocked = false,
    this.reserve = false,
    this.exclusive = false,
    this.timeLeft = 1,
    this.size = 104,
    this.touchSize,
    this.touchKey = const ValueKey<String>('trip-radar-touch-target'),
  });

  final String title;
  final String status;
  final String subtitle;
  final VoidCallback? onTap;
  final bool active;
  final bool loading;
  final bool offer;
  final double pulse;
  final double sweep;
  final bool blocked;

  /// A reservation on Home: black orb, grey rings, no mint, and only
  /// [title] over a small [status] ("Accept" · "TAP").
  final bool reserve;

  /// An Exclusive offer is live: a blue orb that is its Accept, with
  /// [title] ("Accept") over [status] (the seconds left), inside a blue
  /// ring that empties clockwise as [timeLeft] runs from 1 to 0.
  final bool exclusive;
  final double timeLeft;
  final double size;
  final double? touchSize;
  final Key touchKey;

  @override
  Widget build(BuildContext context) {
    const mint = Color(0xFF58E5A6);
    const detectedGold = Color(0xFFFFD166);
    const detectedAmber = Color(0xFFFFA94D);
    const holdRed = Color(0xFFE15B4A);
    const reserveInk = Color(0xFF111518);
    final accent = reserve
        ? reserveInk
        : blocked
        ? holdRed
        : offer
            ? Color.lerp(detectedGold, detectedAmber, pulse) ?? detectedGold
            : mint;
    final glowStrength = !active
        ? 0.08
        : loading
            ? 0.10 + (pulse * 0.14)
            : offer
                ? 0.14 + (pulse * 0.26)
                : 0.11 + (pulse * 0.16);
    final ringScale = !active
        ? 1.0
        : loading
            ? 0.96 + (pulse * 0.07)
            : offer
                ? 0.84 + (pulse * 0.22)
                : 0.91 + (pulse * 0.12);
    final secondWaveScale = !active
        ? 1.0
        : loading
            ? 0.90 + ((1 - pulse) * 0.10)
            : 0.86 + ((1 - pulse) * 0.16);
    final s = size / 104;
    final hit = touchSize ?? size;
    if (exclusive) { return _exclusiveOrb(s, hit); }

    return Semantics(
      button: true,
      label: "$title, $status. $subtitle",
      child: GestureDetector(
        key: touchKey,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: hit,
          height: hit,
          child: Center(
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: ringScale,
                    child: Container(
                      width: 102 * s,
                      height: 102 * s,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: active ? 0.04 : 0.025),
                        border: Border.all(
                          color: accent.withValues(alpha: active ? 0.30 : 0.15),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                  if (active)
                    Transform.scale(
                      scale: secondWaveScale,
                      child: Container(
                        width: 96 * s,
                        height: 96 * s,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.withValues(alpha: offer ? 0.045 : 0.025),
                          border: Border.all(
                            color: accent.withValues(alpha: offer ? 0.42 : 0.20),
                            width: offer ? 1.35 : 1.0,
                          ),
                        ),
                      ),
                    ),
                  Container(
                    width: 90 * s,
                    height: 90 * s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: active ? 0.045 : 0.03),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.72),
                        width: 1.2,
                      ),
                    ),
                  ),
                  Container(
                    width: 79 * s,
                    height: 79 * s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (reserve
                              ? const Color(0xFFD5D9DC)
                              : const Color(0xFFBFD9CF))
                          .withValues(alpha: 0.12),
                      border: Border.all(
                        color: accent.withValues(alpha: active ? 0.38 : 0.19),
                        width: 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: glowStrength),
                          blurRadius: active ? 19 : 11,
                          spreadRadius: active ? 5 : 2,
                        ),
                      ],
                    ),
                  ),
                  if (active && !reserve)
                    Transform.rotate(
                      angle: sweep * 6.283185307179586,
                      child: SizedBox(
                        width: 75 * s,
                        height: 75 * s,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            width: 2,
                            height: 18 * s,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  accent.withValues(alpha: 0),
                                  accent.withValues(alpha: offer ? 0.95 : 0.78),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Material(
                    color: Colors.transparent,
                    elevation: 16,
                    shadowColor: const Color(0xFF12201C).withValues(alpha: 0.38),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: Ink(
                      width: 73 * s,
                      height: 73 * s,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: const Alignment(-0.24, -0.32),
                          radius: 0.98,
                          colors: reserve
                              ? const [
                                  Color(0xFF2A3136),
                                  Color(0xFF161B1E),
                                  Color(0xFF0D1113),
                                ]
                              : blocked
                              ? const [
                                  Color(0xD9C45A52),
                                  Color(0xD98E3A34),
                                  Color(0xE05C2420),
                                ]
                              : const [
                                  Color(0xD98F999C),
                                  Color(0xD9727D80),
                                  Color(0xE05A6468),
                                ],
                          stops: const [0, 0.58, 1],
                        ),
                        border: Border.all(
                          color: offer
                              ? accent.withValues(alpha: 0.82)
                              : const Color(0xD9E7ECEE),
                          width: offer ? 1.9 : 1.6,
                        ),
                      ),
                      child: InkWell(
                        onTap: null,
                        customBorder: const CircleBorder(),
                        splashColor: accent.withValues(alpha: 0.14),
                        highlightColor: accent.withValues(alpha: 0.07),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (reserve)
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.6 * s,
                                      height: 1.1,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  SizedBox(height: 2 * s),
                                  Text(
                                    status,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: const Color(0xFF8F9AA0),
                                      fontSize: 6.4 * s,
                                      height: 1,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.4,
                                    ),
                                  ),
                                ],
                              )
                            else
                            Padding(
                              padding: EdgeInsets.fromLTRB(6 * s, 16 * s, 6 * s, 4 * s),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8.8 * s,
                                      height: 1.1,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  SizedBox(height: 2.5 * s),
                                  Text(
                                    status,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: offer
                                          ? accent
                                          : const Color(0xFFE2E9E6),
                                      fontSize: 6.1 * s,
                                      height: 1,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.9,
                                    ),
                                  ),
                                  SizedBox(height: 3 * s),
                                  Container(
                                    width: 10 * s,
                                    height: 1,
                                    color: Colors.white.withValues(alpha: 0.36),
                                  ),
                                  SizedBox(height: 4 * s),
                                  Text(
                                    subtitle,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: const Color(0xFFB7C2BE),
                                      fontSize: 5.9 * s,
                                      height: 1.12,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (loading)
                              Positioned(
                                bottom: 5 * s,
                                child: SizedBox(
                                  width: 8 * s,
                                  height: 8 * s,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.1,
                                    // White on the black reservation orb.
                                    color: (reserve ? Colors.white : accent)
                                        .withValues(alpha: 0.90),
                                  ),
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
          ),
        ),
      ),
    );
  }

  static const Color exclusiveBlue = Color(0xFF1769E8);
  static const Color exclusiveTrack = Color(0xFFE3E9F0);

  Widget _exclusiveOrb(double s, double hit) {
    return Semantics(
      button: true,
      label: "$title, $status. $subtitle",
      child: GestureDetector(
        key: touchKey,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: hit,
          height: hit,
          child: Center(
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // White gap, blue glow, then the time-left ring.
                  Container(
                    width: 94 * s,
                    height: 94 * s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: exclusiveBlue.withValues(alpha: 0.33),
                          blurRadius: 26 * s,
                          spreadRadius: 6 * s,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 88 * s,
                    height: 88 * s,
                    child: CustomPaint(
                      key: const ValueKey<String>('radar-exclusive-ring'),
                      painter: ExclusiveTimeRingPainter(
                        timeLeft: timeLeft,
                        stroke: 6 * s,
                      ),
                    ),
                  ),
                  Container(
                    key: const ValueKey<String>('radar-exclusive-core'),
                    width: 72 * s,
                    height: 72 * s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        center: Alignment(-0.2, -0.36),
                        radius: 0.9,
                        colors: [
                          Color(0xFF3F86F2),
                          exclusiveBlue,
                          Color(0xFF0E4FB8),
                        ],
                        stops: [0, 0.55, 1],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14 * s,
                            height: 1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4 * s),
                        if (loading)
                          SizedBox(
                            width: 10 * s,
                            height: 10 * s,
                            child: const CircularProgressIndicator(
                              strokeWidth: 1.2,
                              color: Colors.white,
                            ),
                          )
                        else
                          Text(
                            status,
                            style: TextStyle(
                              color: const Color(0xFFCFE0FB),
                              fontSize: 11.5 * s,
                              height: 1,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Exclusive radar's time left: a blue arc on a light track. The
/// spent part grows clockwise from twelve o'clock.
class ExclusiveTimeRingPainter extends CustomPainter {
  const ExclusiveTimeRingPainter({required this.timeLeft, required this.stroke});

  /// 1 full, 0 empty.
  final double timeLeft;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      paint..color = MoveraRadarOrb.exclusiveTrack,
    );
    final left = timeLeft.clamp(0.0, 1.0);
    if (left <= 0) { return; }
    final spent = (1 - left) * math.pi * 2;
    canvas.drawArc(
      rect,
      -math.pi / 2 + spent,
      left * math.pi * 2,
      false,
      paint..color = MoveraRadarOrb.exclusiveBlue,
    );
  }

  @override
  bool shouldRepaint(ExclusiveTimeRingPainter oldDelegate) =>
      oldDelegate.timeLeft != timeLeft || oldDelegate.stroke != stroke;
}

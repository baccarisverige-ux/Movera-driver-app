import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';

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

  /// A reservation on Home: the normal grey Radar-offer orb with its
  /// green turned black ([reserveInk]) and a small calendar over
  /// [title] ("Accept").
  final bool reserve;

  /// An Exclusive offer is live: the normal grey Radar-offer orb with its
  /// green turned blue ([exclusiveBlue]) and a small check over [title]
  /// ("Accept"), inside a hairline blue ring that empties clockwise as
  /// [timeLeft] runs from 1 to 0.
  final bool exclusive;
  final double timeLeft;
  final double size;
  final double? touchSize;
  final Key touchKey;

  /// The orb's colour while a reservation is up ([reserve]): the dark
  /// Accept. The reservation popup's pictures use it for their accent.
  static const Color reserveInk = Color(0xFF111518);

  /// The radar's green while a trip is found: its ring, glow and sweep.
  /// Home's radar offer cards, the dock dash and the island use it for
  /// their contour, so all stay in step. The same green marks Radar on.
  static const Color offerAccent = Color(0xFF5FB87D);

  /// Radar on, nothing found yet: the same green.
  static const Color onlineGreen = offerAccent;

  /// The radar on hold, and the red dock under it.
  static const Color holdRed = Color(0xFFBB371F);

  /// The red dock's face, a shade darker than [holdRed], and its gradient.
  static const Color holdSheet = Color(0xFFA9311C);
  static const List<Color> holdSheetGradient = [
    holdRed,
    holdSheet,
    Color(0xFF922A18),
  ];

  @override
  Widget build(BuildContext context) {
    const mint = onlineGreen;
    // A found trip breathes from a lighter green into the green.
    const detectedLight = Color(0xFF9ED6B0);
    const detectedGreen = offerAccent;
    // Exclusive is the normal radar in blue, with its time ring.
    final accent = exclusive
        ? exclusiveBlue
        : reserve
        ? reserveInk
        : blocked
        ? holdRed
        : offer
            ? Color.lerp(detectedLight, detectedGreen, pulse) ?? detectedGreen
            : mint;
    // Exclusive and reservation are the Radar-offer orb in their colour.
    final tinted = exclusive || reserve;
    final hot = offer || tinted;
    final glowStrength = !active
        ? 0.08
        : loading
            ? 0.10 + (pulse * 0.14)
            : hot
                ? 0.14 + (pulse * 0.26)
                : 0.11 + (pulse * 0.16);
    final ringScale = !active
        ? 1.0
        : loading
            ? 0.96 + (pulse * 0.07)
            : hot
                ? 0.84 + (pulse * 0.22)
                : 0.91 + (pulse * 0.12);
    final secondWaveScale = !active
        ? 1.0
        : loading
            ? 0.90 + ((1 - pulse) * 0.10)
            : 0.86 + ((1 - pulse) * 0.16);
    final s = size / 104;
    final hit = touchSize ?? size;

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
                          color: accent.withValues(alpha: hot ? 0.045 : 0.025),
                          border: Border.all(
                            color: accent.withValues(alpha: hot ? 0.42 : 0.20),
                            width: hot ? 1.35 : 1.0,
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
                              : exclusive
                              ? const Color(0xFFCFE0FB)
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
                  // The time left runs on the normal ring.
                  if (exclusive)
                    SizedBox(
                      width: 90 * s,
                      height: 90 * s,
                      child: CustomPaint(
                        key: const ValueKey<String>('radar-exclusive-ring'),
                        painter: ExclusiveTimeRingPainter(
                          timeLeft: timeLeft,
                          stroke: 1.5 * s,
                        ),
                      ),
                    ),
                  if (active)
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
                                  accent.withValues(alpha: hot ? 0.95 : 0.78),
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
                      key: exclusive
                          ? const ValueKey<String>('radar-exclusive-core')
                          : null,
                      width: 73 * s,
                      height: 73 * s,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: const Alignment(-0.24, -0.32),
                          radius: 0.98,
                          colors: blocked
                              ? const [
                                  Color(0xD9C4432A),
                                  Color(0xD9962A17),
                                  Color(0xE062190D),
                                ]
                              : const [
                                  Color(0xD98F999C),
                                  Color(0xD9727D80),
                                  Color(0xE05A6468),
                                ],
                          stops: const [0, 0.58, 1],
                        ),
                        border: Border.all(
                          color: hot
                              ? accent.withValues(alpha: 0.82)
                              : const Color(0xD9E7ECEE),
                          width: hot ? 1.9 : 1.6,
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
                            Padding(
                              // The small icon takes some of the top room.
                              padding: EdgeInsets.fromLTRB(
                                6 * s,
                                (tinted ? 10 : 16) * s,
                                6 * s,
                                4 * s,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (tinted) ...[
                                    SvgPicture.asset(
                                      exclusive
                                          ? AppAssets.solarCheckCircle
                                          : AppAssets.solarCalendar,
                                      key: ValueKey<String>(
                                        exclusive
                                            ? 'radar-exclusive-icon'
                                            : 'radar-reserve-icon',
                                      ),
                                      width: 8 * s,
                                      height: 8 * s,
                                      colorFilter: const ColorFilter.mode(
                                        Colors.white,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                    SizedBox(height: 2 * s),
                                  ],
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
                                      color: hot
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
}

/// The Exclusive radar's time left: a hairline blue arc on a barely
/// visible track. The spent part grows clockwise from twelve o'clock.
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
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      paint..color = MoveraRadarOrb.exclusiveTrack.withValues(alpha: 0.35),
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

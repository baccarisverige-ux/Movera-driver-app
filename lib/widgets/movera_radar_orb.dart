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
    this.wedge,
    this.statusPulse = 0,
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

  /// A reservation request on Home: the normal grey Radar-offer orb with
  /// its green waves turned grey ([reserveLight] pulsing to [reserveGrey],
  /// halo [reserveHalo]) and [status] ("MATCH") in [offerInk]. Same
  /// core, sizes, pulse and sweep; no icon.
  final bool reserve;

  /// An Exclusive offer is live: the normal grey Radar-offer orb with its
  /// green turned blue ([exclusiveBlue]) and a small check over [title]
  /// ("Accept"), inside a hairline blue ring that empties clockwise as
  /// [timeLeft] runs from 1 to 0.
  ///
  /// With [reserve] as well it is the Exclusive offer on Home: the
  /// reservation's grey look (grey waves and halo, black "Accept", MATCH in
  /// [offerInk], no icon) inside a hairline [reserveInk] time ring. No
  /// blue anywhere.
  final bool exclusive;
  final double timeLeft;

  /// The soft light sweep around the ring, as a fraction of a full turn
  /// from twelve o'clock (null: none). Home's Radar runs it, slower when
  /// nothing is found yet; Exclusive and reservation never do.
  final double? wedge;

  /// 0..1: the small pulse of a found trip's black [status] ("MATCH").
  final double statusPulse;
  final double size;
  final double? touchSize;
  final Key touchKey;

  /// A reservation request ([reserve]): grey waves, breathing from
  /// [reserveLight] into [reserveGrey], a soft grey halo and "MATCH" in
  /// black; [reserveInk] is its light black time ring.
  static const Color reserveLight = Color(0xFFC6CBD0);
  static const Color reserveGrey = Color(0xFF8E959C);
  static const Color reserveHalo = Color(0xFFD5D9DD);
  static const Color reserveInk = Color(0xFF2E3338);

  /// A reservation's [title] ("Accept"): black.
  static const Color reserveTitle = Color(0xFF111518);

  /// The radar's grey while it is on: its ring, glow and sweep. Home's
  /// radar offer cards, the dock dash and the island use it for their
  /// contour, so all stay in step.
  static const Color offerAccent = Color(0xFF969CA1);

  /// A found trip breathes from this lighter grey into [offerAccent].
  static const Color offerAccentLight = Color(0xFFC2C7CB);

  /// A found trip's [status] ("MATCH"): black.
  static const Color offerInk = Color(0xFF111614);

  /// The orb's labels: Urbanist (bundled), the rider sign-in face.
  static const String orbFontFamily = 'Urbanist';

  /// Radar on, outside the radar itself (side menu, lists): green.
  static const Color onlineGreen = Color(0xFF5FB87D);

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
    // R15: Radar on looks the same with or without a trip found: it
    // breathes from a lighter grey into the grey. Only the sweep's speed
    // (set by Home) tells them apart.
    const detectedLight = offerAccentLight;
    const detectedGrey = offerAccent;
    // Exclusive is the normal radar in blue, with its time ring.
    // The ink of the orb's three lines: white on the red (blocked) disc,
    // black for a reservation's Accept, the offer ink otherwise.
    final labelInk = blocked
        ? Colors.white
        : reserve
        ? reserveTitle
        : offerInk;
    final accent = reserve
        ? Color.lerp(reserveLight, reserveGrey, pulse) ?? reserveGrey
        : exclusive
        ? exclusiveBlue
        : blocked
        ? holdRed
        : Color.lerp(detectedLight, detectedGrey, pulse) ?? detectedGrey;
    // Exclusive and reservation are the Radar-offer orb in their colour;
    // only the blue Exclusive carries a small icon.
    final tinted = exclusive && !reserve;
    // A Radar trip found: black status with its small pulse.
    final found = offer && !exclusive && !reserve;
    final p = statusPulse.clamp(0.0, 1.0);
    final hot = offer || exclusive || reserve;
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

    // Only a radar that does something on a tap reads as a button.
    return Semantics(
      button: onTap != null,
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
                      color:
                          (reserve
                                  ? reserveHalo
                                  : exclusive
                                  ? const Color(0xFFCFE0FB)
                                  : reserveHalo)
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
                          // The grey Exclusive: a dark hairline.
                          color: reserve ? reserveInk : exclusiveBlue,
                          track: reserve ? reserveHalo : exclusiveTrack,
                        ),
                      ),
                    ),
                  if (active && wedge != null)
                    SizedBox(
                      width: 102 * s,
                      height: 102 * s,
                      child: CustomPaint(
                        key: const ValueKey<String>('radar-sweep-wedge'),
                        painter: RadarWedgePainter(
                          turn: wedge!,
                          inner: 36.5 * s,
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
                    shadowColor: const Color(
                      0xFF12201C,
                    ).withValues(alpha: 0.38),
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
                              // Large text (200 %): the orb is a fixed
                              // control, so its labels follow the system
                              // text size only up to 1.25x, and the whole
                              // block shrinks together inside a square set
                              // well inside the disc, so nothing leaves it
                              // (release evidence b8bd860, F1).
                              child: MediaQuery.withClampedTextScaling(
                                maxScaleFactor: 1.25,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: SizedBox(
                                    width: 58 * s,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (tinted) ...[
                                          SvgPicture.asset(
                                            AppAssets.solarCheckCircle,
                                            key: const ValueKey<String>(
                                              'radar-exclusive-icon',
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
                                        // One ink for the three lines (the
                                        // title used to be white on the grey
                                        // disc while the rest was dark): the
                                        // title is the quiet label, the status
                                        // the big word, the hint the small
                                        // line. The title shrinks rather than
                                        // cuts ("Acce…" at 200 %, F2).
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            title,
                                            maxLines: 1,
                                            softWrap: false,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: labelInk.withValues(
                                                alpha: reserve ? 1 : 0.72,
                                              ),
                                              fontFamily: orbFontFamily,
                                              fontSize: 8 * s,
                                              height: 1.1,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 1.5 * s),
                                        // Status and subtitle: 10 px on Home's
                                        // 104 px radar, dark on the grey disc
                                        // and white on the red one (4.5:1).
                                        Transform.scale(
                                          scale: found ? 1 + 0.05 * p : 1,
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              status,
                                              key: found
                                                  ? const ValueKey<String>(
                                                      'radar-status-found',
                                                    )
                                                  : null,
                                              maxLines: 1,
                                              softWrap: false,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: blocked
                                                    ? Colors.white
                                                    : found
                                                    ? offerInk.withValues(
                                                        alpha: 0.94 + 0.06 * p,
                                                      )
                                                    : offerInk,
                                                fontFamily: orbFontFamily,
                                                fontSize: 12 * s,
                                                height: 1,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.6,
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 3 * s),
                                        Container(
                                          width: 12 * s,
                                          height: 1,
                                          color: labelInk.withValues(
                                            alpha: blocked ? 0.36 : 0.22,
                                          ),
                                        ),
                                        SizedBox(height: 3.5 * s),
                                        // Round 4: one line in every language;
                                        // longer words shrink to fit the orb.
                                        Text(
                                          subtitle,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: blocked
                                                ? Colors.white
                                                : offerInk,
                                            fontFamily: orbFontFamily,
                                            fontSize: 10 * s,
                                            height: 1.15,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
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
                                    // White on the grey reservation orb.
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

/// Home Radar's soft sweep: a light wedge that fades behind its leading
/// edge, in the ring between the core ([inner]) and the outer wave.
class RadarWedgePainter extends CustomPainter {
  const RadarWedgePainter({required this.turn, required this.inner});

  /// The leading edge, as a fraction of a turn from twelve o'clock.
  final double turn;
  final double inner;

  /// The faded tail behind the leading edge.
  static const double tail = math.pi / 3;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final lead = -math.pi / 2 + (turn % 1) * 2 * math.pi;
    final band = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: center, radius: outer))
      ..addOval(Rect.fromCircle(center: center, radius: inner));
    canvas.save();
    canvas.clipPath(band);
    // Drawn from zero to [tail] and rotated so it ends at the leading
    // edge: a sweep gradient reads angles in [0, 2π), so one from -tail to
    // 0 would clamp the whole wedge to its end colour (driver-u180).
    canvas.translate(center.dx, center.dy);
    canvas.rotate(lead - tail);
    final rect = Rect.fromCircle(center: Offset.zero, radius: outer);
    final paint = Paint()
      ..shader = SweepGradient(
        endAngle: tail,
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.6),
        ],
      ).createShader(rect);
    canvas.drawArc(rect, 0, tail, true, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(RadarWedgePainter old) =>
      old.turn != turn || old.inner != inner;
}

/// The Exclusive radar's time left: a hairline arc in [color] on a barely
/// visible [track]. The spent part grows clockwise from twelve o'clock.
class ExclusiveTimeRingPainter extends CustomPainter {
  const ExclusiveTimeRingPainter({
    required this.timeLeft,
    required this.stroke,
    this.color = MoveraRadarOrb.exclusiveBlue,
    this.track = MoveraRadarOrb.exclusiveTrack,
  });

  /// 1 full, 0 empty.
  final double timeLeft;
  final double stroke;
  final Color color;
  final Color track;

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
      paint..color = track.withValues(alpha: 0.35),
    );
    final left = timeLeft.clamp(0.0, 1.0);
    if (left <= 0) {
      return;
    }
    final spent = (1 - left) * math.pi * 2;
    canvas.drawArc(
      rect,
      -math.pi / 2 + spent,
      left * math.pi * 2,
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(ExclusiveTimeRingPainter oldDelegate) =>
      oldDelegate.timeLeft != timeLeft ||
      oldDelegate.stroke != stroke ||
      oldDelegate.color != color ||
      oldDelegate.track != track;
}

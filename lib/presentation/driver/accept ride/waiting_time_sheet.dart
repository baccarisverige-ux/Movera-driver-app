import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/widgets/owned_route_exit.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/ride/waiting_rules.dart';
import 'package:movera/widgets/movera_modal_sheet.dart';

/// The free minutes and the no-show time of the trip on screen (Q19/Q20).
int get _graceSeconds => WaitingTerms.active.freeSeconds;
int get _noShowSeconds => WaitingTerms.active.noShowSeconds;

/// Opens the pickup-wait screen. It reads live seconds from the active trip.
Future<void> showWaitingTimeSheet(
  BuildContext context, {
  required int Function() readSeconds,
  VoidCallback? onNoShow,
  bool fullyPaid = false,
  WaitingTerms? terms,
  Money? chargedSoFar,
  bool cancelAfterArrivedIsNoShow = false,
  DateTime? noShowAt,
}) {
  return showMoveraModalSheet<void>(
    context: context,
    heightFactor: 0.92,
    builder: (sheetContext) {
      return WaitingTimeSheet(
        readSeconds: readSeconds,
        onNoShow: onNoShow,
        fullyPaid: fullyPaid,
        terms: terms,
        chargedSoFar: chargedSoFar,
        cancelAfterArrivedIsNoShow: cancelAfterArrivedIsNoShow,
        noShowAt: noShowAt,
      );
    },
  );
}

class WaitingTimeSheet extends StatefulWidget {
  const WaitingTimeSheet({
    super.key,
    required this.readSeconds,
    this.onNoShow,
    this.fullyPaid = false,
    this.terms,
    this.chargedSoFar,
    this.cancelAfterArrivedIsNoShow = false,
    this.noShowAt,
  });

  /// Checker round 2: the server's no-show moment (`waiting.noShowAt`);
  /// the sheet says its clock time instead of the zone's minutes.
  final DateTime? noShowAt;

  final int Function() readSeconds;
  final VoidCallback? onNoShow;
  final bool fullyPaid;

  /// The waiting rules for this pickup; the trip's own by default
  /// (contract v0.18.7 `TripProjection.terms`, the zone's pricing).
  final WaitingTerms? terms;

  /// Q5 (contract v0.18.7 `waiting.chargedSoFar`): the rider's waiting
  /// cost so far as the server counts it, when the server said.
  final Money? chargedSoFar;

  /// Q2 (contract v0.18.7 `terms.cancelAfterArrivedIsNoShow`): the zone
  /// charges a cancel after arrival as a no-show.
  final bool cancelAfterArrivedIsNoShow;

  @override
  State<WaitingTimeSheet> createState() => _WaitingTimeSheetState();
}

class _WaitingTimeSheetState extends State<WaitingTimeSheet> {
  static const _ink = Color(0xFF1C242C);
  static const _muted = Color(0xFF7D898F);
  Timer? _tick;

  int get _seconds => widget.readSeconds();

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = _seconds;
    final terms = widget.terms ?? WaitingTerms.active;
    final phase = _WaitPhase.of(seconds);
    final paidSeconds = widget.fullyPaid
        ? seconds
        : math.max(0, seconds - terms.freeSeconds);

    return MoveraModalSheet(
      key: const ValueKey<String>('waiting-time-sheet'),
      heightFactor: 0.92,
      color: const Color(0xFFF6F7F8),
      radius: 28,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                _CloseMark(onTap: () => popOwned(context)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.fullyPaid ? tr.stopWait : tr.pickupWait,
                    style: TextStyle(
                      color: _ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              physics: const BouncingScrollPhysics(),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE6E8EA)),
                  ),
                  child: Column(
                    children: [
                      WaitingClock(seconds: seconds, diameter: 132),
                      const SizedBox(height: 14),
                      Text(
                        widget.fullyPaid ? tr.everyMinuteIsPaid : phase.title,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.fullyPaid
                            ? tr.thisStopHasNoFreeMinutes
                            : phase.detail,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // Q42/Q43: once the free wait is over, the waiting
                      // fee counts up live; it is all the driver's.
                      if (paidSeconds > 0 && terms.pricesKnown) ...[
                        const SizedBox(height: 12),
                        WaitingFeeCounter(
                          fee: terms.driverWaitingFee(paidSeconds),
                          perMinute: terms.perMinute,
                        ),
                      ],
                      if (widget.chargedSoFar case final charged?
                          when !charged.isZero) ...[
                        const SizedBox(height: 8),
                        Text(
                          tr.waitingChargedSoFar(charged.formatted),
                          key: const ValueKey<String>('waiting-charged-so-far'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (terms.rule.isNotEmpty) ...[
                  Text(
                    tr.ruleForThisPickupRule(terms.rule),
                    key: const ValueKey<String>('waiting-rule'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (!widget.fullyPaid) ...[
                  _PhaseCard(
                    title: tr.includedTime,
                    detail: tr.openingMinutesStayInsideFare,
                    value: '${terms.freeMinutes} min',
                    state: seconds < _graceSeconds
                        ? _PhaseState.now
                        : _PhaseState.done,
                  ),
                  const SizedBox(height: 8),
                ],
                _PhaseCard(
                  title: tr.waitTime,
                  detail: widget.fullyPaid
                      ? tr.addedFromFirstSecondAtThis
                      : tr.addedToFareWhenThisTrip,
                  value: terms.pricesKnown
                      ? tr.perMinuteFormattedMin(terms.perMinute.formatted)
                      : '',
                  tone: const Color(0xFF146B45),
                  state: widget.fullyPaid || seconds >= _graceSeconds
                      ? _PhaseState.now
                      : _PhaseState.later,
                ),
                if (!widget.fullyPaid) ...[
                  const SizedBox(height: 8),
                  _PhaseCard(
                    title: tr.noShow,
                    detail: widget.noShowAt == null
                        ? tr.canBeAppliedAfterNoShow(terms.noShowAfterMinutes)
                        : tr.noShowFromTime(_clockTime(widget.noShowAt!)),
                    value: terms.pricesKnown ? terms.noShowFee.formatted : '',
                    tone: const Color(0xFF9E2B33),
                    state: seconds < _noShowSeconds
                        ? _PhaseState.later
                        : _PhaseState.now,
                  ),
                ],
                if (widget.cancelAfterArrivedIsNoShow) ...[
                  const SizedBox(height: 8),
                  Text(
                    tr.cancelAfterArrivedNote,
                    key: const ValueKey<String>('waiting-cancel-after-arrived'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 11.5,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (!widget.fullyPaid &&
                    seconds >= _noShowSeconds &&
                    widget.onNoShow != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      key: const ValueKey<String>('waiting-no-show-cancel'),
                      onPressed: () {
                        if (!popOwned(context)) return;
                        widget.onNoShow?.call();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF9E2B33),
                        side: const BorderSide(color: Color(0xFF9E2B33)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        tr.riderDidnTShow,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                if (terms.pricesKnown)
                  Text(
                    widget.fullyPaid
                        ? tr.youGetDriverShareWaitPercent(
                            terms.driverShareWaitPercent,
                          )
                        : tr.youGetDriverShareWaitPercent2(
                            terms.driverShareWaitPercent,
                            terms.driverShareNoShowPercent,
                            terms.driverNoShowFee.formatted,
                          ),
                    key: const ValueKey<String>('waiting-driver-share'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  tr.amountsCanChangeWithTaxesAnd,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () => popOwned(context),
                style: FilledButton.styleFrom(
                  elevation: 0,
                  backgroundColor: _ink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  tr.close,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The live waiting fee on the pickup-wait screen: "+3,68 kr" with its
/// rate (Q42). [fee] is the driver's part (100% by default, Q43).
class WaitingFeeCounter extends StatelessWidget {
  const WaitingFeeCounter({
    super.key,
    required this.fee,
    required this.perMinute,
  });

  final Money fee;
  final Money perMinute;

  static const _green = Color(0xFF146B45);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('waiting-fee-counter'),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F6EE),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFFBFE3CF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '+${fee.formatted}',
            key: const ValueKey<String>('waiting-fee-amount'),
            style: const TextStyle(
              color: _green,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              tr.waitingFeePerMinuteFormattedMin(perMinute.formatted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _green,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _PhaseState { now, done, later }

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({
    required this.title,
    required this.detail,
    required this.value,
    required this.state,
    this.tone = const Color(0xFF1C242C),
  });

  final String title;
  final String detail;
  final String value;
  final _PhaseState state;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF1C242C);
    const muted = Color(0xFF7D898F);
    final active = state == _PhaseState.now;
    final label = switch (state) {
      _PhaseState.now => tr.now,
      _PhaseState.done => tr.done,
      _PhaseState.later => tr.later,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active ? tone : const Color(0xFFE6E8EA),
          width: active ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: state == _PhaseState.later ? muted : ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 11.5,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: state == _PhaseState.later ? muted : ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: active ? tone : muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CloseMark extends StatelessWidget {
  const _CloseMark({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // driver-u108: the × has a name for screen readers.
    return Tooltip(
      message: tr.close,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE6E8EA)),
            ),
            child: const Icon(
              Icons.close_rounded,
              size: 18,
              color: Color(0xFF1C242C),
            ),
          ),
        ),
      ),
    );
  }
}

class _WaitPhase {
  const _WaitPhase(this.title, this.detail);

  final String title;
  final String detail;

  static _WaitPhase of(int seconds) {
    if (seconds < _graceSeconds) {
      return _WaitPhase(tr.includedMinutes, tr.theseFirstMinutesAreAlreadyPart);
    }
    if (seconds < _noShowSeconds) {
      return _WaitPhase(tr.waitTimeIsRunning, tr.eachMinuteAfterIncludedTimeIs);
    }
    return _WaitPhase(tr.noShowCanBeApplied, tr.riderIsStillNotHereNo);
  }
}

/// Round pickup clock. A quiet hand keeps moving, and the ring tracks the wait.
class WaitingClock extends StatefulWidget {
  const WaitingClock({
    super.key,
    required this.seconds,
    this.onTap,
    this.diameter = 48,
    this.onDark = false,
    this.paid = false,
  });

  /// Paid from the first second (a stop wait): green "+m:ss" and the ring
  /// goes round once a minute.
  final bool paid;

  final int seconds;
  final VoidCallback? onTap;
  final double diameter;

  /// On a dark banner the included-minutes countdown is drawn white, since
  /// the default ink is hard to read there; later phases keep their colour.
  final bool onDark;

  @override
  State<WaitingClock> createState() => _WaitingClockState();
}

class _WaitingClockState extends State<WaitingClock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hand;

  @override
  void initState() {
    super.initState();
    _hand = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _hand.stop();
    } else {
      _hand.repeat();
    }
  }

  @override
  void dispose() {
    _hand.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paid = widget.paid;
    final label = paid
        ? '+${_clockLabel(widget.seconds)}'
        : _clockLabel(widget.seconds);
    final tone = paid ? const Color(0xFF146B45) : _waitTone(widget.seconds);
    final clock = AnimatedBuilder(
      animation: _hand,
      builder: (context, _) {
        return CustomPaint(
          size: Size.square(widget.diameter),
          painter: _ClockPainter(
            seconds: widget.seconds,
            hand: _hand.value,
            tone: tone,
            minuteRing: paid,
          ),
          child: SizedBox(
            width: widget.diameter,
            height: widget.diameter,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.92,
                        end: 1,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  label,
                  key: ValueKey<String>(label),
                  style: TextStyle(
                    color:
                        widget.onDark && !paid && widget.seconds < _graceSeconds
                        ? Colors.white
                        : paid && widget.onDark
                        ? const Color(0xFF3DDC97)
                        : tone,
                    fontSize: widget.diameter * 0.24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (widget.onTap == null) {
      return clock;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        customBorder: const CircleBorder(),
        child: clock,
      ),
    );
  }
}

/// "10:05" in the phone's time (24 h in every app language).
String _clockTime(DateTime at) {
  final local = at.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}';
}

String _clockLabel(int seconds) {
  final minutes = seconds ~/ 60;
  final rest = (seconds % 60).toString().padLeft(2, '0');
  return '$minutes:$rest';
}

class _ClockPainter extends CustomPainter {
  _ClockPainter({
    required this.seconds,
    required this.hand,
    required this.tone,
    this.minuteRing = false,
  });

  final int seconds;
  final double hand;
  final Color tone;
  final bool minuteRing;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width < 70 ? 2 : 3
      ..color = const Color(0xFFE6E8EA);
    canvas.drawCircle(center, radius, track);

    final window = minuteRing
        ? (seconds % 60) / 60
        : seconds < _graceSeconds
        ? seconds / _graceSeconds
        : seconds < _noShowSeconds
        ? (seconds - _graceSeconds) / (_noShowSeconds - _graceSeconds)
        : 1.0;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width < 70 ? 2.2 : 3.2
      ..strokeCap = StrokeCap.round
      ..color = tone;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.max(0.08, window) * math.pi * 2,
      false,
      arc,
    );

    final angle = (-math.pi / 2) + hand * math.pi * 2;
    final inner = radius * 0.62;
    final outer = radius * 0.86;
    final handPaint = Paint()
      ..color = tone.withValues(alpha: 0.9)
      ..strokeWidth = size.width < 70 ? 1.4 : 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center + Offset(math.cos(angle), math.sin(angle)) * inner,
      center + Offset(math.cos(angle), math.sin(angle)) * outer,
      handPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ClockPainter oldDelegate) =>
      oldDelegate.seconds != seconds ||
      oldDelegate.hand != hand ||
      oldDelegate.tone != tone ||
      oldDelegate.minuteRing != minuteRing;
}

Color _waitTone(int seconds) {
  if (seconds >= _noShowSeconds) {
    return const Color(0xFF9E2B33);
  }
  if (seconds >= _graceSeconds) {
    return const Color(0xFF146B45);
  }
  return const Color(0xFF1C242C);
}

import 'package:flutter/material.dart';
import 'package:movera/core/contracts/driver_app_config.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/driver/driver_home_notices.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/phone/phone_checks.dart';
import 'package:movera/widgets/movera_dialog_theme.dart';

/// The card's reason line for [notice], in the driver's language.
String offlineReasonText(DriverSetOfflineNotice notice) {
  return switch (notice.reason) {
    DriverOfflineReason.noPosition => tr.offlineReasonNoPosition(
      notice.count ?? DriverAppConfig.defaultNoFixMinutes,
    ),
    DriverOfflineReason.missedOffers => tr.offlineReasonMissedOffers(
      notice.count ?? DriverOfferRules.current.autoOfflineAfter,
    ),
    DriverOfflineReason.appRestart => tr.offlineReasonAppRestart,
    DriverOfflineReason.movera => tr.offlineReasonMovera,
  };
}

/// Owner 2026-10-31 ("new set offline message", decisions/driver-g3.md,
/// "Reason + phone check"): the driver was set offline. Inside the Home
/// sheet, in place of its icons: "You're offline" with Movera's warning
/// mark, the real [reason], "Check my phone" (location, internet, battery
/// saver, notifications, each ✓ or ✗ with its fix), a big Go online and
/// OK. Only black, simple (owner 2026-10-31: no green text or outlines).
class HomeOfflineCard extends StatefulWidget {
  const HomeOfflineCard({
    super.key,
    required this.reason,
    required this.onGoOnline,
    required this.onOk,
    this.checks,
    this.onLocationFixed,
  });

  final String reason;
  final VoidCallback onGoOnline;
  final VoidCallback onOk;

  /// The checks; [PhoneChecks.current] when null.
  final PhoneChecks? checks;

  /// The location fix was done: Home reads the location again.
  final VoidCallback? onLocationFixed;

  /// Owner: the card goes by itself after 2 minutes.
  static const Duration showsFor = Duration(minutes: 2);

  static const Color ink = MoveraDialogTheme.ink;
  static const Color muted = MoveraDialogTheme.muted;
  static const Color grey = Color(0xFF9AA3A0);

  @override
  State<HomeOfflineCard> createState() => _HomeOfflineCardState();
}

class _HomeOfflineCardState extends State<HomeOfflineCard> {
  /// Null: not checked yet.
  Map<PhoneCheckKind, PhoneCheckResult?>? _results;

  PhoneChecks get _checks => widget.checks ?? PhoneChecks.current;

  Future<void> _checkAll() async {
    setState(
      () => _results = {for (final kind in PhoneCheckKind.values) kind: null},
    );
    final results = await _checks.all();
    if (!mounted) return;
    setState(() => _results = {for (final r in results) r.kind: r});
  }

  Future<void> _fix(PhoneCheckResult result) async {
    setState(() => _results?[result.kind] = null);
    try {
      await _checks.fix(result);
    } catch (_) {
      // The check below says how it is now.
    }
    if (result.kind == PhoneCheckKind.location) {
      widget.onLocationFixed?.call();
    }
    PhoneCheckResult again;
    try {
      again = await _checks.check(result.kind).timeout(PhoneChecks.limit);
    } catch (_) {
      again = PhoneCheckResult.unknown(result.kind);
    }
    if (!mounted) return;
    setState(() => _results?[result.kind] = again);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final results = _results;
    return MoveraDialogTheme(
      child: Builder(
        builder: (context) => Material(
          key: const ValueKey<String>('home-offline-card'),
          color: Colors.white,
          elevation: 8,
          shadowColor: const Color(0x3311181C),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 12 + bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDADEE1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MoveraWarningMark(),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr.offlineCardTitle,
                              key: const ValueKey<String>('offline-card-title'),
                              style: const TextStyle(
                                color: HomeOfflineCard.ink,
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.reason,
                              key: const ValueKey<String>(
                                'offline-card-reason',
                              ),
                              style: const TextStyle(
                                color: HomeOfflineCard.muted,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (results == null)
                  OutlinedButton.icon(
                    key: const ValueKey<String>('offline-card-check'),
                    onPressed: _checkAll,
                    icon: const Icon(Icons.fact_check_outlined, size: 20),
                    label: Text(tr.offlineCheckPhone),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: HomeOfflineCard.ink,
                      side: const BorderSide(
                        color: HomeOfflineCard.ink,
                        width: 1.4,
                      ),
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7F6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          for (final kind in PhoneCheckKind.values)
                            _CheckLine(
                              kind: kind,
                              result: results[kind],
                              onFix: _fix,
                            ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                FilledButton(
                  key: const ValueKey<String>('offline-card-go-online'),
                  onPressed: widget.onGoOnline,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: Text(tr.offlineGoOnline),
                ),
                const SizedBox(height: 2),
                TextButton(
                  key: const ValueKey<String>('offline-card-ok'),
                  onPressed: widget.onOk,
                  style: TextButton.styleFrom(
                    foregroundColor: HomeOfflineCard.ink,
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: Text(tr.ok),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One ✓ / ✗ line; null [result]: still checking.
class _CheckLine extends StatelessWidget {
  const _CheckLine({
    required this.kind,
    required this.result,
    required this.onFix,
  });

  final PhoneCheckKind kind;
  final PhoneCheckResult? result;
  final void Function(PhoneCheckResult result) onFix;

  String get _label => switch (kind) {
    PhoneCheckKind.location => tr.offlineCheckLocation,
    PhoneCheckKind.internet => tr.offlineCheckInternet,
    PhoneCheckKind.batterySaver => tr.offlineCheckBattery,
    PhoneCheckKind.notifications => tr.offlineCheckNotifications,
  };

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    final state = result?.state;
    final name = kind.name;
    final Widget mark = switch (state) {
      null => const SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: HomeOfflineCard.ink,
        ),
      ),
      PhoneCheckState.ok => const Icon(
        Icons.check_circle_outline_rounded,
        color: HomeOfflineCard.muted,
        size: 22,
      ),
      PhoneCheckState.problem => const Icon(
        Icons.cancel_rounded,
        color: HomeOfflineCard.ink,
        size: 22,
      ),
      PhoneCheckState.unknown => const Icon(
        Icons.remove_circle_outline_rounded,
        color: HomeOfflineCard.grey,
        size: 22,
      ),
    };
    final String? note = switch (state) {
      null => tr.offlineChecking,
      PhoneCheckState.unknown => tr.offlineCheckUnknown,
      PhoneCheckState.problem
          when result?.fix == PhoneCheckFix.browserSettings =>
        tr.offlineCheckBrowser,
      _ => null,
    };
    final String? action = state != PhoneCheckState.problem
        ? null
        : switch (result?.fix) {
            PhoneCheckFix.turnOn => tr.offlineFixTurnOn,
            PhoneCheckFix.openSettings => tr.locationOpenSettings,
            PhoneCheckFix.retry => tr.retry,
            _ => null,
          };
    return Semantics(
      container: true,
      child: Padding(
        key: ValueKey<String>(
          'offline-check-$name-${state?.name ?? 'checking'}',
        ),
        padding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Row(
            children: [
              SizedBox(width: 24, child: Center(child: mark)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _label,
                      style: const TextStyle(
                        color: HomeOfflineCard.ink,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (note != null)
                      Text(
                        note,
                        style: const TextStyle(
                          color: HomeOfflineCard.muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              if (action != null && result != null)
                TextButton(
                  key: ValueKey<String>('offline-check-$name-fix'),
                  onPressed: () => onFix(result),
                  style: TextButton.styleFrom(
                    foregroundColor: HomeOfflineCard.ink,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(48, 36),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  child: Text(action),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Movera's own warning mark: a black disc with a white rounded triangle
/// and a black "!" (no other company's look; only black, owner).
class MoveraWarningMark extends StatelessWidget {
  const MoveraWarningMark({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      key: const ValueKey<String>('offline-card-mark'),
      dimension: size,
      child: CustomPaint(painter: _WarningPainter()),
    ),
  );
}

class _WarningPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, s / 2, Paint()..color = HomeOfflineCard.ink);
    // A rounded triangle: the stroke's round joins soften the corners.
    final top = Offset(center.dx, s * 0.25);
    final left = Offset(s * 0.25, s * 0.71);
    final right = Offset(s * 0.75, s * 0.71);
    final triangle = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(left.dx, left.dy)
      ..close();
    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawPath(triangle, white);
    canvas.drawPath(
      triangle,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.08
        ..strokeJoin = StrokeJoin.round,
    );
    final bar = Paint()
      ..color = HomeOfflineCard.ink
      ..strokeWidth = s * 0.065
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx, s * 0.42),
      Offset(center.dx, s * 0.56),
      bar,
    );
    canvas.drawCircle(
      Offset(center.dx, s * 0.645),
      s * 0.036,
      Paint()..color = HomeOfflineCard.ink,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

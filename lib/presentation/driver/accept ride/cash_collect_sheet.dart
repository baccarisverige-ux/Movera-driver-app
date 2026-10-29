import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/earnings/cash_balance.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/widgets/owned_route_exit.dart';

/// Q24 / R8-4: at the drop-off of a cash trip the driver taps "Collect
/// cash"; this sheet covers about three quarters of the screen (the trip
/// stays visible on top) and shows the cash to take from the rider in a
/// "case", then "Finish {category}". True when the driver finishes.
Future<bool> showCashCollectSheet(
  BuildContext context, {
  required String fare,
  String? cash,
  required String riderName,
  String category = '',
  bool recalculated = false,
}) async {
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    builder: (_) => CashCollectSheet(
      fare: fare,
      cash: cash ?? fare,
      riderName: riderName,
      category: category,
      recalculated: recalculated,
    ),
  );
  return done == true;
}

class CashCollectSheet extends StatelessWidget {
  const CashCollectSheet({
    super.key,
    required this.fare,
    String? cash,
    required this.riderName,
    this.category = '',
    this.recalculated = false,
  }) : cash = cash ?? fare;

  /// The driver's own money for the trip, after Movera's commission
  /// (owner decision 2026-10-26); no fee is taken off it again.
  final String fare;

  /// The cash to take from the rider: their fare, which differs from
  /// [fare]; the difference is settled with Movera.
  final String cash;
  final String riderName;
  final String category;

  /// Contract v0.17.3 §26 (owner decision 28): the driver finishes more
  /// than 300 m before the drop-off, so the server priced what was driven;
  /// the sheet says so above the amount.
  final bool recalculated;

  /// Share of the screen the sheet covers.
  static const double heightFactor = 0.76;

  static const Color _ink = Color(0xFF111614);
  static const Color _muted = Color(0xFF6F7B82);
  static const Color _line = Color(0xFFECEEF0);
  static const Color _greyInk = Color(0xFF5E6A71);
  static const Color _owe = Color(0xFFB4232C);
  static const Color _due = Color(0xFF1E7A46);

  /// "250 kr" for whole kronor, otherwise "126,75 kr" (any currency).
  static String _short(String label) =>
      Money.parseLabel(label)?.formattedShort ?? label;

  String get _finishLabel => category.trim().isEmpty
      ? driverText(DriverTexts.tripFinishRide)
      : driverText(DriverTexts.tripFinishCategory, {
          'category': category.trim(),
        });

  @override
  Widget build(BuildContext context) {
    final amount = _short(cash);
    final balance = CashBalance.fromLabels(fare: fare, cashCollected: cash);
    final first = riderName.trim().split(' ').first;
    final height = MediaQuery.sizeOf(context).height * heightFactor;
    return SizedBox(
      height: height,
      child: Material(
        key: const ValueKey<String>('cash-collect-sheet'),
        color: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9DDDB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  driverText(DriverTexts.tripCollectCash),
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  first.isEmpty
                      ? tr.takeCashBeforeYouFinish
                      : tr.takeCashFromFirstBeforeYou(first),
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (recalculated) ...[
                          _recalculatedNotice(),
                          const SizedBox(height: 12),
                        ],
                        _cashCase(amount),
                        if (balance != null) ...[
                          const SizedBox(height: 14),
                          _balanceCard(balance),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 58,
                  child: FilledButton(
                    key: const ValueKey<String>('cash-complete-ride'),
                    onPressed: () => popOwned(context, true),
                    style: FilledButton.styleFrom(
                      elevation: 0,
                      backgroundColor: _ink,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      _finishLabel,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  key: const ValueKey<String>('cash-not-yet'),
                  onPressed: () => popOwned(context, false),
                  child: Text(
                    tr.notYet,
                    style: TextStyle(
                      color: _ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// "Ending before the destination – price recalculated".
  Widget _recalculatedNotice() {
    return Container(
      key: const ValueKey<String>('cash-price-recalculated'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 20, color: Color(0xFF7A5200)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tr.cashPriceRecalculatedEarlyEnd,
              style: const TextStyle(
                color: Color(0xFF5C3D00),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The "case": the cash to take, big and clear.
  Widget _cashCase(String amount) {
    return Semantics(
      label: tr.collectAmountInCash(amount),
      container: true,
      excludeSemantics: true,
      // R10-3: a light grey tray pressed into the sheet: inner shadow at
      // the top/left, soft light at the bottom, no outer drop shadow.
      child: CustomPaint(
        key: const ValueKey<String>('cash-collect-case'),
        foregroundPainter: const _InsetTrayPainter(radius: 26),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE6E8EB), Color(0xFFEFF1F3)],
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SvgPicture.asset(
                  AppAssets.solarWadOfMoney,
                  width: 30,
                  height: 30,
                  colorFilter: const ColorFilter.mode(_ink, BlendMode.srcIn),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                tr.collect,
                style: TextStyle(
                  color: _greyInk,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  amount,
                  key: const ValueKey<String>('cash-collect-amount'),
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 52,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.8,
                  ),
                ),
              ),
              Text(
                tr.inCash,
                style: TextStyle(
                  color: _greyInk,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The driver's earnings, the cash, and what is owed by or to Movera
  /// (R8-4).
  Widget _balanceCard(CashBalance balance) {
    final color = balance.driverOwesMovera
        ? _owe
        : balance.moveraOwesDriver
        ? _due
        : _ink;
    return Container(
      key: const ValueKey<String>('cash-collect-balance'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          _row(tr.yourEarnings, _short(fare)),
          const SizedBox(height: 8),
          _row(tr.cashFromRider, _short(cash)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: _line),
          ),
          _row(
            balance.directionLabel,
            balance.signedLabel,
            color: color,
            strong: true,
          ),
          if (balance.balance.minorUnits != 0) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                tr.settledInYourNextPayout,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? color, bool strong = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: strong ? color ?? _ink : _muted,
              fontSize: 13.5,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color ?? _ink,
            fontSize: strong ? 15 : 13.5,
            fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// R10-3: Flutter has no inset BoxShadow, so the tray's inner shadow is
/// painted over its fill: a blurred dark ring offset down/right (shadow on
/// the top/left edge), a light ring offset up (light on the bottom edge),
/// and a fine edge line, all clipped to the tray.
class _InsetTrayPainter extends CustomPainter {
  const _InsetTrayPainter({required this.radius});

  final double radius;

  void _ring(Canvas canvas, RRect tray, Offset offset, Paint paint) {
    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(tray.outerRect.inflate(24))
      ..addRRect(tray.shift(offset));
    canvas.drawPath(ring, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final tray = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.save();
    canvas.clipRRect(tray);
    _ring(
      canvas,
      tray,
      const Offset(2, 4),
      Paint()
        ..color = const Color(0xFF1C2A33).withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    _ring(
      canvas,
      tray,
      const Offset(-1, -3),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.restore();
    canvas.drawRRect(
      tray.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFD9DDE1),
    );
  }

  @override
  bool shouldRepaint(_InsetTrayPainter oldDelegate) =>
      oldDelegate.radius != radius;
}

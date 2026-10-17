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
  }) : cash = cash ?? fare;

  /// The driver's fare.
  final String fare;

  /// The cash to take from the rider; can differ from [fare].
  final String cash;
  final String riderName;
  final String category;

  /// Share of the screen the sheet covers.
  static const double heightFactor = 0.76;

  static const Color _ink = Color(0xFF111614);
  static const Color _muted = Color(0xFF6F7B82);
  static const Color _line = Color(0xFFECEEF0);
  static const Color _gold = Color(0xFF7A5200);
  static const Color _owe = Color(0xFFB4232C);
  static const Color _due = Color(0xFF1E7A46);

  /// "250 kr" for whole kronor, otherwise "126,75 kr".
  static String _short(String label) {
    final money = Money.parseSekLabel(label);
    if (money == null) return label;
    return money.formatted.replaceFirst(RegExp(r',00 kr$'), ' kr');
  }

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
                      ? 'Take the cash before you finish.'
                      : 'Take the cash from $first before you finish.',
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
                  child: const Text(
                    'Not yet',
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

  /// The "case": the cash to take, big and clear.
  Widget _cashCase(String amount) {
    return Semantics(
      label: 'Collect $amount in cash',
      container: true,
      excludeSemantics: true,
      child: Container(
        key: const ValueKey<String>('cash-collect-case'),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF8E6), Color(0xFFFFEFC7)],
          ),
          border: Border.all(color: const Color(0xFFF2DDA4)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7A5200).withValues(alpha: 0.10),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
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
              ),
              child: SvgPicture.asset(
                AppAssets.solarWadOfMoney,
                width: 30,
                height: 30,
                colorFilter: const ColorFilter.mode(_gold, BlendMode.srcIn),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Collect',
              style: TextStyle(
                color: _gold,
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
            const Text(
              'in cash',
              style: TextStyle(
                color: _gold,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Fare, cash, and what is owed by or to Movera (R8-4).
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
          _row('Your fare', _short(fare)),
          const SizedBox(height: 8),
          _row('Cash from rider', _short(cash)),
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
                balance.driverOwesMovera
                    ? 'The rider paid more than your fare (promotion). '
                          'It is settled in your next payout.'
                    : 'The rider paid less than your fare (promotion). '
                          'Movera adds it to your next payout.',
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

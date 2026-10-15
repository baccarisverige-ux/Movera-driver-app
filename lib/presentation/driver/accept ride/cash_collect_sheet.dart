import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/widgets/owned_route_exit.dart';

/// Round 3, Q24: at the drop-off of a cash trip the driver taps "Collect
/// cash"; this shows the amount to collect, then "Complete ride". True
/// when the driver completes the ride.
Future<bool> showCashCollectSheet(
  BuildContext context, {
  required String fare,
  required String riderName,
}) async {
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    builder: (_) => CashCollectSheet(fare: fare, riderName: riderName),
  );
  return done == true;
}

class CashCollectSheet extends StatelessWidget {
  const CashCollectSheet({
    super.key,
    required this.fare,
    required this.riderName,
  });

  final String fare;
  final String riderName;

  static const Color _ink = Color(0xFF111614);
  static const Color _muted = Color(0xFF6F7B82);

  @override
  Widget build(BuildContext context) {
    final amount = Money.parseSekLabel(fare)?.formatted ?? fare;
    final owed = WaybillPayment.fromFare(fare)?.serviceFee;
    final first = riderName.trim().split(' ').first;
    return Material(
      key: const ValueKey<String>('cash-collect-sheet'),
      color: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 16),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4DC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: SvgPicture.asset(
                      AppAssets.solarWadOfMoney,
                      width: 24,
                      height: 24,
                      colorFilter: const ColorFilter.mode(
                        Color(0xFF7A5200),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Collect cash',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                first.isEmpty ? 'Amount to collect' : 'Amount to collect from $first',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  amount,
                  key: const ValueKey<String>('cash-collect-amount'),
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 44,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.6,
                  ),
                ),
              ),
              if (owed != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Movera’s fee ($owed) is taken from your next payout.',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12.5,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                height: 56,
                child: FilledButton(
                  key: const ValueKey<String>('cash-complete-ride'),
                  onPressed: () => popOwned(context, true),
                  style: FilledButton.styleFrom(
                    elevation: 0,
                    backgroundColor: _ink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Complete ride',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
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
    );
  }
}

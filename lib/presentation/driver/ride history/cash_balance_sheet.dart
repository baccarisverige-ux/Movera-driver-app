import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/earnings/cash_balance.dart';
import 'package:movera/core/history/trip_history.dart';

/// R8-4: "Other earnings" details. Each cash trip with its fare, the cash
/// collected and its +/− balance, then the total the driver owes Movera
/// (−) or is owed (+).
Future<void> showCashBalanceSheet(
  BuildContext context,
  List<TripHistoryRecord> trips,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    builder: (_) => CashBalanceSheet(trips: trips),
  );
}

class CashBalanceSheet extends StatelessWidget {
  const CashBalanceSheet({super.key, required this.trips});

  /// Completed cash trips; others are left out.
  final List<TripHistoryRecord> trips;

  static const Color _ink = Color(0xFF1F2933);
  static const Color _muted = Color(0xFF7C868D);
  static const Color _line = Color(0xFFECEEF0);
  static const Color _tile = Color(0xFFF4F5F6);
  static const Color _owe = Color(0xFFB4232C);
  static const Color _due = Color(0xFF1E7A46);

  static Color colorFor(int minorUnits) => minorUnits < 0
      ? _owe
      : minorUnits > 0
      ? _due
      : _ink;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final trip in trips)
        if (trip.cashBalance case final balance?) (trip, balance),
    ];
    final total = CashBalance.total(rows.map((row) => row.$2));
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Material(
        key: const ValueKey<String>('cash-balance-sheet'),
        color: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
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
                const SizedBox(height: 16),
                Text(
                  tr.otherEarnings,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tr.cashTripsYourFareMinusCash,
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: rows.isEmpty
                      ? Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Text(
                            tr.noCashTripsInThisPeriod,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _muted, fontSize: 13),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _tripCard(rows[i].$1, rows[i].$2),
                        ),
                ),
                const SizedBox(height: 12),
                Container(
                  key: const ValueKey<String>('cash-balance-total'),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: _tile,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          total.minorUnits < 0
                              ? tr.totalYouOweMovera
                              : total.minorUnits > 0
                              ? tr.totalMoveraOwesYou
                              : tr.totalBalance,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        CashBalance.signed(total),
                        style: TextStyle(
                          color: colorFor(total.minorUnits),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tr.settledInYourNextPayout2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tripCard(TripHistoryRecord trip, CashBalance balance) {
    return Container(
      key: ValueKey<String>('cash-balance-trip-${trip.tripId}'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _tile,
              borderRadius: BorderRadius.circular(11),
            ),
            child: SvgPicture.asset(
              AppAssets.solarWadOfMoney,
              width: 18,
              height: 18,
              colorFilter: const ColorFilter.mode(_ink, BlendMode.srcIn),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${trip.pickup} → ${trip.dropoff}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tr.fareFareFormattedCashCashCollected(balance.fare.formatted, balance.cashCollected.formatted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            balance.signedLabel,
            style: TextStyle(
              color: colorFor(balance.balance.minorUnits),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

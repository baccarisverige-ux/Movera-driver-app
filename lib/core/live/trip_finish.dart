import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/money/money.dart';

Money? _money(Object? value) {
  if (value is! Map) return null;
  try {
    return Money.fromJson(Map<String, dynamic>.from(value));
  } on FormatException {
    return null;
  }
}

/// One line of the driver's money for a trip (contract v0.18.10
/// `finish.driverMoney`, owner G8 Q3): `trip | pickup_pay | bonus | tip |
/// adjustment`.
class EarningsLine {
  const EarningsLine(this.code, this.amount);

  final String code;
  final Money amount;

  /// The line's words in the driver's language
  /// (`finish.driverMoney.texts`).
  String get label => switch (code) {
    'trip' => tr.g8LineTrip,
    'pickup_pay' => tr.g8LinePickupPay,
    'bonus' => tr.g8LineBonus,
    'tip' => tr.g8LineTip,
    'adjustment' => tr.g8LineAdjustment,
    _ => code,
  };

  /// `earningsBreakdown`: only well-formed lines in [currency] (when given).
  static List<EarningsLine> parseList(Object? raw, {String? currency}) {
    if (raw is! List) return const [];
    final lines = <EarningsLine>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final code = item['code'];
      final amount = _money(item['amount']);
      if (code is! String || amount == null) continue;
      if (currency != null && amount.currency != currency) continue;
      lines.add(EarningsLine(code, amount));
    }
    return lines;
  }
}

/// `TripProjection.tip` (contract v0.18.10 `finish.tips`): 100 % the
/// driver's.
class TripTipInfo {
  const TripTipInfo({required this.amount, required this.method});

  final Money amount;

  /// `cash | card | apple_pay`.
  final String method;

  bool get cash => method == 'cash';

  static TripTipInfo? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final amount = _money(raw['amount']);
    if (amount == null || amount.minorUnits <= 0) return null;
    final method = raw['method'];
    return TripTipInfo(
      amount: amount,
      method: method is String ? method : 'cash',
    );
  }

  /// "Tip from the rider: 20 kr" or, for cash, "The rider gives you …".
  String get text => cash
      ? tr.g8TipCash(amount.formattedShort)
      : tr.g8TipGot(amount.formattedShort);
}

/// `TripProjection.finish` (contract v0.18.10 `finish.earlyEnd`): how an
/// ended trip with a fare finished.
class TripFinishInfo {
  const TripFinishInfo({
    required this.endedEarly,
    this.endedBy,
    this.reasonCode,
    this.repriced,
    this.total,
    this.cashToCollect,
    this.driverTotal,
    this.earningsBreakdown = const [],
    this.ratingAllowed = false,
  });

  final bool endedEarly;

  /// `rider | driver`.
  final String? endedBy;
  final String? reasonCode;
  final bool? repriced;
  final Money? total;
  final Money? cashToCollect;
  final Money? driverTotal;
  final List<EarningsLine> earningsBreakdown;
  final bool ratingAllowed;

  /// Owner G8 Q1: the rider ended the trip on board; the driver gets the
  /// cash sheet with this amount, then the rating.
  bool get riderEndedEarly => endedEarly && endedBy == 'rider';

  static TripFinishInfo? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final early = raw['endedEarly'];
    final by = raw['endedBy'];
    final reason = raw['reasonCode'];
    final repriced = raw['repriced'];
    final total = _money(raw['total']);
    final driverTotal = _money(raw['driverTotal']);
    return TripFinishInfo(
      endedEarly: early == true,
      endedBy: by is String ? by : null,
      reasonCode: reason is String ? reason : null,
      repriced: repriced is bool ? repriced : null,
      total: total,
      cashToCollect: _money(raw['cashToCollect']),
      driverTotal: driverTotal,
      earningsBreakdown: EarningsLine.parseList(
        raw['earningsBreakdown'],
        currency: driverTotal?.currency,
      ),
      ratingAllowed: raw['ratingAllowed'] == true,
    );
  }
}

/// J11 (contract v0.18.84 `debtModel.driverOwes.cashOffers`, owner Q-S5-1
/// + 2026-11-13 14:54 "can recive trip but cash trip"): a driver at or
/// over his country's owes-limit gets no cash (pay-in-car) trips until he
/// pays Movera. The server refuses his Accept of a cash offer with
/// `409 conflict`, reason `driver_owes_movera`, details
/// `["owed:<minor> <CUR>", "limit:<minor> <CUR>"]`. The offer went away
/// for him: it was not taken by another driver.
library;

import 'package:flutter/foundation.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/money/money.dart';

@immutable
class OwesMoveraRefusal {
  const OwesMoveraRefusal({required this.owed, required this.limit});

  static const reason = 'driver_owes_movera';

  /// What he owes Movera and his owes-limit, as the server sent them.
  final Money owed;
  final Money limit;

  /// The refusal in a 409 answer [body], or null when it is another one
  /// or its amounts are missing.
  static OwesMoveraRefusal? fromConflict(Map<String, dynamic>? body) {
    if (body == null || body['reason'] != reason) return null;
    final details = body['details'];
    if (details is! List) return null;
    Money? owed;
    Money? limit;
    for (final item in details) {
      if (item is! String) continue;
      if (item.startsWith('owed:')) owed = _money(item.substring(5));
      if (item.startsWith('limit:')) limit = _money(item.substring(6));
    }
    if (owed == null || limit == null) return null;
    return OwesMoveraRefusal(owed: owed, limit: limit);
  }

  /// `<minor> <CUR>`, e.g. `152000 TND`.
  static Money? _money(String text) {
    final match = RegExp(r'^\s*(-?\d+)\s+([A-Z]{3})\s*$').firstMatch(text);
    if (match == null) return null;
    final currency = match.group(2)!;
    if (!Money.exponents.containsKey(currency)) return null;
    return Money(minorUnits: int.parse(match.group(1)!), currency: currency);
  }

  /// The Home line's words (contract `reminders.texts.owes_movera_over_limit`).
  String get text => tr.remOwesMoveraOverLimit(owed.formatted, limit.formatted);
}

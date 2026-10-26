import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:movera/core/money/money.dart';

/// `GET /driver/earnings?period=day` (contract `EarningsReport`): today's
/// earnings as the server counts them, in the zone's currency. A live
/// build shows these, not a sum of the trips this device happens to hold
/// (audit Phase 1 R3: zero on a new device, always "kr").
class LiveEarnings {
  LiveEarnings({required ApiClient api}) : _api = api;

  final ApiClient _api;

  static const path = '/api/v1/driver/earnings';

  /// Today's `net`, or null when the server could not say.
  Future<Money?> today({DateTime? now}) async {
    try {
      final report = await _api.get('$path?period=day');
      return todayOf(report, now ?? DateTime.now());
    } catch (error) {
      DriverLog.warn('earnings not read: $error', name: 'live');
      return null;
    }
  }

  /// The period holding [now] (else the newest one) of an
  /// `EarningsReport`; its `net`. Null when there is none.
  static Money? todayOf(Map<String, dynamic> report, DateTime now) {
    final periods = report['periods'];
    if (periods is! List || periods.isEmpty) return null;
    Map? chosen;
    for (final period in periods) {
      if (period is! Map) continue;
      final start = DateTime.tryParse('${period['periodStart']}');
      final end = DateTime.tryParse('${period['periodEnd']}');
      if (start != null &&
          end != null &&
          !now.isBefore(start) &&
          now.isBefore(end)) {
        chosen = period;
        break;
      }
    }
    chosen ??= periods.last is Map ? periods.last as Map : null;
    final net = chosen?['net'];
    if (net is! Map) return null;
    try {
      return Money.fromJson(Map<String, dynamic>.from(net));
    } on FormatException {
      return null;
    }
  }
}

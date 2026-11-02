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

  /// This week's `net` (audit 2026-11-01: the wallet's balance on live);
  /// throws when the server could not answer, null when nothing is earned.
  Future<Money?> thisWeek({DateTime? now}) async => (await week(now: now)).net;

  /// Contract v0.18.14 `deepFix1.earnings`: this week's report in one
  /// [currency] (`?currency=SEK|EUR`; the server's default without it:
  /// the currency of the driver's first zone) with every currency he
  /// earned in, for a kr / € switch. Throws when the server could not
  /// answer.
  Future<EarningsWeek> week({String? currency, DateTime? now}) async {
    final query = currency == null
        ? 'period=week'
        : 'period=week&currency=${Uri.encodeQueryComponent(currency)}';
    final report = await _api.get('$path?$query');
    return EarningsWeek.of(report, now ?? DateTime.now());
  }

  /// `GET /driver/payouts` (newest first): the driver's own payouts.
  /// Throws when the server could not answer.
  Future<List<DriverPayout>> payouts({int limit = 10}) async {
    final page = await _api.get('/api/v1/driver/payouts?limit=$limit');
    final items = page['items'];
    if (items is! List) return const [];
    return [
      for (final item in items)
        if (item is Map)
          ?DriverPayout.tryParse(Map<String, dynamic>.from(item)),
    ];
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

/// One payout of `GET /driver/payouts` (contract Payout, driver view).
class DriverPayout {
  const DriverPayout({
    required this.amount,
    required this.paid,
    required this.periodStart,
    required this.periodEnd,
    required this.tripCount,
  });

  final Money amount;
  final bool paid;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int tripCount;

  static DriverPayout? tryParse(Map<String, dynamic> json) {
    final amount = json['amount'];
    final start = DateTime.tryParse('${json['periodStart']}');
    final end = DateTime.tryParse('${json['periodEnd']}');
    if (amount is! Map || start == null || end == null) return null;
    try {
      return DriverPayout(
        amount: Money.fromJson(Map<String, dynamic>.from(amount)),
        paid: json['status'] == 'paid',
        periodStart: start,
        periodEnd: end,
        tripCount: (json['tripCount'] as num?)?.toInt() ?? 0,
      );
    } on FormatException {
      return null;
    }
  }
}

/// One currency of an `EarningsReport` (contract v0.18.14): its `net` for
/// the period holding now, the report's `currency` and `currencies`.
class EarningsWeek {
  const EarningsWeek({this.net, this.currency, this.currencies = const []});

  factory EarningsWeek.of(Map<String, dynamic> report, DateTime now) {
    final listed = report['currencies'];
    return EarningsWeek(
      net: LiveEarnings.todayOf(report, now),
      currency: report['currency'] is String
          ? report['currency'] as String
          : null,
      currencies: [
        if (listed is List)
          for (final c in listed)
            if (c is String && c.isNotEmpty) c,
      ],
    );
  }

  final Money? net;
  final String? currency;

  /// Every currency earned in during the range; two or more → the switch.
  final List<String> currencies;
}

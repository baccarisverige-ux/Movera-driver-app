import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/money/money.dart';

/// v0.18.153 P29 (contract.json#driverIncomeYear; owner 2026-11-21 "Don't
/// only save ! Execute ! Add section in admin all what need and in code and
/// everywhere"; EU DAC7): `GET /driver/income-statement`, what Movera reports
/// to the tax office for the driver (his company's row when he owns one,
/// his own part when he only drives for a fleet). Every amount is the
/// server's; the app adds nothing up (moneyBase).
class LiveIncomeStatement {
  LiveIncomeStatement({required ApiClient api}) : _api = api;

  final ApiClient _api;

  static const path = '/api/v1/driver/income-statement';

  /// [detail] is `month`, `day` or `trips` (trips needs [month]). Throws
  /// when the server could not answer.
  Future<IncomeStatement> load({
    required int year,
    String detail = 'month',
    String? month,
  }) async {
    final query = [
      'year=$year',
      'detail=$detail',
      if (month != null) 'month=${Uri.encodeQueryComponent(month)}',
    ].join('&');
    return IncomeStatement.of(await _api.get('$path?$query'));
  }
}

/// The totals every level carries (contract `DriverIncomeTotals`).
class IncomeTotals {
  const IncomeTotals({
    required this.rides,
    required this.grossFares,
    required this.netEarnings,
    required this.moveraCommission,
    required this.tips,
    required this.bonuses,
    this.adjustments,
    required this.cash,
    required this.paidOut,
  });

  final int rides;
  final Money grossFares;
  final Money netEarnings;
  final Money moveraCommission;
  final Money tips;
  final Money bonuses;

  /// Movera's changes to the pay (may be negative); null from an older answer.
  final Money? adjustments;
  final Money cash;
  final Money paidOut;

  static Money _money(Object? value, String currency) => value is Map
      ? Money.fromJson(Map<String, dynamic>.from(value))
      : Money(minorUnits: 0, currency: currency);

  factory IncomeTotals.of(Map<String, dynamic> json, String currency) =>
      IncomeTotals(
        rides: (json['rides'] as num?)?.toInt() ?? 0,
        grossFares: _money(json['grossFares'], currency),
        netEarnings: _money(json['netEarnings'], currency),
        moveraCommission: _money(json['moveraCommission'], currency),
        tips: _money(json['tips'], currency),
        bonuses: _money(json['bonuses'], currency),
        adjustments: _money(json['adjustments'], currency),
        cash: _money(json['cashCollectedByDriver'], currency),
        paidOut: _money(json['paidOutByMovera'], currency),
      );
}

/// One trip line (detail trips): its zone-local end time and money.
class IncomeTripLine {
  const IncomeTripLine({
    required this.localTime,
    this.lineKind = 'trip',
    required this.tripId,
    required this.paymentMethod,
    required this.totals,
  });

  final String localTime;

  /// v0.18.153 review: `trip` (the trip's own entries), `credit` (money
  /// credited later or with no trip: a tip, bonus or change by Movera) or
  /// `payout` (a paid payout: only paidOutByMovera).
  final String lineKind;
  final String? tripId;
  final String? paymentMethod;
  final IncomeTotals totals;
}

class IncomeDay {
  const IncomeDay({required this.day, required this.totals, this.trips});

  final String day;
  final IncomeTotals totals;
  final List<IncomeTripLine>? trips;
}

class IncomeMonth {
  const IncomeMonth({required this.month, required this.totals, this.days});

  final String month;
  final IncomeTotals totals;
  final List<IncomeDay>? days;
}

/// One payee row in one currency.
class IncomeRow {
  const IncomeRow({
    required this.kind,
    required this.name,
    required this.orgNumber,
    required this.currency,
    required this.ownPartOnly,
    required this.totals,
    required this.months,
  });

  final String kind;
  final String name;
  final String? orgNumber;
  final String currency;
  final bool ownPartOnly;
  final IncomeTotals totals;
  final List<IncomeMonth> months;

  bool get company => kind == 'company';
}

class IncomeStatement {
  const IncomeStatement({required this.year, required this.rows});

  final int year;
  final List<IncomeRow> rows;

  static List<Map<String, dynamic>> _list(Object? value) => [
    if (value is List)
      for (final item in value)
        if (item is Map) Map<String, dynamic>.from(item),
  ];

  factory IncomeStatement.of(Map<String, dynamic> json) {
    final rows = <IncomeRow>[];
    for (final row in _list(json['items'])) {
      final currency = '${row['currency'] ?? ''}';
      rows.add(
        IncomeRow(
          kind: '${row['kind'] ?? 'driver'}',
          name: '${row['name'] ?? ''}',
          orgNumber: row['orgNumber'] as String?,
          currency: currency,
          ownPartOnly: row['ownPartOnly'] == true,
          totals: IncomeTotals.of(row, currency),
          months: [
            for (final m in _list(row['months']))
              IncomeMonth(
                month: '${m['month']}',
                totals: IncomeTotals.of(m, currency),
                days: m['days'] is List
                    ? [
                        for (final d in _list(m['days']))
                          IncomeDay(
                            day: '${d['day']}',
                            totals: IncomeTotals.of(d, currency),
                            trips: d['trips'] is List
                                ? [
                                    for (final t in _list(d['trips']))
                                      IncomeTripLine(
                                        localTime: '${t['localTime'] ?? ''}',
                                        lineKind: '${t['lineKind'] ?? 'trip'}',
                                        tripId: t['tripId'] as String?,
                                        paymentMethod:
                                            t['paymentMethod'] as String?,
                                        totals: IncomeTotals.of(t, currency),
                                      ),
                                  ]
                                : null,
                          ),
                      ]
                    : null,
              ),
          ],
        ),
      );
    }
    return IncomeStatement(
      year: (json['year'] as num?)?.toInt() ?? 0,
      rows: rows,
    );
  }
}

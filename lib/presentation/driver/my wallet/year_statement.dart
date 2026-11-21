import 'package:flutter/material.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/live/live_income_statement.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:share_plus/share_plus.dart';

/// v0.18.153 P29 (contract.json#driverIncomeYear; owner 2026-11-21 "Don't
/// only save ! Execute ! ... everywhere" + "yearly but with monthly details
/// ... monthly and daily ... even all trip per day"; EU DAC7): Earnings ›
/// Year statement. Year → months → days → trips, with the server's totals
/// (the same row Movera's accountant reports). Share sends a plain text.
class YearStatementScreen extends StatefulWidget {
  const YearStatementScreen({super.key, this.source, this.now});

  /// Test seam: the statement reader (default: the live services').
  final LiveIncomeStatement? source;
  final DateTime? now;

  @override
  State<YearStatementScreen> createState() => _YearStatementScreenState();
}

/// The line for a failed read: the server's too-big answer has its own
/// text (contract driverIncomeYear.texts.tooBig), anything else the
/// generic one.
String yearStatementError(Object? error) =>
    error is ApiError && error.reason == 'income_detail_too_big'
    ? tr.yearStatementTooBig
    : tr.yearStatementUnavailable;

/// A trip line's label (existing texts only): a payout is "Paid out by
/// Movera"; a credit says what it holds (tip, bonus, a change by Movera);
/// a trip line names its trip.
String tripLineLabel(IncomeTripLine t) {
  if (t.lineKind == 'payout') return tr.yearStatementPaidOut;
  if (t.lineKind == 'credit') {
    final x = t.totals;
    if (x.tips.minorUnits != 0) return tr.yearStatementTips;
    if (x.bonuses.minorUnits != 0) {
      return t.tripId == null
          ? tr.yearStatementBonusLine
          : tr.yearStatementBonuses;
    }
    if ((x.adjustments?.minorUnits ?? 0) != 0) return tr.g8LineAdjustment;
    return tr.yearStatementEarnings;
  }
  return t.tripId ?? tr.yearStatementBonusLine;
}

/// The amount a line shows: what Movera paid out for a payout line, else
/// the line's earnings.
Money tripLineAmount(IncomeTripLine t) =>
    t.lineKind == 'payout' ? t.totals.paidOut : t.totals.netEarnings;

class _YearStatementScreenState extends State<YearStatementScreen> {
  late final DateTime _now = widget.now ?? DateTime.now();
  late int _year = _now.year - 1 < 2020 ? 2020 : _now.year - 1;
  late Future<IncomeStatement> _statement = _load();
  final Map<String, Future<IncomeStatement>> _trips = {};

  /// The days opened: only their month's trips are read (one read per
  /// month, when a day of it is opened).
  final Set<String> _openDays = {};

  LiveIncomeStatement get _source =>
      widget.source ?? LiveDriverServices.instance!.incomeStatement;

  Future<IncomeStatement> _load() => _source.load(year: _year, detail: 'day');

  Future<IncomeStatement> _tripsOf(String month) => _trips.putIfAbsent(
    month,
    () => _source.load(year: _year, detail: 'trips', month: month),
  );

  void _pickYear(int year) => setState(() {
    _year = year;
    _trips.clear();
    _openDays.clear();
    _statement = _load();
  });

  static String _shareText(IncomeStatement s) {
    final lines = <String>[tr.yearStatementReported(s.year)];
    for (final row in s.rows) {
      lines.add('');
      lines.add(row.ownPartOnly ? tr.yearStatementOwnPart(row.name) : row.name);
      if (row.orgNumber != null) lines.add(row.orgNumber!);
      lines.addAll(_totalLines(row.totals));
      for (final m in row.months) {
        lines.add(
          '${m.month}: ${tr.yearStatementEarnings} ${m.totals.netEarnings.formatted} · ${tr.yearStatementRides(m.totals.rides)}',
        );
      }
    }
    return lines.join('\n');
  }

  static List<String> _totalLines(IncomeTotals t) => [
    tr.yearStatementRides(t.rides),
    '${tr.yearStatementEarnings}: ${t.netEarnings.formatted}',
    '${tr.yearStatementFares}: ${t.grossFares.formatted}',
    '${tr.yearStatementCommission}: ${t.moveraCommission.formatted}',
    '${tr.yearStatementTips}: ${t.tips.formatted}',
    '${tr.yearStatementBonuses}: ${t.bonuses.formatted}',
    '${tr.yearStatementCash}: ${t.cash.formatted}',
    '${tr.yearStatementPaidOut}: ${t.paidOut.formatted}',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: tr.back,
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => popOwned(context),
        ),
        title: Text(tr.yearStatementTitle),
        actions: [
          FutureBuilder<IncomeStatement>(
            future: _statement,
            builder: (context, snap) => IconButton(
              key: const ValueKey<String>('year-statement-share'),
              tooltip: tr.yearStatementShare,
              icon: const Icon(Icons.ios_share),
              onPressed: snap.hasData && snap.data!.rows.isNotEmpty
                  ? () => SharePlus.instance.share(
                      ShareParams(text: _shareText(snap.data!)),
                    )
                  : null,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          Row(
            children: [
              Text(tr.yearStatementYear),
              const SizedBox(width: 12),
              DropdownButton<int>(
                key: const ValueKey<String>('year-statement-year'),
                value: _year,
                items: [
                  for (var y = _now.year; y >= 2020; y--)
                    DropdownMenuItem(value: y, child: Text('$y')),
                ],
                onChanged: (y) => y == null ? null : _pickYear(y),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<IncomeStatement>(
            future: _statement,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return Column(
                  children: [
                    Text(yearStatementError(snap.error)),
                    TextButton(
                      onPressed: () => setState(() => _statement = _load()),
                      child: Text(tr.retry),
                    ),
                  ],
                );
              }
              final s = snap.data!;
              if (s.rows.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    tr.yearStatementEmpty,
                    key: const ValueKey<String>('year-statement-empty'),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr.yearStatementReported(s.year),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  for (final row in s.rows) _row(row),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _row(IncomeRow row) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 14),
      Text(
        row.ownPartOnly ? tr.yearStatementOwnPart(row.name) : row.name,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      if (row.orgNumber != null) Text(row.orgNumber!),
      const SizedBox(height: 6),
      _totals(row.totals, key: ValueKey<String>('year-total-${row.currency}')),
      for (final m in row.months)
        ExpansionTile(
          key: ValueKey<String>('year-month-${m.month}'),
          tilePadding: EdgeInsets.zero,
          title: Text(m.month),
          subtitle: Text(
            '${m.totals.netEarnings.formatted} · ${tr.yearStatementRides(m.totals.rides)}',
          ),
          children: [
            _totals(m.totals),
            for (final d in m.days ?? const <IncomeDay>[])
              ExpansionTile(
                key: ValueKey<String>('year-day-${d.day}'),
                title: Text(d.day),
                subtitle: Text(
                  '${d.totals.netEarnings.formatted} · ${tr.yearStatementRides(d.totals.rides)}',
                ),
                onExpansionChanged: (open) => setState(
                  () => open ? _openDays.add(d.day) : _openDays.remove(d.day),
                ),
                children: [
                  if (_openDays.contains(d.day)) _dayTrips(row, m.month, d.day),
                ],
              ),
          ],
        ),
    ],
  );

  Widget _dayTrips(
    IncomeRow row,
    String month,
    String day,
  ) => FutureBuilder<IncomeStatement>(
    future: _tripsOf(month),
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const LinearProgressIndicator();
      }
      if (snap.hasError) return Text(yearStatementError(snap.error));
      final same = snap.data!.rows.where((r) => r.currency == row.currency);
      final lines = [
        for (final r in same)
          for (final m in r.months)
            for (final d in m.days ?? const <IncomeDay>[])
              if (d.day == day) ...?d.trips,
      ];
      return Column(
        children: [
          for (final t in lines)
            ListTile(
              dense: true,
              title: Text(
                '${t.localTime.length >= 16 ? t.localTime.substring(11, 16) : t.localTime} · ${tripLineLabel(t)}${t.lineKind == 'credit' && t.tripId != null ? ' · ${t.tripId}' : ''}',
              ),
              subtitle: t.lineKind != 'trip'
                  ? null
                  : Text(
                      '${tr.yearStatementFares} ${t.totals.grossFares.formatted} · ${tr.yearStatementCommission} ${t.totals.moveraCommission.formatted}${t.paymentMethod == 'cash' ? ' · ${tr.yearStatementCash} ${t.totals.cash.formatted}' : ''}',
                    ),
              trailing: Text(tripLineAmount(t).formatted),
            ),
        ],
      );
    },
  );

  Widget _totals(IncomeTotals t, {Key? key}) => Container(
    key: key,
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F5F6),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final line in _totalLines(t)) Text(line)],
    ),
  );
}

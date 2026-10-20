import 'package:movera/widgets/owned_route_exit.dart';
import 'package:movera/widgets/single_route_entry.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/contracts/trip_transitions.dart';
import 'package:movera/core/money/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/history/trip_history.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/earnings/cash_balance.dart';
import 'package:movera/presentation/driver/ride%20history/cash_balance_sheet.dart';
import 'package:movera/presentation/driver/ride%20history/history%20detail/history_detail.dart';

Widget _solarIcon(String asset, {double size = 18, Color color = const Color(0xFF1F2933)}) =>
    SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );

class DriverRideHistory extends StatefulWidget {
  const DriverRideHistory({super.key, this.loadHistory});

  final Future<List<TripHistoryRecord>> Function()? loadHistory;

  @override
  State<DriverRideHistory> createState() => _DriverRideHistoryState();
}

enum _HistoryView { overview, rides }
enum _HistoryPeriod { today, week, month }

class _DriverRideHistoryState extends State<DriverRideHistory> {
  static const Color _ink = Color(0xFF1F2933);
  static const Color _muted = Color(0xFF7C868D);
  static const Color _subtle = Color(0xFF5F6B72);
  static const Color _tile = Color(0xFFF4F5F6);
  static const Color _line = Color(0xFFECEEF0);

  _HistoryView _view = _HistoryView.overview;
  _HistoryPeriod _period = _HistoryPeriod.week;

  List<_HistoryRide> _rides = <_HistoryRide>[];
  late final _readHistory =
      widget.loadHistory ?? PrefsTripHistoryRepository().list;
  bool _loading = true;
  bool _loadFailed = false;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (_restoring || !mounted) return;
    _restoring = true;
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final records = await _readHistory();
      if (!mounted) { return; }
      setState(() => _rides = records.map((record) {
        final at = record.completedAt;
        return _HistoryRide(
          record: record,
          id: record.tripId,
          day: at == null ? 'Previous' : '${at.day}/${at.month}/${at.year}',
          time: at == null ? '' : '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}',
          category: record.category,
          pickup: record.pickup,
          dropoff: record.dropoff,
          distance: record.distance,
          duration: record.duration,
          earnings: record.status == TripStatus.completed ? record.fare : '—',
          status:record.status,
          fareMoney:record.fareMoney,
          completedAt: at,
        );
      }).toList());
    } catch (_) {
      if (mounted) {
        setState(() => _loadFailed = true);
      }
    } finally {
      _restoring = false;
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<_HistoryRide> get _periodRidesList {
    final now = DateTime.now();
    return _rides.where((ride) {
      final at = ride.completedAt;
      if (at == null) { return false; }
      return switch (_period) {
        _HistoryPeriod.today => at.year == now.year && at.month == now.month && at.day == now.day,
        _HistoryPeriod.week => now.difference(at).inDays < 7 && !at.isAfter(now),
        _HistoryPeriod.month => at.year == now.year && at.month == now.month,
      };
    }).toList();
  }

  String get _periodLabel {
    switch (_period) {
      case _HistoryPeriod.today:
        return 'Today';
      case _HistoryPeriod.week:
        return 'Last 7 days';
      case _HistoryPeriod.month:
        final now = DateTime.now();
        return '${now.month}/${now.year}';
    }
  }

  String get _periodEarnings {
    var total=0;
    for(final ride in _periodRidesList.where((ride)=>ride.status==TripStatus.completed)) {
      if(ride.fareMoney==null) { return 'Unavailable'; }
      total+=ride.fareMoney!.minorUnits;
    }
    return Money.ore(total).formatted;
  }

  /// R8-4: completed cash trips of the period, for "Other earnings".
  List<TripHistoryRecord> get _periodCashTrips => [
    for (final ride in _periodRidesList)
      if (ride.record.cashBalance != null) ride.record,
  ];

  /// Fare − cash over the period's cash trips: owed to (+) or by (−) the
  /// driver.
  Money get _periodCashBalance => CashBalance.total(
    _periodCashTrips.map((trip) => trip.cashBalance!),
  );

  String get _periodRides => _periodRidesList.where((ride)=>ride.status==TripStatus.completed).length.toString();

  String get _periodHours => '—';

  void _showOverview() {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    if (_view == _HistoryView.overview) { return; }
    setState(() => _view = _HistoryView.overview);
  }

  void _showAllRides() {
    if (!mounted || _loading || _loadFailed ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    if (_view == _HistoryView.rides) { return; }
    setState(() => _view = _HistoryView.rides);
  }

  void _closeHistory() {
    if (!mounted || _view != _HistoryView.overview ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    popOwned(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: _view == _HistoryView.overview,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _view == _HistoryView.rides) _showOverview();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0.025, 0),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                  child: _loading || _loadFailed
                      ? _buildLoadState()
                      : _view == _HistoryView.overview
                          ? _buildOverview()
                          : _buildAllRides(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadState() => ListView(
    key: ValueKey<String>(_loading ? 'history-loading' : 'history-load-error'),
    padding: const EdgeInsets.all(24),
    children: [
      if (_loading) const LinearProgressIndicator(),
      const SizedBox(height: 16),
      Semantics(
        liveRegion: true,
        child: Text(
          _loading ? 'Loading ride history…' : 'Could not load ride history.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 14),
        ),
      ),
      if (!_loading)
        Center(
          child: TextButton(
            key: const ValueKey<String>('history-retry'),
            onPressed: _loadHistory,
            child: const Text('Retry'),
          ),
        ),
    ],
  );

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 9),
      child: Row(
        children: [
          Material(
            color: Colors.white,
            shape: const CircleBorder(side: BorderSide(color: _line)),
            child: IconButton(tooltip: 'Back', 
              onPressed: _view == _HistoryView.rides
                  ? _showOverview
                  : _closeHistory,
              icon: _solarIcon(AppAssets.solarAltArrowLeft, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Column(
                key: ValueKey<_HistoryView>(_view),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _view == _HistoryView.overview
                        ? 'Earnings & history'
                        : 'All rides',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.45,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _view == _HistoryView.overview
                        ? 'Your Movera activity'
                        : _periodLabel,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_view == _HistoryView.rides)
            Container(
              height: 36,
              width: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _tile,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _solarIcon(AppAssets.solarTuning2),
            ),
        ],
      ),
    );
  }

  Widget _buildOverview() {
    final visibleRideCount = _periodRidesList.length;

    return ListView(
      key: const ValueKey<String>('history-overview'),
      padding: const EdgeInsets.fromLTRB(14, 7, 14, 28),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildPeriodSelector(),
        const SizedBox(height: 14),
        _buildEarningsHero(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: AppAssets.solarClockCircle,
                label: 'Online',
                value: _periodHours,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                icon: AppAssets.solarCar,
                label: 'Rides',
                value: _periodRides,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'Earnings breakdown',
          style: TextStyle(
            color: _ink,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 9),
        _buildBreakdownCard(),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Latest rides',
                style: TextStyle(
                  color: _ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            TextButton(
              key: const ValueKey<String>('history-all-rides-button'),
              onPressed: _showAllRides,
              style: TextButton.styleFrom(
                foregroundColor: _ink,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'All rides',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 3),
                  _solarIcon(AppAssets.solarAltArrowRight, size: 14),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        if (_periodRidesList.isEmpty)
          const Padding(padding: EdgeInsets.all(18), child: Text('No completed rides in this period.')),
        for (final ride in _periodRidesList.take(2)) ...[
          _HistoryRideCard(ride: ride, compact: true),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            key: const ValueKey<String>('history-view-all-rides'),
            onPressed: _showAllRides,
            icon: _solarIcon(AppAssets.solarList),
            label: Text('View all $visibleRideCount rides'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _ink,
              side: const BorderSide(color: _line),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAllRides() {
    final groups = <String, List<_HistoryRide>>{};
    for (final ride in _periodRidesList) {
      groups.putIfAbsent(ride.day, () => <_HistoryRide>[]).add(ride);
    }

    return ListView(
      key: const ValueKey<String>('history-all-rides'),
      padding: const EdgeInsets.fromLTRB(14, 7, 14, 28),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildPeriodSelector(),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _line),
          ),
          child: Row(
            children: [
              _solarIcon(AppAssets.solarBillList),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$_periodRides rides in $_periodLabel',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                _periodEarnings,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
            child: Text(
              entry.key,
              style: const TextStyle(
                color: _muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          for (final ride in entry.value) ...[
            _HistoryRideCard(ride: ride),
            const SizedBox(height: 9),
          ],
          const SizedBox(height: 5),
        ],
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _tile,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _PeriodButton(
            label: 'Today',
            selected: _period == _HistoryPeriod.today,
            onTap: () => setState(() => _period = _HistoryPeriod.today),
          ),
          _PeriodButton(
            label: 'Week',
            selected: _period == _HistoryPeriod.week,
            onTap: () => setState(() => _period = _HistoryPeriod.week),
          ),
          _PeriodButton(
            label: 'Month',
            selected: _period == _HistoryPeriod.month,
            onTap: () => setState(() => _period = _HistoryPeriod.month),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsHero() {
    return TweenAnimationBuilder<double>(
      key: ValueKey<_HistoryPeriod>(_period),
      tween: Tween<double>(begin: 0.96, end: 1),
      duration: const Duration(milliseconds: 330),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            Container(
              height: 48,
              width: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _tile,
                borderRadius: BorderRadius.circular(16),
              ),
              child: _solarIcon(AppAssets.solarWallet, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _periodLabel,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _periodEarnings,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 27,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Recorded fares',
                    style: TextStyle(
                      color: _subtle,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 38,
              width: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: _line),
              ),
              child: _solarIcon(AppAssets.solarGraphUp),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          _BreakdownRow(label: 'Recorded fares', value: _periodEarnings, strong: true),
          const SizedBox(height: 10),
          _buildOtherEarningsRow(),
          const SizedBox(height: 10),
          const _BreakdownRow(label: 'Tips and fees', value: 'Not available'),
        ],
      ),
    );
  }

  /// R8-4: the cash trips' balance; tap for each trip and the total.
  Widget _buildOtherEarningsRow() {
    final trips = _periodCashTrips;
    final balance = _periodCashBalance;
    return InkWell(
      key: const ValueKey<String>('history-other-earnings'),
      onTap: () => showCashBalanceSheet(context, trips),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Expanded(
            child: _BreakdownRow(
              label: trips.isEmpty
                  ? 'Other earnings'
                  : 'Other earnings · ${trips.length} cash',
              value: CashBalance.signed(balance),
              valueColor: CashBalanceSheet.colorFor(balance.minorUnits),
            ),
          ),
          const SizedBox(width: 4),
          _solarIcon(AppAssets.solarAltArrowRight, size: 14, color: _muted),
        ],
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 7,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? const Color(0xFF1F2933)
                  : const Color(0xFF7C868D),
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFECEEF0)),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F5F6),
              borderRadius: BorderRadius.circular(11),
            ),
            child: _solarIcon(icon),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF7C868D),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1F2933),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.value,
    this.strong = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: strong
                  ? const Color(0xFF1F2933)
                  : const Color(0xFF7C868D),
              fontSize: strong ? 12.5 : 11.5,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? const Color(0xFF1F2933),
            fontSize: strong ? 13 : 11.5,
            fontWeight: strong ? FontWeight.w900 : FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _HistoryRideCard extends StatelessWidget {
  const _HistoryRideCard({
    required this.ride,
    this.compact = false,
  });

  final _HistoryRide ride;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          pushSingle(context,
            MaterialPageRoute<void>(
              builder: (_) => DriverRideHistoryDetail(
                record: ride.record,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(17),
        child: Container(
      key: ValueKey<String>(ride.id),
      padding: EdgeInsets.fromLTRB(
        12,
        compact ? 10 : 12,
        12,
        compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFECEEF0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: compact ? 34 : 38,
                width: compact ? 34 : 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F5F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _solarIcon(AppAssets.solarCar),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${ride.pickup} → ${ride.dropoff}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1F2933),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${ride.category} · ${ride.duration} · ${ride.distance}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF7C868D),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    ride.earnings,
                    style: const TextStyle(
                      color: Color(0xFF1F2933),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  // Q16/Q18: the earnings have Movera's bonus in them.
                  if (ride.status == TripStatus.completed &&
                      ride.record.driverBonus != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      WaybillRecord.bonusNote(ride.record.driverBonus!),
                      key: ValueKey<String>('history-row-bonus-${ride.id}'),
                      style: const TextStyle(
                        color: Color(0xFF7C868D),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    ride.time,
                    style: const TextStyle(
                      color: Color(0xFF7C868D),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 9),
            Row(
              children: [
                const SizedBox(
                  height: 6,
                  width: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFF9AA3A8),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  ride.status == TripStatus.completed ? 'Completed' : ride.status.isReleasedToDispatch ? 'cancelled_by_driver' : ride.status.wireName,
                  style: TextStyle(
                    color: Color(0xFF5F6B72),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
        ),
      ),
    );
  }
}

class _HistoryRide {
  const _HistoryRide({
    required this.record,
    required this.id,
    required this.day,
    required this.time,
    required this.category,
    required this.pickup,
    required this.dropoff,
    required this.distance,
    required this.duration,
    required this.earnings,
    this.completedAt,
    this.status=TripStatus.completed,
    this.fareMoney,
  });

  final TripHistoryRecord record;
  final String id;
  final String day;
  final String time;
  final String category;
  final String pickup;
  final String dropoff;
  final String distance;
  final String duration;
  final String earnings;
  final DateTime? completedAt;
  final TripStatus status;
  final Money? fareMoney;
}

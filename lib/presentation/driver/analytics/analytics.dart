import 'package:movera/widgets/owned_route_exit.dart';
import 'package:movera/widgets/single_route_entry.dart';
import 'package:flutter/material.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/presentation/driver/analytics/acceptance%20rate/acceptance_rate.dart';
import 'package:movera/presentation/driver/analytics/cancelation%20rate/cancelation_rate.dart';
import 'package:movera/presentation/driver/earning%20stats/earning_stats.dart';
import 'package:movera/widgets/movera_line_icon.dart';
import 'package:movera/widgets/navigation_transition.dart';

class Analytics extends StatelessWidget {
  const Analytics({super.key});

  static const Color _ink = Color(0xFF252E3A);
  static const Color _muted = Color(0xFF7D898F);
  static const Color _line = Color(0xFFE6E8EA);

  /// The same sample numbers as the Home performance sheet.
  static const DriverPerformanceConfig _sample = DriverPerformanceConfig.sample;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F7),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(tooltip: 'Back', 
          onPressed: () => maybePopOwned(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
        ),
        titleSpacing: 0,
        title: const Text(
          'Analytics preview',
          style: TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _line),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DEMO DATA',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '183,25 kr',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Sample: 3 rides completed',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            child: const Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sample last trip',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Central Station → Södermalm',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Comfort · 21:42',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '126 kr',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _demand(const DriverHomeAdminContentService().load().stockholmWork),
          const SizedBox(height: 16),
          const Text(
            'Sample performance',
            style: TextStyle(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _metric('Rating', _sample.ratingLabel),
              const SizedBox(width: 8),
              _metric('Acceptance', _sample.acceptanceLabel),
              const SizedBox(width: 8),
              _metric('Cancel', _sample.cancellationLabel),
            ],
          ),
          const SizedBox(height: 16),
          _link(
            context,
            title: 'Earnings',
            detail: 'Same period as the home sheet',
            page: const EarningStatsScreen(),
          ),
          const SizedBox(height: 8),
          _link(
            context,
            title: 'Acceptance rate',
            detail: 'Sample · ${_sample.acceptanceLabel} of offers accepted',
            page: const AcceptanceRate(),
          ),
          const SizedBox(height: 8),
          _link(
            context,
            title: 'Cancellation rate',
            detail: 'Sample · ${_sample.cancellationLabel} of accepted trips',
            page: const CancelationRate(),
          ),
        ],
      ),
    );
  }

  Widget _demand(StockholmWorkStatsConfig stats) {
    final strongest = stats.innerAreas.reduce(
      (current, next) =>
          next.demandPercent > current.demandPercent ? next : current,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF173F32), Color(0xFF245845)],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const MoveraLineIcon(
                  mark: MoveraMark.trend,
                  color: Color(0xFFBCE7D2),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sample strongest area',
                      style: TextStyle(
                        color: Color(0xFFBFD5CC),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      strongest.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEBF7F1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${strongest.demandPercent}%',
                  style: const TextStyle(
                    color: Color(0xFF176F52),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final area in stats.innerAreas) ...[
          _areaRow(area),
          const SizedBox(height: 8),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F8F6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE1EBE6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 28,
                    width: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFDFE9E4)),
                    ),
                    child: const MoveraLineIcon(
                      mark: MoveraMark.explore,
                      size: 15,
                      color: Color(0xFF1C242C),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    stats.surroundingTitle,
                    style: const TextStyle(
                      color: Color(0xFF22312D),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  )),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final area in stats.surroundingAreas) _chip(area),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _areaRow(StockholmAreaConfig area) {
    final busy = area.demandPercent >= 75;
    final accent = busy ? const Color(0xFF1C7D5B) : const Color(0xFF67A98C);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 8,
                width: 8,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  area.name,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Flexible(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: busy ? const Color(0xFFE8F5EF) : const Color(0xFFF3F5F4),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  area.demandLabel,
                  style: TextStyle(
                    color: busy ? const Color(0xFF155F47) : const Color(0xFF737F7A),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )),
              const SizedBox(width: 8),
              Flexible(child: Text(
                '${area.demandPercent}%',
                style: const TextStyle(
                  color: _ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              )),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: area.demandPercent / 100,
              minHeight: 5,
              backgroundColor: const Color(0xFFE6ECE9),
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(StockholmAreaConfig area) {
    final status = area.demandLabel.toLowerCase();
    final isBusy = status == 'busy';
    final isQuiet = status == 'quiet';
    final accent = isBusy
        ? const Color(0xFF167653)
        : isQuiet
            ? const Color(0xFF98A49F)
            : const Color(0xFF65A98B);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: BoxDecoration(
        color: isBusy ? const Color(0xFFE8F5EF) : const Color(0xFFF7FBFA),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFFDCE9E3)),
      ),
      child: Text(
        '${area.name}  ${area.demandPercent}%',
        style: TextStyle(
          color: accent,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: _ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: child,
    );
  }

  Widget _link(
    BuildContext context, {
    required String title,
    required String detail,
    required Widget page,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => pushSingle(context, RightToLeftTransition(page)),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _line),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFB0B8BC)),
            ],
          ),
        ),
      ),
    );
  }
}

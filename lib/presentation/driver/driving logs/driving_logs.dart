import 'package:movera/widgets/live_soon_notice.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:flutter/material.dart';

class DrivingLogs extends StatelessWidget {
  const DrivingLogs({super.key});

  static const Color _ink = Color(0xFF252E3A);
  static const Color _muted = Color(0xFF7D898F);
  static const Color _line = Color(0xFFE6E8EA);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F7),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: tr.back,
          onPressed: () => maybePopOwned(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
        ),
        titleSpacing: 0,
        title: Text(
          LiveDriverServices.active ? tr.drivingLogs : tr.logsPreview,
          style: TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: LiveDriverServices.active
          // Audit 2026-11-01: no example hours on a live build.
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [LiveSoonNotice(message: tr.liveDrivingLogsSoon)],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr.demoDataBadge,
                        style: TextStyle(
                          color: _muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '6 h 26 min',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr.logsSampleNotLive,
                        style: TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: const LinearProgressIndicator(
                          minHeight: 4,
                          value: 0.75,
                          backgroundColor: Color(0xFFE8EBED),
                          valueColor: AlwaysStoppedAnimation<Color>(_ink),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  tr.logsSampleWeek,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                _shift(
                  tr.monday,
                  '5 h 10 min',
                  tr.logsOnlineFromTo('07:12', '12:22'),
                ),
                _shift(
                  tr.tuesday,
                  '6 h 40 min',
                  tr.logsOnlineFromTo('06:48', '13:28'),
                ),
                _shift(
                  tr.wednesday,
                  '4 h 05 min',
                  tr.logsOnlineFromTo('15:10', '19:15'),
                ),
                _shift(tr.thursday, '6 h 26 min', tr.logsSampleOnlineState),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _line),
                  ),
                  child: Text(
                    tr.logsDemoCompliance,
                    style: TextStyle(
                      color: _muted,
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _shift(String day, String hours, String detail) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: _ink,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13,
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
          Flexible(
            child: Text(
              hours,
              style: const TextStyle(
                color: _ink,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

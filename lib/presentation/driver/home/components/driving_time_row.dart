import 'package:movera/core/l10n/driver_l10n.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:movera/widgets/movera_radar_orb.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';
import 'package:movera/core/session/driving_time_clock.dart';
import 'package:movera/widgets/driving_time_gauge.dart';

/// Driving time row: the small stopwatch, time left before the rest (or
/// "Rest until 04:30") and the seconds running while Radar is on.
class DrivingTimeRow extends StatefulWidget {
  const DrivingTimeRow({
    super.key,
    required this.clock,
    required this.running,
    required this.onTap,
  });

  final DrivingTimeClock clock;
  final bool running;
  final VoidCallback onTap;

  @override
  State<DrivingTimeRow> createState() => _DrivingTimeRowState();
}

class _DrivingTimeRowState extends State<DrivingTimeRow> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _syncTick();
  }

  @override
  void didUpdateWidget(DrivingTimeRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.running != widget.running) {
      _syncTick();
    }
  }

  void _syncTick() {
    _tick?.cancel();
    _tick = widget.running
        ? Timer.periodic(const Duration(seconds: 1), (_) {
            if (mounted) {
              setState(() {});
            }
          })
        : null;
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clock = widget.clock;
    const sub = Color(0xFF80888E);
    return InkWell(
      key: const ValueKey<String>('home-sheet-driving-time'),
      onTap: widget.onTap,
      child: SizedBox(
        height: 72,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Center(
                  child: DrivingTimeGauge(used: clock.usedFraction, size: 28),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  switch (clock.restUntil) {
                    final until? => tr.restUntilTime(clockLabel(until)),
                    null => tr.timeLeftToDrive(
                      DrivingTimeClock.hoursMinutes(clock.left),
                    ),
                  },
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF3A4247),
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.running
                      ? MoveraRadarOrb.onlineGreen
                      : const Color(0xFFB6BDC2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                widget.running
                    ? DrivingTimeClock.clock(clock.worked)
                    : tr.paused,
                style: const TextStyle(
                  color: sub,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

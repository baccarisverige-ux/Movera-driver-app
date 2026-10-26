import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:flutter/material.dart';
import 'package:movera/presentation/driver/home/components/radar_hold_off.dart';
import 'package:movera/widgets/movera_radar_orb.dart';

/// The next-trip radar at the bottom middle of the trip sheet: the Home
/// radar (as when the Home sheet is fully up), a third smaller. Holding it
/// for a second stops next-trip offers; holding it again starts them.
class TripRadarDock extends StatefulWidget {
  const TripRadarDock({super.key, required this.on, required this.onToggle});

  /// Next-trip offers are on.
  final bool on;
  final VoidCallback onToggle;

  /// Home's radar is 104; this one is 33% smaller.
  static const double size = 70;

  @override
  State<TripRadarDock> createState() => _TripRadarDockState();
}

class _TripRadarDockState extends State<TripRadarDock>
    with TickerProviderStateMixin {
  // Same rhythm as the Home radar.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
      _sweep.stop();
    } else {
      if (!_pulse.isAnimating) {
        _pulse.repeat(reverse: true);
      }
      if (!_sweep.isAnimating) {
        _sweep.repeat();
      }
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.on;
    return Center(
      child: RadarHoldOff(
        // A new hold ring each time the state flips.
        key: ValueKey<String>(
          on ? 'trip-radar-dock-on' : 'trip-radar-dock-off',
        ),
        holdKey: const ValueKey<String>('trip-radar-hold'),
        semanticsLabel: on ? tr.holdToStopNextTrips : tr.holdToStartNextTrips,
        size: TripRadarDock.size,
        onConfirmed: widget.onToggle,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulse, _sweep]),
          builder: (context, _) => MoveraRadarOrb(
            title: tr.hold,
            status: on ? tr.orbOff : tr.orbOn,
            subtitle: on ? tr.stopRadar : tr.startRadar,
            active: on,
            pulse: _pulse.value,
            sweep: on ? _sweep.value : 0,
            size: TripRadarDock.size,
            touchKey: const ValueKey<String>('trip-radar-dock-orb'),
          ),
        ),
      ),
    );
  }
}

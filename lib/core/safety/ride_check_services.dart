import 'package:flutter/widgets.dart';
import 'package:movera/core/admin/ride_check_admin_config.dart';
import 'package:movera/core/safety/demo_safety_alert_repository.dart';
import 'package:movera/core/safety/ride_check.dart';
import 'package:movera/core/safety/ride_check_log.dart';
import 'package:movera/core/safety/ride_check_recorder.dart';
import 'package:movera/core/safety/safety_alert_repository.dart';
import 'package:url_launcher/url_launcher.dart';

/// What a Ride check needs from outside the trip screen. The composition
/// root provides it with [RideCheckScope]; tests inject their own.
class RideCheckServices {
  RideCheckServices({
    required this.alerts,
    required this.log,
    RideCheckRules? rules,
    RideCheckRecorder Function()? recorder,
    Future<bool> Function(Uri uri)? launch,
    this.hardStops,
    DateTime Function()? now,
  }) : _rules = rules,
       createRecorder = recorder ?? createRideCheckRecorder,
       launch = launch ?? launchUrl,
       now = now ?? DateTime.now;

  final SafetyAlertRepository alerts;
  final RideCheckLog log;
  final RideCheckRules? _rules;

  /// Read when a trip starts, so admin changes reach the next trip.
  RideCheckRules get rules =>
      _rules ?? RideCheckRules.fromAdmin(RideCheckAdminConfig.current);
  final RideCheckRecorder Function() createRecorder;

  /// Opens the phone dialer with tel:112. The person calls; Movera never does.
  final Future<bool> Function(Uri uri) launch;

  /// Possible-crash hook: a motion sensor adapter adds an event for each very
  /// hard stop. No sensor package is connected yet, so this is usually null
  /// and the demo tools open the crash card instead.
  final Stream<DateTime>? hardStops;
  final DateTime Function() now;

  static final Uri emergencyNumber = Uri(scheme: 'tel', path: '112');

  static RideCheckServices? _fallback;

  /// Used when no [RideCheckScope] is above the trip screen.
  static RideCheckServices get fallback => _fallback ??= RideCheckServices(
    alerts: DemoSafetyAlertRepository(),
    log: PrefsRideCheckLog(),
  );
}

class RideCheckScope extends InheritedWidget {
  const RideCheckScope({
    super.key,
    required this.services,
    required super.child,
  });

  final RideCheckServices services;

  /// Without registering a dependency: services live as long as the app.
  static RideCheckServices? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<RideCheckScope>()?.services;

  @override
  bool updateShouldNotify(RideCheckScope oldWidget) =>
      oldWidget.services != services;
}

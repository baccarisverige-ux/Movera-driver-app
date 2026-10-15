import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';
import 'package:movera/core/session/driver_runtime_config.dart';

/// Widget tests run without GPS hardware, network routing or an activated
/// demo account. These are explicit test policies, not binding detection.
const testRuntimeConfig = DriverRuntimeConfig(
  simulatedArrival: true,
  externalRouting: false,
  skipAccountActivation: true,
  liveMapTicker: false,
  reservationPopup: false,
  islandHint: false,
);

/// The scheduled-ride day follows the test's fake time: widget tests move
/// it with `pump`. Outside a widget test it stands still at the time the
/// fake clock starts from, so plain tests get the same day every run.
DateTime _testNow() {
  try {
    final binding = WidgetsBinding.instance;
    if (binding is AutomatedTestWidgetsFlutterBinding && binding.inTest) {
      return binding.clock.now();
    }
  } catch (_) {
    // No binding yet: a plain test.
  }
  return DateTime.utc(2015);
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  DriverRuntimeConfig.current = testRuntimeConfig;
  ScheduledClock.realNow = _testNow;
  // Every test starts the demo day again (07:00 at its first reading).
  setUp(ScheduledClock.instance.reset);
  await testMain();
}

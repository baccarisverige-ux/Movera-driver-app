import 'dart:async';

import 'package:movera/core/legal/driver_legal.dart';
import 'package:movera/core/live/live_driver_services.dart';

/// The app came back on screen (main.dart's `AppLifecycleListener`): the
/// live services and the country's legal texts. One function, so the
/// resume request budget (test/perf/request_budget) runs what the app runs.
void driverAppResumed({
  required LiveDriverServices live,
  required DriverLegal legal,
}) {
  live.resumed();
  // G27: not again when read in the last minute.
  unawaited(legal.refreshIfStale());
}

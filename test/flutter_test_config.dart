import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/documents/document_expiry.dart';
import 'package:movera/core/notifications/driver_notifications.dart';
import 'package:movera/core/ride/waiting_rules.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/session/driving_time_clock.dart';
import 'package:movera/core/vehicle/ride_categories.dart';

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
  // The app runs on the real clock and books its demo reservations from
  // now. Tests run the fast test day instead: 07:00 at the first reading,
  // 30 times faster, with the rides at 07:40, 08:05 and 09:30.
  ScheduledClock.instance = ScheduledClock.fastDay();
  DemoReservations.plan = DemoReservationPlan.testDay;
  // Every test starts the demo day again (07:00 at its first reading),
  // with cash rides on, no missed Exclusive offers and the zone's waiting
  // terms. The account is quiet: no driving time yet, no documents that
  // run out, no notifications, every allowed category on and the app's
  // own texts.
  setUp(() {
    ScheduledClock.instance.reset();
    DriverOfferPreferences.reset();
    WaitingTerms.active = WaitingRules.current.base;
    DrivingTimeClock.instance.reset();
    DocumentExpiryStore.instance.load(const <TrackedDocument>[]);
    DriverNotificationFeed.instance
      ..load(const <DriverNotice>[])
      ..arrivals = const [];
    DriverCategoryChoice.reset();
    DriverAppTexts.reset();
  });
  await testMain();
}

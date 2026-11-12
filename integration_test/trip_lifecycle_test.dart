import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/common.dart';
import 'package:integration_test/integration_test.dart';
import 'package:movera/core/session/driver_runtime_config.dart';

import 'staging/check_log.dart';
import 'staging/session.dart';
import 'staging/trip_run.dart';

/// Owner 2026-11-12 ("U can't make all trip lifecycle test on firebase?"):
/// one whole trip on a real Test Lab phone against staging. The driver app
/// runs on the phone; the rider is played over HTTP by the test with one
/// big-test rider (se.r35, fallback se.r36) handed over at run time.
///
/// Live scenario (testlab_test `trip-lifecycle`): SIGN-IN, ONLINE,
/// RIDER-SIGN-IN, BOOK, OFFER, ACCEPT, SWITCH-1, WAYBILL-DURING, ARRIVE,
/// START, CHAT, CALL, SWITCH-2, SOS, RIDE-CHECK, DROPOFF, PAY, RATE,
/// WAYBILL-AFTER, RIDER, HISTORY, CLEANUP, OFFLINE, and for every screen
/// change `TRANSITION:<name>:SMOOTH` / RELOAD / ERRORS.
///
/// Booked scenario (`trip-scheduled`, MOVERA_TL_SCENARIO=scheduled):
/// SCHED-CANCEL-BOOK, SCHED-CANCEL-OFFER, SCHED-CANCEL, SCHED-BOOK,
/// SCHED-OFFER, SCHED-LIST, SCHED-REMINDER, SCHED-LEAVE, then the same
/// trip steps without chat/call/SOS/ride check.
///
/// Numbers and the code come ONLY at run time (MainActivityTest copies the
/// instrumentation arguments into this process's environment); nothing is
/// built into the APK. They are never printed.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Real frames at the display's pace (the frame checks measure them).
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  final phone = tlEnv('MOVERA_TL_PHONE');
  final code = tlEnv('MOVERA_TL_CODE');
  final riderPhone = tlEnv('MOVERA_TL_RIDER_PHONE');
  final scheduled = tlEnv('MOVERA_TL_SCENARIO') == 'scheduled';
  final live = DriverRuntimeConfig.current.authRequired;
  final name = scheduled ? 'booked ride lifecycle' : 'trip lifecycle';

  // Run 6 (2026-11-12): a test that times out (or hangs) is recorded
  // nowhere by the integration_test binding, so JUnit said "OK (0 tests)"
  // and Test Lab "Passed". Tear-downs run last-in-first-out, so this one
  // (registered after ensureInitialized) runs before the binding's own
  // `allTestsFinished`: JUnit then shows 1 test, 1 failure.
  var bodyDone = false;
  var bodyStarted = false;
  tearDownAll(() {
    if (bodyStarted && !bodyDone && binding.results[name] is! Failure) {
      binding.results[name] = Failure(
        name,
        'test body did not finish (timeout or hang)',
      );
    }
  });

  final String? skipReason = !live
      ? 'not a live build (MOVERA_AUTH_REQUIRED is off)'
      : phone == null || code == null || riderPhone == null
      ? 'no test driver / rider number at run time (the workflow passes '
            'them from the MOVERA_TEST_NUMBERS secret)'
      : null;

  if (skipReason != null) {
    testWidgets('trip lifecycle SKIPPED: $skipReason', (tester) async {
      CheckLog.say('SKIP all checks: $skipReason');
    });
    return;
  }

  testWidgets(
    name,
    (tester) async {
      bodyStarted = true;
      final log = CheckLog(
        binding: binding,
        outDir: tlEnv('MOVERA_TL_OUT'),
        shots: tlEnv('MOVERA_TL_SHOTS') != '0',
      );
      final run = TripRun(tester, log, scheduled: scheduled);
      try {
        await run.start();
        await run.all(phone: phone!, code: code!, riderPhone: riderPhone!);
      } finally {
        // SUMMARY / SUMMARY-JSON / summary.json, then the END line (once:
        // the watchdog may have written them already).
        await run.writeResults();
      }
      final failed = log.failures;
      expect(
        failed,
        isEmpty,
        reason: [
          for (final f in failed) '${f.id} (${f.title}): ${f.detail}',
        ].join('\n'),
      );
      bodyDone = true;
    },
    // The order of the stops (run 6): hard stop 15 min (TripRun.hardAfter)
    // -> watchdog 15 min 45 s (TripRun.watchAfter, only when a pump hung)
    // -> clean-up done by about 17 min 30 s (TripRun.cleanupBudget) -> this
    // test timeout 18 min (TripRun.testLimit) -> Test Lab --timeout 25 min
    // (install and start count too, ~1 min).
    timeout: const Timeout(TripRun.testLimit),
  );
}

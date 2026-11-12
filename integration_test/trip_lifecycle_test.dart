import 'package:flutter_test/flutter_test.dart';
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
    scheduled ? 'booked ride lifecycle' : 'trip lifecycle',
    (tester) async {
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
        await log.write(
          requestLog: [for (final c in run.rec.calls) '$c'],
          extra: {'transitions': run.watch.rows},
        );
      }
      final failed = log.failures;
      expect(
        failed,
        isEmpty,
        reason: [
          for (final f in failed) '${f.id} (${f.title}): ${f.detail}',
        ].join('\n'),
      );
    },
    // Test Lab --timeout is 20m: sign-in, ~3 min of driving, the ride
    // check's 2-minute stop and the clean-up fit with room.
    timeout: const Timeout(Duration(minutes: 18)),
  );
}

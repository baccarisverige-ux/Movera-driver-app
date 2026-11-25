import 'package:movera/core/logging/crash_breadcrumbs.dart';
import 'package:movera/core/logging/crash_catcher.dart';
import 'package:movera/core/logging/crash_files.dart';
import 'package:movera/core/logging/crash_reports.dart';
import 'package:movera/core/logging/driver_log.dart';

/// Owner 2026-11-24 "Add to admin all kind of crash" (contract v0.18.158
/// `contract.json#crashCatcher`): starts the crash catcher of a live build
/// next to its [reports] sink: the unclean end of the last run is reported,
/// the running marker and the freeze watch start, the main isolate's own
/// errors are listened to and reports a previous run could not send go
/// again. The zone's `crashReports.on` comes with the driver document
/// (LiveDriverConfig, [CrashCatcher.acceptSwitch]).
Future<void> startDriverCrashCatcher(CrashReportSink reports) async {
  try {
    final files = await openCrashFiles();
    // No support folder outside the web (no path_provider: a widget test):
    // nothing to keep a marker in, so no catcher (and no freeze timer).
    if (files == null && crashMarkerSupported) return;
    final catcher = CrashCatcher(
      files: files ?? MemoryCrashFiles(),
      markerSupported: files != null && crashMarkerSupported,
      appVersion: reports.appVersion,
      build: reports.build,
      send: (event) => reports.report(
        event.message,
        StackTrace.fromString(event.stack),
        kind: event.kind,
        screen: event.screen,
        nativeReason: event.nativeReason,
        freezeMs: event.freezeMs,
        breadcrumbs: event.breadcrumbs,
        extra: {
          for (final e in event.extra.entries)
            if (e.value is String) e.key: e.value! as String,
        },
      ),
    );
    CrashCatcher.instance = catcher;
    CrashReports.context = catcher.context;
    if (files != null) reports.outbox = catcher.outbox;
    reports.resendOutbox();
    catcher.start();
    listenToIsolateErrors(
      (error, stack) => DriverLog.crash('Uncaught isolate error', error, stack),
    );
    CrashBreadcrumbs.instance.add('lifecycle', 'start');
  } catch (_) {
    // The catcher must never stop the app.
  }
}

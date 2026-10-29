# R09 - Error routing seam

Source: deep re-audit of 2 October 2026 (N22).

- `DriverLog` emits `DriverLogRecord`s to a replaceable `DriverLog.sink`. The default still prints to the console.
- `installGlobalErrorHooks()` (called in `main`) routes `FlutterError.onError` and `PlatformDispatcher.onError` into `DriverLog` and keeps any previous handler.

## Not done

No crash-reporting vendor (Sentry, Crashlytics) is added. That needs an account, a DSN secret, a consent decision and a privacy notice update. Write the vendor adapter as a `DriverLogSink` that scrubs rider names, phones and addresses, and enable it only after consent.

## Crash reports (contract v0.16.0, 29 Oct 2026)

Owner: "Add automatic and add this in term and condition". A live build (`MOVERA_AUTH_REQUIRED=true`) wraps `DriverLog.sink` in `CrashReportSink` (`lib/core/logging/crash_reports.dart`): uncaught errors (`DriverLog.crash`, from `installGlobalErrorHooks`) go out as `kind: crash`, `DriverLog.error` with an error object as `kind: error`, to `POST /api/v1/telemetry/crashes` with app, platform, appVersion, build, screen (top route name), occurredAt and the driver's token. Phones, e-mails, coordinates and personal JSON fields are scrubbed on the phone; at most 16 KB; one request at a time from a bounded queue; repeats within a minute are counted, not sent; offline, 5xx or 429 retried later with backoff. No switch; the Terms of service carry the clause. No vendor SDK.

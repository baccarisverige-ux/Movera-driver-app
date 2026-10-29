import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:movera/core/logging/driver_log.dart';

/// The running build's version (`pubspec` `version`, e.g. `1.0.0+1`), passed
/// by the live build with `--dart-define=MOVERA_APP_VERSION=...`; `dev` in
/// local and check builds.
const driverAppVersion = String.fromEnvironment(
  'MOVERA_APP_VERSION',
  defaultValue: 'dev',
);

/// Crash and error reports to `POST /api/v1/telemetry/crashes` (contract
/// v0.16.0 §11, `contract.json#telemetry.crashReport`).
///
/// Owner 2026-10-29: "Add automatic and add this in term and condition":
/// reports go out on their own in a live build; there is no switch. Rider
/// names, phone numbers, e-mails, addresses and coordinates are scrubbed
/// here before anything leaves the phone (the server scrubs again).
///
/// The sink never blocks or crashes the app: each report is one small
/// fire-and-forget request from a bounded queue, one at a time; the same
/// crash again within [burstWindow] is only counted; a report that could
/// not be delivered (offline, 5xx, 429) waits and is tried again later.
class CrashReportSink {
  CrashReportSink({
    required this.baseUri,
    required http.Client client,
    this.accessToken,
    this.app = 'driver',
    this.appVersion,
    this.build,
    this.platform,
    this.next,
    this.queueLimit = 30,
    this.burstWindow = const Duration(minutes: 1),
    this.retryDelay = const Duration(seconds: 30),
    this.maxRetryDelay = const Duration(minutes: 10),
    this.maxAttempts = 6,
    DateTime Function()? clock,
  }) : _client = client,
       _clock = clock ?? DateTime.now;

  final Uri baseUri;
  final http.Client _client;
  final DateTime Function() _clock;

  /// The signed-in driver's access token, as every other call sends it.
  final Future<String?> Function()? accessToken;

  final String app;
  final String? appVersion;
  final String? build;
  final String? platform;

  /// The sink that was there before (the console); every record still goes
  /// to it.
  final DriverLogSink? next;

  final int queueLimit;
  final Duration burstWindow;
  final Duration retryDelay;
  final Duration maxRetryDelay;
  final int maxAttempts;

  static const path = '/api/v1/telemetry/crashes';

  final List<_Report> _pending = [];
  final Map<String, DateTime> _recent = {};
  bool _inFlight = false;
  bool _disposed = false;
  Timer? _retry;
  int _failures = 0;

  int get sentCount => _sent;
  int _sent = 0;
  int get droppedCount => _dropped;
  int _dropped = 0;
  int get repeatedCount => _repeated;
  int _repeated = 0;
  int get pendingCount => _pending.length;

  /// A [DriverLogSink]: `DriverLog.sink = reports.call`.
  void call(DriverLogRecord record) {
    try {
      next?.call(record);
    } catch (_) {}
    if (record.level != DriverLogLevel.error || record.error == null) return;
    report(
      record.error!,
      record.stack ?? StackTrace.empty,
      kind: record.fatal ? CrashReports.kindCrash : CrashReports.kindError,
      message: record.message,
    );
  }

  void report(
    Object error,
    StackTrace stack, {
    String kind = CrashReports.kindCrash,
    String? message,
    String? screen,
  }) {
    if (_disposed) return;
    try {
      final now = _clock();
      final body = CrashReports.body(
        error: error,
        stackTrace: stack,
        extra: {if (message != null) 'message': message},
        app: app,
        platform: platform,
        appVersion: appVersion,
        build: build,
        screen: screen ?? CrashReports.currentScreen,
        kind: kind,
        occurredAt: now,
      );
      final key = CrashReports.fingerprint(
        kind,
        body['error']! as String,
        body['stack']! as String,
      );
      _recent.removeWhere((_, at) => now.difference(at) >= burstWindow);
      if (_recent.containsKey(key)) {
        _repeated += 1;
        return;
      }
      if (_recent.length >= 100) _recent.clear();
      _recent[key] = now;
      _pending.add(_Report(body));
      while (_pending.length > queueLimit) {
        _pending.removeAt(0);
        _dropped += 1;
      }
      _drain();
    } catch (_) {
      // A crash report must never crash the app.
    }
  }

  void _drain() {
    if (_inFlight || _pending.isEmpty || _disposed || _retry != null) return;
    final report = _pending.removeAt(0);
    _inFlight = true;
    _sent += 1;
    var failed = false;
    unawaited(
      _send(report)
          .then((response) {
            final code = response.statusCode;
            failed = code >= 500 || code == 429;
          })
          .catchError((_) {
            failed = true;
          })
          .whenComplete(() {
            _inFlight = false;
            if (_disposed) return;
            if (failed) {
              _retryLater(report);
              return;
            }
            _failures = 0;
            _drain();
          }),
    );
  }

  Future<http.Response> _send(_Report report) async {
    String? token;
    try {
      token = await accessToken?.call();
    } catch (_) {
      token = null;
    }
    return _client
        .post(
          baseUri.resolve(path),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
          body: jsonEncode(report.body),
        )
        .timeout(const Duration(seconds: 10));
  }

  void _retryLater(_Report report) {
    report.attempts += 1;
    if (report.attempts >= maxAttempts) {
      _dropped += 1;
      _drain();
      return;
    }
    _pending.insert(0, report);
    while (_pending.length > queueLimit) {
      _pending.removeLast();
      _dropped += 1;
    }
    _failures += 1;
    var delay = retryDelay * (1 << (_failures - 1).clamp(0, 16));
    if (delay > maxRetryDelay) delay = maxRetryDelay;
    _retry = Timer(delay, () {
      _retry = null;
      _drain();
    });
  }

  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _retry = null;
    _pending.clear();
  }
}

class _Report {
  _Report(this.body);
  final Map<String, Object?> body;
  int attempts = 0;
}

/// The report body and the scrubbing it goes through.
abstract final class CrashReports {
  /// The server refuses a body over 16 KB (`TELEMETRY.maxBodyBytes`).
  static const maxBytes = 16 * 1024;

  /// `TelemetryCrash`: error at most 4000, stack at most 12000 characters.
  static const maxError = 4000;
  static const maxStack = 12000;

  static const kindCrash = 'crash';
  static const kindError = 'error';

  /// The route name on top, kept by the app's route observer.
  static String? currentScreen;

  /// `android`, `ios` or `web`; null elsewhere (the contract lists three).
  static String? platformName({bool isWeb = kIsWeb, TargetPlatform? platform}) {
    if (isWeb) return 'web';
    switch (platform ?? defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return null;
    }
  }

  /// `1.4.2+17` → version `1.4.2`, build `17`.
  static ({String version, String? build}) splitVersion(String raw) {
    final value = raw.trim();
    final plus = value.indexOf('+');
    if (plus == -1) return (version: value, build: null);
    final build = value.substring(plus + 1);
    return (
      version: value.substring(0, plus),
      build: build.isEmpty ? null : build,
    );
  }

  /// A route name with no ids, at most 80 characters.
  static String? cleanScreen(Object? raw) {
    if (raw is! String) return null;
    var value = raw.split('?').first.trim();
    value = value.replaceAll(
      RegExp(r'(?=[0-9a-fA-F-]*\d)[0-9a-fA-F-]{8,}|\d+'),
      ':id',
    );
    value = value.replaceAll(RegExp(r'[^A-Za-z0-9_:./ -]'), '').trim();
    if (value.isEmpty) return null;
    return value.length > 80 ? value.substring(0, 80) : value;
  }

  static final _email = RegExp(r'[\w.+-]+@[\w-]+(?:\.[\w-]+)+');
  static final _intlPhone = RegExp(r'\+\d[\d\s().-]{6,}\d');
  static final _nationalPhone = RegExp(
    r'(?<![\w.])0\d{1,3}[\s-]?\d{2,4}[\s-]?\d{2,4}(?:[\s-]?\d{2,4})?(?![\w.])',
  );
  static final _coordinate = RegExp(r'(?<![\w.])-?\d{1,3}\.\d{4,}(?![\w.])');

  /// Keys whose values are never sent (`riderName`, `pickupAddress`, ...).
  static final _personalKey = RegExp(
    r'name|phone|e-?mail|address|street|^lat|^lng|^lon|coord|token|password|'
    r'^(?:pin|otp|code)$',
    caseSensitive: false,
  );

  /// Replaces e-mails, phone numbers, precise coordinates and the values of
  /// personal JSON fields (`"riderName":"Anna"`) in free text.
  static String scrubText(String text) {
    String phone(Match m) {
      final digits = m[0]!.replaceAll(RegExp(r'\D'), '').length;
      return digits >= 8 && digits <= 15 ? '[phone]' : m[0]!;
    }

    return text
        .replaceAllMapped(
          RegExp(r'"([A-Za-z_]+)"\s*:\s*"[^"]*"'),
          (m) => _personalKey.hasMatch(m[1]!) ? '"${m[1]}":"[removed]"' : m[0]!,
        )
        .replaceAll(_email, '[email]')
        .replaceAllMapped(_intlPhone, phone)
        .replaceAllMapped(_nationalPhone, phone)
        .replaceAll(_coordinate, '[coord]');
  }

  static String _cut(String text, int max) =>
      text.length > max ? text.substring(0, max) : text;

  static String fingerprint(String kind, String error, String stack) {
    final firstFrame = stack
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
    final head = error.length > 200 ? error.substring(0, 200) : error;
    return '$kind|$head|$firstFrame';
  }

  /// The scrubbed body, cut to fit [maxBytes].
  static Map<String, Object?> body({
    required Object error,
    required StackTrace stackTrace,
    Map<String, String> extra = const {},
    required String app,
    String? platform,
    String? appVersion,
    String? build,
    String? screen,
    String kind = kindCrash,
    required DateTime occurredAt,
  }) {
    final cleanExtra = <String, Object?>{
      for (final e in extra.entries)
        if (!_personalKey.hasMatch(e.key)) e.key: scrubText(_cut(e.value, 500)),
    };
    var errorText = _cut(
      scrubText(_cut(DriverLog.scrub(error).toString(), maxError)),
      maxError,
    );
    var stack = _cut(
      scrubText(_cut(stackTrace.toString(), maxStack)),
      maxStack,
    );
    final version = appVersion == null ? null : _cut(appVersion, 40);
    final buildNo = build == null ? null : _cut(build, 40);
    final cleanName = cleanScreen(screen);
    Map<String, Object?> make() => {
      'error': errorText,
      'stack': stack,
      'extra': cleanExtra,
      'app': app,
      if (platform != null) 'platform': platform,
      if (version != null && version.isNotEmpty) 'appVersion': version,
      if (buildNo != null && buildNo.isNotEmpty) 'build': buildNo,
      if (cleanName != null) 'screen': cleanName,
      'kind': kind == kindError ? kindError : kindCrash,
      'occurredAt': occurredAt.toUtc().toIso8601String(),
    };
    var result = make();
    int size() => utf8.encode(jsonEncode(result)).length;
    while (size() > maxBytes && stack.isNotEmpty) {
      stack = stack.substring(0, stack.length ~/ 2);
      result = make();
    }
    while (size() > maxBytes && errorText.length > 64) {
      errorText = errorText.substring(0, errorText.length ~/ 2);
      result = make();
    }
    if (size() > maxBytes) {
      cleanExtra.clear();
      result = make();
    }
    return result;
  }
}

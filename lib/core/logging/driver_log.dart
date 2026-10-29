import 'package:flutter/foundation.dart';

enum DriverLogLevel { info, warn, error }

/// One structured log record. Messages must not contain rider names, phone
/// numbers or free text; trip IDs and status names are allowed.
class DriverLogRecord {
  const DriverLogRecord({
    required this.level,
    required this.name,
    required this.message,
    this.error,
    this.stack,
    this.fatal = false,
  });

  final DriverLogLevel level;
  final String name;
  final String message;
  final Object? error;
  final StackTrace? stack;

  /// Contract v0.16.0: an uncaught error (`kind: crash`); a reported
  /// [DriverLog.error] with an error object is `kind: error`.
  final bool fatal;
}

/// Destination for log records. A crash-reporting adapter (with user consent
/// and PII scrubbing) implements this later; the default prints to console.
typedef DriverLogSink = void Function(DriverLogRecord record);

/// Single structured log seam for Driver.
class DriverLog {
  const DriverLog._();

  static DriverLogSink sink = _debugSink;

  /// [error] without the stored text it may quote. A FormatException from
  /// `jsonDecode` carries the record around the bad character (rider names,
  /// addresses, phone numbers); only its message and offset are kept.
  static Object scrub(Object error) =>
      error is FormatException && error.source != null
      ? FormatException(error.message, null, error.offset)
      : error;

  static void _debugSink(DriverLogRecord record) {
    final prefix = switch (record.level) {
      DriverLogLevel.info => '',
      DriverLogLevel.warn => 'WARN ',
      DriverLogLevel.error => 'ERROR ',
    };
    final detail = record.error == null
        ? record.message
        : '${record.message}: ${record.error}';
    debugPrint('[${record.name}] $prefix$detail');
    if (record.stack != null) {
      debugPrint('${record.stack}');
    }
  }

  static void info(String message, {String name = 'movera'}) {
    sink(
      DriverLogRecord(level: DriverLogLevel.info, name: name, message: message),
    );
  }

  static void warn(String message, {String name = 'movera'}) {
    sink(
      DriverLogRecord(level: DriverLogLevel.warn, name: name, message: message),
    );
  }

  /// An uncaught framework or platform error (see installGlobalErrorHooks).
  static void crash(String message, Object error, StackTrace? stack) {
    sink(
      DriverLogRecord(
        level: DriverLogLevel.error,
        name: 'movera',
        message: message,
        error: scrub(error),
        stack: stack,
        fatal: true,
      ),
    );
  }

  static void error(
    String message, [
    Object? error,
    StackTrace? stack,
    String name = 'movera',
  ]) {
    sink(
      DriverLogRecord(
        level: DriverLogLevel.error,
        name: name,
        message: message,
        error: error == null ? null : scrub(error),
        stack: stack,
      ),
    );
  }
}

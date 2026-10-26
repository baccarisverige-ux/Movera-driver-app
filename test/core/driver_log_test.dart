import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:movera/core/logging/global_error_hooks.dart';

void main() {
  test('log records reach a replaceable sink', () {
    final records = <DriverLogRecord>[];
    final previous = DriverLog.sink;
    DriverLog.sink = records.add;
    addTearDown(() => DriverLog.sink = previous);

    DriverLog.info('ride restored');
    DriverLog.warn('route slow');
    DriverLog.error('save failed', StateError('disk'), StackTrace.current);

    expect(records.map((r) => r.level), [
      DriverLogLevel.info,
      DriverLogLevel.warn,
      DriverLogLevel.error,
    ]);
    expect(records.last.error, isA<StateError>());
    expect(records.last.stack, isNotNull);
  });

  test(
    'framework errors are routed to the log and still reach the previous handler',
    () {
      final records = <DriverLogRecord>[];
      final previousSink = DriverLog.sink;
      final previousOnError = FlutterError.onError;
      final previousPlatform = PlatformDispatcher.instance.onError;
      var forwarded = false;
      FlutterError.onError = (_) => forwarded = true;
      DriverLog.sink = records.add;
      addTearDown(() {
        DriverLog.sink = previousSink;
        FlutterError.onError = previousOnError;
        PlatformDispatcher.instance.onError = previousPlatform;
      });

      installGlobalErrorHooks();
      FlutterError.onError!(
        FlutterErrorDetails(exception: StateError('layout')),
      );

      expect(forwarded, isTrue);
      expect(records.single.message, 'Flutter framework error');
    },
  );
}

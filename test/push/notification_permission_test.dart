import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/push/notification_permission.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(NotificationPermission.channelName);
  late int asks;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    asks = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'request') asks++;
          return true;
        });
  });

  test('D14-7: Android asks the system once, then never again', () async {
    final permission = NotificationPermission(isAndroid: () => true);
    expect(await permission.requestOnce(), isTrue);
    expect(await permission.requestOnce(), isFalse);
    expect(asks, 1);
  });

  test('D14-7: not Android: nothing is asked', () async {
    final permission = NotificationPermission(isAndroid: () => false);
    expect(await permission.requestOnce(), isFalse);
    expect(asks, 0);
  });
}

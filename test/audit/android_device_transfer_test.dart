import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// driver-u2: on Android 12+ `allowBackup="false"` does not stop
/// device-to-device transfer; only the `<device-transfer>` rules do.
/// Ride-check audio is written under getApplicationDocumentsDirectory(),
/// which on Android is `<dataDir>/app_flutter`: the `root` domain, not
/// `file`. So `root` must be excluded too.
Set<String> _excluded(String xml, String section) {
  final body = RegExp(
    '<$section>(.*?)</$section>',
    dotAll: true,
  ).firstMatch(xml)?.group(1);
  expect(body, isNotNull, reason: '<$section> is missing');
  return RegExp(
    r'<exclude\s+domain="([^"]+)"\s+path="\."\s*/>',
  ).allMatches(body!).map((m) => m.group(1)!).toSet();
}

void main() {
  test(
    'device transfer and cloud backup exclude the app_flutter (root) domain',
    () {
      final rules = File(
        'android/app/src/main/res/xml/data_extraction_rules.xml',
      ).readAsStringSync();
      expect(_excluded(rules, 'device-transfer'), contains('root'));
      expect(_excluded(rules, 'cloud-backup'), contains('root'));
    },
  );
}

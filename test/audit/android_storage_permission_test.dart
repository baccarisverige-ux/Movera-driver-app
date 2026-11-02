import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android manifest does not request legacy external storage', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, isNot(contains('READ_EXTERNAL_STORAGE')));
    expect(manifest, isNot(contains('WRITE_EXTERNAL_STORAGE')));
    expect(manifest, contains('android.permission.INTERNET'));
    expect(manifest, contains('ACCESS_FINE_LOCATION'));
    expect(manifest, contains('ACCESS_COARSE_LOCATION'));
  });
}

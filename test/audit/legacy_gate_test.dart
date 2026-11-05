import 'package:flutter_test/flutter_test.dart';
import 'demo_features.dart';

void main() {
  test('legacy auth is unavailable in normal demo builds', () {
    expect(legacyAuthEnabled, false);
  });
}

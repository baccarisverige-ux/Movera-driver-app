import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no empty enabled button callbacks', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      expect(
        file.readAsStringSync(),
        isNot(matches(r'onPressed:\s*\(\)\s*\{\s*\}')),
        reason: file.path,
      );
    }
  });
}

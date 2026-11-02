import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release evidence matrix does not claim unproven certification', () {
    final result = Process.runSync('python3', [
      'tool/check_evidence_matrix.py',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final matrix = File('docs/certification/RELEASE_EVIDENCE_MATRIX.md')
        .readAsStringSync();
    expect(matrix, contains('| iphone |'));
    expect(matrix, contains('| chrome |'));
    expect(matrix, contains('| perf-soak |'));
    expect(matrix, isNot(contains('| PASS |')));
  });
}

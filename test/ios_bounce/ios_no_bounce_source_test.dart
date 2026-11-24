import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Owner 2026-11-24: nothing in the driver app may bounce past its edge on
/// iOS. A hard-coded bouncing physics would override the app's clamping
/// scroll behaviour, so none may be used.
void main() {
  test('no bouncing physics used in lib/', () {
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (RegExp(
          r'physics:\s*(const\s+)?\w*Bouncing\w*Physics\(',
        ).hasMatch(lines[i])) {
          hits.add('${f.path}:${i + 1}');
        }
      }
    }
    expect(hits, isEmpty);
  });

  test('MaterialApp uses the Movera clamping scroll behaviour', () {
    final src = File('lib/main.dart').readAsStringSync();
    expect(src, contains('scrollBehavior: const MoveraScrollBehavior()'));
  });
}

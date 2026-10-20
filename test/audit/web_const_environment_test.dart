import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// On web (dart2js), `bool/int/String.fromEnvironment` and `hasEnvironment`
/// throw "can only be used as a const constructor" unless they are const.
/// The VM tests don't catch it, so this check reads lib/ directly.
void main() {
  test('every fromEnvironment/hasEnvironment read in lib/ is const', () {
    final offenders = <String>[];
    final read = RegExp(r'\b(bool|int|String)\.(fromEnvironment|hasEnvironment)\(');
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!read.hasMatch(lines[i])) continue;
        final here = lines[i];
        final before = i > 0 ? lines[i - 1] : '';
        final isConst = here.contains('const ') ||
            (before.contains('const ') && before.trimRight().endsWith('='));
        if (!isConst) offenders.add('${entity.path}:${i + 1}: ${here.trim()}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'Non-const environment reads crash the web build');
  });
}

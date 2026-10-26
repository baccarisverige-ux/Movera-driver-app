import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Iterable<File> _dart(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'));

void main() {
  test('every IconButton has a tooltip for screen readers', () {
    final missing = <String>[];
    for (final file in _dart('lib')) {
      final source = file.readAsStringSync();
      for (final match in RegExp(
        r'IconButton(\.filled|\.outlined)?\(',
      ).allMatches(source)) {
        var depth = 1, i = match.end;
        while (depth > 0 && i < source.length) {
          final c = source[i++];
          if (c == '(') depth++;
          if (c == ')') depth--;
        }
        if (!source.substring(match.start, i).contains('tooltip:')) {
          missing.add(
            '${file.path}:${source.substring(0, match.start).split('\n').length}',
          );
        }
      }
    }
    expect(missing, isEmpty);
  });

  test('every declared AppAssets constant is used and exists', () {
    final declarations = RegExp(
      r"static const String (\w+)\s*=\s*'([^']+)'",
    ).allMatches(File('lib/constants/appassets.dart').readAsStringSync());
    final code = [
      for (final dir in ['lib', 'test'])
        ..._dart(dir).map((f) => f.readAsStringSync()),
    ].join('\n');
    final unused = <String>[], missingFiles = <String>[];
    for (final d in declarations) {
      if (!code.contains('AppAssets.${d.group(1)}')) unused.add(d.group(1)!);
      if (!File(d.group(2)!).existsSync()) missingFiles.add(d.group(2)!);
    }
    expect(unused, isEmpty, reason: 'Remove unused assets so they do not ship');
    expect(missingFiles, isEmpty);
  });
}

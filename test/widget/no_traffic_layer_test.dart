import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Owner, live test 2026-10-26 (N5): Google's live traffic layer (the
/// green / red / yellow roads) is on no driver map any more; only the
/// Movera map style draws the roads. The setting that switched it on for
/// the trip map is gone with it.
void main() {
  test('no driver map asks Google for the traffic layer', () {
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    final enabling = <String>[];
    var fixedOff = 0;
    for (final file in sources) {
      final text = file.readAsStringSync();
      if (text.contains('MapTrafficSetting')) enabling.add(file.path);
      for (final match in RegExp(r'trafficEnabled:\s*([^,\n]+)').allMatches(text)) {
        if (match.group(1)!.trim() == 'false') {
          fixedOff++;
        } else {
          enabling.add('${file.path}: ${match.group(0)}');
        }
      }
    }
    expect(enabling, isEmpty);
    // The one map widget every driver map is built on keeps it off.
    expect(fixedOff, 1);
    expect(File('lib/core/settings/map_traffic_setting.dart').existsSync(), isFalse);
  });
}

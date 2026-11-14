import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Base split (owner 2026-11-05, rule 25): the driver texts live in one file
// per area, lib/l10n/parts/<area>.<lang>.arb, and tool/l10n_parts.py
// combines them into the one ARB per language that gen-l10n reads.

const _langs = ['en', 'fr', 'sv'];

List<String> _areas() =>
    Directory('lib/l10n/parts')
        .listSync()
        .map((f) => f.uri.pathSegments.last)
        .where((name) => name.endsWith('.arb'))
        .map((name) => name.split('.').first)
        .toSet()
        .toList()
      ..sort();

/// What tool/l10n_parts.py writes: the inner lines of every area file,
/// areas in name order.
String _merged(String lang) {
  final bodies = <String>[];
  for (final area in _areas()) {
    final lines = File(
      'lib/l10n/parts/$area.$lang.arb',
    ).readAsStringSync().trimRight().split('\n');
    if (lines.length > 2) {
      bodies.add(lines.sublist(1, lines.length - 1).join('\n'));
    }
  }
  return '{\n${bodies.join(',\n')}\n}\n';
}

void main() {
  test('each ARB is exactly its area files combined', () {
    for (final lang in _langs) {
      expect(
        File('lib/l10n/app_$lang.arb').readAsStringSync(),
        _merged(lang),
        reason: 'Run python3 tool/l10n_parts.py and commit the result.',
      );
    }
  });

  test('each area holds the same messages in every language, once', () {
    final seen = <String, String>{};
    for (final area in _areas()) {
      Set<String> keys(String lang) =>
          (jsonDecode(File('lib/l10n/parts/$area.$lang.arb').readAsStringSync())
                  as Map<String, dynamic>)
              .keys
              .where((k) => !k.startsWith('@'))
              .toSet();
      for (final lang in _langs) {
        expect(keys(lang), keys('en'), reason: '$area.$lang.arb');
      }
      for (final key in keys('en')) {
        expect(seen[key], isNull, reason: '$key is in ${seen[key]} and $area');
        seen[key] = area;
      }
    }
  });

  test(
    'the split kept every message (2795 en entries, 2108 fr / sv; +SV break, +G30 e-mail verified, +G32 waybill commission, +0.18.66 call hint + version line, +0.18.65 next trips switch, +0.18.56 chat, +0.18.57 emergency numbers, +0.18.58 arrived distance; +job 9 airport_queue, +go_offline, +job 8 calls, +job 10 blocked_pairs, +L8 driver early end, +0.18.51 beforePickup)',
    () {
      const counts = {'en': 2795, 'fr': 2108, 'sv': 2108};
      for (final lang in _langs) {
        final arb =
            jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
                as Map<String, dynamic>;
        expect(arb.length, counts[lang], reason: lang);
      }
    },
  );
}

// Owner 2026-11-07 ("Oui, construire"): the driver app opens like the rider
// app. Before this, web/index.html had no viewport tag (the page was laid out
// 980 px wide until Flutter added its own, so "MOVERA" showed small, then
// big), no html/body background (white around the beige boot box) and the
// manifest splash was white.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final html = File('web/index.html').readAsStringSync();
  final manifest =
      jsonDecode(File('web/manifest.json').readAsStringSync())
          as Map<String, dynamic>;

  String rule(String selector) {
    final start = html.indexOf('$selector {');
    expect(start, isNot(-1), reason: 'missing CSS rule "$selector"');
    final end = html.indexOf('}', start);
    return html.substring(start, end);
  }

  group('Driver opening looks like the rider opening', () {
    test(
      'viewport tag is in the page from the first byte, pinch-zoom kept',
      () {
        expect(
          html,
          contains(
            '<meta name="viewport" content="width=device-width, '
            'initial-scale=1.0, maximum-scale=5.0">',
          ),
        );
        expect(html, isNot(contains('maximum-scale=1"')));
        expect(html, isNot(contains('maximum-scale=1,')));
        expect(html, isNot(contains('user-scalable=no')));
        expect(html, isNot(contains('viewport-fit')));
      },
    );

    test('html and body are beige, full height, no margin', () {
      final r = rule('html, body');
      expect(r, contains('height: 100%;'));
      expect(r, contains('margin: 0;'));
      expect(r, contains('padding: 0;'));
      expect(r, contains('background: #eef1e8;'));
    });

    test('boot block values are the rider values', () {
      final boot = rule('#movera-boot');
      expect(boot, contains('position: absolute;'));
      expect(boot, contains('background: #eef1e8;'));
      final mark = rule('#movera-boot .movera-boot-mark');
      expect(mark, contains('font-size: 34px;'));
      expect(mark, contains('letter-spacing: 0.14em;'));
      expect(mark, contains('color: #1d252c;'));
      final track = rule('#movera-boot .movera-boot-track');
      expect(track, contains('width: 132px;'));
      expect(track, contains('height: 3px;'));
      expect(html, contains('movera-boot-slide 1150ms'));
      expect(html, isNot(contains('position: fixed')));
    });

    test('manifest splash is beige; theme colour unchanged', () {
      expect(manifest['background_color'], '#eef1e8');
      expect(manifest['theme_color'], '#252E3A');
      expect(html, contains('<meta name="theme-color" content="#252E3A">'));
    });
  });
}

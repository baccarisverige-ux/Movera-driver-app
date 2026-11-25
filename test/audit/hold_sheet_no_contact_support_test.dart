import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Owner 2026-11-24: the "account not active / Finish sign-up" sheet shows
/// only Documents and My fleet (live) or Skip demo (demo) under the card; no
/// "Contact support" link in any variant (support stays in the side menu).
/// The rendered demo variant is covered in test/widget/d3_home_back_test.dart.
void main() {
  test('no variant of the hold sheet builds a Contact support link', () {
    final sheet = File(
      'lib/presentation/driver/home/home_map_sheet.dart',
    ).readAsStringSync();
    final start = sheet.indexOf('Widget _inactiveSheetFace()');
    final end = sheet.indexOf('void openDestinationPanel()', start);
    expect(start, greaterThan(0));
    final face = sheet.substring(start, end);
    expect(face, contains("ValueKey('hold-documents')"));
    expect(face, contains("ValueKey('hold-fleet')"));
    expect(face, isNot(contains('contactSupport')));
    expect(face, isNot(contains('_openActivationSupport')));
  });

  test('support stays reachable from the side menu', () {
    final menu = File(
      'lib/presentation/driver/side menu/side_menu.dart',
    ).readAsStringSync();
    expect(menu, contains('_open(context, supportScreen())'));
  });
}

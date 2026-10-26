import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('restore has no fabricated plate or rider', () {
    final home = File(
      'lib/presentation/driver/home/home.dart',
    ).readAsStringSync();
    expect(home, isNot(contains("snapshot.riderName ?? 'Angelica'")));
    expect(home, isNot(contains("licensePlate: 'MVR 418'")));
    // driver-u69: stored as the English stand-in, shown translated.
    expect(home, contains('WaybillRecord.plateUnavailable'));
    expect(
      File('lib/core/waybill/waybill.dart').readAsStringSync(),
      contains("plateUnavailable = 'Plate unavailable'"),
    );
    final english =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    expect(english['plateUnavailable'], 'Plate unavailable');
  });
}

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('destination deferred open has attachment and teardown guards', () {
    final text =
        File('lib/presentation/driver/home/home.dart').readAsStringSync() +
        File(
          'lib/presentation/driver/home/home_map_sheet.dart',
        ).readAsStringSync();
    expect(text, contains('_destinationOpenTimer?.cancel()'));
    expect(text, contains('!_destinationPanelController.isAttached'));
    expect(text, isNot(contains('Future.delayed(Duration(milliseconds: 100)')));
  });
}

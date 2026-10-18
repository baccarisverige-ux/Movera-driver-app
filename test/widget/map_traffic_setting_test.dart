import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/settings/map_traffic_setting.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/presentation/driver/settings/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(MapTrafficSetting.reset);

  testWidgets('Show traffic on map is ON by default and the switch saves it',
      (tester) async {
    final repository = SettingsRepository();
    await tester.pumpWidget(MaterialApp(home: Settings(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('Show traffic on map'), findsOneWidget);
    final toggle = find.byKey(const ValueKey<String>('settings-show-traffic'));
    expect(tester.widget<Switch>(toggle).value, isTrue);
    expect(MapTrafficSetting.enabled.value, isTrue);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await SettingsRepository.settle();
    expect(tester.widget<Switch>(toggle).value, isFalse);
    expect(MapTrafficSetting.enabled.value, isFalse);

    // A fresh start reads the saved choice back.
    MapTrafficSetting.reset();
    expect(await MapTrafficSetting.restore(repository), isFalse);
  });

  test('only the trip map follows the setting; every other map keeps traffic '
      'off', () {
    final trip = File('lib/presentation/driver/accept ride/accept_ride.dart')
        .readAsStringSync();
    expect(trip, contains('trafficEnabled: MapTrafficSetting.enabled.value'));
    final maps = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('trafficEnabled: true'));
    expect(maps.map((f) => f.path), isEmpty);
  });
}

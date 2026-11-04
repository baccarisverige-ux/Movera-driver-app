import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/driver_app_config.dart';
import 'package:movera/core/history/today_earnings.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/presentation/driver/accept%20ride/navigation_instruction_banner.dart';
import 'package:movera/presentation/driver/home/components/digital_island.dart';

/// Job 3 / L12: a France driver never sees "kr"; amounts with no currency
/// of their own use the zone's currency.
void main() {
  tearDown(() => Money.zoneCurrency = 'SEK');

  void france() {
    final raw = File(
      'test/fixtures/config/driver_app_config.FR-PC.json',
    ).readAsStringSync();
    DriverAppConfig.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    ).apply();
  }

  test('the France zone config puts € in use', () {
    france();
    expect(Money.zoneCurrency, 'EUR');
    expect(Money.zoneSymbol, '€');
  });

  test('FR: no-currency fallbacks say €, never kr', () {
    france();
    expect(TodayEarnings.totalOf(const [], DateTime.now()), contains('€'));
    expect(DigitalIslandParts.unitOf(null), '€');
    expect(NavigationCuePainter.zoneTollUnit(), '€');
    expect(Money.parseLabel('12,50')?.currency, 'EUR');
  });

  testWidgets('FR: the hidden island total reads "•••• €"', (tester) async {
    france();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: DigitalIslandParts.hiddenFace())),
    );
    expect(find.text('•••• €'), findsOneWidget);
    expect(find.textContaining('kr'), findsNothing);
  });
}

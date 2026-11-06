import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/driver_app_config.dart';
import 'package:movera/core/history/today_earnings.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/presentation/driver/home/components/digital_island.dart';

/// P26: in Paris the driver's hidden island total read "•••• kr". The
/// island was built before the zone config arrived, and a today's total
/// made in the "kr" default won over the zone's currency.
void main() {
  tearDown(() {
    TodayEarnings.reset();
    Money.zoneCurrency = 'SEK';
  });

  void apply(String zone) {
    final raw = File(
      'test/fixtures/config/driver_app_config.$zone.json',
    ).readAsStringSync();
    DriverAppConfig.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    ).apply();
  }

  Future<void> pumpHidden(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(home: Scaffold(body: DigitalIslandParts.hiddenFace())),
  );

  testWidgets('EUR: config arriving late turns "kr" into "•••• €"', (
    tester,
  ) async {
    Money.forgetZone();
    // Today's total was made before the zone was known (0 in the default).
    await TodayEarnings.refresh(read: () async => const []);
    await pumpHidden(tester);

    apply('FR-PC');
    await tester.pump();
    expect(find.text('•••• €'), findsOneWidget);
    expect(find.textContaining('kr'), findsNothing);
  });

  testWidgets('SEK: a Swedish zone config shows "•••• kr"', (tester) async {
    Money.forgetZone();
    await pumpHidden(tester);
    expect(find.text('••••'), findsOneWidget);

    apply('Z001');
    await tester.pump();
    expect(Money.zoneCurrency, 'SEK');
    expect(find.text('•••• kr'), findsOneWidget);
    expect(find.textContaining('€'), findsNothing);
  });

  test('a trip fare\'s own symbol wins over the zone', () {
    apply('FR-PC');
    expect(DigitalIslandParts.unitOf('104,80 kr'), 'kr');
    expect(DigitalIslandParts.unitOf(null), '€');
  });
}

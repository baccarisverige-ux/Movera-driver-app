import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/session/driver_composition_guard.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/analytics/analytics.dart';
import 'package:movera/presentation/driver/home/components/digital_island.dart';
import 'package:movera/presentation/driver/home/components/driver_suspended_sheet.dart';
import 'package:movera/presentation/driver/settings/accessibility/accessibility.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Live clean-up (audit 2026-11-02 B1/B2/B4/B7/B9/B10/B16).
void main() {
  late DriverRuntimeConfig previous;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    previous = DriverRuntimeConfig.current;
  });
  tearDown(() => DriverRuntimeConfig.current = previous);

  void live() => DriverRuntimeConfig.current = const DriverRuntimeConfig(
    simulatedArrival: true,
    externalRouting: false,
    skipAccountActivation: true,
    authRequired: true,
  );

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: child));
    await tester.pump(const Duration(milliseconds: 300));
  }

  test('B1: demo things follow the live build, not MOVERA_PRODUCTION', () {
    expect(driverProductionRequested, isFalse);
    expect(driverDemoFeatures, isTrue);
    live();
    expect(driverDemoFeatures, isFalse);
  });

  testWidgets('B2: Analytics has no sample Earnings page on live', (
    tester,
  ) async {
    await pump(tester, const Analytics());
    expect(find.text('Same period as the home sheet'), findsOneWidget);
    live();
    await pump(tester, const Analytics(key: ValueKey('live')));
    expect(find.text('Same period as the home sheet'), findsNothing);
  });

  testWidgets('B4: Accessibility has no demo wording on live', (tester) async {
    live();
    await pump(tester, const Accessibility());
    expect(find.textContaining('demo'), findsNothing);
    expect(find.text('These preferences are saved on this phone.'), findsOne);
  });

  testWidgets('B7: the updating island shows the trip currency', (
    tester,
  ) async {
    expect(DigitalIslandParts.unitOf('24,50 €'), '€');
    expect(DigitalIslandParts.unitOf('104,80 kr'), 'kr');
    await pump(
      tester,
      Scaffold(
        body: DigitalUpdatingFace(unit: DigitalIslandParts.unitOf('9 €')),
      ),
    );
    expect(find.text('€'), findsOneWidget);
    expect(find.text('kr'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  test('B16: Swedish says Movera Förare, never Movera Driver', () {
    expect(
      File('lib/l10n/app_sv.arb').readAsStringSync(),
      isNot(contains('Movera Driver')),
    );
  });

  testWidgets('G16 Q16-3: paused sheet is short, cannot be closed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late BuildContext owner;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            owner = context;
            return const Scaffold(body: Text('Home'));
          },
        ),
      ),
    );
    showDriverSuspendedSheet(owner);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final sheet = find.byKey(const ValueKey('driver-suspended-state'));
    expect(sheet, findsOneWidget);
    expect(find.text('Your account is paused. Contact support.'), findsOne);
    expect(find.text('Contact support'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Got it'), findsNothing);

    await tester.tapAt(const Offset(10, 10));
    await tester.pump(const Duration(milliseconds: 300));
    expect(sheet, findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));
    expect(sheet, findsOneWidget);
  });
}

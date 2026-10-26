import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/documents/documents.dart';
import 'package:movera/presentation/driver/my%20bank/add%20new%20account/add_new_account.dart';
import 'package:movera/presentation/driver/side%20menu/side_menu.dart';
import 'package:movera/widgets/movera_sheet_metrics.dart';

void main() {
  testWidgets('Bank account finds the bank and switches to IBAN', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AddNewAccount()));
    await tester.enterText(
      find.byKey(const ValueKey<String>('bank-field-Clearing')),
      '8327-9',
    );
    await tester.pump();
    expect(find.text('Swedbank'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('bank-tab-International')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const ValueKey<String>('bank-field-IBAN')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('bank-field-IBAN')),
      'SE45 5000 0000 0583 9825 7466',
    );
    await tester.pump();
    expect(find.text('SEB'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('bank-save')));
    await tester.pump();
    expect(find.textContaining('account holder'), findsWidgets);
  });

  testWidgets('Menu ring: orange while pending, white when active', (
    tester,
  ) async {
    Future<void> show(bool active) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DriverSideMenu(accountActive: active)),
      ),
    );
    await show(false);
    expect(
      find.byKey(const ValueKey<String>('menu-ring-pending')),
      findsOneWidget,
    );
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('MD'), findsOneWidget);
    await show(true);
    expect(
      find.byKey(const ValueKey<String>('menu-ring-active')),
      findsOneWidget,
    );
    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets('Documents list every item as needed', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DriverDocuments()));
    expect(find.text('0 of 11 approved'), findsOneWidget);
    expect(find.text('Company registration'), findsOneWidget);
  });

  test('A small push goes to the next stage in the finger direction', () {
    const snap = 0.4;
    double target(double start, double pos) =>
        MoveraSheetMetrics.directionalTarget(
          start: start,
          position: pos,
          velocityPxPerSec: 0,
          snap: snap,
        );
    expect(target(0, 0.06), snap);
    expect(target(snap, 0.46), 1);
    expect(target(1, 0.94), snap);
    expect(target(snap, 0.34), 0);
    expect(target(snap, 0.41), snap);
  });

  test('Home sheet has two stops: a small push goes to the other end', () {
    double target(double start, double pos, [double v = 0]) =>
        MoveraSheetMetrics.twoStopTarget(
          start: start,
          position: pos,
          velocityPxPerSec: v,
        );
    expect(target(0, 0.06), 1);
    expect(target(1, 0.94), 0);
    expect(target(0, 0.02), 0);
    expect(target(1, 0.99), 1);
    expect(target(0.5, 0.5, -400), 1);
    expect(target(0.5, 0.5, 400), 0);
  });
}

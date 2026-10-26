import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/my%20bank/add%20new%20account/add_new_account.dart';

void main() {
  testWidgets(
    'foreign IBAN shows country and validation guidance accepts international intent',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AddNewAccount()));
      await tester.tap(
        find.byKey(const ValueKey<String>('bank-tab-International')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('bank-field-Holder')),
        'Test Driver',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('bank-field-IBAN')),
        'DE89 3704 0044 0532 0130 00',
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('bank-row-Country')),
        findsOneWidget,
      );
      expect(find.text('DE'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('bank-row-Bank')), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey<String>('bank-field-IBAN')),
        'DE00',
      );
      await tester.tap(find.byKey(const ValueKey<String>('bank-save')));
      await tester.pump();
      expect(
        find.textContaining('Check the IBAN format and check digits'),
        findsWidgets,
      );
      expect(find.textContaining('starts with SE'), findsNothing);
      expect(find.text('Check details'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('bank country tabs can be selected with keyboard', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AddNewAccount()));
    for (var i = 0; i < 12; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<TextButton>();
      if (focused?.key == const ValueKey<String>('bank-tab-International')) {
        break;
      }
    }
    final focused = FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<TextButton>();
    expect(focused?.key, const ValueKey<String>('bank-tab-International'));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('bank-field-IBAN')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

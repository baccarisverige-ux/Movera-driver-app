import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/safety/safety_audio_option.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/presentation/driver/my%20bank/add%20new%20account/add_new_account.dart';
import 'package:movera/presentation/driver/my%20wallet/wallet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// B16 (2026-11-04): behaviour tests that replace source-reading guards
/// (archived in Rules/archive/old-tests/Movera-driver-app/). Each one opens
/// the real screen and checks what the driver sees.
void main() {
  late DriverRuntimeConfig previous;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    previous = DriverRuntimeConfig.current;
  });
  tearDown(() {
    DriverRuntimeConfig.current = previous;
    SafetyAudioOption.debugEnabled = null;
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        builder: (_, __) => MaterialApp(home: child),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Every text on screen, scrolled through each list.
  Future<String> texts(WidgetTester tester) async {
    final seen = <String>{};
    void collect() {
      for (final w in tester.widgetList<Text>(find.byType(Text))) {
        final s = w.data ?? w.textSpan?.toPlainText();
        if (s != null) seen.add(s);
      }
      for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
        seen.add(w.text.toPlainText());
      }
    }

    collect();
    final lists = find.byType(Scrollable);
    for (var n = 0; n < lists.evaluate().length; n++) {
      for (var i = 0; i < 10; i++) {
        await tester.drag(
          lists.at(n),
          const Offset(0, -300),
          warnIfMissed: false,
        );
        await tester.pump(const Duration(milliseconds: 50));
        collect();
      }
    }
    return seen.join('\n');
  }

  group('the old withdrawal simulation cannot come back', () {
    testWidgets('a complete bank form says "account not saved"', (
      tester,
    ) async {
      await pump(tester, const AddNewAccount());
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
      await tester.enterText(
        find.byKey(const ValueKey<String>('bank-field-BIC')),
        'COBADEFFXXX',
      );
      await tester.pump();
      final save = find.byKey(const ValueKey<String>('bank-save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump();
      // Saved nowhere, and it says so; no fake "withdrawal successful".
      expect(find.text('Preview only — account not saved.'), findsOneWidget);
      expect(find.textContaining('uccess'), findsNothing);
    });

    testWidgets('Wallet shows no sample \$50 balance', (tester) async {
      await pump(tester, const WalletScreen());
      expect(await texts(tester), isNot(contains(r'$50')));
    });
  });
}

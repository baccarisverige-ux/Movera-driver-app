import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movera/presentation/common/chat/chat.dart';
import 'package:movera/presentation/driver/analytics/acceptance rate/acceptance_rate.dart';
import 'package:movera/presentation/driver/analytics/cancelation rate/cancelation_rate.dart';
import 'package:movera/presentation/driver/earning stats/earning_stats.dart';
import 'package:movera/presentation/driver/my wallet/wallet.dart';
import 'package:movera/presentation/driver/profile/legal_document.dart';
import 'package:movera/presentation/driver/settings/emergency_contacts.dart';
import 'package:movera/presentation/driver/destination mode/destination_picker.dart';
import 'package:movera/presentation/driver/pin verification/pin_verification.dart';
import 'package:movera/presentation/driver/safety toolkits/safety_toolkits.dart';

VoidCallback _icon(WidgetTester tester, String tooltip) => tester
    .widget<IconButton>(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == tooltip,
      ),
    )
    .onPressed!;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final screens = <String, (Widget, VoidCallback Function(WidgetTester))>{
    'wallet': (
      const WalletScreen(),
      (tester) => tester
          .widget<InkWell>(find.byKey(const ValueKey<String>('wallet-back')))
          .onTap!,
    ),
    'acceptance': (const AcceptanceRate(), (tester) => _icon(tester, 'Back')),
    'cancellation': (
      const CancelationRate(),
      (tester) => _icon(tester, 'Back'),
    ),
    'earnings': (const EarningStatsScreen(), (tester) => _icon(tester, 'Back')),
    'chat': (
      const Chat(riderDisplayName: 'Demo rider'),
      (tester) => _icon(tester, 'Back'),
    ),
    'contacts': (
      const EmergencyContactsScreen(),
      (tester) => _icon(tester, 'Back'),
    ),
    'legal': (LegalDocumentScreen.privacy, (tester) => _icon(tester, 'Back')),
    'destination': (
      const DriverDestinationPicker(),
      (tester) => _icon(tester, 'Back'),
    ),
    'pin': (
      const PinVerification(),
      (tester) => tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Close preview'),
          )
          .onPressed!,
    ),
    'safety': (const SafetyToolKits(), (tester) => _icon(tester, 'Close')),
  };
  for (final entry in screens.entries) {
    testWidgets('${entry.key} repeated exit preserves its caller', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, __) => MaterialApp(
            navigatorKey: nav,
            home: const Scaffold(body: Text('Root owner')),
          ),
        ),
      );
      nav.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Caller owner')),
        ),
      );
      await tester.pumpAndSettle();
      nav.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => entry.value.$1),
      );
      await tester.pumpAndSettle();
      final close = entry.value.$2(tester);
      close();
      close();
      await tester.pumpAndSettle();
      expect(find.text('Caller owner'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

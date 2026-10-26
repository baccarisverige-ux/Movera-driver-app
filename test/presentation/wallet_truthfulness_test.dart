import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/my%20bank/my_bank.dart';
import 'package:movera/presentation/driver/my%20wallet/wallet.dart';

void main() {
  testWidgets('wallet does not invent a live balance or payout', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: WalletScreen()));
    expect(find.text('0,00 kr'), findsOneWidget);
    expect(find.text('Preview only'), findsOneWidget);
    expect(find.textContaining('2 994'), findsNothing);
    expect(find.textContaining('21 Sep'), findsNothing);
    expect(find.textContaining('••••'), findsNothing);
    expect(
      find.text('No payouts yet. Local preview cannot invent earnings.'),
      findsOneWidget,
    );
    expect(find.text('No payout account connected'), findsOneWidget);
    expect(find.text('No automatic payout'), findsOneWidget);
    expect(find.text('Weekly'), findsNothing);
  });

  testWidgets('my bank starts disconnected and does not seed accounts', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (_, __) => const MaterialApp(home: MyBank()),
      ),
    );
    expect(find.text('No payout account connected'), findsOneWidget);
    expect(find.textContaining('SE45'), findsNothing);
    expect(find.textContaining('SE91'), findsNothing);
    expect(find.text('Erik Johansson'), findsNothing);
    expect(find.text('Handelsbanken'), findsNothing);
    expect(find.text('Nordea'), findsNothing);
    expect(find.text('Weekly payouts'), findsNothing);
    expect(find.text('Use for weekly payouts'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

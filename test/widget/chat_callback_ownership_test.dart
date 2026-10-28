import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/common/chat/chat.dart';

void main() {
  for (final disposed in [false, true]) {
    testWidgets(
      'captured chat actions ignore ${disposed ? 'disposed' : 'covered'} route',
      (tester) async {
        tester.view.physicalSize = const Size(430, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          ScreenUtilInit(
            designSize: const Size(375, 812),
            builder: (_, _) => MaterialApp(
              navigatorKey: navigator,
              home: const Chat(riderDisplayName: 'Test Rider'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), 'Retain this draft');
        await tester.pump();
        final field = tester.widget<TextField>(find.byType(TextField));
        final send = tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton &&
                    widget.tooltip == 'Save message locally',
              ),
            )
            .onPressed!;
        final call = tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == 'Call rider',
              ),
            )
            .onPressed!;
        if (disposed) {
          await tester.pumpWidget(const SizedBox());
        } else {
          navigator.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Covering route')),
            ),
          );
          await tester.pumpAndSettle();
        }
        send();
        field.onSubmitted!('Retain this draft');
        call();
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
        expect(tester.takeException(), isNull);
        if (!disposed) {
          navigator.currentState!.pop();
          await tester.pumpAndSettle();
          expect(field.controller!.text, 'Retain this draft');
          expect(find.byType(SenderMessage), findsNothing);
          send();
          await tester.pumpAndSettle();
          expect(find.byType(SenderMessage), findsOneWidget);
          expect(field.controller!.text, isEmpty);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}

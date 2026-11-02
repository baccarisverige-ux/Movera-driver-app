import 'dart:ui' show SemanticsAction, SemanticsActionEvent;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/common/chat/chat.dart';

Future<void> _chat(
  WidgetTester tester, {
  Size size = const Size(375, 812),
  double scale = 1,
  double keyboard = 0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const Chat(riderDisplayName: 'Maya'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('chat send has a named disabled/enabled local-save action', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await _chat(tester);
      final send = find.byTooltip('Save message locally');
      expect(send, findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton &&
                    widget.tooltip == 'Save message locally',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextFormField), 'On my way');
      await tester.pump();
      final node = tester.getSemantics(
        find.bySemanticsLabel('Save message locally'),
      );
      expect(node.getSemanticsData().label, contains('Save message locally'));
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(
          viewId: tester.view.viewId,
          nodeId: node.id,
          type: SemanticsAction.tap,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('On my way'), findsOneWidget);
      expect(find.byType(SenderMessage), findsOneWidget);
      expect(find.text('Local preview · not sent'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('keyboard Send saves locally once and rejects whitespace', (
    tester,
  ) async {
    await _chat(tester);
    await tester.enterText(find.byType(TextFormField), 'Keyboard message');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(find.text('Keyboard message'), findsOneWidget);
    expect(find.byType(SenderMessage), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '  ');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(find.byType(SenderMessage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(375, 812),
    const Size(430, 932),
    const Size(768, 1024),
    const Size(1440, 900),
    const Size(568, 320),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'chat composer reachable with keyboard at $size scale $scale',
        (tester) async {
          await _chat(
            tester,
            size: size,
            scale: scale,
            keyboard: size.height < 400 ? 120 : 220,
          );
          expect(tester.takeException(), isNull);
          final field = find.byType(TextFormField);
          final fieldRect = tester.getRect(field);
          expect(
            fieldRect.bottom,
            lessThanOrEqualTo(size.height - (size.height < 400 ? 120 : 220)),
          );
          await tester.enterText(
            field,
            'Message with a long rider update that wraps onto multiple lines',
          );
          await tester.testTextInput.receiveAction(TextInputAction.send);
          await tester.pumpAndSettle();
          expect(find.byType(SenderMessage), findsOneWidget);
          expect(
            find.byTooltip('Save message locally').hitTestable(),
            findsOneWidget,
          );
          expect(
            tester.getSize(find.byTooltip('Save message locally')).shortestSide,
            greaterThanOrEqualTo(48),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

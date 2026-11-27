import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/driver/accept%20ride/cash_collect_sheet.dart';

/// Owner 2026-11-27: the premium collect-cash sheet. Both buttons stay
/// visible on small and large phones at large text, the early-end note is
/// a hairline note (no yellow box) and "priced for the distance driven"
/// shows as a recalculation icon with "Price recalculated".
/// With `--dart-define=CASH_SHOTS=<dir>` the PNGs are written there.
const _shots = String.fromEnvironment('CASH_SHOTS');

String? _font;

Future<void> _loadFont() async {
  if (_font != null) return;
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  final files = [
    for (final n in [
      'Roboto-Regular',
      'Roboto-Medium',
      'Roboto-Bold',
      'Roboto-Black',
    ])
      File('$dir/$n.ttf'),
  ].where((f) => f.existsSync()).toList();
  if (files.isEmpty) return;
  final loader = FontLoader('CashProof');
  for (final f in files) {
    loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  }
  await loader.load();
  _font = 'CashProof';
  // The icons too, so the info and recalculation icons show in the PNGs.
  final icons = File('$dir/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    await (FontLoader(
          'MaterialIcons',
        )..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync()))))
        .load();
  }
}

String _early() =>
    '${tr.arrivedFarWarning('25,6 km')}\n${tr.g8PricedForDriven}';

Future<void> _open(
  WidgetTester tester, {
  required String lang,
  required Size size,
  double scale = 1,
  bool early = false,
}) async {
  DriverAppTexts.language = lang;
  addTearDown(() => DriverAppTexts.language = 'en');
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, _) => MaterialApp(
        theme: ThemeData(fontFamily: _font),
        builder: (_, child) =>
            RepaintBoundary(key: const ValueKey('cash-proof'), child: child),
        home: Scaffold(
          backgroundColor: const Color(0xFFD3DAD6),
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                key: const ValueKey('open'),
                onPressed: () => showCashCollectSheet(
                  context,
                  fare: '86,00 kr',
                  cash: lang == 'fr' ? '109,00 €' : '109,00 kr',
                  riderName: 'Houssem B',
                  recalculated: early,
                  earlyEndNote: early ? _early() : null,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open')));
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _expectVisible(WidgetTester tester, Finder f, Size size, String why) {
  expect(f, findsOneWidget, reason: why);
  final r = tester.getRect(f);
  expect(r.top >= 0 && r.bottom <= size.height, isTrue, reason: '$why $r');
  expect(r.height, greaterThan(20), reason: why);
  f.hitTestable().evaluate().isNotEmpty || fail('$why not tappable');
}

void main() {
  setUpAll(_loadFont);

  for (final lang in ['sv', 'fr', 'en']) {
    for (final size in const [Size(390, 844), Size(375, 667)]) {
      for (final scale in const [1.0, 1.3, 2.0]) {
        for (final early in [false, true]) {
          final name =
              '$lang ${size.width.toInt()}x${size.height.toInt()} '
              'x$scale${early ? ' early-end' : ''}';
          testWidgets(name, (tester) async {
            await _open(
              tester,
              lang: lang,
              size: size,
              scale: scale,
              early: early,
            );
            expect(tester.takeException(), isNull, reason: name);
            _expectVisible(
              tester,
              find.byKey(const ValueKey('cash-complete-ride')),
              size,
              '$name finish',
            );
            _expectVisible(
              tester,
              find.byKey(const ValueKey('cash-not-yet')),
              size,
              '$name not yet',
            );
            // The old yellow/brown box is gone.
            final yellow = find.byWidgetPredicate(
              (w) =>
                  w is Container &&
                  w.decoration is BoxDecoration &&
                  (w.decoration! as BoxDecoration).color ==
                      const Color(0xFFFFF4E0),
            );
            expect(yellow, findsNothing);
            final recalc = find.byKey(const ValueKey('cash-recalc-icon'));
            if (early) {
              expect(find.text(tr.cashPriceRecalculated), findsOneWidget);
              expect(recalc, findsOneWidget);
              expect(
                find.byKey(const ValueKey('cash-note-info-icon')),
                findsOneWidget,
              );
              expect(find.text(tr.g8PricedForDriven), findsNothing);
              final note = tester.widget<Container>(
                find.byKey(const ValueKey('cash-price-recalculated')),
              );
              final deco = note.decoration! as BoxDecoration;
              expect(deco.color, Colors.white);
              expect(deco.border, isNotNull);
            } else {
              expect(recalc, findsNothing);
              expect(find.text(tr.cashPriceRecalculated), findsNothing);
            }
          });
        }
      }
    }
  }

  test('new texts', () {
    for (final (lang, text) in [
      ('sv', 'Priset har räknats om'),
      ('en', 'Price recalculated'),
      ('fr', 'Prix recalculé'),
    ]) {
      DriverAppTexts.language = lang;
      expect(tr.cashPriceRecalculated, text);
    }
    DriverAppTexts.language = 'en';
  });

  testWidgets('a booked-price note stays as it is, with no recalc icon', (
    tester,
  ) async {
    DriverAppTexts.language = 'en';
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => const MaterialApp(
          home: Scaffold(
            body: CashCollectSheet(
              fare: '73,60 kr',
              cash: '93,00 kr',
              riderName: 'Anna',
              earlyEndNote: 'The booked price applies.',
            ),
          ),
        ),
      ),
    );
    expect(find.text('The booked price applies.'), findsOneWidget);
    expect(find.byKey(const ValueKey('cash-recalc-icon')), findsNothing);
  });

  for (final (name, lang, early) in [
    ('sv-normal', 'sv', false),
    ('sv-early-end', 'sv', true),
    ('fr-early-end', 'fr', true),
  ]) {
    testWidgets('screenshot $name', (tester) async {
      await _open(tester, lang: lang, size: const Size(375, 667), early: early);
      if (_shots.isEmpty) return;
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('cash-proof')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$_shots/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}

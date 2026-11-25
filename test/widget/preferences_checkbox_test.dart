import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/presentation/driver/preferences/preferences.dart';

/// Owner 2026-11-25: a small box top-right of every ride-type card.
/// Set MOVERA_SHOTS to a folder to also write the screen as PNGs.
const _shots = String.fromEnvironment('MOVERA_SHOTS');

class _Settings extends SettingsRepository {
  @override
  Future<Map<String, dynamic>> read(String section) async => {};
  @override
  Future<void> save(String section, Map<String, dynamic> values) async {}
}

Finder get _boxes => find.byWidgetPredicate(
  (w) =>
      w.key == const ValueKey<String>('ride-type-box-on') ||
      w.key == const ValueKey<String>('ride-type-box-off'),
);

Future<String?> _fonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return null;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<void> load(String family, String file) async {
    final f = File('$dir/$file');
    if (!f.existsSync()) return;
    await (FontLoader(
      family,
    )..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())))).load();
  }

  await load('MaterialIcons', 'MaterialIcons-Regular.otf');
  await load('CbProof', 'Roboto-Regular.ttf');
  return 'CbProof';
}

Future<void> _open(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double scale = 1,
  String? font,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(fontFamily: font),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: RepaintBoundary(
        key: const ValueKey('cb-proof'),
        child: Preferences(repository: _Settings()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// No box may touch its card's icon or texts.
int _expectNoOverlap(WidgetTester tester, String reason) {
  final boxes = _boxes.hitTestable().evaluate().toList();
  for (final box in boxes) {
    final boxRect = tester.getRect(find.byWidget(box.widget)).inflate(1);
    final card = find.ancestor(
      of: find.byWidget(box.widget),
      matching: find.byType(InkWell),
    );
    final cardRect = tester.getRect(card);
    expect(cardRect.contains(boxRect.topLeft), isTrue, reason: reason);
    expect(cardRect.contains(boxRect.bottomRight), isTrue, reason: reason);
    for (final finder in [
      find.descendant(of: card, matching: find.byType(Text)),
    ]) {
      for (final e in finder.evaluate()) {
        final r = tester.getRect(find.byWidget(e.widget));
        Rect ink = r;
        if (e.widget is Text) {
          // Only the painted text width counts (the line is centred).
          final p = e.renderObject! as RenderParagraph;
          final w = p.textSize.width;
          ink = Rect.fromCenter(center: r.center, width: w, height: r.height);
        }
        expect(
          ink.overlaps(boxRect),
          isFalse,
          reason: '$reason: box overlaps ${e.widget}',
        );
      }
    }
    // The icon and the title stay centred in the card (look unchanged).
    for (final type in [SvgPicture, Text]) {
      final c = tester.getRect(
        find.descendant(of: card, matching: find.byType(type)).first,
      );
      expect(
        (c.center.dx - cardRect.center.dx).abs(),
        lessThan(1.5),
        reason: '$reason: $type not centred',
      );
    }
  }
  return boxes.length;
}

/// The icon's drawn lines never touch the box: a ring 1.5-4 px around each
/// box (past the black frame's edge pixels) is plain white in the rendered screen.
Future<void> _expectRingClear(WidgetTester tester, String reason) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('cb-proof')),
  );
  final origin = tester.getTopLeft(find.byKey(const ValueKey('cb-proof')));
  final rects = [
    for (final e in _boxes.hitTestable().evaluate())
      tester.getRect(find.byWidget(e.widget)).shift(-origin),
  ];
  final data = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData();
    final w = image.width;
    image.dispose();
    return (bytes!, w);
  });
  final (bytes, w) = data!;
  for (final r in rects) {
    final ring = r.inflate(4);
    for (var x = ring.left.floor(); x <= ring.right.ceil(); x++) {
      for (var y = ring.top.floor(); y <= ring.bottom.ceil(); y++) {
        if (r.inflate(1.5).contains(Offset(x.toDouble(), y.toDouble()))) {
          continue;
        }
        if (x < 0 ||
            x >= w ||
            y < 0 ||
            (y * w + x) * 4 >= bytes.lengthInBytes) {
          continue;
        }
        final i = (y * w + x) * 4;
        final dark = bytes.getUint8(i) < 160 && bytes.getUint8(i + 1) < 160;
        if (dark && _shots.isNotEmpty) {
          await _shot(tester, 'fail-${reason.replaceAll(' ', '_')}');
        }
        expect(dark, isFalse, reason: '$reason: icon touches box at $x,$y');
      }
    }
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  if (_shots.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('cb-proof')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_shots/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  tearDown(() => DriverAppTexts.language = 'en');

  testWidgets('tapping the card or the box toggles; counter follows', (
    tester,
  ) async {
    DriverAppTexts.language = 'sv';
    final font = await _fonts();
    await _open(tester, font: font);
    final total = _boxes.evaluate().length;
    expect(find.text('$total av $total aktiva'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ride-type-box-on')),
      findsNWidgets(total),
    );
    await _shot(tester, 'ride-types-sv-all-on');

    // Tap the box itself.
    await tester.tap(find.byKey(const ValueKey('ride-type-box-on')).first);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('${total - 1} av $total aktiva'), findsOneWidget);
    expect(find.byKey(const ValueKey('ride-type-box-off')), findsOneWidget);

    // Tap a card body (its middle, not the box).
    await tester.tap(
      find
          .ancestor(
            of: find.byKey(const ValueKey('ride-type-box-on')).first,
            matching: find.byType(InkWell),
          )
          .first,
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('${total - 2} av $total aktiva'), findsOneWidget);
    await _shot(tester, 'ride-types-sv-two-off');

    // Semantics: checked follows the state.
    final handle = tester.ensureSemantics();
    final pet = tester.getSemantics(
      find
          .ancestor(
            of: find.text('Movera Pet'),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(pet.flagsCollection.isChecked, ui.CheckedState.isFalse);
    await tester.tap(find.text('Movera Pet'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    final petOn = tester.getSemantics(
      find
          .ancestor(
            of: find.text('Movera Pet'),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(petOn.flagsCollection.isChecked, ui.CheckedState.isTrue);
    handle.dispose();
  });

  for (final size in const [Size(390, 844), Size(375, 667)]) {
    testWidgets('all cards and header on one screen, no Save: $size', (
      tester,
    ) async {
      DriverAppTexts.language = 'sv';
      await _open(tester, size: size);
      expect(find.byType(ListView), findsNothing);
      expect(_boxes.hitTestable(), findsNWidgets(_boxes.evaluate().length));
      // Owner 2026-11-25: no Save button, each tap saves.
      expect(find.text('Spara inställningar'), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      for (final e in _boxes.evaluate()) {
        expect(
          tester.getRect(find.byWidget(e.widget)).bottom,
          lessThanOrEqualTo(size.height),
        );
      }
      expect(find.text('Välj dina reseval'), findsOneWidget);
    });
  }

  testWidgets('box: white with black frame; black check only when on', (
    tester,
  ) async {
    await _open(tester);
    const ink = Color(0xFF12201C);
    void expectBox(String key, {required bool check}) {
      final box = tester.widget<AnimatedContainer>(
        find.byKey(ValueKey<String>(key)).first,
      );
      final deco = box.decoration! as BoxDecoration;
      expect(deco.color, Colors.white);
      expect((deco.border! as Border).top.color, ink);
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(ValueKey<String>(key)).first,
          matching: find.byType(Icon),
        ),
      );
      expect(icon.color, ink);
      final opacity = tester.widget<AnimatedOpacity>(
        find.descendant(
          of: find.byKey(ValueKey<String>(key)).first,
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(opacity.opacity, check ? 1 : 0);
    }

    expectBox('ride-type-box-on', check: true);
    await tester.tap(find.byKey(const ValueKey('ride-type-box-on')).first);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expectBox('ride-type-box-off', check: false);
  });

  for (final lang in const ['sv', 'fr']) {
    testWidgets('screenshots $lang on/off', (tester) async {
      DriverAppTexts.language = lang;
      final font = await _fonts();
      await _open(tester, font: font);
      await _shot(tester, 'ride-types-v2-$lang-all-on');
      await tester.tap(find.byKey(const ValueKey('ride-type-box-on')).first);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('ride-type-box-on')).at(2));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await _shot(tester, 'ride-types-v2-$lang-two-off');
    });
  }

  for (final lang in ['sv', 'fr', 'en']) {
    for (final size in const [Size(320, 640), Size(390, 844)]) {
      for (final scale in const [1.0, 1.3, 1.6]) {
        testWidgets('box clear of icon and text: $lang $size x$scale', (
          tester,
        ) async {
          DriverAppTexts.language = lang;
          await _open(tester, size: size, scale: scale);
          expect(tester.takeException(), isNull);
          // Large text shows a list: check every card while scrolling.
          final list = find.byType(ListView);
          var seen = 0;
          for (var step = 0; step < 8; step++) {
            seen += _expectNoOverlap(tester, '$lang $size x$scale on $step');
            await _expectRingClear(tester, '$lang $size x$scale $step');
            final on = find.byKey(const ValueKey('ride-type-box-on'));
            if (on.hitTestable().evaluate().isNotEmpty) {
              await tester.tap(on.hitTestable().first);
              await tester.pump(const Duration(milliseconds: 400));
              await tester.pumpAndSettle();
              _expectNoOverlap(tester, '$lang $size x$scale off $step');
            }
            if (list.evaluate().isEmpty) break;
            await tester.drag(list, const Offset(0, -250));
            await tester.pumpAndSettle();
          }
          expect(seen, greaterThan(0));
        });
      }
    }
  }
}

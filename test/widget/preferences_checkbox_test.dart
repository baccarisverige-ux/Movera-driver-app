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
      find.descendant(of: card, matching: find.byType(SvgPicture)),
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
  }
  return boxes.length;
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
            final on = find.byKey(const ValueKey('ride-type-box-on'));
            if (on.hitTestable().evaluate().isNotEmpty) {
              await tester.tap(on.hitTestable().first);
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

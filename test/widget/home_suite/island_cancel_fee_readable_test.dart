// Launch bug (staging 2026-11-08 and 2026-11-19): after a rider's late
// cancel the driver's island said "Resenären avbokade · +35,…": the fee was
// cut off. The whole line must be readable on a 320 pt wide phone in
// English, Swedish and French. No text is changed.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/presentation/driver/home/components/digital_island.dart';
import 'package:movera/presentation/driver/home/components/home_island_notices.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';

import '_helpers.dart';

/// The test font ("Ahem") draws every letter as a full square, about twice
/// as wide as on a phone. The widths here must be the real ones, so the
/// phone's own font (Roboto, bold as on the island) is loaded from the
/// Flutter SDK.
bool _phoneFontLoaded = false;

Future<void> _loadPhoneFont(WidgetTester tester) async {
  if (_phoneFontLoaded) {
    return;
  }
  final sdk = Platform.environment['FLUTTER_ROOT'];
  final files = [
    '$sdk/bin/cache/dart-sdk/bin/resources/devtools/assets/packages/'
        'devtools_app_shared/fonts/Roboto/Roboto-Bold.ttf',
    '$sdk/bin/cache/artifacts/material_fonts/Roboto-Bold.ttf',
  ].map(File.new).where((f) => f.existsSync());
  expect(files, isNotEmpty, reason: 'Roboto-Bold.ttf not in the Flutter SDK');
  await tester.runAsync(() async {
    final bytes = await files.first.readAsBytes();
    final loader = FontLoader('Roboto')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  });
  _phoneFontLoaded = true;
}

void main() {
  registerCommonSetUp();

  const cases = <(String, String, String)>[
    ('en', 'SEK', 'Rider cancelled · +35,00 kr'),
    ('sv', 'SEK', 'Resenären avbokade · +35,00 kr'),
    ('fr', 'EUR', 'Le passager a annulé · +35,00 €'),
  ];

  for (final (language, currency, words) in cases) {
    testWidgets('late cancel on a 320 pt phone ($language): the island shows '
        'the whole line with the fee, nothing cut off', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(() => DriverAppTexts.language = 'en');
      DriverAppTexts.language = language;
      await _loadPhoneFont(tester);
      await pumpHome(tester, const Size(320, 640));
      await wakeIsland(tester);

      final notice = HomeIslandNotices.riderCancelledWithFee(
        Money(minorUnits: 3500, currency: currency),
      );
      // The words themselves stay as they are.
      expect(notice.title, words);
      IslandMessages.show(notice);
      // The island resizes (680 ms) and writes the words in (640 ms).
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final face = find.byType(DigitalMessageFace);
      final line = find.descendant(of: face, matching: find.text(words));
      expect(line, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: line, matching: find.byType(RichText)),
      );
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: 'the island cuts "$words" off with "…"',
      );
      // The words stay inside the island and the island inside the phone.
      final island = tester.getRect(find.byType(DigitalIslandShell));
      final text = tester.getRect(line);
      expect(island.left, greaterThanOrEqualTo(0));
      expect(island.right, lessThanOrEqualTo(320));
      expect(text.left, greaterThanOrEqualTo(island.left));
      expect(text.right, lessThanOrEqualTo(island.right));
      expect(text.top, greaterThanOrEqualTo(island.top));
      expect(text.bottom, lessThanOrEqualTo(island.bottom));
      expectNoException(tester);
    });
  }

  testWidgets('a short island message keeps one line at the normal size', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _loadPhoneFont(tester);
    await pumpHome(tester, const Size(320, 640));
    await wakeIsland(tester);
    IslandMessages.show(HomeIslandNotices.riderCancelled);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final line = find.descendant(
      of: find.byType(DigitalMessageFace),
      matching: find.text('Rider cancelled'),
    );
    final text = tester.widget<Text>(line);
    expect(text.maxLines, 1);
    expect(text.style?.fontSize, messageStyle.fontSize);
    expectNoException(tester);
  });
}

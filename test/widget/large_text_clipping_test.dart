import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/presentation/driver/my%20wallet/wallet.dart';
import 'package:movera/widgets/movera_radar_orb.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Release evidence b8bd860, 200 % text (findings F1-F3): the radar orb's
// hint fell out of the disc, the accept orb's title was cut to "Acce…",
// and Wallet broke "Utbetalningsdatum" in the middle of the word.
Widget _at200(Widget child) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: const TextScaler.linear(2)),
    child: child!,
  ),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => DriverAppTexts.language = 'en');

  Future<void> expectOrbFits(
    WidgetTester tester, {
    required String title,
    required String status,
    required String subtitle,
    bool offer = false,
  }) async {
    await tester.pumpWidget(
      _at200(
        MoveraRadarOrb(
          title: title,
          status: status,
          subtitle: subtitle,
          offer: offer,
          onTap: () {},
        ),
      ),
    );
    await tester.pump();
    final disc = tester.getRect(find.byType(Ink));
    for (final text in [title, status, subtitle]) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: '"$text" is cut with an ellipsis at 200 % text',
      );
      final rect = tester.getRect(find.text(text));
      expect(
        rect.top >= disc.top && rect.bottom <= disc.bottom,
        isTrue,
        reason: '"$text" ($rect) leaves the disc ($disc) at 200 % text',
      );
    }
  }

  testWidgets(
    'F1: the Home radar orb keeps its hint inside the disc at 200 %',
    (tester) async {
      await expectOrbFits(
        tester,
        title: 'Radar',
        status: 'AV',
        subtitle: 'Tryck för att söka',
      );
    },
  );

  testWidgets('F2: the accept orb shows the whole word at 200 %', (
    tester,
  ) async {
    await expectOrbFits(
      tester,
      title: 'Acceptera',
      status: 'TA',
      subtitle: 'Tryck för att acceptera',
      offer: true,
    );
  });

  testWidgets('F3: Wallet never breaks the payout-date line inside a word', (
    tester,
  ) async {
    DriverAppTexts.language = 'sv';
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_at200(const WalletScreen()));
    await tester.pump();
    const line = 'Utbetalningsdatum saknas';
    final paragraph = tester.renderObject<RenderParagraph>(find.text(line));
    final style = (paragraph.text as TextSpan).style;
    final word = TextPainter(
      text: TextSpan(text: 'Utbetalningsdatum', style: style),
      textDirection: TextDirection.ltr,
      textScaler: paragraph.textScaler,
    )..layout();
    expect(
      paragraph.constraints.maxWidth,
      greaterThanOrEqualTo(word.width),
      reason: 'the longest word must fit on one line, else Flutter splits it',
    );
    expect(tester.takeException(), isNull);
  });
}

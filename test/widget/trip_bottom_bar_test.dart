import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/accept%20ride/trip_bottom_bar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';

Widget _bar({
  String instruction = 'Pick up Michael',
  String address = 'Köpmangatan 12',
  VoidCallback? onPreferences,
  VoidCallback? onTap,
}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: 320,
      child: TripBottomBar(
        instruction: instruction,
        address: address,
        onPreferences: onPreferences ?? () {},
        onTap: onTap ?? () {},
      ),
    ),
  ),
);

void main() {
  testWidgets('Bar shows only the next step, its address and preferences', (
    tester,
  ) async {
    var preferences = 0, details = 0;
    await tester.pumpWidget(
      _bar(onPreferences: () => preferences++, onTap: () => details++),
    );
    expect(find.text('Pick up Michael'), findsOneWidget);
    expect(find.text('Köpmangatan 12'), findsOneWidget);
    // Nothing else: no times, distances, progress line or details button.
    expect(find.byType(Text), findsNWidgets(2));
    expect(find.byTooltip('Trip details'), findsNothing);
    final icon = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(
      (icon.bytesLoader as SvgAssetLoader).assetName,
      AppAssets.navMenuBranch,
    );

    await tester.tap(find.byTooltip('Trip settings'));
    await tester.tap(find.byKey(const ValueKey('trip-bar-details')));
    expect(preferences, 1);
    expect(details, 1);
    expect(tester.getSize(find.byType(TripBottomBar)).height, 76);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Text sits on the left, preferences on the right', (
    tester,
  ) async {
    await tester.pumpWidget(_bar());
    final text = tester.getTopLeft(find.text('Pick up Michael'));
    final button = tester.getCenter(find.byTooltip('Trip settings'));
    expect(text.dx, closeTo(20, 1));
    expect(button.dx, greaterThan(260));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Long text stays on one line each', (tester) async {
    await tester.pumpWidget(
      _bar(
        instruction: 'Waiting for Maximiliana-Charlotte at stop 2',
        address: 'Drottning Kristinas väg 61, 114 28 Stockholm, Sverige',
      ),
    );
    for (final key in ['trip-bar-instruction', 'trip-bar-next-address']) {
      final text = tester.widget<Text>(find.byKey(ValueKey(key)));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    }
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/accept%20ride/trip_island.dart';
import 'package:movera/presentation/driver/accept%20ride/trip_top_reveal.dart';

Widget _island(String? status, {VoidCallback? onMenu, VoidCallback? onSearch}) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: TripIsland(
          status: status,
          onMenu: onMenu,
          onSearch: onSearch,
          lastTripLabel: '126 kr',
        ),
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('Trip island opens on the trip step; a tap closes it', (
    tester,
  ) async {
    await tester.pumpWidget(_island('To pickup'));
    await _settle(tester);
    expect(find.text('To pickup'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('trip-island-middle')));
    await _settle(tester);
    expect(find.text('To pickup'), findsNothing);
    expect(find.text('•••• kr'), findsOneWidget);

    // A new step shows again.
    await tester.pumpWidget(_island('Waiting for Angelica'));
    await _settle(tester);
    expect(find.text('Waiting for Angelica'), findsOneWidget);
  });

  testWidgets('Menu and search work on the trip island', (tester) async {
    var menu = 0;
    var search = 0;
    await tester.pumpWidget(
      _island(null, onMenu: () => menu++, onSearch: () => search++),
    );
    await _settle(tester);
    await tester.tap(find.byTooltip('Menu'));
    await tester.tap(find.byKey(const ValueKey<String>('trip-island-search')));
    expect(menu, 1);
    expect(search, 1);
  });

  for (final width in const [320.0, 390.0]) {
    testWidgets('UI-12 Menu and Search are 48x48 at $width wide, text 130 %', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 640);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.3),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: TripIsland(onMenu: () {}, onSearch: () {}, lastTripLabel: '126 kr'),
            ),
          ),
        ),
      );
      await _settle(tester);
      final menu = tester.getRect(
        find.descendant(of: find.byTooltip('Menu'), matching: find.byType(InkWell)),
      );
      final search = tester.getRect(
        find.byKey(const ValueKey<String>('trip-island-search')),
      );
      for (final target in [menu, search]) {
        expect(target.width, greaterThanOrEqualTo(47.99));
        expect(target.height, greaterThanOrEqualTo(47.99));
        expect(target.left, greaterThanOrEqualTo(0));
        expect(target.right, lessThanOrEqualTo(width));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Money screens cycle and hide again after 5 s', (tester) async {
    await tester.pumpWidget(_island(null));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey<String>('trip-island-middle')));
    await _settle(tester);
    expect(find.text('LAST TRIP'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await _settle(tester);
    expect(find.text('•••• kr'), findsOneWidget);
  });

  testWidgets('Revealed island goes back up on a touch anywhere else', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: Colors.blueGrey)),
            Align(
              alignment: Alignment.topCenter,
              child: TripTopReveal(
                status: 'To pickup',
                child: Container(height: 120, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    ));
    await tester.drag(
      find.byKey(const ValueKey<String>('trip-top-reveal')),
      const Offset(0, 60),
    );
    await _settle(tester);
    expect(find.byKey(const ValueKey<String>('trip-top-island')), findsOneWidget);

    // A touch on the island's middle keeps it open (it closes the message).
    await tester.tap(find.byKey(const ValueKey<String>('trip-island-middle')));
    await _settle(tester);
    expect(find.byKey(const ValueKey<String>('trip-top-island')), findsOneWidget);

    // A touch on the map puts the card back.
    await tester.tapAt(const Offset(200, 600));
    await _settle(tester);
    expect(find.byKey(const ValueKey<String>('trip-top-island')), findsNothing);
  });
}

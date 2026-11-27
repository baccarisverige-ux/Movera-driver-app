import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/l10n/app_localizations.dart';
import 'package:movera/presentation/driver/content/driver_online_strip.dart';

const _shots = String.fromEnvironment('STRIP_SHOTS');

Future<void> _pump(
  WidgetTester tester,
  DriverSessionController session,
  GlobalKey<NavigatorState> nav,
  ValueNotifier<bool> sos,
) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 47 * 3);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: nav,
      locale: const Locale('sv'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => RepaintBoundary(
        key: const ValueKey('shot'),
        child: Column(
          children: [
            DriverOnlineStrip(
              session: session,
              navigatorKey: nav,
              sosOpen: sos,
            ),
            Expanded(child: child!),
          ],
        ),
      ),
      home: const Scaffold(body: Center(child: Text('Home map'))),
    ),
  );
}

Future<void> _shot(WidgetTester tester, String name) async {
  if (_shots.isEmpty) return;
  await expectLater(
    find.byKey(const ValueKey('shot')),
    matchesGoldenFile('$_shots/$name.png'),
  );
}

void main() {
  late DriverSessionController session;
  late GlobalKey<NavigatorState> nav;
  late ValueNotifier<bool> sos;
  setUp(() {
    session = DriverSessionController();
    nav = GlobalKey<NavigatorState>();
    sos = ValueNotifier<bool>(false);
  });

  double stripHeight(WidgetTester t) =>
      t.getSize(find.byType(DriverOnlineStrip)).height;

  testWidgets('offline: no text, normal height; online: text, +18', (
    tester,
  ) async {
    await _pump(tester, session, nav, sos);
    expect(find.text('Du är online'), findsNothing);
    expect(stripHeight(tester), 47);
    await _shot(tester, 'offline');
    session.setOnline(true);
    await tester.pump();
    expect(find.text('Du är online'), findsOneWidget);
    expect(stripHeight(tester), 47 + 18);
    await _shot(tester, 'online-home');
    session.setOnline(false);
    await tester.pump();
    expect(find.text('Du är online'), findsNothing);
    expect(stripHeight(tester), 47);
  });

  testWidgets('tap while online pops to the first route', (tester) async {
    await _pump(tester, session, nav, sos);
    session.setOnline(true);
    nav.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Center(child: Text('Wallet'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Wallet'), findsOneWidget);
    await _shot(tester, 'online-other-screen');
    await tester.tap(find.text('Du är online'));
    await tester.pumpAndSettle();
    expect(find.text('Wallet'), findsNothing);
    expect(find.text('Home map'), findsOneWidget);
  });

  testWidgets('tap ignored while SOS is open', (tester) async {
    await _pump(tester, session, nav, sos);
    session.setOnline(true);
    sos.value = true;
    nav.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Center(child: Text('SOS'))),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Du är online'));
    await tester.pumpAndSettle();
    expect(find.text('SOS'), findsOneWidget);
  });

  testWidgets('status bar icons are white (light style)', (tester) async {
    await _pump(tester, session, nav, sos);
    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.descendant(
        of: find.byType(DriverOnlineStrip),
        matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      ),
    );
    expect(region.value.statusBarBrightness, Brightness.dark);
    expect(region.value.statusBarIconBrightness, Brightness.light);
    final colored = tester.widget<ColoredBox>(
      find
          .descendant(
            of: find.byType(DriverOnlineStrip),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(colored.color, Colors.black);
  });

  test('main.dart stays under 1500 lines', () {
    expect(File('lib/main.dart').readAsLinesSync().length, lessThan(1500));
  });
}

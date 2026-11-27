import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/l10n/app_localizations.dart';
import 'package:movera/presentation/driver/content/driver_online_strip.dart';
import 'package:movera/presentation/driver/safety%20toolkits/safety_toolkits.dart';

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

  testWidgets('tap during a trip keeps the trip screen; online still shows', (
    tester,
  ) async {
    await _pump(tester, session, nav, sos);
    session.setOnline(true);
    session.beginTrip('trip-1');
    nav.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const PopScope(
          canPop: false,
          child: Scaffold(body: Center(child: Text('Trip screen'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Du är online'), findsOneWidget);
    await tester.tap(find.text('Du är online'));
    await tester.pumpAndSettle();
    expect(find.text('Trip screen'), findsOneWidget);
  });

  testWidgets('tap with the real safety sheet open keeps it open', (
    tester,
  ) async {
    await _pump(tester, session, nav, DriverOnlineStrip.sosScreenOpen);
    session.setOnline(true);
    unawaited(showSafetyToolKitSheet<void>(nav.currentContext!));
    await tester.pumpAndSettle();
    expect(find.byType(SafetyToolKits), findsOneWidget);
    expect(DriverOnlineStrip.sosScreenOpen.value, isTrue);
    await tester.tap(find.text('Du är online'));
    await tester.pumpAndSettle();
    expect(find.byType(SafetyToolKits), findsOneWidget);
  });

  testWidgets('tap with the real SOS screen (a page) keeps it open', (
    tester,
  ) async {
    await _pump(tester, session, nav, DriverOnlineStrip.sosScreenOpen);
    session.setOnline(true);
    nav.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const SafetyToolKits()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Du är online'));
    await tester.pumpAndSettle();
    expect(find.byType(SafetyToolKits), findsOneWidget);
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(DriverOnlineStrip.sosScreenOpen.value, isFalse);
  });

  testWidgets('tap never answers a non-dismissible dialog', (tester) async {
    await _pump(tester, session, nav, sos);
    session.setOnline(true);
    bool? answer = true;
    var closed = false;
    unawaited(
      showDialog<bool>(
        context: nav.currentContext!,
        barrierDismissible: false,
        builder: (_) => const PopScope(
          canPop: false,
          child: AlertDialog(title: Text('Unresolved trip')),
        ),
      ).then((v) {
        answer = v;
        closed = true;
      }),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Du är online'));
    await tester.pumpAndSettle();
    expect(find.text('Unresolved trip'), findsOneWidget);
    expect(closed, isFalse);
    expect(answer, isTrue);
  });

  testWidgets('the whole strip is a button, status bar included', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, session, nav, sos);
    session.setOnline(true);
    nav.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Center(child: Text('Wallet'))),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(300, 10));
    await tester.pumpAndSettle();
    expect(find.text('Wallet'), findsNothing);
    // Semantics of the strip alone (in the test harness the routes below
    // hide semantics painted before them).
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('sv'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DriverOnlineStrip(
            session: session,
            navigatorKey: GlobalKey<NavigatorState>(),
            sosOpen: sos,
          ),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Du är online')),
      matchesSemantics(
        isButton: true,
        hasTapAction: true,
        label: 'Du är online',
      ),
    );
    handle.dispose();
  });

  testWidgets('large text grows the strip instead of clipping', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(tester, session, nav, sos);
    session.setOnline(true);
    await tester.pump();
    expect(stripHeight(tester), greaterThan(47 + 18));
    expect(tester.takeException(), isNull);
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

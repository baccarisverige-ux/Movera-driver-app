import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/deferred_screens.dart';
import 'package:movera/widgets/custom_google_map.dart';
import 'package:movera/widgets/deferred_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owner 2026-11-03, decisions/servers-test-live.md "Load time" LT-4:
/// Wallet, Ride history, Chat, Google Maps and Google sign-in load when they
/// are first needed; the first open shows a short spinner, nothing removed.
void main() {
  setUpAll(loadDeferredScreens);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // By name: in the test VM a class reached through a deferred import is
  // not always the same Type object as the directly imported one.
  Finder screenNamed(String name) => find.byWidgetPredicate(
    (w) => w.runtimeType.toString() == name,
    skipOffstage: false,
  );

  Future<void> open(WidgetTester tester, Widget Function() screen) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const ValueKey('open'),
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => screen())),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pump();
    // The short spinner first (a frame or two here), then the screen.
    // (skipOffstage false: a pushed route's first frame is built offstage.)
    final loading = find.byKey(
      const ValueKey('deferred-screen-loading'),
      skipOffstage: false,
    );
    for (var i = 0; i < 20 && loading.evaluate().isNotEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(loading, findsNothing);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
  }

  testWidgets('Wallet still opens, through its loader', (tester) async {
    await open(tester, walletScreen);
    expect(find.byType(DeferredScreen), findsOneWidget);
    expect(screenNamed('WalletScreen'), findsOneWidget);
    expect(find.byKey(const ValueKey('deferred-screen-loading')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Ride history still opens, through its loader', (tester) async {
    await open(tester, rideHistoryScreen);
    expect(screenNamed('DriverRideHistory'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });

  testWidgets('Chat still opens, through its loader', (tester) async {
    await open(tester, () => chatScreen(riderDisplayName: 'Karin'));
    expect(screenNamed('Chat'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the first open shows a short spinner, then the screen', (
    tester,
  ) async {
    final loading = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: DeferredScreen(
          load: () => loading.future,
          builder: (_) => const Text('screen'),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('deferred-screen-loading')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('screen'), findsNothing);
    loading.complete();
    await tester.pump();
    expect(find.text('screen'), findsOneWidget);
  });

  testWidgets('a failed download can be tried again', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: DeferredScreen(
          load: () async {
            calls += 1;
            if (calls == 1) throw StateError('offline');
          },
          builder: (_) => const Text('screen'),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('deferred-screen-retry')), findsOneWidget);
    // and a back button to leave
    expect(find.byKey(const ValueKey('deferred-screen-back')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('deferred-screen-retry')));
    await tester.pump();
    await tester.pump();
    expect(find.text('screen'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('the first map asks the page for Google Maps', (tester) async {
    final probe = CustomGoogleMap.mapsReadyProbe;
    final request = CustomGoogleMap.requestMaps;
    var asked = 0;
    CustomGoogleMap.mapsReadyProbe = () => false;
    CustomGoogleMap.requestMaps = () => asked += 1;
    addTearDown(() {
      CustomGoogleMap.mapsReadyProbe = probe;
      CustomGoogleMap.requestMaps = request;
    });
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CustomGoogleMap())),
    );
    expect(asked, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('the page loads Google Maps and Google sign-in only on request', () {
    final html = File('web/index.html').readAsStringSync();
    // No Maps script tag at start; the loader adds it once.
    expect(html, isNot(contains('<script src="https://maps.googleapis.com')));
    expect(html, contains('window.moveraLoadGoogleMaps = function()'));
    // The google_sign_in plugin's script is held back.
    expect(html, contains("'https://accounts.google.com/gsi/client'"));
    expect(html, contains('window.moveraLoadGoogleSignIn = function()'));
  });

  test('only deferred_screens.dart imports Wallet, Ride history and Chat', () {
    final direct = RegExp(
      r"import '[^']*(my%20wallet/wallet|ride%20history/ride_history|"
      r"common/chat/chat)\.dart'(?!\s*deferred)",
    );
    final offenders = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            direct.hasMatch(file.readAsStringSync()))
          file.path,
    ];
    expect(offenders, isEmpty);
  });
  // B9 "Fast app start" (owner 2026-11-04).
  testWidgets('Settings still opens, through its loader', (tester) async {
    await open(tester, () => settingsScreen());
    expect(screenNamed('Settings'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Documents still opens, through its loader', (tester) async {
    await open(tester, () => driverDocumentsScreen());
    expect(screenNamed('DriverDocuments'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Help still opens, through its loader', (tester) async {
    await open(tester, () => supportScreen());
    expect(screenNamed('SupportScreen'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

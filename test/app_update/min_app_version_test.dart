import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/app_update/min_app_version.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/content/driver_content.dart';
import 'package:movera/core/content/driver_content_store.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/l10n/app_localizations.dart';
import 'package:movera/presentation/driver/content/driver_content_gate.dart';

/// Contract v0.18.154 P16c (`contract.json#appUpdate`; owner 2026-11-21
/// "Yes, build it now (Recommended)"). Fails on main: there is no minimum
/// per platform, so nothing blocks and no X-App-Version is sent.
void main() {
  const store = 'https://play.google.com/store/apps/details?id=example.fake';
  Map<String, Object?> doc(Object? android, {Object? ios, Object? url}) => {
    'minimumVersion': '9.0.0',
    'latestVersion': '9.0.0',
    'minVersion': {'android': android, 'ios': ios},
    'storeUrls': {'android': url, 'ios': null},
  };

  setUp(() {
    MinAppVersion.reset();
    MinAppVersion.running = const AppVersion(1, 4, 0);
    MinAppVersion.platform = 'android';
    MinAppVersion.tripChecked.value = true;
  });
  tearDown(MinAppVersion.reset);

  group('rule', () {
    test('below blocks; equal, above, the other platform and off do not', () {
      MinAppVersion.accept(doc('1.4.1'));
      expect(MinAppVersion.required, isTrue);
      MinAppVersion.accept(doc('1.4.0'));
      expect(MinAppVersion.required, isFalse);
      MinAppVersion.accept(doc('1.3.9'));
      expect(MinAppVersion.required, isFalse);
      MinAppVersion.accept(doc(null, ios: '5.0.0'));
      expect(MinAppVersion.required, isFalse);
      MinAppVersion.accept(null);
      expect(MinAppVersion.required, isFalse);
    });

    test('the older keys and bad values never block', () {
      MinAppVersion.accept({
        'minimumVersion': '9.0.0',
        'latestVersion': '9.9.9',
      });
      expect(MinAppVersion.required, isFalse);
      for (final bad in ['1.5', 'v2.0.0', 2, '2.0.0-beta']) {
        MinAppVersion.accept(doc(bad));
        expect(MinAppVersion.required, isFalse, reason: '$bad');
      }
    });

    test('a dev build or the web is never blocked and sends no header', () {
      MinAppVersion.accept(doc('9.0.0'));
      expect(MinAppVersion.headers, {
        'X-App-Version': '1.4.0',
        'X-App-Platform': 'android',
      });
      MinAppVersion.running = null;
      expect(MinAppVersion.required, isFalse);
      expect(MinAppVersion.headers, isEmpty);
      MinAppVersion.running = const AppVersion(1, 0, 0);
      MinAppVersion.platform = null;
      expect(MinAppVersion.required, isFalse);
      expect(MinAppVersion.headers, isEmpty);
    });

    test('a 426 app_update_required blocks until the next document', () {
      MinAppVersion.markServerSaid({'code': 'conflict', 'reason': 'other'});
      expect(MinAppVersion.required, isFalse);
      MinAppVersion.markServerSaid({
        'code': 'upgrade_required',
        'reason': 'app_update_required',
      });
      expect(MinAppVersion.required, isTrue);
      MinAppVersion.accept(doc(null));
      expect(MinAppVersion.required, isFalse);
    });

    test('the store link: the zone\'s, else the built-in one', () {
      MinAppVersion.accept(doc('2.0.0', url: store));
      expect(
        MinAppVersion.storeUri('https://fallback.example/x'),
        Uri.parse(store),
      );
      MinAppVersion.accept(doc('2.0.0', url: 'http://not-https.example'));
      expect(
        MinAppVersion.storeUri('https://fallback.example/x'),
        Uri.parse('https://fallback.example/x'),
      );
    });
  });

  group('screen', () {
    Future<DriverSessionController> pumpGate(
      WidgetTester tester, {
      bool onTrip = false,
      List<Uri>? opened,
    }) async {
      DriverAppTexts.language = 'en';
      final session = DriverSessionController(initialOnline: true);
      if (onTrip) session.beginTrip('trip_1');
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => DriverContentGate(
            session: session,
            navigatorKey: key,
            store: DriverContentStore(cache: MemoryDriverContentCache()),
            openStore: (uri) async {
              opened?.add(uri);
              return true;
            },
            child: child!,
          ),
          home: const Scaffold(body: Text('home')),
        ),
      );
      await tester.pump();
      return session;
    }

    const screen = ValueKey<String>('min-version-required');

    testWidgets(
      'below: "Update Movera to continue"; Update opens the zone store',
      (tester) async {
        MinAppVersion.accept(doc('1.5.0', url: store));
        final opened = <Uri>[];
        await pumpGate(tester, opened: opened);
        expect(find.byKey(screen), findsOneWidget);
        expect(find.text('Update Movera to continue'), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('min-version-sos')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('min-version-update')),
        );
        await tester.pump();
        expect(opened, [Uri.parse(store)]);
      },
    );

    testWidgets('it goes away only when a document says the version is OK', (
      tester,
    ) async {
      MinAppVersion.accept(doc('1.5.0'));
      await pumpGate(tester);
      expect(find.byKey(screen), findsOneWidget);
      MinAppVersion.accept(doc('1.4.0'));
      await tester.pump();
      expect(find.byKey(screen), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('never during a trip: a small line, the block after it', (
      tester,
    ) async {
      MinAppVersion.accept(doc('1.5.0'));
      final session = await pumpGate(tester, onTrip: true);
      expect(find.byKey(screen), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('content-update-trip')),
        findsOneWidget,
      );
      session.endTrip();
      await tester.pump();
      expect(find.byKey(screen), findsOneWidget);
    });

    testWidgets('equal or no minimum: nothing shown', (tester) async {
      MinAppVersion.accept(doc('1.4.0'));
      await pumpGate(tester);
      expect(find.byKey(screen), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('content-update-trip')),
        findsNothing,
      );
    });

    testWidgets('cold start: no block until the active-trip check answered', (
      tester,
    ) async {
      MinAppVersion.tripChecked.value = false;
      MinAppVersion.accept(doc('1.5.0'));
      await pumpGate(tester);
      expect(find.byKey(screen), findsNothing);
      MinAppVersion.tripChecked.value = true;
      await tester.pump();
      expect(find.byKey(screen), findsOneWidget);
    });

    testWidgets(
      'cold start mid-trip: the trip comes first, the block after it',
      (tester) async {
        MinAppVersion.tripChecked.value = false;
        MinAppVersion.accept(doc('1.5.0'));
        final session = await pumpGate(tester);
        expect(find.byKey(screen), findsNothing);
        session.beginTrip('trip_restored');
        await tester.pump();
        expect(find.byKey(screen), findsNothing);
        session.endTrip();
        await tester.pump();
        expect(find.byKey(screen), findsOneWidget);
      },
    );
  });

  test('a 426 with an unreadable body or another reason does not block', () {
    MinAppVersion.markServerSaid(null);
    MinAppVersion.markServerSaid({'reason': 'other'});
    expect(MinAppVersion.required, isFalse);
  });
}

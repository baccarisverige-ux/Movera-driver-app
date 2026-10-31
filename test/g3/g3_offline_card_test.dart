import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/driver/driver_home_notices.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/location/driver_start_position.dart';
import 'package:movera/core/phone/phone_checks.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/home/components/home_offline_card.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:movera/widgets/movera_radar_orb.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

/// Owner 2026-10-31 "new set offline message" (Rules decisions/driver-g3.md,
/// "Reason + phone check"): set offline without asking, the Home sheet
/// shows "You're offline" in place of its icons, with the real reason,
/// "Check my phone" (✓/✗ with a fix), Go online and OK; it goes when he
/// goes online, taps OK, or after 2 minutes.
void main() {
  final previous = DriverRuntimeConfig.current;
  final previousChecks = PhoneChecks.current;
  late _FakeChecks checks;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DriverStartPosition.clearMemory();
    IslandMessages.reset();
    ScheduledRideStore.reset();
    DriverAreaWatch.instance.reset();
    DriverSetOfflineNotice.instance.clear();
    checks = _FakeChecks();
    PhoneChecks.current = checks;
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      simulatedArrival: false,
      externalRouting: false,
      skipAccountActivation: true,
      liveMapTicker: false,
      reservationPopup: false,
      islandHint: false,
    );
  });
  tearDown(() {
    DriverRuntimeConfig.current = previous;
    PhoneChecks.current = previousChecks;
    LiveDriverServices.instance = null;
    DriverAppTexts.language = 'en';
  });

  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  Future<void> frames(WidgetTester tester, [int count = 20]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<({DriverSessionController session, LiveDriverServices? live})>
  pumpHome(
    WidgetTester tester, {
    Future<http.Response> Function(http.Request request)? answer,
    DriverAccountSession Function(http.Client client)? account,
  }) async {
    LiveDriverServices? live;
    DriverAccountSession? accountSession;
    if (answer != null) {
      final tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
      final client = MockClient(answer);
      final origin = Uri.parse('https://api.test.movera.se');
      live = LiveDriverServices.instance = LiveDriverServices(
        client: client,
        origin: origin,
        tokens: tokens,
        api: ApiClient(client: client, baseUri: origin, tokens: tokens),
        location: _Gps(),
        locationEvery: const Duration(hours: 1),
      );
      accountSession = account?.call(client);
    }
    final maps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = DriverSessionController();
    final Widget home = DriverHome(
      sessionController: session,
      dispatchRepository: live?.dispatch,
      locationRepository: _Gps(),
      activeRideRepository: MemoryActiveRideRepository(),
    );
    await tester.pumpWidget(
      LayoutViewport(
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          minTextAdapt: true,
          splitScreenMode: true,
          useInheritedMediaQuery: true,
          builder: (_, _) => MaterialApp(
            home: accountSession == null
                ? home
                : DriverRuntimeScope(
                    session: session,
                    homeBuilder: () => const SizedBox(),
                    account: accountSession,
                    child: home,
                  ),
          ),
        ),
      ),
    );
    await frames(tester);
    return (session: session, live: live);
  }

  Future<void> leave(WidgetTester tester, LiveDriverServices? live) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await live?.dispose();
    await frames(tester);
  }

  final card = find.byKey(const ValueKey<String>('home-offline-card'));
  Finder text(String value) =>
      find.descendant(of: card, matching: find.text(value));

  group('on Home', () {
    testWidgets('app restarted: "You\'re offline" with the reason, in the '
        'sheet over its icons and the radar; the old line is gone', (
      tester,
    ) async {
      await pumpHome(tester);
      expect(card, findsNothing);
      DriverSetOfflineNotice.instance.show(
        reason: DriverOfflineReason.appRestart,
      );
      await frames(tester, 3);
      expect(card, findsOneWidget);
      expect(text("You're offline"), findsOneWidget);
      expect(
        text('The app was restarted while you were online.'),
        findsOneWidget,
      );
      expect(
        find.text('You were set offline – tap to go online again'),
        findsNothing,
      );
      // In the sheet: from the bottom of the screen, full width, over the
      // dock's icons and the radar.
      final rect = tester.getRect(card);
      expect(rect.bottom, 844);
      expect(rect.left, 0);
      expect(rect.right, 390);
      // The radar (Go online) is in the card now, not over it.
      expect(find.byType(MoveraRadarOrb), findsNothing);
      expect(rect.top, lessThan(844 - 108), reason: 'taller than the dock');
      await leave(tester, null);
    });

    testWidgets('OK hides the card', (tester) async {
      final home = await pumpHome(tester);
      DriverSetOfflineNotice.instance.show(
        reason: DriverOfflineReason.appRestart,
      );
      await frames(tester, 3);
      await tester.tap(find.byKey(const ValueKey<String>('offline-card-ok')));
      await frames(tester, 3);
      expect(card, findsNothing);
      expect(DriverSetOfflineNotice.instance.value, isFalse);
      expect(home.session.isOnline || home.session.isGoingOnline, isFalse);
      await leave(tester, null);
    });

    testWidgets('Go online hides the card and goes online', (tester) async {
      final home = await pumpHome(tester);
      DriverSetOfflineNotice.instance.show(
        reason: DriverOfflineReason.appRestart,
      );
      await frames(tester, 3);
      await tester.tap(
        find.byKey(const ValueKey<String>('offline-card-go-online')),
      );
      await frames(tester, 3);
      expect(home.session.isGoingOnline || home.session.isOnline, isTrue);
      expect(card, findsNothing);
      await frames(tester, 30);
      await leave(tester, null);
    });

    testWidgets('going online another way hides the card too', (tester) async {
      final home = await pumpHome(tester);
      DriverSetOfflineNotice.instance.show();
      await frames(tester, 3);
      expect(card, findsOneWidget);
      home.session.setOnline(true);
      await frames(tester, 3);
      expect(card, findsNothing);
      await frames(tester, 30);
      await leave(tester, null);
    });

    testWidgets('the card goes by itself after 2 minutes', (tester) async {
      await pumpHome(tester);
      DriverSetOfflineNotice.instance.show(
        reason: DriverOfflineReason.appRestart,
      );
      await frames(tester, 3);
      await tester.pump(const Duration(seconds: 115));
      expect(card, findsOneWidget, reason: 'still there before 2 minutes');
      await tester.pump(const Duration(seconds: 6));
      await frames(tester, 3);
      expect(card, findsNothing);
      expect(DriverSetOfflineNotice.instance.value, isFalse);
      await leave(tester, null);
    });

    testWidgets('a new reason on a shown card replaces the text', (
      tester,
    ) async {
      await pumpHome(tester);
      DriverSetOfflineNotice.instance.show();
      await frames(tester, 3);
      expect(text('Movera set you offline.'), findsOneWidget);
      DriverSetOfflineNotice.instance.show(
        reason: DriverOfflineReason.missedOffers,
        count: 10,
      );
      await frames(tester, 3);
      expect(
        text('10 offers in a row were missed or declined.'),
        findsOneWidget,
      );
      await leave(tester, null);
    });

    testWidgets('G3-R1 live: the server set him offline and its bell notice '
        'set_offline says why: "no position for 5 minutes"', (tester) async {
      DriverRuntimeConfig.current = const DriverRuntimeConfig(
        simulatedArrival: false,
        externalRouting: false,
        skipAccountActivation: true,
        liveMapTicker: false,
        reservationPopup: false,
        islandHint: false,
        authRequired: true,
      );
      var status = 'offline';
      var version = 3;
      var noticeSent = false;
      final home = await pumpHome(
        tester,
        answer: (request) async => switch ((request.method, request.url.path)) {
          ('GET', '/api/v1/driver/profile') => json(200, {
            'driverId': 'd1',
            'accountStatus': 'active',
            'firstName': 'Amira',
            'country': 'SE',
            'onlineStatus': status,
            'version': version,
          }),
          ('POST', '/api/v1/driver/availability') => json(200, {
            'driverId': 'd1',
            'accountStatus': 'active',
            'onlineStatus': status = 'online',
            'version': version = 4,
          }),
          ('GET', '/api/v1/notifications') => json(200, {
            'items': [
              if (noticeSent)
                {
                  'notificationId': 'n1',
                  'audience': 'driver',
                  'kind': 'set_offline',
                  'title': 'You were set offline',
                  'body': 'Tap to go online again',
                  'at': DateTime.now().toUtc().toIso8601String(),
                  'read': false,
                },
            ],
          }),
          _ => http.Response('', 503),
        },
        account: (client) => DriverAccountSession(
          repository: DriverAccountRepository(
            ApiClient(
              client: client,
              baseUri: Uri.parse('https://api.test.movera.se'),
              tokens: MemoryTokenStore()..save(access: 'a1', refresh: 'r1'),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(MoveraRadarOrb).last);
      await frames(tester, 40);
      expect(home.session.isOnline, isTrue);
      // The server's job: offline, version up, the bell notice.
      status = 'offline';
      version = 6;
      noticeSent = true;
      await tester.pump(const Duration(seconds: 61));
      await frames(tester, 20);
      expect(home.session.isOnline, isFalse);
      expect(card, findsOneWidget);
      expect(
        text('Movera got no position from your phone for 5 minutes.'),
        findsOneWidget,
      );
      await leave(tester, home.live);
    });
  });

  group('the card alone', () {
    Future<void> pumpCard(
      WidgetTester tester, {
      String reason = 'Movera set you offline.',
      VoidCallback? onGoOnline,
      VoidCallback? onOk,
      VoidCallback? onLocationFixed,
    }) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: HomeOfflineCard(
                reason: reason,
                onGoOnline: onGoOnline ?? () {},
                onOk: onOk ?? () {},
                onLocationFixed: onLocationFixed,
              ),
            ),
          ),
        ),
      );
    }

    Finder line(PhoneCheckKind kind, String state) =>
        find.byKey(ValueKey<String>('offline-check-${kind.name}-$state'));

    testWidgets('Check my phone: one ✓ / ✗ line per check, a fix button on '
        'each ✗', (tester) async {
      checks.answers = {
        PhoneCheckKind.location: const PhoneCheckResult(
          PhoneCheckKind.location,
          PhoneCheckState.problem,
          fix: PhoneCheckFix.openSettings,
        ),
        PhoneCheckKind.internet: const PhoneCheckResult.ok(
          PhoneCheckKind.internet,
        ),
        PhoneCheckKind.batterySaver: const PhoneCheckResult(
          PhoneCheckKind.batterySaver,
          PhoneCheckState.problem,
          fix: PhoneCheckFix.openSettings,
        ),
        PhoneCheckKind.notifications: const PhoneCheckResult(
          PhoneCheckKind.notifications,
          PhoneCheckState.problem,
          fix: PhoneCheckFix.turnOn,
        ),
      };
      checks.delay = const Duration(milliseconds: 300);
      await pumpCard(tester);
      expect(line(PhoneCheckKind.location, 'problem'), findsNothing);
      await tester.tap(find.text('Check my phone'));
      await tester.pump();
      expect(find.text('Checking…'), findsNWidgets(4));
      await tester.pumpAndSettle();
      expect(line(PhoneCheckKind.location, 'problem'), findsOneWidget);
      expect(line(PhoneCheckKind.internet, 'ok'), findsOneWidget);
      expect(line(PhoneCheckKind.batterySaver, 'problem'), findsOneWidget);
      expect(line(PhoneCheckKind.notifications, 'problem'), findsOneWidget);
      expect(find.text('Location on and allowed'), findsOneWidget);
      expect(find.text('Internet and Movera server'), findsOneWidget);
      expect(find.text('Battery saver off'), findsOneWidget);
      expect(find.text('Notifications allowed'), findsOneWidget);
      expect(find.text('Open Settings'), findsNWidgets(2));
      expect(find.text('Turn on'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('offline-check-internet-fix')),
        findsNothing,
      );
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.cancel_rounded), findsNWidgets(3));
    });

    testWidgets('a fix runs, then the check runs again: ✗ becomes ✓', (
      tester,
    ) async {
      var locationFixed = 0;
      checks.answers = {
        for (final kind in PhoneCheckKind.values)
          kind: PhoneCheckResult.ok(kind),
        PhoneCheckKind.notifications: const PhoneCheckResult(
          PhoneCheckKind.notifications,
          PhoneCheckState.problem,
          fix: PhoneCheckFix.turnOn,
        ),
      };
      await pumpCard(tester, onLocationFixed: () => locationFixed++);
      await tester.tap(find.text('Check my phone'));
      await tester.pumpAndSettle();
      expect(line(PhoneCheckKind.notifications, 'problem'), findsOneWidget);
      checks.answers[PhoneCheckKind.notifications] = const PhoneCheckResult.ok(
        PhoneCheckKind.notifications,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('offline-check-notifications-fix')),
      );
      await tester.pumpAndSettle();
      expect(checks.fixes.single.kind, PhoneCheckKind.notifications);
      expect(locationFixed, 0, reason: 'Home reads the location after its fix');
      expect(line(PhoneCheckKind.notifications, 'ok'), findsOneWidget);
    });

    testWidgets('the location fix makes Home read the location again', (
      tester,
    ) async {
      var locationFixed = 0;
      checks.answers[PhoneCheckKind.location] = const PhoneCheckResult(
        PhoneCheckKind.location,
        PhoneCheckState.problem,
        fix: PhoneCheckFix.turnOn,
      );
      await pumpCard(tester, onLocationFixed: () => locationFixed++);
      await tester.tap(find.text('Check my phone'));
      await tester.pumpAndSettle();
      checks.answers[PhoneCheckKind.location] = const PhoneCheckResult.ok(
        PhoneCheckKind.location,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('offline-check-location-fix')),
      );
      await tester.pumpAndSettle();
      expect(locationFixed, 1);
      expect(line(PhoneCheckKind.location, 'ok'), findsOneWidget);
    });

    testWidgets('internet ✗ has Retry; a browser-blocked permission says '
        'where to allow it; what the phone cannot tell says so', (
      tester,
    ) async {
      checks.answers = {
        PhoneCheckKind.location: const PhoneCheckResult(
          PhoneCheckKind.location,
          PhoneCheckState.problem,
          fix: PhoneCheckFix.browserSettings,
        ),
        PhoneCheckKind.internet: const PhoneCheckResult(
          PhoneCheckKind.internet,
          PhoneCheckState.problem,
          fix: PhoneCheckFix.retry,
        ),
        PhoneCheckKind.batterySaver: const PhoneCheckResult.unknown(
          PhoneCheckKind.batterySaver,
        ),
        PhoneCheckKind.notifications: const PhoneCheckResult.ok(
          PhoneCheckKind.notifications,
        ),
      };
      await pumpCard(tester);
      await tester.tap(find.text('Check my phone'));
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text("Allow it in the browser's site settings"), findsOne);
      expect(
        find.byKey(const ValueKey<String>('offline-check-location-fix')),
        findsNothing,
      );
      expect(line(PhoneCheckKind.batterySaver, 'unknown'), findsOneWidget);
      expect(find.text("Can't be checked here"), findsOneWidget);
    });

    testWidgets('a check that never answers counts as "can\'t tell" after '
        'its limit', (tester) async {
      checks.hang = {PhoneCheckKind.internet};
      await pumpCard(tester);
      await tester.tap(find.text('Check my phone'));
      await tester.pump();
      await tester.pump(PhoneChecks.limit + const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(line(PhoneCheckKind.internet, 'unknown'), findsOneWidget);
      expect(line(PhoneCheckKind.location, 'ok'), findsOneWidget);
    });

    testWidgets('owner: only black, no green text or outlines (Check my '
        'phone, OK, the fix actions, ✓)', (tester) async {
      checks.answers[PhoneCheckKind.location] = const PhoneCheckResult(
        PhoneCheckKind.location,
        PhoneCheckState.problem,
        fix: PhoneCheckFix.turnOn,
      );
      await pumpCard(tester);
      const ink = Color(0xFF111614);
      Color textColor(String text) =>
          DefaultTextStyle.of(tester.element(find.text(text))).style.color!;
      expect(textColor('Check my phone'), ink);
      expect(textColor('OK'), ink);
      final outlined = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey<String>('offline-card-check')),
      );
      expect(outlined.style!.side!.resolve(const <WidgetState>{})!.color, ink);
      await tester.tap(find.text('Check my phone'));
      await tester.pumpAndSettle();
      expect(textColor('Turn on'), ink);
      for (final icon in tester.widgetList<Icon>(
        find.descendant(
          of: find.byType(HomeOfflineCard),
          matching: find.byType(Icon),
        ),
      )) {
        final c = icon.color!;
        final greenish = c.g > c.r + 0.15 && c.g > c.b + 0.1;
        expect(greenish, isFalse, reason: '${icon.icon} is $c');
      }
    });

    testWidgets('Go online and OK call their actions', (tester) async {
      var online = 0;
      var ok = 0;
      await pumpCard(tester, onGoOnline: () => online++, onOk: () => ok++);
      await tester.tap(find.text('Go online'));
      await tester.tap(find.text('OK'));
      expect((online, ok), (1, 1));
    });

    testWidgets('every reason in its own words', (tester) async {
      String reasonOf(DriverOfflineReason reason, {int? count}) {
        final notice = DriverSetOfflineNotice()
          ..show(reason: reason, count: count);
        return offlineReasonText(notice);
      }

      expect(
        reasonOf(DriverOfflineReason.noPosition, count: 5),
        'Movera got no position from your phone for 5 minutes.',
      );
      expect(
        reasonOf(DriverOfflineReason.missedOffers, count: 10),
        '10 offers in a row were missed or declined.',
      );
      expect(
        reasonOf(DriverOfflineReason.appRestart),
        'The app was restarted while you were online.',
      );
      // Defaults when the count is not known: the contract's 5 and 10.
      expect(
        reasonOf(DriverOfflineReason.noPosition),
        'Movera got no position from your phone for 5 minutes.',
      );
      expect(
        reasonOf(DriverOfflineReason.missedOffers),
        '10 offers in a row were missed or declined.',
      );
      expect(reasonOf(DriverOfflineReason.movera), 'Movera set you offline.');
    });

    testWidgets('Swedish and French', (tester) async {
      DriverAppTexts.language = 'sv';
      await pumpCard(tester);
      expect(find.text('Du är offline'), findsOneWidget);
      expect(find.text('Kontrollera min telefon'), findsOneWidget);
      expect(find.text('Gå online'), findsOneWidget);
      DriverAppTexts.language = 'fr';
      await tester.pumpWidget(const SizedBox());
      await pumpCard(tester);
      expect(find.text('Vous êtes hors ligne'), findsOneWidget);
      expect(find.text('Vérifier mon téléphone'), findsOneWidget);
      expect(find.text('Passer en ligne'), findsOneWidget);
      final notice = DriverSetOfflineNotice()
        ..show(reason: DriverOfflineReason.appRestart);
      expect(
        offlineReasonText(notice),
        "L'application a redémarré pendant que vous étiez en ligne.",
      );
    });
  });
}

class _FakeChecks extends PhoneChecks {
  Map<PhoneCheckKind, PhoneCheckResult> answers = {
    for (final kind in PhoneCheckKind.values) kind: PhoneCheckResult.ok(kind),
  };
  Set<PhoneCheckKind> hang = {};
  Duration delay = Duration.zero;
  final List<PhoneCheckResult> fixes = [];

  @override
  Future<PhoneCheckResult> check(PhoneCheckKind kind) {
    if (hang.contains(kind)) return Completer<PhoneCheckResult>().future;
    return Future<PhoneCheckResult>.delayed(delay, () => answers[kind]!);
  }

  @override
  Future<void> fix(PhoneCheckResult result) async => fixes.add(result);
}

class _Gps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() async => DriverLocation(
    point: const GeoPoint(59.3326, 18.0649),
    accuracyMeters: 5,
    measuredAt: DateTime.now(),
  );

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream<DriverLocation>.empty();
}

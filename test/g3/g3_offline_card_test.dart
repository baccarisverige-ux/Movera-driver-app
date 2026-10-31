import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/driver/driver_home_notices.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
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
/// "Check my phone" (✓/✗ with a fix) and OK, with Home's radar reading
/// "Go online" in the risen sheet's notch; it goes when he
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
        text('The app was restarted while you were online'),
        findsOneWidget,
      );
      expect(
        find.text('You were set offline – tap to go online again'),
        findsNothing,
      );
      // The sheet rises from the bottom of the screen, full width, over
      // the dock's icons.
      final rect = tester.getRect(card);
      expect(rect.bottom, 844);
      expect(rect.left, 0);
      expect(rect.right, 390);
      expect(rect.top, lessThan(844 - 108), reason: 'taller than the dock');
      // Owner: the radar stays, on the sheet's top edge, reading Go online.
      final radar = find.byType(MoveraRadarOrb);
      expect(radar, findsOneWidget);
      expect(
        find.descendant(of: radar, matching: find.text('Go online')),
        findsOneWidget,
      );
      final orb = tester.getRect(radar);
      final sheetTop = rect.top + HomeOfflineCard.radarTop;
      expect((orb.center.dy - sheetTop).abs(), lessThan(4));
      expect(orb.center.dx, closeTo(195, 1));
      // No second, separate Go online button.
      expect(find.byType(FilledButton), findsNothing);
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

    testWidgets('the radar\'s Go online hides the card and goes online', (
      tester,
    ) async {
      final home = await pumpHome(tester);
      DriverSetOfflineNotice.instance.show(
        reason: DriverOfflineReason.appRestart,
      );
      await frames(tester, 3);
      await tester.tap(find.byType(MoveraRadarOrb));
      await frames(tester, 3);
      expect(home.session.isGoingOnline || home.session.isOnline, isTrue);
      expect(card, findsNothing);
      // Back on the usual radar.
      expect(find.byType(MoveraRadarOrb), findsOneWidget);
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
      expect(text('Movera set you offline'), findsOneWidget);
      DriverSetOfflineNotice.instance.show(
        reason: DriverOfflineReason.missedOffers,
        count: 10,
      );
      await frames(tester, 3);
      expect(text('You missed or declined 10 offers in a row'), findsOneWidget);
      await leave(tester, null);
    });

    testWidgets('G3-R1 live: the server set him offline and its bell notice '
        'reason no_position says why; a server without offlineReason (before '
        'v0.18.6) gets "Movera set you offline", never a guess', (
      tester,
    ) async {
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
      String? reason;
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
            'offlineReason': ?reason,
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
      reason = 'no_position';
      await tester.pump(const Duration(seconds: 61));
      await frames(tester, 20);
      expect(home.session.isOnline, isFalse);
      expect(card, findsOneWidget);
      expect(text('Your phone sent no position for 5 min'), findsOneWidget);
      // Again, from an older server: a set_offline notice but no reason.
      await tester.tap(find.byKey(const ValueKey<String>('offline-card-ok')));
      await frames(tester, 3);
      await tester.tap(find.byType(MoveraRadarOrb).last);
      await frames(tester, 40);
      expect(home.session.isOnline, isTrue);
      status = 'offline';
      version = 8;
      reason = null;
      await tester.pump(const Duration(seconds: 61));
      await frames(tester, 20);
      expect(home.session.isOnline, isFalse);
      expect(text('Movera set you offline'), findsOneWidget);
      await leave(tester, home.live);
    });
  });

  group('contract v0.18.6 offlineReason (owner "Send the real reason")', () {
    test('the profile carries offlineReason, offlineNote and offlineAt', () {
      final account = DriverAccount.fromJson(const {
        'driverId': 'd1',
        'accountStatus': 'active',
        'firstName': 'Amira',
        'version': 7,
        'onlineStatus': 'offline',
        'offlineReason': 'vehicle_blocked',
        'offlineNote': 'Brake light broken',
        'offlineAt': '2026-10-31T10:00:00Z',
      });
      expect(account.offlineReason, 'vehicle_blocked');
      expect(account.offlineNote, 'Brake light broken');
      expect(account.offlineAt, DateTime.utc(2026, 10, 31, 10));
      expect(
        DriverOfflineReason.fromServer(account.offlineReason),
        DriverOfflineReason.vehicleBlocked,
      );
      expect(
        [
          for (final r in [
            'no_position',
            'missed_offers',
            'fleet_removed',
            'account_status',
            'admin',
            'something_new',
            null,
          ])
            DriverOfflineReason.fromServer(r),
        ],
        [
          DriverOfflineReason.noPosition,
          DriverOfflineReason.missedOffers,
          DriverOfflineReason.fleetRemoved,
          DriverOfflineReason.accountStatus,
          DriverOfflineReason.movera,
          null,
          null,
        ],
      );
    });

    test('every server reason in its contract words, the admin\'s note on '
        'its own line', () {
      String reasonOf(DriverOfflineReason reason, {String? note}) =>
          offlineReasonText(
            DriverSetOfflineNotice()..show(reason: reason, note: note),
          );
      expect(
        reasonOf(
          DriverOfflineReason.vehicleBlocked,
          note: 'Brake light broken',
        ),
        'Your car cannot be used right now\nBrake light broken',
      );
      expect(
        reasonOf(DriverOfflineReason.fleetRemoved),
        'You are no longer in a fleet',
      );
      expect(
        reasonOf(DriverOfflineReason.accountStatus),
        'Your account is paused – contact Movera',
      );
      DriverAppTexts.language = 'sv';
      expect(
        reasonOf(DriverOfflineReason.vehicleBlocked),
        'Din bil kan inte användas just nu',
      );
      DriverAppTexts.language = 'fr';
      expect(
        reasonOf(DriverOfflineReason.fleetRemoved),
        'Vous ne faites plus partie d’une flotte',
      );
    });

    Future<LiveDriverServices?> pumpLive(
      WidgetTester tester,
      Map<String, Object?> profile, {
      bool goOnlineFirst = false,
      void Function()? afterOnline,
    }) async {
      DriverRuntimeConfig.current = const DriverRuntimeConfig(
        simulatedArrival: false,
        externalRouting: false,
        skipAccountActivation: true,
        liveMapTicker: false,
        reservationPopup: false,
        islandHint: false,
        authRequired: true,
      );
      final home = await pumpHome(
        tester,
        answer: (request) async => switch ((request.method, request.url.path)) {
          ('GET', '/api/v1/driver/profile') => json(200, {
            'driverId': 'd1',
            'accountStatus': 'active',
            'firstName': 'Amira',
            'country': 'SE',
            ...profile,
          }),
          ('POST', '/api/v1/driver/availability') => json(200, {
            'driverId': 'd1',
            'accountStatus': 'active',
            'onlineStatus': profile['onlineStatus'] = 'online',
            'version': profile['version'] = 4,
          }),
          ('GET', '/api/v1/notifications') => json(200, {'items': []}),
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
      return home.live;
    }

    testWidgets('server set him offline while online: the card gives the '
        'profile\'s offlineReason and the admin\'s note', (tester) async {
      final profile = <String, Object?>{
        'onlineStatus': 'offline',
        'version': 3,
      };
      final live = await pumpLive(tester, profile);
      await tester.tap(find.byType(MoveraRadarOrb).last);
      await frames(tester, 40);
      profile
        ..['onlineStatus'] = 'offline'
        ..['version'] = 6
        ..['offlineReason'] = 'vehicle_blocked'
        ..['offlineNote'] = 'Brake light broken'
        ..['offlineAt'] = DateTime.now().toUtc().toIso8601String();
      await tester.pump(const Duration(seconds: 61));
      await frames(tester, 20);
      expect(card, findsOneWidget);
      expect(
        text('Your car cannot be used right now\nBrake light broken'),
        findsOne,
      );
      await leave(tester, live);
    });

    testWidgets('the app opens offline a few minutes after the server set '
        'him offline (from the push): the card says why, once', (tester) async {
      final live = await pumpLive(tester, {
        'onlineStatus': 'offline',
        'version': 6,
        'offlineReason': 'fleet_removed',
        'offlineAt': DateTime.now()
            .toUtc()
            .subtract(const Duration(minutes: 3))
            .toIso8601String(),
      });
      await frames(tester, 10);
      expect(text('You are no longer in a fleet'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('offline-card-ok')));
      await frames(tester, 3);
      expect(card, findsNothing);
      await tester.pump(const Duration(seconds: 61));
      await frames(tester, 10);
      expect(card, findsNothing, reason: 'the same offline is not told twice');
      await leave(tester, live);
    });

    testWidgets('an old server offline (hours ago) or none: no card on open', (
      tester,
    ) async {
      final live = await pumpLive(tester, {
        'onlineStatus': 'offline',
        'version': 6,
        'offlineReason': 'no_position',
        'offlineAt': DateTime.now()
            .toUtc()
            .subtract(const Duration(hours: 3))
            .toIso8601String(),
      });
      await frames(tester, 10);
      expect(card, findsNothing);
      await leave(tester, live);
    });
  });

  group('the card alone', () {
    Future<void> pumpCard(
      WidgetTester tester, {
      String reason = 'Movera set you offline',
      Widget? radar,
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
                radar: radar ?? const SizedBox.square(dimension: 104),
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

    testWidgets('the radar it is given sits in the notch; OK calls its '
        'action', (tester) async {
      var ok = 0;
      await pumpCard(
        tester,
        radar: const SizedBox.square(
          key: ValueKey<String>('given-radar'),
          dimension: 104,
        ),
        onOk: () => ok++,
      );
      final sheet = tester.getRect(
        find.byKey(const ValueKey<String>('home-offline-card')),
      );
      final radar = tester.getRect(
        find.byKey(const ValueKey<String>('given-radar')),
      );
      expect(radar.top, sheet.top);
      expect(radar.center.dy, sheet.top + HomeOfflineCard.radarTop - 2);
      await tester.tap(find.text('OK'));
      expect(ok, 1);
    });

    testWidgets('every reason in its own words', (tester) async {
      String reasonOf(DriverOfflineReason reason, {int? count}) {
        final notice = DriverSetOfflineNotice()
          ..show(reason: reason, count: count);
        return offlineReasonText(notice);
      }

      expect(
        reasonOf(DriverOfflineReason.noPosition, count: 5),
        'Your phone sent no position for 5 min',
      );
      expect(
        reasonOf(DriverOfflineReason.missedOffers, count: 10),
        'You missed or declined 10 offers in a row',
      );
      expect(
        reasonOf(DriverOfflineReason.appRestart),
        'The app was restarted while you were online',
      );
      // Defaults when the count is not known: the contract's 5 and 10.
      expect(
        reasonOf(DriverOfflineReason.noPosition),
        'Your phone sent no position for 5 min',
      );
      expect(
        reasonOf(DriverOfflineReason.missedOffers),
        'You missed or declined 10 offers in a row',
      );
      expect(reasonOf(DriverOfflineReason.movera), 'Movera set you offline');
    });

    testWidgets('Swedish and French', (tester) async {
      DriverAppTexts.language = 'sv';
      await pumpCard(tester);
      expect(find.text('Du är offline'), findsOneWidget);
      expect(find.text('Kontrollera min telefon'), findsOneWidget);
      expect(tr.offlineGoOnline, 'Gå online');
      DriverAppTexts.language = 'fr';
      await tester.pumpWidget(const SizedBox());
      await pumpCard(tester);
      expect(find.text('Vous êtes hors ligne'), findsOneWidget);
      expect(find.text('Vérifier mon téléphone'), findsOneWidget);
      // The radar's label (Home builds the orb with it).
      expect(tr.offlineGoOnline, 'Passer en ligne');
      final notice = DriverSetOfflineNotice()
        ..show(reason: DriverOfflineReason.appRestart);
      expect(
        offlineReasonText(notice),
        'L’application a redémarré pendant que vous étiez en ligne',
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

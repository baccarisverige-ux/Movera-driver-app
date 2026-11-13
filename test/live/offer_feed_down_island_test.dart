import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/session/driver_route_observer.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

// D4 (fix plan 2026-11-13, owner 12:22 UTC "Show \"No connection\"
// (Rec.)"): online on Home, an offer feed down for more than 10 s puts the
// existing "No connection" line on the island; the feed back up takes it
// away. Driver app only; the text is `islandNoConnection` (sv/fr/en).
//
// A live build (as test/widget/live_home_online_test.dart): Home online
// through the server's availability, the offer feed opened by
// LiveDriverServices, no demo offers.
void main() {
  late LiveDriverServices live;

  /// GET /driver/offers/stream: 503 while false; 200 and held open while
  /// true.
  var feedUp = false;
  final feeds = <StreamController<List<int>>>[];

  http.StreamedResponse json(int status, Object body) => http.StreamedResponse(
    Stream.value(utf8.encode(jsonEncode(body))),
    status,
    headers: {'content-type': 'application/json'},
  );

  setUp(() {
    feedUp = false;
    feeds.clear();
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    ScheduledRideStore.reset();
  });

  tearDown(() => LiveDriverServices.instance = null);

  /// Made inside the test: its futures must run on the test's clock.
  void makeLive() {
    final tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
    final client = MockClient.streaming((request, _) async {
      return switch (request.url.path) {
        '/api/v1/driver/profile' => json(200, {
          'driverId': 'd1',
          'onlineStatus': 'offline',
          'version': 1,
        }),
        '/api/v1/driver/availability' => json(200, {
          'driverId': 'd1',
          'onlineStatus': 'online',
          'version': 2,
        }),
        '/api/v1/driver/location' => json(200, {'accepted': 1}),
        '/api/v1/driver/offers' => json(200, {
          'items': const <Object>[],
          'nextCursor': null,
        }),
        '/api/v1/driver/offers/stream' when feedUp => () {
          final feed = StreamController<List<int>>();
          feeds.add(feed);
          return http.StreamedResponse(feed.stream, 200);
        }(),
        _ => http.StreamedResponse(const Stream.empty(), 503),
      };
    });
    live = LiveDriverServices(
      client: client,
      origin: Uri.parse('https://api.test.movera.se'),
      tokens: tokens,
      api: ApiClient(
        client: client,
        baseUri: Uri.parse('https://api.test.movera.se'),
        tokens: tokens,
      ),
      location: _Gps(),
      locationEvery: const Duration(hours: 1),
    );
    LiveDriverServices.instance = live;
  }

  Future<void> frames(WidgetTester tester, Duration total) async {
    const step = Duration(milliseconds: 100);
    for (var t = Duration.zero; t < total; t += step) {
      await tester.pump(step);
    }
  }

  Future<DriverSessionController> home(
    WidgetTester tester, {
    bool online = true,
  }) async {
    makeLive();
    final maps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = DriverSessionController();
    live.attach(session);
    await tester.pumpWidget(
      LayoutViewport(
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          minTextAdapt: true,
          splitScreenMode: true,
          useInheritedMediaQuery: true,
          builder: (_, __) => MaterialApp(
            navigatorObservers: [driverRouteObserver],
            home: DriverHome(
              sessionController: session,
              dispatchRepository: live.dispatch,
              locationRepository: _Gps(),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    if (online) {
      tester
          .widget<GestureDetector>(
            find.byKey(const ValueKey<String>('trip-radar-touch-target')),
          )
          .onTap!
          .call();
    }
    await frames(tester, const Duration(milliseconds: 2000));
    return session;
  }

  Future<void> leave(WidgetTester tester) async {
    for (final feed in feeds) {
      unawaited(feed.close());
    }
    await tester.pumpWidget(const SizedBox.shrink());
    // As the app does on sign-out (lib/main.dart:385): not awaited. Under
    // the test clock with this streaming fake, the closed offer stream's
    // done future is never delivered (no listener is left on it).
    unawaited(live.dispose());
    await frames(tester, const Duration(seconds: 2));
  }

  /// Waits (test clock) until the feed is open, at most [limit].
  Future<void> untilLive(WidgetTester tester, Duration limit) async {
    for (
      var t = Duration.zero;
      t < limit && !live.dispatch.feedLive;
      t += const Duration(milliseconds: 100)
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  final noConnection = find.text('No connection');

  testWidgets('online, the offer feed down for 11 s: the island says '
      '"No connection"; the feed back up: the line is gone', (tester) async {
    final session = await home(tester);
    expect(session.status, DriverOnlineStatus.online);
    // The server refuses the feed (503) since Go online.
    expect(live.dispatch.feedLive, isFalse);
    await frames(tester, const Duration(seconds: 9));
    expect(noConnection, findsNothing);
    await frames(tester, const Duration(seconds: 2));
    expect(live.dispatch.feedLive, isFalse);
    expect(noConnection, findsOneWidget);

    // The feed opens again (its own backoff): the line goes.
    feedUp = true;
    await untilLive(tester, const Duration(seconds: 40));
    expect(live.dispatch.feedLive, isTrue);
    // The island's face switch fades the old words out.
    await frames(tester, const Duration(seconds: 1));
    expect(noConnection, findsNothing);
    await leave(tester);
  });

  testWidgets('a feed down for less than 10 s shows nothing; 10 s down '
      'shows the line', (tester) async {
    feedUp = true;
    await home(tester);
    await untilLive(tester, const Duration(seconds: 5));
    expect(live.dispatch.feedLive, isTrue);
    expect(noConnection, findsNothing);

    // The server ends the feed and refuses the next ones: down from now.
    feedUp = false;
    await feeds.last.close();
    await frames(tester, const Duration(milliseconds: 300));
    expect(live.dispatch.feedLive, isFalse);
    await frames(tester, const Duration(seconds: 8));
    expect(noConnection, findsNothing);
    await frames(tester, const Duration(seconds: 3));
    expect(noConnection, findsOneWidget);
    await leave(tester);
  });

  testWidgets('offline, no feed: no "No connection" line', (tester) async {
    await home(tester, online: false);
    await frames(tester, const Duration(seconds: 12));
    expect(live.dispatch.feedLive, isFalse);
    expect(noConnection, findsNothing);
    await leave(tester);
  });
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

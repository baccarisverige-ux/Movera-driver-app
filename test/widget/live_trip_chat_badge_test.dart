import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/presentation/common/chat/chat.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

/// A live build: a rider's message from the trip's stream counts on the
/// trip screen's chat button until Chat is opened.
void main() {
  late LiveDriverServices live;

  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/events')) {
        // No live stream in this test: it keeps retrying quietly.
        return http.Response('', 503);
      }
      if (request.method == 'GET' && path == '/api/v1/trips/live-trip') {
        return json(200, {
          'tripId': 'live-trip',
          'status': 'driver_to_pickup',
          'version': 4,
        });
      }
      if (request.method == 'GET' &&
          path == '/api/v1/trips/live-trip/messages') {
        return json(200, {'items': <Object>[], 'nextCursor': null});
      }
      return json(404, {'code': 'not_found', 'message': 'No.'});
    });
    final api = ApiClient(
      client: client,
      baseUri: Uri.parse('https://api.test.movera.se'),
      tokens: tokens,
    );
    live = LiveDriverServices(
      client: client,
      origin: Uri.parse('https://api.test.movera.se'),
      tokens: tokens,
      api: api,
      location: _NoGps(),
    );
    LiveDriverServices.instance = live;
  });

  tearDown(() async {
    LiveDriverServices.instance = null;
    await live.dispose();
  });

  Future<void> frames(WidgetTester tester, [int count = 12]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  // B16 (2026-11-04): replaces the source-reading chat-contact guard
  // (archived in Rules/archive/old-tests/Movera-driver-app/).
  // Calls: test/widget/chat_closed_call_test.dart (only the server's masked
  // number is dialled) and chat_contact_truth_test.dart (no dial offline).
  testWidgets('the trip screen opens Chat for this trip and rider, with no '
      'number of its own', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, __) => MaterialApp(
          home: AcceptRide(
            tripId: 'live-trip',
            locationRepository: _NoGps(),
            activeRideRepository: MemoryActiveRideRepository(),
          ),
        ),
      ),
    );
    await frames(tester);
    tester
        .widget<SlidingUpPanel>(find.byType(SlidingUpPanel))
        .controller!
        .animatePanelToSnapPoint();
    await frames(tester, 16);
    final button = find.byKey(
      const ValueKey<String>('active-ride-message-rider'),
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await frames(tester, 16);
    final chat = tester.widget<Chat>(find.byType(Chat));
    expect(chat.tripId, 'live-trip');
    expect(chat.riderDisplayName.trim(), isNotEmpty);
    expect(find.text(chat.riderDisplayName), findsWidgets);
    // No number of its own anywhere on the Chat screen.
    expect(find.textContaining(RegExp(r'\+?46\d{6,}')), findsNothing);
    expect(find.textContaining('tel:'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a rider\'s message counts on the chat button; opening Chat '
      'reads it', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, __) => MaterialApp(
          home: AcceptRide(
            tripId: 'live-trip',
            locationRepository: _NoGps(),
            activeRideRepository: MemoryActiveRideRepository(),
          ),
        ),
      ),
    );
    await frames(tester);
    tester
        .widget<SlidingUpPanel>(find.byType(SlidingUpPanel))
        .controller!
        .animatePanelToSnapPoint();
    await frames(tester, 16);

    final button = find.byKey(
      const ValueKey<String>('active-ride-message-rider'),
    );
    expect(button, findsOneWidget);
    expect(find.byTooltip(tr.messageRider), findsOneWidget);
    Badge badge() => tester.widget<Badge>(
      find.byKey(const ValueKey<String>('active-ride-chat-unread')),
    );
    expect(badge().isLabelVisible, isFalse);

    // As the trip's stream delivers it.
    live.chat.receive(
      'live-trip',
      RealtimeMessage(
        messageId: 'm1',
        from: 'rider',
        text: 'Where are you?',
        at: DateTime.utc(2026, 10, 25, 10),
      ),
    );
    await frames(tester, 2);
    expect(badge().isLabelVisible, isTrue);
    expect(
      find.descendant(of: find.byType(Badge), matching: find.text('1')),
      findsOneWidget,
    );
    expect(find.byTooltip(tr.chatNewMessages(1)), findsOneWidget);

    await tester.ensureVisible(button);
    await tester.tap(button);
    await frames(tester, 16);
    expect(find.byType(Chat), findsOneWidget);
    expect(find.text('Where are you?'), findsOneWidget);
    expect(live.chat.unreadOf('live-trip'), 0);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}

class _NoGps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() =>
      Completer<DriverLocation>().future;
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream.empty();
}

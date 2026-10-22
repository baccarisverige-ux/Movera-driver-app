// Audit round 5, the low bugs (Wave 6b).
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_start_position.dart';
import 'package:movera/core/privacy/local_data.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/core/storage/local_write_session.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/widgets/route_mark_pins.dart';
import 'package:movera/widgets/web_map_bitmap.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

Future<void> _frames(WidgetTester tester, int count, [int ms = 50]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _app(Widget home, {GlobalKey<NavigatorState>? navigator}) =>
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, _) => MaterialApp(navigatorKey: navigator, home: home),
    );

/// Slides the trip's primary action, opening its panel first.
Future<void> _slide(WidgetTester tester) async {
  final action = find.byKey(const ValueKey('active-ride-primary-action'));
  if (action.evaluate().isEmpty) {
    tester.widgetList<SlidingUpPanel>(find.byType(SlidingUpPanel)).last
        .controller!.animatePanelToSnapPoint();
    await _frames(tester, 20);
  }
  await tester.ensureVisible(action);
  await tester.drag(action, const Offset(320, 0));
  await _frames(tester, 8, 30);
}

/// Every trip save, in order.
class _Saves extends MemoryActiveRideRepository {
  final saved = <PersistedActiveRide>[];
  @override
  Future<void> save(PersistedActiveRide ride) {
    saved.add(ride);
    return super.save(ride);
  }
}

void main() {
  test('driver-r5-8: admin\'s scheduled-rides "until" is a local time', () {
    final access = ScheduledRidesDriverAccess.fromJson(
        {'on': false, 'until': '2026-10-23T22:30:00Z'});
    expect(access.until!.isUtc, isFalse,
        reason: 'the notice formats its date: a UTC date can be a day early');
    expect(access.until!.isAtSameMomentAs(DateTime.utc(2026, 10, 23, 22, 30)),
        isTrue);
  });

  testWidgets('driver-r5-21: a stalled accept ends as a network error',
      (tester) async {
    final stalled = Completer<http.Response>();
    final repo = ApiDispatchRepository(
      client: MockClient((request) async => request.method == 'GET'
          ? http.Response(jsonEncode({'items': [_wireOffer], 'nextCursor': null}),
              200, headers: {'content-type': 'application/json'})
          : stalled.future),
      baseUri: Uri.parse('https://api.dev.movera.invalid/api/v1'),
      accessToken: () async => 'token',
    );
    final listed = repo.watchNearbyOffers().skip(1).first;
    repo.refreshOffers();
    await tester.runAsync(() => listed);
    ClaimResult? result;
    unawaited(repo.claimOffer('o1').then((r) => result = r));
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(result?.outcome, ClaimOutcome.networkError,
        reason: 'before: the claim waited for the socket forever');
  });

  test('driver-r5-40: a GPS fix during logout cleanup is not saved',
      () async {
    SharedPreferences.setMockInitialValues({});
    DriverStartPosition.clearMemory();
    // Logout has begun and cleared the position; a Home fix lands now.
    LocalWriteSession.beginCleanup();
    DriverStartPosition.clearMemory();
    await DriverStartPosition.save(const GeoPoint(59.33, 18.06));
    LocalWriteSession.endCleanup();
    expect(DriverStartPosition.cached, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(DriverStartPosition.key), isNull,
        reason: 'before: the departing driver\'s position was written back');
  });

  test('driver-r5-18: logout removes a settings section another tab wrote',
      () async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();
    // Another tab writes to the shared store; this tab's cache never sees it.
    const key = '${SettingsRepository.sectionPrefix}contacts';
    await SharedPreferencesStorePlatform.instance
        .setValue('String', 'flutter.$key', '{"phones":["+46700000000"]}');
    await clearLocalUserData();
    final stored = await SharedPreferencesStorePlatform.instance.getAll();
    expect(stored.keys, isNot(contains('flutter.$key')),
        reason: 'before: only keys in this tab\'s cache were removed');
  });

  test('driver-r5-17: each trip reuses the route pins and their web URLs',
      () async {
    var urls = 0;
    WebMapBitmaps.debugCreateUrl = (_) => 'blob:test/${urls++}';
    addTearDown(() => WebMapBitmaps.debugCreateUrl = null);
    // Two trips ask for the same three pins, as AcceptRide does on mount.
    for (var trip = 0; trip < 2; trip++) {
      for (final kind in RouteMarkKind.values) {
        await RouteMarkPins.pin(kind);
      }
    }
    expect(urls, RouteMarkKind.values.length,
        reason: 'before: a new PNG and Blob URL per pin per trip');
  });

  testWidgets('driver-r5-39: the Start-trip save holds the pickup\'s paid '
      'wait and the start time', (tester) async {
    _phone(tester);
    SharedPreferences.setMockInitialValues({});
    final saves = _Saves();
    await tester.pumpWidget(_app(AcceptRide(
      tripId: 'start-save',
      initialStage: ActiveRideStage.waitingForRider,
      initialWaitSeconds: 6 * 60 + 30,
      waitNow: () => DateTime(2026, 10, 20, 12),
      activeRideRepository: saves,
    )));
    await _frames(tester, 8);
    await _slide(tester);
    final first = saves.saved
        .firstWhere((ride) => ride.stage == ActiveRideStage.onTrip);
    expect([first.paidWaitSeconds, first.startedAt != null], [90, true],
        reason: 'before: the first onTrip save had 0 paid seconds and no '
            'start, and a kill then lost the waiting fee');
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester, 10, 100);
  });
}

/// Contract `Offer` (openapi.yaml#Offer).
const _wireOffer = {
  'offerId': 'o1',
  'tripId': 'trip-o1',
  'kind': 'radar',
  'status': 'open',
  'version': 1,
  'expiresAt': '2026-10-20T12:00:15Z',
  'fare': {'amountMinor': 8810, 'currency': 'SEK'},
  'source': 'system',
  'pickup': {'address': 'Tegnérgatan, Stockholm', 'lat': 59.3335, 'lng': 18.0610},
  'dropoff': {'address': 'Odengatan, Stockholm', 'lat': 59.3428, 'lng': 18.0475},
  'categoryId': 'comfort',
  'paymentMethod': 'card',
  'pickupEtaSeconds': 180,
  'pickupMeters': 900,
  'tripSeconds': 720,
  'tripMeters': 5200,
};

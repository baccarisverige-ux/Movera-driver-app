// Audit round 5, the low bugs (Wave 6b).
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_start_position.dart';
import 'package:movera/core/privacy/local_data.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/core/storage/local_write_session.dart';
import 'package:movera/widgets/route_mark_pins.dart';
import 'package:movera/widgets/web_map_bitmap.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

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

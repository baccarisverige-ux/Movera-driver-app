import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/driver/driver_home_notices.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/offline_after_trips.dart';
import 'package:movera/presentation/driver/accept%20ride/trip_bottom_bar.dart';
import 'package:movera/presentation/driver/home/components/home_offline_card.dart';

/// Contract v0.18.37 §61 (go offline after trips, owner 2026-11-05): Go
/// offline during a trip = offline after all his trips. One POST, the
/// server answers 200 with Driver.offlineAfterTrip; the trip sheet shows
/// "Going offline after this trip" with Undo; after the last trip the
/// offline card says "You went offline after your trip".

Map<String, Object?> _driver(String status, {bool flag = false, int v = 4}) => {
  'driverId': 'drv_1',
  'onlineStatus': status,
  'offlineAfterTrip': flag,
  'version': v,
};

void main() {
  tearDown(() {
    OfflineAfterTrips.pending.value = false;
    OfflineAfterTrips.undoAction = null;
  });

  test(
    'on a trip: one POST offline, 200 with the flag; undo posts online',
    () async {
      final posts = <Map<String, Object?>>[];
      var flag = false;
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.method == 'POST') {
            final body = jsonDecode(request.body) as Map<String, Object?>;
            posts.add(body);
            flag = body['onlineStatus'] == 'offline';
            return http.Response(
              jsonEncode(_driver('on_trip', flag: flag, v: 5)),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode(_driver('on_trip', flag: flag)),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        baseUri: Uri.parse('https://api.example.test'),
        tokens: MemoryTokenStore()..save(access: 'a1', refresh: 'r1'),
      );
      expect(await OfflineAfterTrips.request(api, offline: true), isNull);
      expect(posts.single, {'expectedVersion': 4, 'onlineStatus': 'offline'});
      expect(OfflineAfterTrips.pending.value, isTrue);
      expect(await OfflineAfterTrips.request(api, offline: false), isNull);
      expect(posts.last['onlineStatus'], 'online');
      expect(OfflineAfterTrips.pending.value, isFalse);
    },
  );

  test(
    'the profile (after a restart) brings the banner back; off a trip it is gone',
    () {
      OfflineAfterTrips.observe(_driver('on_trip', flag: true));
      expect(OfflineAfterTrips.pending.value, isTrue);
      OfflineAfterTrips.observe(_driver('offline'));
      expect(OfflineAfterTrips.pending.value, isFalse);
    },
  );

  testWidgets('trip sheet: "Going offline after this trip" with Undo', (
    tester,
  ) async {
    var undone = 0;
    OfflineAfterTrips.undoAction = () async {
      undone++;
      return null;
    };
    Widget bar() => MaterialApp(
      home: Scaffold(
        body: TripBottomBar(
          instruction: 'Drop off Maya',
          address: 'Medborgarplatsen',
          onPreferences: () {},
          onTap: () {},
        ),
      ),
    );
    await tester.pumpWidget(bar());
    expect(find.byKey(const ValueKey('trip-bar-going-offline')), findsNothing);
    OfflineAfterTrips.pending.value = true;
    await tester.pump();
    expect(
      find.byKey(const ValueKey('trip-bar-going-offline')),
      findsOneWidget,
    );
    expect(find.text(tr.goingOfflineAfterTrip), findsOneWidget);
    await tester.tap(find.text(tr.goingOfflineUndo));
    await tester.pump();
    expect(undone, 1);
  });

  test('offline card: reason after_trip', () {
    expect(
      DriverOfflineReason.fromServer('after_trip'),
      DriverOfflineReason.afterTrip,
    );
    final notice = DriverSetOfflineNotice()
      ..show(reason: DriverOfflineReason.afterTrip);
    expect(offlineReasonText(notice), tr.offlineReasonAfterTrip);
    expect(tr.offlineReasonAfterTrip, 'You went offline after your trip');
  });
}

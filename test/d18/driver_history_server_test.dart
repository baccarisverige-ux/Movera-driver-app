import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/history/trip_history.dart';
import 'package:movera/core/live/live_trip_history.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/presentation/driver/ride history/ride_history.dart';

/// D18 (contract v0.18.124 C10 `driverTripHistory`; owner G11 Q10 "Load
/// from server (Recommended)", Rules decisions/driver-g11.md): History
/// reads the driver's trips from `GET /driver/trips`, so a reinstall or a
/// new phone (empty phone store) shows the same trips. Fail-before: the
/// app had no server read (Rules audits/impact/findings-g18-g23-2026-11-17.md).
Map<String, dynamic> _item(
  String id,
  String status,
  String endedAt, {
  int earned = 0,
  String currency = 'SEK',
  int? cash,
}) => {
  'tripId': id,
  'status': status,
  'categoryId': 'standard',
  'pickup': {'lat': 59.33, 'lng': 18.06, 'address': 'Sergels torg'},
  'dropoff': {'lat': 59.31, 'lng': 18.07, 'address': 'Medborgarplatsen'},
  'paymentMethod': 'cash',
  'rider': {'firstName': 'Anna'},
  'createdAt': endedAt,
  'endedAt': endedAt,
  'distanceMeters': 6800,
  'earned': {'amountMinor': earned, 'currency': currency},
  if (cash != null)
    'cashCollected': {'amountMinor': cash, 'currency': currency},
};

void main() {
  test('a new phone (empty phone store) lists the trips the server has, '
      'with the server\'s earned money, page by page', () async {
    final asked = <Uri>[];
    final api = ApiClient(
      client: MockClient((request) async {
        asked.add(request.url);
        final second = request.url.queryParameters['cursor'] == 'c1';
        return http.Response(
          jsonEncode({
            'items': second
                ? [_item('t3', 'no_show', '2026-10-02T12:00:00Z')]
                : [
                    _item(
                      't1',
                      'completed',
                      '2026-11-17T08:00:00Z',
                      earned: 21000,
                      cash: 27000,
                    ),
                    _item(
                      't2',
                      'cancelled_by_rider',
                      '2026-11-17T07:00:00Z',
                      earned: 4500,
                    ),
                  ],
            'nextCursor': second ? null : 'c1',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
      baseUri: Uri.parse('https://api.test.movera.se'),
      tokens: MemoryTokenStore()..save(access: 'a', refresh: 'r'),
    );
    final history = LiveTripHistory(api: api);
    final first = await history.page();
    expect(asked.single.path, '/api/v1/driver/trips');
    expect(asked.single.queryParameters['limit'], '20');
    expect(first.nextCursor, 'c1');
    expect(first.items.map((r) => r.tripId), ['t1', 't2']);
    final done = first.items.first;
    expect(done.status, TripStatus.completed);
    expect(done.fareMinorUnits, 21000);
    expect(done.earnedMoney?.minorUnits, 21000);
    expect(done.cashCollected, isNotNull);
    expect(done.pickup, 'Sergels torg');
    expect(done.riderName, 'Anna');
    expect(done.completedAt?.toUtc(), DateTime.utc(2026, 11, 17, 8));
    final cancelled = first.items[1];
    expect(cancelled.status, TripStatus.cancelledByRider);
    expect(cancelled.earnedMoney?.minorUnits, 4500);
    final next = await history.page(cursor: first.nextCursor);
    expect(asked.last.queryParameters['cursor'], 'c1');
    expect(next.items.single.status, TripStatus.noShow);
    expect(next.nextCursor, isNull);
  });

  test('server rows win over the phone copy; phone-only rows stay (offline '
      'or not yet sent); newest first', () {
    const phone = TripHistoryRecord(
      tripId: 't1',
      riderName: 'Old',
      whenLabel: '',
      pickup: 'Old',
      dropoff: 'Old',
      fare: '1 kr',
      category: 'Standard',
    );
    final phoneOnly = TripHistoryRecord(
      tripId: 't9',
      riderName: 'Local',
      whenLabel: '',
      pickup: 'A',
      dropoff: 'B',
      fare: '5 kr',
      category: 'Standard',
      completedAt: DateTime.utc(2026, 11, 17, 9),
    );
    final server = LiveTripHistory.recordOf(
      _item('t1', 'completed', '2026-11-17T08:00:00Z', earned: 21000),
    );
    final merged = LiveTripHistory.merge(
      server: [server],
      phone: [phone, phoneOnly],
    );
    expect(merged.map((r) => r.tripId), ['t9', 't1']);
    expect(merged.last.riderName, 'Anna');
  });

  testWidgets('History on a new phone (empty phone store) shows the '
      'server\'s trips, not an empty list', (tester) async {
    Money.zoneCurrency = 'SEK';
    final now = DateTime.now().toUtc().toIso8601String();
    final asked = <String?>[];
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: DriverRideHistory(
          loadHistory: () async => const <TripHistoryRecord>[],
          loadServerPage: ({String? cursor}) async {
            asked.add(cursor);
            return DriverTripHistoryPage(
              items: [
                LiveTripHistory.recordOf(
                  _item('t1', 'completed', now, earned: 21000),
                ),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(asked, [null]);
    expect(find.textContaining('Sergels torg'), findsWidgets);
    expect(find.text('210,00 kr'), findsWidgets);
  });

  testWidgets('offline: the server cannot be reached, the phone copy is '
      'shown', (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: DriverRideHistory(
          loadHistory: () async => [
            TripHistoryRecord(
              tripId: 'p1',
              riderName: 'Local',
              whenLabel: '',
              pickup: 'Odenplan',
              dropoff: 'Slussen',
              fare: '99 kr',
              category: 'Movera',
              completedAt: DateTime.now(),
            ),
          ],
          loadServerPage: ({String? cursor}) async =>
              throw Exception('offline'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Odenplan'), findsWidgets);
  });
}

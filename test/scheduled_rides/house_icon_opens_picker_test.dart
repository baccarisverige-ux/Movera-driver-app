import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/live/live_reservations.dart';
import 'package:movera/core/scheduled/preferred_areas.dart';
import 'package:movera/core/scheduled/server_reservations.dart';
import 'package:movera/presentation/driver/scheduled rides/preferred_areas.dart';

import 'preferred_areas_fakes.dart';

/// v0.18.172: the house icon shows the count of set areas and opens the
/// picker; the live client sends ids only and reads inPreferredArea.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('house icon: no badge with no area, "2" with two; tap opens', (
    tester,
  ) async {
    var opened = 0;
    PreferredAreasStore.saved.value = const [];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PreferredAreasButton(onPressed: () => opened++)),
      ),
    );
    expect(find.byKey(const ValueKey('preferred-areas-count')), findsNothing);
    PreferredAreasStore.saved.value = const [sodermalm, solna];
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('preferred-areas-count')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('preferred-areas-house')));
    expect(opened, 1);
    PreferredAreasStore.saved.value = const [];
  });

  test(
    'live: search, area at, PUT ids only, profile read, inPreferredArea parsed',
    () async {
      final requests = <http.Request>[];
      final live = LiveReservations(
        api: ApiClient(
          client: MockClient((r) async {
            requests.add(r);
            final path = r.url.path;
            final body = switch (path) {
              '/api/v1/driver/areas/search' => {
                'items': [
                  {
                    'areaId': 'SE-SDO-SODERMALM',
                    'name': 'Södermalm',
                    'kind': 'stadsdelsomrade',
                    'kindLabel': 'Område',
                    'zoneId': 'Z001',
                    'country': 'SE',
                    'parentName': 'Stockholm',
                  },
                ],
              },
              '/api/v1/driver/areas/at' => {
                'area': {
                  'areaId': 'SE-K-0181',
                  'name': 'Södertälje',
                  'kind': 'kommun',
                  'kindLabel': 'Kommun',
                  'zoneId': 'Z001',
                  'country': 'SE',
                },
                'containing': [],
              },
              _ => {
                'driverId': 'drv_1',
                'preferredAreaIds': ['SE-K-0181'],
                'preferredAreas': [
                  {
                    'areaId': 'SE-K-0181',
                    'name': 'Södertälje',
                    'kind': 'kommun',
                    'kindLabel': 'Kommun',
                    'zoneId': 'Z001',
                    'country': 'SE',
                  },
                ],
              },
            };
            return http.Response(
              jsonEncode(body),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
          baseUri: Uri.parse('https://api.example.test'),
          tokens: MemoryTokenStore()..save(access: 'a1', refresh: 'r1'),
        ),
      );
      expect((await live.searchAreas('söd')).single.name, 'Södermalm');
      expect(requests.last.url.queryParameters['q'], 'söd');
      expect((await live.areaAt(59.1955, 17.6253))!.areaId, 'SE-K-0181');
      // GM 2026-11-28: the point is in the body of a POST, never in the URL.
      expect(requests.last.method, 'POST');
      expect(requests.last.url.query, isEmpty);
      expect(jsonDecode(requests.last.body), {'lat': 59.1955, 'lng': 17.6253});
      final saved = (await live.setPreferredAreas(['SE-K-0181'])).saved;
      expect(saved!.single.areaId, 'SE-K-0181');
      expect(requests.last.method, 'PUT');
      expect(requests.last.url.path, '/api/v1/driver/preferred-areas');
      expect(jsonDecode(requests.last.body), {
        'areaIds': ['SE-K-0181'],
      });
      expect((await live.loadPreferredAreas()).single.name, 'Södertälje');

      final row = {
        'tripId': 'trp_1',
        'version': 1,
        'scheduledAt': '2026-11-28T12:00:00Z',
        'categoryId': 'economy',
        'rideType': 'normal',
        'pickup': {'address': 'A', 'lat': 59.31, 'lng': 18.07},
        'dropoff': {'address': 'B', 'lat': 59.33, 'lng': 18.06},
        'earnings': {'amountMinor': 10000, 'currency': 'SEK'},
        'status': 'requested',
        'mustBeOnlineAt': '2026-11-28T11:00:00Z',
        'canStartAt': '2026-11-28T11:00:00Z',
      };
      expect(
        ServerReservation.fromJson({
          ...row,
          'inPreferredArea': true,
        }).inPreferredArea,
        isTrue,
      );
      expect(
        ServerReservation.fromJson(row).inPreferredArea,
        isFalse,
        reason: 'an older server: not preferred',
      );
    },
  );
}

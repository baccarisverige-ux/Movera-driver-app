import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/live/live_reservations.dart';
import 'package:movera/core/scheduled/preferred_areas.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';

import 'preferred_areas_fakes.dart';

/// v0.18.172 (owner 2026-11-28): Bokade resor shows the server's two groups
/// with small headers: "I dina favoritområden" then "Övriga"; with favourite
/// areas but none of the open rides in them, "0 bokningar i dina
/// favoritområden" on top; with no favourite areas, no header at all.
Map<String, dynamic> row(
  String id,
  String address,
  int hour, {
  required bool fav,
}) => {
  'tripId': id,
  'version': 1,
  'scheduledAt': '2030-11-05T${hour.toString().padLeft(2, '0')}:00:00Z',
  'categoryId': 'economy',
  'rideType': 'normal',
  'pickup': {'address': address, 'lat': 59.31, 'lng': 18.07},
  'dropoff': {'address': 'Arlanda', 'lat': 59.65, 'lng': 17.92},
  'distanceMeters': 40000,
  'durationSeconds': 2400,
  'earnings': {'amountMinor': 45000, 'currency': 'SEK'},
  'driverTotal': {'amountMinor': 45000, 'currency': 'SEK'},
  'status': 'requested',
  'mustBeOnlineAt': '2030-11-05T07:00:00Z',
  'canStartAt': '2030-11-05T07:00:00Z',
  'inPreferredArea': fav,
};

Future<void> showList(
  WidgetTester tester,
  List<Map<String, dynamic>> open, {
  required List<PreferredArea> favourites,
}) async {
  ScheduledRideStore.reset();
  PreferredAreasStore.saved.value = favourites;
  final live = LiveReservations(
    api: ApiClient(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'items': request.url.query.contains('accepted') ? [] : open,
            'nextCursor': null,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
      baseUri: Uri.parse('https://api.example.test'),
      tokens: MemoryTokenStore()..save(access: 'a1', refresh: 'r1'),
    ),
  );
  await tester.runAsync(() => ScheduledRideStore.syncFromServer(live));
  await tester.binding.setSurfaceSize(const Size(390, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const MaterialApp(home: ScheduledRidesScreen()));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => DriverAppTexts.language = 'sv');
  tearDown(() {
    DriverAppTexts.language = 'en';
    PreferredAreasStore.saved.value = const [];
  });

  testWidgets('favourites first under "I dina favoritområden", then "Övriga"', (
    tester,
  ) async {
    await showList(
      tester,
      [
        row('t1', 'Götgatan 1', 10, fav: true),
        row('t2', 'Folkungagatan 2', 11, fav: true),
        row('t3', 'Kungsgatan 3', 9, fav: false),
      ],
      favourites: const [sodermalm],
    );
    expect(find.text('I dina favoritområden'), findsOneWidget);
    expect(find.text('Övriga'), findsOneWidget);
    expect(find.text('0 bokningar i dina favoritområden'), findsNothing);
    final fav = tester.getTopLeft(find.text('I dina favoritområden')).dy;
    final gotgatan = tester
        .getTopLeft(find.textContaining('Götgatan 1').first)
        .dy;
    final others = tester.getTopLeft(find.text('Övriga')).dy;
    final kungsgatan = tester
        .getTopLeft(find.textContaining('Kungsgatan 3').first)
        .dy;
    expect(
      fav < gotgatan && gotgatan < others && others < kungsgatan,
      isTrue,
      reason: 'server order kept, headers in place',
    );
    expect(
      find.byKey(const ValueKey('scheduled-in-your-area')),
      findsNWidgets(2),
      reason: 'the card label stays',
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'favourites but none in them: "0 bokningar…" on top, then the others',
    (tester) async {
      await showList(
        tester,
        [
          row('t3', 'Kungsgatan 3', 9, fav: false),
          row('t4', 'Drottninggatan 4', 10, fav: false),
        ],
        favourites: const [sodermalm],
      );
      expect(find.text('0 bokningar i dina favoritområden'), findsOneWidget);
      expect(find.text('I dina favoritområden'), findsNothing);
      expect(find.text('Övriga'), findsNothing);
      expect(
        tester.getTopLeft(find.text('0 bokningar i dina favoritområden')).dy,
        lessThan(
          tester.getTopLeft(find.textContaining('Kungsgatan 3').first).dy,
        ),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('no favourite areas chosen: the list as before, no header', (
    tester,
  ) async {
    await showList(tester, [
      row('t3', 'Kungsgatan 3', 9, fav: false),
      row('t4', 'Drottninggatan 4', 10, fav: false),
    ], favourites: const []);
    expect(find.text('I dina favoritområden'), findsNothing);
    expect(find.text('Övriga'), findsNothing);
    expect(find.text('0 bokningar i dina favoritområden'), findsNothing);
    expect(find.textContaining('Kungsgatan 3'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('French headers', (tester) async {
    DriverAppTexts.language = 'fr';
    await showList(
      tester,
      [
        row('t1', 'Götgatan 1', 10, fav: true),
        row('t3', 'Kungsgatan 3', 9, fav: false),
      ],
      favourites: const [sodermalm],
    );
    expect(find.text('Dans vos zones favorites'), findsOneWidget);
    expect(find.text('Autres'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

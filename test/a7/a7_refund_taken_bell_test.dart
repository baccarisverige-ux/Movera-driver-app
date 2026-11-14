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
import 'package:movera/core/history/trip_history.dart';
import 'package:movera/presentation/driver/ride history/history detail/history_detail.dart';
import 'package:movera/presentation/driver/ride history/ride_history.dart';
import 'package:movera/presentation/driver/notifications/server_notifications_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

/// Job A7 (contract v0.18.91 `finish.refund.driverNotice`; owner
/// 2026-11-02 "taken from the driver's NEXT payout (driver sees why)",
/// Rules decisions/driver-g8.md:95-98): when an admin refund is taken from
/// the driver's earnings the server writes a `driver_refund_taken` notice
/// (bell + push) with how much and why. The bell list shows the server's
/// words with a money icon; built-in sv / fr / en texts if a row has none.
void main() {
  // The contract's texts, as the server writes them in his language.
  const rows = [
    (
      'en',
      'Deduction from your payout',
      '65,00 kr is taken from your next payout: the rider got money back for the trip. Reason: Wrong route',
    ),
    (
      'sv',
      'Avdrag från din utbetalning',
      '65,00 kr dras från din nästa utbetalning: resenären fick pengar tillbaka för resan. Orsak: Fel väg',
    ),
    (
      'fr',
      'Retenue sur votre versement',
      '5.000 DT sera retenu sur votre prochain versement : le passager a été remboursé pour la course. Motif : Détour',
    ),
  ];

  Map<String, Object?> row(String title, String body) => {
    'notificationId': 'ntf_1',
    'kind': 'driver_refund_taken',
    'title': title,
    'body': body,
    'at': '2026-11-14T10:00:00Z',
    'read': false,
    'tripId': 'trp_1',
    'deepLink': 'movera-driver://trips/trp_1',
  };

  test('driver_refund_taken is a money notice, not a trip warning', () {
    final notice = ServerNotification.fromJson(row('t', 'b'));
    expect(notice.isRefundTaken, isTrue);
    expect(notice.isTripWarning, isFalse);
    expect(notice.opensFleet, isFalse);
    expect(
      ServerNotification.fromJson({
        ...row('t', 'b'),
        'kind': 'driver_trip_update',
      }).isRefundTaken,
      isFalse,
    );
  });

  Future<void> showBell(
    WidgetTester tester,
    Map<String, Object?> item, {
    Future<List<TripHistoryRecord>> Function()? loadHistory,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final tokens = MemoryTokenStore()..save(access: 'a', refresh: 'r');
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/api/v1/notifications') {
          return http.Response(
            jsonEncode({
              'items': [item],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('{}', 200);
      }),
      baseUri: Uri.parse('https://api.test.movera.se'),
      tokens: tokens,
    );
    final account = DriverAccountSession(
      repository: DriverAccountRepository(api),
    );
    // A phone screen and a map that draws nothing: the trip page has a map.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final maps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          home: ServerNotificationsScreen(
            account: account,
            loadHistory: loadHistory,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (lang, title, body) in rows) {
    testWidgets('bell list ($lang): « $title » with the amount and why', (
      tester,
    ) async {
      await showBell(tester, row(title, body));
      expect(find.text(title), findsOneWidget);
      expect(find.text(body), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('notification-ntf_1')),
          matching: find.byIcon(Icons.payments_outlined),
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('a row without texts shows the built-in words', (tester) async {
    await showBell(tester, row('', ''));
    expect(find.text('Deduction from your payout'), findsOneWidget);
    expect(
      find.text(
        'Money was taken from your next payout because the rider got money back for a trip.',
      ),
      findsOneWidget,
    );
  });

  // Supervisor should-fix (Rules audits/impact/a7-c8-supervisor.md): a tap
  // opens the trip, as the contract's deep link movera-driver://trips/{tripId}.
  testWidgets('a tap opens that trip in Ride history', (tester) async {
    await showBell(
      tester,
      row(rows.first.$2, rows.first.$3),
      loadHistory: () async => const [
        TripHistoryRecord(
          tripId: 'trp_other',
          riderName: 'Sara',
          whenLabel: '13/11/2026, 09:00',
          pickup: 'Odenplan',
          dropoff: 'Slussen',
          fare: '99,00 kr',
          category: 'Economy',
        ),
        TripHistoryRecord(
          tripId: 'trp_1',
          riderName: 'Karin',
          whenLabel: '14/11/2026, 09:30',
          pickup: 'Gamla vägen',
          dropoff: 'Solna centrum',
          fare: '150,00 kr',
          category: 'Comfort',
        ),
      ],
    );
    await tester.tap(find.byKey(const ValueKey('notification-ntf_1')));
    await tester.pumpAndSettle();
    final detail = tester.widget<DriverRideHistoryDetail>(
      find.byType(DriverRideHistoryDetail),
    );
    expect(detail.record.tripId, 'trp_1');
  });

  testWidgets('a trip not on this phone opens Ride history', (tester) async {
    await showBell(
      tester,
      row(rows.first.$2, rows.first.$3),
      loadHistory: () async => const [],
    );
    await tester.tap(find.byKey(const ValueKey('notification-ntf_1')));
    await tester.pumpAndSettle();
    expect(find.byType(DriverRideHistory), findsOneWidget);
    expect(find.byType(DriverRideHistoryDetail), findsNothing);
  });
}

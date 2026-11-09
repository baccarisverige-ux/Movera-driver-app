import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/presentation/driver/notifications/server_notifications_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lifecycle L1 (contract v0.18.50 §72 `driverTripPush`, owner button
/// 2026-11-07 "New driver push (Recommended)" and "OK, these real texts"):
/// when the rider cancels or ends early, or an admin cancels, reassigns or
/// marks a no-show, the server writes a `driver_trip_update` entry (bell
/// true) with « Course annulée » and the moment's text. The bell list shows
/// it as a trip warning (warning icon), with the server's words.
void main() {
  // The contract's own texts (contract.json#driverTripPush, v0.18.50), as
  // the server writes them in the driver's language.
  const rows = [
    (
      'fr',
      'Course annulée',
      'Le passager a annulé la course. Vous recevez 35 kr.',
    ),
    ('sv', 'Resan är avbokad', 'Movera gav resan till en annan förare.'),
    ('en', 'Trip cancelled', 'Movera marked the rider as a no-show.'),
  ];

  ServerNotification notice(String kind) => ServerNotification.fromJson({
    'notificationId': 'ntf_$kind',
    'kind': kind,
    'title': 'Course annulée',
    'body': 'Le passager a annulé la course.',
    'at': '2026-11-07T10:00:00Z',
    'read': false,
    'tripId': 'trp_1',
    'deepLink': 'movera-driver://trips/trp_1',
  });

  test('driver_trip_update is a trip warning', () {
    expect(notice('driver_trip_update').isTripWarning, isTrue);
    // Unchanged: other kinds.
    expect(notice('reservation_taken_back').isTripWarning, isTrue);
    expect(notice('trip_pay_changed').isTripWarning, isFalse);
    expect(notice('fleet_invitation').isTripWarning, isFalse);
  });

  for (final (lang, title, body) in rows) {
    testWidgets('bell list ($lang): « $title » with a warning icon', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final tokens = MemoryTokenStore()..save(access: 'a', refresh: 'r');
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.url.path == '/api/v1/notifications') {
            return http.Response(
              jsonEncode({
                'items': [
                  {
                    'notificationId': 'ntf_1',
                    'kind': 'driver_trip_update',
                    'title': title,
                    'body': body,
                    'at': '2026-11-07T10:00:00Z',
                    'read': false,
                    'tripId': 'trp_1',
                    'deepLink': 'movera-driver://trips/trp_1',
                  },
                ],
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
      await tester.pumpWidget(
        MaterialApp(home: ServerNotificationsScreen(account: account)),
      );
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
      expect(find.text(body), findsOneWidget);
      final row = find.byKey(const ValueKey('notification-ntf_1'));
      expect(
        find.descendant(
          of: row,
          matching: find.byIcon(Icons.warning_amber_rounded),
        ),
        findsOneWidget,
      );
    });
  }
}

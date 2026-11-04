import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/preview/preview_mode.dart';
import 'package:movera/core/scheduled/server_reservations.dart';

// Owner 2026-11-04 (B7 "B: Empty screens"): with a preview token the server
// answers the driver's own reads with a brand-new account's empty result.
// These are the server's exact answers (movera-server
// test/config/preview_reads.test.ts); every read must parse, never throw.
void main() {
  final answers = <String, (int, Object?)>{
    '/api/v1/driver/profile': (
      200,
      {
        'driverId': 'preview:driver:Z001',
        'accountStatus': 'active',
        'onlineStatus': 'offline',
        'moving': false,
        'firstName': '',
        'zoneIds': ['Z001'],
        'categoryIds': <String>[],
        'documents': <Object>[],
        'version': 1,
      },
    ),
    '/api/v1/driver/fleet': (
      404,
      {'code': 'not_found', 'message': 'x', 'reason': 'no_fleet'},
    ),
    '/api/v1/driver/fleet/invitations': (200, {'items': <Object>[]}),
    '/api/v1/driver/reminders': (
      200,
      {'items': <Object>[], 'blocksOnline': 0},
    ),
    '/api/v1/driver/vehicles': (200, {'items': <Object>[], 'nextCursor': null}),
    '/api/v1/notifications': (200, {'items': <Object>[], 'nextCursor': null}),
  };
  late DriverAccountRepository account;

  setUp(() {
    account = DriverAccountRepository(
      ApiClient(
        client: MockClient((request) async {
          final hit = answers[request.url.path];
          if (hit == null) return http.Response('{"items":[]}', 200);
          return http.Response(jsonEncode(hit.$2), hit.$1);
        }),
        baseUri: Uri.parse('https://api.test'),
        tokens: PreviewTokenStore('a.b.c'),
        preview: const PreviewMode(token: 'a.b.c', zoneId: 'Z001'),
      ),
    );
  });

  test('blank profile, no fleet, no reminders, no cars: no error', () async {
    final profile = await account.profile();
    expect(profile, isNotNull);
    expect(await account.fleet(), isNull);
    expect(await account.invitations(), isEmpty);
    expect((await account.reminders()).items, isEmpty);
    expect(await account.vehicles(), isEmpty);
    expect(await account.notifications(), isEmpty);
    expect(
      ServerReservations.parsePage({'items': <Object>[], 'nextCursor': null}),
      isEmpty,
    );
  });
}

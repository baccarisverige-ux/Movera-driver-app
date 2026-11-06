import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/settings/server_settings_sync.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/core/vehicle/ride_categories.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// BASE B13 (contract v0.18.26 §47; owner 2026-11-03 "Phone-only data: Yes,
/// all to server"): Ride preferences and Emergency contacts are kept on the
/// server. Before this change SettingsRepository was phone-only: nothing
/// reached the server, so dispatch could not skip a switched-off category
/// and a new phone lost the contacts.
void main() {
  late List<String> calls;
  late Map<String, dynamic> preferences;
  late Map<String, dynamic> contacts;

  ApiClient api() => ApiClient(
    client: MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      final prefs = request.url.path.endsWith('/driver/preferences');
      if (request.method == 'PUT') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (prefs) {
          preferences = {...body, 'updatedAt': '2026-11-04T12:00:00Z'};
        } else {
          contacts = {...body, 'updatedAt': '2026-11-04T12:00:00Z'};
        }
      }
      return http.Response(
        jsonEncode(prefs ? preferences : contacts),
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
    baseUri: Uri.parse('https://api.example.test'),
    tokens: MemoryTokenStore()..save(access: 'a1', refresh: 'r1'),
  );

  setUp(() {
    calls = [];
    preferences = {'categoriesOff': <String>[], 'updatedAt': null};
    contacts = {'items': <Object>[], 'updatedAt': null};
    SharedPreferences.setMockInitialValues({});
    SettingsRepository.remote = ServerSettingsSync(api: api());
  });
  tearDown(() => SettingsRepository.remote = null);

  test('switching a category off is saved on the server as its id', () async {
    final selected = List<bool>.filled(DriverCategoryAccess.all.length, true);
    selected[DriverCategoryAccess.all.indexOf('Premium')] = false;
    await SettingsRepository().save(DriverCategoryChoice.section, {
      'selected': selected,
    });
    expect(calls, ['PUT /api/v1/driver/preferences']);
    expect(preferences['categoriesOff'], ['premium']);
  });

  test('a new phone shows the choice the server keeps', () async {
    preferences = {
      'categoriesOff': ['premium'],
      'updatedAt': '2026-11-04T11:00:00Z',
    };
    final data = await SettingsRepository().read(DriverCategoryChoice.section);
    final selected = data['selected'] as List<bool>;
    expect(selected[DriverCategoryAccess.all.indexOf('Premium')], isFalse);
    expect(selected[DriverCategoryAccess.all.indexOf('Comfort')], isTrue);
  });

  test('contacts kept only on the phone are uploaded once', () async {
    SettingsRepository.remote = null;
    await SettingsRepository().save('contacts', {
      'rows': [
        {'name': 'Sara', 'phone': '+46 70 123 45 67', 'relation': 'Sister'},
      ],
    });
    SettingsRepository.remote = ServerSettingsSync(api: api());
    final rows = (await SettingsRepository().read('contacts'))['rows'] as List;
    expect(rows.single['name'], 'Sara');
    expect(calls, [
      'GET /api/v1/driver/emergency-contacts',
      'PUT /api/v1/driver/emergency-contacts',
    ]);
    expect(contacts['items'], [
      {'name': 'Sara', 'phone': '+46701234567', 'relation': 'Sister'},
    ]);
    // Next time the server's list is read; nothing is uploaded again.
    calls.clear();
    await SettingsRepository().read('contacts');
    expect(calls, ['GET /api/v1/driver/emergency-contacts']);
  });

  test('offline: the phone copy is shown', () async {
    SettingsRepository.remote = null;
    await SettingsRepository().save('contacts', {
      'rows': [
        {'name': 'Paul', 'phone': '0612345678'},
      ],
    });
    SettingsRepository.remote = ServerSettingsSync(
      api: ApiClient(
        client: MockClient((_) async => throw http.ClientException('offline')),
        baseUri: Uri.parse('https://api.example.test'),
        tokens: MemoryTokenStore()..save(access: 'a1', refresh: 'r1'),
      ),
    );
    final rows = (await SettingsRepository().read('contacts'))['rows'] as List;
    expect(rows.single['name'], 'Paul');
  });
}

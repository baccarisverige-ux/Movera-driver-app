import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/privacy/local_data.dart';
import 'package:movera/core/support/local_support_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // UAT 2026-10-22: the rider app keeps its language across sign-out; the
  // driver app wiped it, so Log out switched the phone to the zone default.
  test('logout clear keeps the driver\'s language', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'movera_driver_settings_section_language':
          '{"schemaVersion":1,"values":{"code":"en"}}',
      'movera_driver_settings_section_contacts': '{"schemaVersion":1,"values":{}}',
    });
    await clearLocalUserData();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('movera_driver_settings_section_language'), isNotNull);
    expect(prefs.getString('movera_driver_settings_section_contacts'), isNull);
  });

  test('logout clear removes personal keys and leaves other keys', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'movera_driver_support_drafts': '{not json',
      'movera_driver_settings_section_contacts':
          '{"schemaVersion":1,"values":{"rows":[{"phone":"+46701112233"}]}}',
      'movera_driver_completed_trips': '{"schemaVersion":1,"rows":[]}',
      'movera_driver_active_ride': '{"tripId":"trip-1"}',
      'movera_driver_terminal_trips': <String>['trip-1'],
      'movera_driver_completion_journal': '{}',
      'movera_driver_settings': '{}',
      'unrelated_preview_flag': 'keep',
    });

    final before = LocalSupportRepository();
    await expectLater(before.read(), throwsA(isA<SupportDataUnreadable>()));

    await clearLocalUserData();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('movera_driver_support_drafts'), isNull);
    expect(prefs.getString('movera_driver_settings_section_contacts'), isNull);
    expect(prefs.getString('movera_driver_completed_trips'), isNull);
    expect(prefs.getString('movera_driver_active_ride'), isNull);
    expect(prefs.getStringList('movera_driver_terminal_trips'), isNull);
    expect(prefs.getString('movera_driver_completion_journal'), isNull);
    expect(prefs.getString('movera_driver_settings'), isNull);
    expect(prefs.getString('unrelated_preview_flag'), 'keep');
    expect(
      localDataInventory.map((record) => record.key),
      containsAll(<String>[
        'movera_driver_active_ride',
        'movera_driver_completed_trips',
        'movera_driver_support_drafts',
      ]),
    );
  });
}

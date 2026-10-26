import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:movera/core/ride/prefs_active_ride_repository.dart';
import 'package:movera/core/ride/active_ride_repository.dart';

class FaultPrefs extends SharedPreferencesStorePlatform {
  bool throws = false;
  @override
  Future<Map<String, Object>> getAll() async => {};
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (throws) throw StateError('write fault');
    return false;
  }

  @override
  Future<bool> remove(String key) async {
    if (throws) throw StateError('remove fault');
    return false;
  }

  @override
  Future<bool> clear() async => false;
}

void main() {
  for (final throws in [false, true]) {
    test('prefs $throws faults are observable', () async {
      SharedPreferences.setMockInitialValues({});
      final original = SharedPreferencesStorePlatform.instance;
      final faulty = FaultPrefs()..throws = throws;
      SharedPreferencesStorePlatform.instance = faulty;
      addTearDown(() => SharedPreferencesStorePlatform.instance = original);
      final repo = PrefsActiveRideRepository();
      await expectLater(
        repo.save(
          const PersistedActiveRide(tripId: 'A', stage: ActiveRideStage.onTrip),
        ),
        throwsStateError,
      );
      await expectLater(repo.clear(), throwsStateError);
    });
  }
}

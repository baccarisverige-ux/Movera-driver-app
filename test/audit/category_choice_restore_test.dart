import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/core/vehicle/ride_categories.dart';
import 'package:movera/main.dart';
import 'package:movera/presentation/driver/preferences/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

// driver-31 / driver-78: the categories a driver switched off in Ride
// preferences are saved, and offers must follow that choice after a cold
// start, not only once Ride preferences is opened again.

/// Stored order is DriverCategoryAccess.all: Comfort and Movera Pet off.
const _saved = <bool>[true, false, true, true, true, true, false, true];

class _NoGps implements DriverLocationRepository {
  const _NoGps();
  @override
  Future<DriverLocation> getCurrentPosition() =>
      Future<DriverLocation>.error(StateError('no GPS in this test'));
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream<DriverLocation>.empty();
}

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(375, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const MoveraApp(locationRepository: _NoGps()));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'driver-31 the saved choice is restored into the offer filter',
    () async {
      await SettingsRepository().save('categories', {'selected': _saved});
      expect(DriverCategoryChoice.off.value, isEmpty);

      await DriverCategoryChoice.restore();

      expect(DriverCategoryChoice.off.value, {'Comfort', 'Movera Pet'});
      expect(DriverCategoryChoice.takes('Comfort'), isFalse);
      expect(DriverCategoryChoice.takes('Movera Pet'), isFalse);
      expect(DriverCategoryChoice.takes('Premium'), isTrue);
    },
  );

  test(
    'driver-31 a missing or unreadable choice keeps every category on',
    () async {
      await SettingsRepository().save('categories', {'selected': 'bad'});
      await DriverCategoryChoice.restore();
      expect(DriverCategoryChoice.off.value, isEmpty);
    },
  );

  testWidgets('driver-78 a cold start applies the saved choice to offers', (
    tester,
  ) async {
    await tester.runAsync(
      () => SettingsRepository().save('categories', {'selected': _saved}),
    );
    await _pumpApp(tester);

    expect(DriverCategoryChoice.off.value, {'Comfort', 'Movera Pet'});
    expect(DriverCategoryChoice.takes('Comfort'), isFalse);
    await _unmount(tester);
  });

  testWidgets('driver-78 Ride preferences shows the same choice it restored', (
    tester,
  ) async {
    await tester.runAsync(
      () => SettingsRepository().save('categories', {'selected': _saved}),
    );
    await tester.runAsync(DriverCategoryChoice.restore);
    final restored = DriverCategoryChoice.off.value;

    await tester.pumpWidget(const MaterialApp(home: Preferences()));
    await tester.pumpAndSettle();

    expect(DriverCategoryChoice.off.value, restored);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/vehicle/ride_categories.dart';
import 'package:movera/main.dart';
import 'package:movera/widgets/demo_mode_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

// driver-82: logout clears the saved Ride-preferences choice, so the
// in-memory offer filter must be cleared with it.

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

  testWidgets('driver-82 logout clears the in-memory category filter', (
    tester,
  ) async {
    await _pumpApp(tester);
    DriverCategoryChoice.off.value = {'Comfort'};
    expect(DriverCategoryChoice.takes('Comfort'), isFalse);

    final scope = DriverRuntimeScope.maybeOf(
      tester.element(find.byType(DemoModeBanner)),
    )!;
    await tester.runAsync(scope.logout!);
    await tester.pump();

    expect(DriverCategoryChoice.off.value, isEmpty);
    expect(DriverCategoryChoice.takes('Comfort'), isTrue);
    await _unmount(tester);
  });
}

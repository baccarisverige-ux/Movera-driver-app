import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/location/driver_location_service.dart';
import 'package:movera/core/location/location_freshness.dart';

void main() {
  test('denied stale invalid and fresh GPS are distinguished', () {
    final now = DateTime(2026);
    expect(hasFreshLocation(null, null, now), false);
    expect(
      hasFreshLocation(
        const GeoPoint(59, 18),
        now.subtract(const Duration(seconds: 31)),
        now,
      ),
      false,
    );
    expect(hasFreshLocation(const GeoPoint(999, 18), now, now), false);
    expect(hasFreshLocation(const GeoPoint(59, 18), now, now), true);
  });

  test('last known GPS fallback requires a recent accurate fix', () {
    final now = DateTime.utc(2026, 10, 8, 14);
    DriverLocation sample({
      Duration age = Duration.zero,
      double accuracy = 5,
      GeoPoint point = const GeoPoint(59.3, 18.0),
    }) => DriverLocation(
      point: point,
      measuredAt: now.subtract(age),
      accuracyMeters: accuracy,
    );

    final recent = sample(age: const Duration(seconds: 30));
    expect(DriverLocationService.vetCachedFix(recent, now), same(recent));
    expect(DriverLocationService.vetCachedFix(null, now), isNull);
    expect(
      DriverLocationService.vetCachedFix(
        sample(age: const Duration(seconds: 31)),
        now,
      ),
      isNull,
    );
    // A fix stamped beyond the clock-skew tolerance is still refused.
    expect(
      DriverLocationService.vetCachedFix(
        sample(age: const Duration(seconds: -6)),
        now,
      ),
      isNull,
    );
    expect(
      DriverLocationService.vetCachedFix(sample(accuracy: 51), now),
      isNull,
    );
    expect(
      DriverLocationService.vetCachedFix(
        sample(point: const GeoPoint(100, 18)),
        now,
      ),
      isNull,
    );
    expect(
      DriverLocationService.vetCachedFix(sample(accuracy: double.nan), now),
      isNull,
    );
  });
}

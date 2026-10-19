import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';

void main() {
  final now = DateTime.utc(2026, 10, 8, 18);
  const car = GeoPoint(59.33, 18.06);
  DriverLocation at({
    GeoPoint point = car,
    DateTime? measuredAt,
    double? accuracy,
  }) => DriverLocation(
    point: point,
    measuredAt: measuredAt,
    accuracyMeters: accuracy,
  );

  test('measured map positions require fresh accurate real GPS', () {
    expect(at(measuredAt: now, accuracy: 5).isDisplayableAt(now), isTrue);
    expect(at(
      measuredAt: now.subtract(const Duration(seconds: 30)),
      accuracy: 50,
    ).isDisplayableAt(now), isTrue);
    expect(at(
      measuredAt: now.subtract(const Duration(seconds: 31)),
      accuracy: 5,
    ).isDisplayableAt(now), isFalse);
    // A GPS clock a little ahead of the phone clock is still fresh (D-03);
    // beyond the tolerance a fix from the future is refused.
    expect(at(
      measuredAt: now.add(const Duration(seconds: 1)),
      accuracy: 5,
    ).isDisplayableAt(now), isTrue);
    expect(at(
      measuredAt: now.add(const Duration(seconds: 6)),
      accuracy: 5,
    ).isDisplayableAt(now), isFalse);
    expect(at(measuredAt: now, accuracy: 51).isDisplayableAt(now), isFalse);
    expect(at(measuredAt: now, accuracy: double.nan).isDisplayableAt(now), isFalse);
    expect(at(measuredAt: now).isDisplayableAt(now), isFalse);
    expect(at(accuracy: 5).isDisplayableAt(now), isFalse);
  });

  test('invalid coordinates are rejected even in demo mode', () {
    expect(at().isDisplayableAt(now), isTrue);
    for (final point in [
      const GeoPoint(91, 18),
      const GeoPoint(-91, 18),
      const GeoPoint(59, 181),
      const GeoPoint(59, -181),
      const GeoPoint(double.nan, 18),
      const GeoPoint(59, double.infinity),
    ]) {
      expect(at(point: point).isDisplayableAt(now), isFalse);
      expect(at(point: point, measuredAt: now, accuracy: 5).isDisplayableAt(now), isFalse);
    }
  });
}

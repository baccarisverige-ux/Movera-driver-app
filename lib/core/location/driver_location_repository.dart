import 'package:movera/core/geo/geo_point.dart';

/// A fix may be stamped by the GPS clock a little ahead of the phone clock.
/// Up to this much "from the future" still counts as fresh.
const Duration gpsClockSkewTolerance = Duration(seconds: 5);

class DriverLocation {
  const DriverLocation({
    required this.point,
    this.headingDegrees = 0,
    this.speedMetersPerSecond,
    this.measuredAt,
    this.accuracyMeters,
  });

  final GeoPoint point;
  final double headingDegrees;
  final double? speedMetersPerSecond;

  /// A stationary/invalid GPS course must never spin the vehicle marker.
  double courseOr(double previous) =>
      speedMetersPerSecond != null &&
          speedMetersPerSecond!.isFinite &&
          speedMetersPerSecond! >= 1 &&
          headingDegrees.isFinite &&
          headingDegrees >= 0 &&
          headingDegrees <= 360
      ? headingDegrees % 360
      : previous;
  final DateTime? measuredAt;
  final double? accuracyMeters;

  /// Map and demo boundary. A real measured GPS fix must be fresh and
  /// accurate; metadata-free demo points remain usable for frontend previews.
  bool isDisplayableAt(DateTime now) {
    if (!point.latitude.isFinite ||
        !point.longitude.isFinite ||
        point.latitude.abs() > 90 ||
        point.longitude.abs() > 180) {
      return false;
    }
    if (measuredAt != null || accuracyMeters != null) {
      return isUsableAt(now);
    }
    return true;
  }

  /// Driver group 3: a fresh fix good enough to open the map near the
  /// driver (up to [startHintAccuracyMeters] wide, at most 2 min old),
  /// though too rough for the car's own position or a trip.
  bool isStartHintAt(DateTime now) {
    final at = measuredAt, accuracy = accuracyMeters;
    if (at == null || !point.latitude.isFinite || !point.longitude.isFinite) {
      return false;
    }
    if (point.latitude.abs() > 90 || point.longitude.abs() > 180) return false;
    if (accuracy != null &&
        (!accuracy.isFinite ||
            accuracy < 0 ||
            accuracy > startHintAccuracyMeters)) {
      return false;
    }
    final age = now.difference(at);
    return age >= -gpsClockSkewTolerance && age <= const Duration(minutes: 2);
  }

  static const double startHintAccuracyMeters = 2000;

  bool isUsableAt(DateTime now) {
    final at = measuredAt, accuracy = accuracyMeters;
    if (at == null ||
        accuracy == null ||
        !accuracy.isFinite ||
        accuracy < 0 ||
        accuracy > 50) {
      return false;
    }
    final age = now.difference(at);
    return age >= -gpsClockSkewTolerance &&
        age <= const Duration(seconds: 30) &&
        point.latitude.isFinite &&
        point.longitude.isFinite &&
        point.latitude.abs() <= 90 &&
        point.longitude.abs() <= 180;
  }
}

abstract interface class DriverLocationRepository {
  Future<DriverLocation> getCurrentPosition();

  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8});
}

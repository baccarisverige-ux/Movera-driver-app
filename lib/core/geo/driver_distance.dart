/// Q20: how the driver app writes an offer or trip distance. Under 1 km in
/// metres, rounded to 10 m ("650 m"); from 1 km in km, one decimal under
/// 10 km ("4.2 km") and whole km from there ("12 km").
String driverDistanceMeters(double meters) {
  if (!meters.isFinite || meters < 0) return '0 m';
  final tens = (meters / 10).round() * 10;
  if (tens < 1000) return '$tens m';
  final km = meters / 1000;
  return '${km.toStringAsFixed(km < 9.95 ? 1 : 0)} km';
}

/// [driverDistanceMeters] for a distance kept in km.
String driverDistanceKm(double km) => driverDistanceMeters(km * 1000);

/// "650 m · 2 min", "4.2 km · 9 min".
String driverDistanceAndMinutes(double km, int minutes) =>
    '${driverDistanceKm(km)} · $minutes min';

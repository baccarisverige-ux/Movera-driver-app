/// Owner 2026-11-25 ("km, m under 100"): the early-end warning on the
/// Collect cash sheet writes the distance in km with one decimal and the
/// locale's decimal separator (4226 m -> "4,2 km" in fr/sv, "4.2 km" in
/// en); metres only below 100 m (80 m -> "80 m").
String formatEarlyEndDistance(int meters, String localeName) {
  if (meters < 100) return '$meters m';
  final tenths = (meters / 100).round();
  final sep = localeName.startsWith('en') ? '.' : ',';
  return '${tenths ~/ 10}$sep${tenths % 10} km';
}

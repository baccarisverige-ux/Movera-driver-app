import 'package:movera/core/auth/phone_country_default.dart';
import 'package:movera/core/geo/geo_point.dart';

/// Where Home's map opens before any position of this run is known
/// (owner REMINDERS 145; every rule works for Sweden, France and Tunisia):
/// the saved last position, else the centre of the driver's working zone,
/// else the centre of the driver's country, Stockholm only as the last
/// resort.
abstract final class DriverStartCentre {
  static const GeoPoint stockholm = GeoPoint(59.3293, 18.0686);

  /// Country (ISO) centres: the main city the zones start from.
  static const Map<String, GeoPoint> countries = {
    'SE': stockholm,
    'FR': GeoPoint(48.8566, 2.3522),
    'TN': GeoPoint(36.8065, 10.1815),
  };

  static GeoPoint pick({
    GeoPoint? saved,
    GeoPoint? zoneCentre,
    String? country,
  }) {
    if (saved != null && saved.isValid) return saved;
    if (zoneCentre != null && zoneCentre.isValid) return zoneCentre;
    return countries[country?.toUpperCase()] ?? stockholm;
  }

  /// [pick] from what the phone kept ([StartCountryHints], read in main).
  static GeoPoint fromHints({GeoPoint? saved}) => pick(
    saved: saved,
    zoneCentre: StartCountryHints.zoneCentre,
    country:
        StartCountryHints.zoneCountry ??
        StartCountryHints.fixCountry ??
        defaultPhoneCountry().iso,
  );
}

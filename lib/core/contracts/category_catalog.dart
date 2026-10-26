/// Ride category ids, `contracts/contract.json#categories` (v0.3.0).
///
/// Ids come from the admin Pricing catalog (admins can add more); these are
/// the seed ids every app must know. Labels are display only: the driver app
/// still shows and stores its historic names ("Movera", "Movera XL"), and
/// this catalog maps them to ids at the boundary.
abstract final class CategoryCatalog {
  static final RegExp pattern = RegExp(r'^[a-z][a-z0-9_]{1,31}$');

  static const List<String> seed = <String>[
    'economy',
    'comfort',
    'premium',
    'priority',
    'xl',
    'electric',
    'pet',
  ];

  /// Accepted on read for one release (`movera` was the old economy id).
  static const Map<String, String> aliases = <String, String>{
    'movera': 'economy',
  };

  /// The driver app's display names for the seed ids.
  static const Map<String, String> driverLabels = <String, String>{
    'economy': 'Movera',
    'comfort': 'Comfort',
    'premium': 'Premium',
    'priority': 'Priority',
    'xl': 'Movera XL',
    'electric': 'Electric',
    'pet': 'Movera Pet',
  };

  /// Short names some offers use.
  static const Map<String, String> _shortLabels = <String, String>{'XL': 'xl'};

  /// A wire id, with aliases resolved. Null when it is not a valid id
  /// (unknown but well-formed ids pass: the admin catalog may add them).
  static String? canonicalId(String? raw) {
    if (raw == null) return null;
    final id = aliases[raw] ?? raw;
    return pattern.hasMatch(id) ? id : null;
  }

  static bool isSeed(String id) => seed.contains(canonicalId(id));

  /// Display name for [id]: the driver label, else the id itself.
  static String labelOf(String id) {
    final canonical = canonicalId(id) ?? id;
    return driverLabels[canonical] ?? canonical;
  }

  /// The id behind a driver display name, or null when the name is not a
  /// category (e.g. "Booster Seat", an extra).
  static String? idForLabel(String label) {
    final short = _shortLabels[label];
    if (short != null) return short;
    for (final entry in driverLabels.entries) {
      if (entry.value == label) return entry.key;
    }
    final id = canonicalId(label.toLowerCase());
    return id != null && seed.contains(id) ? id : null;
  }
}

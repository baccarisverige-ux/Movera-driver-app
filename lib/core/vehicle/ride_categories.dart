import 'package:flutter/foundation.dart';

/// Ride categories a driver can drive (Q27). Admin decides them from the
/// car (Vehicles in admin); the driver can switch some off in Ride
/// preferences, and offers follow that choice.
class DriverCategoryAccess {
  const DriverCategoryAccess({
    required this.vehicleId,
    required this.allowed,
  });

  /// Every category in the app, by the name offers use.
  static const List<String> all = <String>[
    'Movera',
    'Comfort',
    'Premium',
    'Priority',
    'Movera XL',
    'Electric',
    'Movera Pet',
    'Booster Seat',
  ];

  /// The demo car, a black Mercedes-Benz E 220 with 4 seats: not XL and
  /// not electric. A backend sends the admin's choice.
  static DriverCategoryAccess current = const DriverCategoryAccess(
    vehicleId: 'V-418',
    allowed: <String>[
      'Movera',
      'Comfort',
      'Premium',
      'Priority',
      'Movera Pet',
      'Booster Seat',
    ],
  );

  final String vehicleId;
  final List<String> allowed;

  /// Offers sometimes use short names, e.g. "XL".
  static String nameOf(String category) =>
      category == 'XL' ? 'Movera XL' : category;

  bool allows(String category) {
    final name = nameOf(category);
    return !all.contains(name) || allowed.contains(name);
  }
}

/// The categories this driver switched off (Q27), kept for the session.
/// Ride preferences saves the choice and sets it here.
class DriverCategoryChoice {
  DriverCategoryChoice._();

  static final ValueNotifier<Set<String>> off =
      ValueNotifier<Set<String>>(const <String>{});

  /// True when this driver gets [category] offers: admin allows it and
  /// the driver has not switched it off.
  static bool takes(String category) =>
      DriverCategoryAccess.current.allows(category) &&
      !off.value.contains(DriverCategoryAccess.nameOf(category));

  static void reset() => off.value = const <String>{};
}

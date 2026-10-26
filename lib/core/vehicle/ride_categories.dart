import 'package:flutter/foundation.dart';
import 'package:movera/core/settings/settings_repository.dart';

/// Ride categories a driver can drive (Q27). Admin decides them from the
/// car (Vehicles in admin); the driver can switch some off in Ride
/// preferences, and offers follow that choice.
class DriverCategoryAccess {
  const DriverCategoryAccess({required this.vehicleId, required this.allowed});

  /// Every category in the app, by the name offers use. This is also the
  /// stored order of the Ride-preferences choice: append only.
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

/// The categories this driver switched off (Q27). Ride preferences saves
/// the choice and sets it here; [restore] loads it at app start.
class DriverCategoryChoice {
  DriverCategoryChoice._();

  /// The settings section Ride preferences saves to.
  static const String section = 'categories';

  static final ValueNotifier<Set<String>> off = ValueNotifier<Set<String>>(
    const <String>{},
  );

  /// Applies the saved choice, so offers follow it after a restart and not
  /// only once Ride preferences is opened (driver-31, driver-78). A missing
  /// or unreadable choice keeps every category on, as the screen does. A
  /// choice published while the read is pending wins.
  static Future<void> restore([SettingsRepository? repository]) async {
    final before = off.value;
    try {
      final data = await (repository ?? SettingsRepository()).read(section);
      if (identical(off.value, before)) {
        off.value = fromSaved(data['selected']);
      }
    } catch (_) {
      // Every category stays on.
    }
  }

  /// The switched-off set for a saved `selected` list (indexed by
  /// [DriverCategoryAccess.all]; missing entries are on).
  static Set<String> fromSaved(Object? saved) {
    const all = DriverCategoryAccess.all;
    if (saved is! List ||
        saved.length > all.length ||
        !saved.every((value) => value is bool)) {
      return const <String>{};
    }
    return {
      for (var index = 0; index < saved.length; index++)
        if (saved[index] == false &&
            DriverCategoryAccess.current.allows(all[index]))
          all[index],
    };
  }

  /// True when this driver gets [category] offers: admin allows it and
  /// the driver has not switched it off.
  static bool takes(String category) =>
      DriverCategoryAccess.current.allows(category) &&
      !off.value.contains(DriverCategoryAccess.nameOf(category));

  static void reset() => off.value = const <String>{};
}

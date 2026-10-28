import 'package:movera/core/l10n/driver_l10n.dart';

/// A ride category's name as the driver reads it (owner 2026-10-28). The
/// app keeps and sends the English names of the seed categories
/// ([CategoryCatalog.driverLabels]); the screens show the plain words among
/// them in the driver's language. Brand names ("Movera", "Movera XL",
/// "Movera Pet"), "Premium" and names admin wrote stay as they are.
String categoryNameText(String name) => switch (name.trim()) {
  'Comfort' => tr.categoryComfort,
  'Priority' => tr.categoryPriority,
  'Electric' => tr.categoryElectric,
  'Booster Seat' => tr.categoryBoosterSeat,
  'XL' => 'Movera XL',
  _ => name,
};

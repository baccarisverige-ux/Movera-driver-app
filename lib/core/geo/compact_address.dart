/// Owner 2026-11-07 (driver trip detail ended with ", Sweden"): the rider
/// app's place formatting (movera-rider-app destination_search
/// compact_address.dart), the same rules here.
///
/// Shortens a geocoder address to "street, city" for display: drops the
/// country, "… kommun"/"… län" style regions, postal codes and repeated
/// parts, then keeps the first part (street or place) and the last town.
String compactAddress(String? address) {
  final value = address?.trim() ?? '';
  if (value.isEmpty) return '';
  final seen = <String>{};
  final parts = <String>[];
  for (final raw in value.split(',')) {
    final part = raw.trim();
    if (part.isEmpty) continue;
    final lower = part.toLowerCase();
    if (_countries.contains(lower)) continue;
    if (_regionSuffixes.any(lower.endsWith)) continue;
    // rider-r5-39: French names put the region word first.
    if (_regionPrefixes.any(lower.startsWith)) continue;
    if (_postal.hasMatch(part)) continue;
    if (!seen.add(lower)) continue;
    parts.add(part);
  }
  if (parts.isEmpty) return value.split(',').first.trim();
  if (parts.length <= 2) return parts.join(', ');
  return '${parts.first}, ${parts.last}';
}

final RegExp _postal = RegExp(r'^[A-Z]{0,2}[-\s]?\d{3,5}(\s?\d{2,3})?$');

const _countries = {
  'sverige',
  'sweden',
  'norge',
  'norway',
  'danmark',
  'denmark',
  'suomi',
  'finland',
  'france',
  'frankrike',
  'tunisie',
  'tunisia',
  'tunisien',
  'deutschland',
  'germany',
  'tyskland',
};

const _regionSuffixes = [
  ' kommun',
  ' län',
  ' municipality',
  ' county',
  ' region',
  ' governorate',
  ' gouvernorat',
  ' département',
];

const _regionPrefixes = [
  'gouvernorat ',
  'département ',
  'région ',
  'délégation ',
];

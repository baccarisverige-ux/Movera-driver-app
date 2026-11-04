import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/contracts/category_catalog.dart';
import 'package:movera/core/vehicle/ride_categories.dart';

/// BASE B13 (contract v0.18.26 §47, `contract.json#phoneDataToServer`; owner
/// 2026-11-03 "Phone-only data: Yes, all to server"): Ride preferences and
/// Emergency contacts are kept on the server, not only on this phone.
///
/// [SettingsRepository] asks this for the two sections it covers:
/// `categories` (`GET|PUT /driver/preferences`, the switched-off categories;
/// the server then stops sending them) and `contacts`
/// (`GET|PUT /driver/emergency-contacts`). The phone copy stays as the
/// offline fallback. When the server never had the section (`updatedAt`
/// null), the phone's own values are uploaded once.
abstract class RemoteSettings {
  bool handles(String section);

  /// The server's values for [section] in the phone's format. [local] is the
  /// phone copy: uploaded when the server has never saved this section.
  Future<Map<String, dynamic>> read(String section, Map<String, dynamic> local);

  Future<void> save(String section, Map<String, dynamic> values);
}

class ServerSettingsSync implements RemoteSettings {
  ServerSettingsSync({required ApiClient api}) : _api = api;

  final ApiClient _api;

  static const categoriesSection = DriverCategoryChoice.section;
  static const contactsSection = 'contacts';
  static const _preferences = '/api/v1/driver/preferences';
  static const _contacts = '/api/v1/driver/emergency-contacts';

  @override
  bool handles(String section) =>
      section == categoriesSection || section == contactsSection;

  @override
  Future<Map<String, dynamic>> read(
    String section,
    Map<String, dynamic> local,
  ) async {
    final path = section == categoriesSection ? _preferences : _contacts;
    final answer = await _api.get(path);
    if (answer['updatedAt'] == null) {
      // Never saved on the server: the phone's choice goes up once.
      if (local.isNotEmpty) await save(section, local);
      return local;
    }
    return section == categoriesSection
        ? {'selected': selectedFromOff(_strings(answer['categoriesOff']))}
        : {'rows': rowsFromItems(answer['items'])};
  }

  @override
  Future<void> save(String section, Map<String, dynamic> values) async {
    if (section == categoriesSection) {
      await _api.put(
        _preferences,
        body: {'categoriesOff': offFromSelected(values['selected'])},
      );
    } else {
      await _api.put(_contacts, body: {'items': itemsFromRows(values['rows'])});
    }
  }

  static List<String> _strings(Object? value) => value is List
      ? [
          for (final v in value)
            if (v is String) v,
        ]
      : const <String>[];

  /// The phone's `selected` list (indexed by [DriverCategoryAccess.all]) as
  /// the category ids switched off.
  static List<String> offFromSelected(Object? selected) {
    if (selected is! List) return const <String>[];
    const all = DriverCategoryAccess.all;
    final off = <String>{};
    for (var i = 0; i < selected.length && i < all.length; i++) {
      if (selected[i] != false) continue;
      final id = CategoryCatalog.idForLabel(all[i]);
      if (id != null) off.add(id);
    }
    return off.toList();
  }

  /// The server's switched-off ids as the phone's `selected` list.
  static List<bool> selectedFromOff(List<String> off) => [
    for (final name in DriverCategoryAccess.all)
      !off.contains(CategoryCatalog.idForLabel(name)),
  ];

  static String _digits(String phone) =>
      phone.replaceAll(RegExp(r'[\s()-]'), '');

  /// The phone's contact rows as `EmergencyContact`s (112 is built in and
  /// never stored).
  static List<Map<String, String>> itemsFromRows(Object? rows) => [
    if (rows is List)
      for (final row in rows)
        if (row is Map &&
            row['name'] is String &&
            row['phone'] is String &&
            _digits(row['phone'] as String) != '112' &&
            RegExp(
              r'^\+?[0-9]{3,15}$',
            ).hasMatch(_digits(row['phone'] as String)))
          {
            'name': (row['name'] as String).trim(),
            'phone': _digits(row['phone'] as String),
            if (row['relation'] is String &&
                (row['relation'] as String).trim().isNotEmpty)
              'relation': (row['relation'] as String).trim(),
          },
  ];

  static List<Map<String, String>> rowsFromItems(Object? items) => [
    if (items is List)
      for (final item in items)
        if (item is Map && item['name'] is String && item['phone'] is String)
          {
            'name': item['name'] as String,
            'phone': item['phone'] as String,
            if (item['relation'] is String)
              'relation': item['relation'] as String,
          },
  ];
}

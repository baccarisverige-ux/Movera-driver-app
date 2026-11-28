import 'package:flutter/foundation.dart';

/// Contract v0.18.172 (`contract.json#preferredAreas`): one `Area` the
/// driver may prefer. Never a polygon, never an address.
class PreferredArea {
  const PreferredArea({
    required this.areaId,
    required this.name,
    required this.kind,
    required this.kindLabel,
    this.parentName,
  });

  final String areaId;
  final String name;
  final String kind;

  /// The kind in the driver's language, from the server ("Kommun",
  /// "Område", "Commune", ...).
  final String kindLabel;

  /// The area it lies in ("Stockholm" for Södermalm), when known.
  final String? parentName;

  /// "Södermalm, Stockholm" (the address answer's row).
  String get nameWithParent =>
      parentName == null || parentName!.isEmpty ? name : '$name, $parentName';

  static PreferredArea? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['areaId'], name = json['name'];
    if (id is! String || id.isEmpty || name is! String || name.isEmpty) {
      return null;
    }
    return PreferredArea(
      areaId: id,
      name: name,
      kind: json['kind'] is String ? json['kind'] as String : '',
      kindLabel: json['kindLabel'] is String ? json['kindLabel'] as String : '',
      parentName: json['parentName'] is String
          ? json['parentName'] as String
          : null,
    );
  }

  static List<PreferredArea> listOf(Object? list) => [
    if (list is List)
      for (final item in list) ?PreferredArea.fromJson(item),
  ];

  @override
  bool operator ==(Object other) =>
      other is PreferredArea && other.areaId == areaId;

  @override
  int get hashCode => areaId.hashCode;
}

/// What the picker needs from the server. [LiveReservations] is the live
/// one; tests pass a fake.
abstract class PreferredAreasApi {
  /// `GET /driver/areas/search?q=` (areas only).
  Future<List<PreferredArea>> searchAreas(String query);

  /// `GET /driver/areas/at?lat=&lng=`: the smallest area of his zones that
  /// holds the point, or null. The point is not kept.
  Future<PreferredArea?> areaAt(double lat, double lng);

  /// `PUT /driver/preferred-areas { areaIds }`: the saved list, or null
  /// when it did not save.
  Future<List<PreferredArea>?> setPreferredAreas(List<String> areaIds);

  /// His saved areas (`Driver.preferredAreas` of `GET /driver/profile`).
  Future<List<PreferredArea>> loadPreferredAreas();
}

/// The driver's saved preferred areas, for the house icon's count badge.
/// Kept in memory only.
class PreferredAreasStore {
  PreferredAreasStore._();

  static final ValueNotifier<List<PreferredArea>> saved = ValueNotifier(
    const [],
  );

  static Future<void> refresh(PreferredAreasApi api) async {
    try {
      saved.value = await api.loadPreferredAreas();
    } catch (_) {
      // A failed read keeps what is shown.
    }
  }
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/settings/settings_repository.dart';

/// Which local photo limit a photo would break.
enum VehiclePhotoLimit { photoTooLarge, storageFull }

/// The local photo budget would be exceeded.
class VehiclePhotoBudgetExceeded implements Exception {
  const VehiclePhotoBudgetExceeded(this.limit);
  final VehiclePhotoLimit limit;

  /// What the driver reads, in their language (driver-51).
  String get message => switch (limit) {
    VehiclePhotoLimit.photoTooLarge => tr.photoTooLargeForDevice,
    VehiclePhotoLimit.storageFull => tr.photoStorageFull,
  };

  @override
  String toString() => message;
}

/// Device-only drafts; no vehicle activation or document verification.
///
/// Photos are kept as base64 inside preferences, which is localStorage on web
/// (about 5 MB per origin, shared with trips and settings). New photos are
/// therefore capped per photo and in total so a save cannot exhaust the quota.
class LocalVehicleStore {
  static final _changes = ValueNotifier<int>(0);

  /// Acknowledged edits notify Profile and other identity consumers.
  static ValueListenable<int> get changes => _changes;

  /// Largest single new photo kept on the device.
  static const maxPhotoBytes = 700 * 1024;

  /// Decoded total of all stored photos (~2.7 MB once base64-encoded).
  static const maxStoredPhotoBytes = 2 * 1024 * 1024;

  static int _encodedPhotoBytes(String value) {
    final padding = value.endsWith('==') ? 2 : (value.endsWith('=') ? 1 : 0);
    return (value.length * 3) ~/ 4 - padding;
  }

  static int _photoBytes(Map<String, dynamic> row) {
    var total = 0;
    for (final field in ['registrationPhoto', 'insurancePhoto']) {
      final value = row[field];
      if (value is String) {
        total += _encodedPhotoBytes(value);
      }
    }
    return total;
  }

  final _settings = SettingsRepository();
  static Future<void>? _pending;
  Future<void> _serial(Future<void> Function() write) {
    final previous = _pending;
    final result = previous == null ? write() : previous.then((_) => write());
    final tail = result.catchError((Object _) {});
    _pending = tail;
    tail.then((_) {
      if (identical(_pending, tail)) _pending = null;
    });
    return result;
  }

  static const demo = <String, dynamic>{
    'id': 'demo-V418',
    'make': 'Mercedes-Benz',
    'model': 'E 220',
    'year': '2022',
    'plate': 'MVR 418',
  };
  Future<List<Map<String, dynamic>>> list() async {
    final data = await _settings.read('vehicles');
    final rows = data['rows'];
    if (rows == null) {
      return [Map.of(demo)];
    }
    if (rows is! List) {
      throw StateError('Invalid vehicle drafts');
    }
    return rows.map((row) {
      if (row is! Map ||
          ![
            'id',
            'make',
            'model',
            'year',
            'plate',
          ].every((key) => row[key] is String)) {
        throw StateError('Invalid vehicle draft');
      }
      for (final field in ['registrationPhoto', 'insurancePhoto']) {
        if (row[field] != null &&
            (row[field] is! String ||
                base64Decode(row[field] as String).length > 2 * 1024 * 1024)) {
          throw StateError('Invalid local photo');
        }
      }
      return Map<String, dynamic>.from(row);
    }).toList();
  }

  /// The vehicle shown on waybills and Profile: the first stored row, or the
  /// demo vehicle. Null when local storage cannot be read.
  Future<({String vehicle, String plate})?> primaryIdentity() async {
    try {
      final rows = await list();
      if (rows.isEmpty) {
        return null;
      }
      final row = rows.first;
      return (
        vehicle: '${row['make']} ${row['model']}'.trim(),
        plate: row['plate'] as String,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> upsert(Map<String, dynamic> vehicle) {
    final Map<String, dynamic> snapshot;
    try {
      snapshot = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(vehicle)) as Map,
      );
    } catch (error, stack) {
      return Future<void>.error(error, stack);
    }
    return _upsertSnapshot(snapshot);
  }

  Future<void> _upsertSnapshot(
    Map<String, dynamic> vehicle,
  ) => _serial(() async {
    // Reject bad drafts at the write boundary: a single invalid row would
    // otherwise make every subsequent vehicle/profile read fail.
    if (!['id', 'make', 'model', 'year', 'plate'].every(
      (key) =>
          vehicle[key] is String && (vehicle[key] as String).trim().isNotEmpty,
    )) {
      throw const FormatException('Vehicle identity fields are required');
    }
    final rows = await list();
    final previous = rows.where((row) => row['id'] == vehicle['id']).toList();
    for (final field in ['registrationPhoto', 'insurancePhoto']) {
      final value = vehicle[field];
      final unchanged = previous.isNotEmpty && previous.first[field] == value;
      if (value == null) continue;
      if (value is! String) {
        throw const FormatException('Invalid vehicle photo payload');
      }
      if (!unchanged && _encodedPhotoBytes(value) > maxPhotoBytes) {
        throw const VehiclePhotoBudgetExceeded(VehiclePhotoLimit.photoTooLarge);
      }
      // Size alone is not proof of valid base64. Refuse a poisoned draft now
      // instead of breaking all future calls to list().
      try {
        base64Decode(value);
      } on FormatException {
        throw const FormatException('Invalid vehicle photo encoding');
      }
    }
    final index = rows.indexWhere((row) => row['id'] == vehicle['id']);
    rows.removeWhere((row) => row['id'] == vehicle['id']);
    // The first row owns Profile/waybill identity. Editing its document
    // photos must not promote another vehicle by moving this row to the end.
    rows.insert(index < 0 ? rows.length : index, Map.of(vehicle));
    final total = rows.fold<int>(0, (sum, row) => sum + _photoBytes(row));
    final before = previous.fold<int>(0, (sum, row) => sum + _photoBytes(row));
    if (total > maxStoredPhotoBytes && _photoBytes(vehicle) > before) {
      throw const VehiclePhotoBudgetExceeded(VehiclePhotoLimit.storageFull);
    }
    await _settings.save('vehicles', {'rows': rows});
    _changes.value++;
  });
  Future<void> remove(String id) => _serial(() async {
    final rows = await list();
    if (!rows.any((row) => row['id'] == id)) return;
    rows.removeWhere((row) => row['id'] == id);
    await _settings.save('vehicles', {'rows': rows});
    _changes.value++;
  });
}

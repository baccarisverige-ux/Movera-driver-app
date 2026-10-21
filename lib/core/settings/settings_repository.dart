import 'dart:convert';

import 'package:movera/core/storage/local_write_session.dart';

import 'package:movera/core/logging/driver_log.dart';
import 'package:movera/core/storage/local_quarantine.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-only settings persistence.
///
/// New writes are section-isolated so malformed data in one settings surface
/// cannot erase unrelated sections. The legacy aggregate key remains readable
/// for existing installs.
class SettingsRepository {
  SettingsRepository({Future<SharedPreferences> Function()? load})
    : _load = load ?? SharedPreferences.getInstance;
  final Future<SharedPreferences> Function() _load;
  static const key = 'movera_driver_settings';
  static const sectionPrefix = 'movera_driver_settings_section_';
  static const _sectionPrefix = sectionPrefix;
  static Future<void>? _pending;
  final int _generation = LocalWriteSession.generation;

  /// Completes after every storage operation queued so far has finished.
  static Future<void> settle() async {
    final pending = _pending;
    if (pending != null) {
      await pending;
    }
  }

  String _sectionKey(String section) => '$_sectionPrefix$section';

  Future<Map<String, dynamic>> read(String section) => _enqueue(() async {
    final prefs = await _load();
    LocalWriteSession.check(_generation);

    final isolated = prefs.getString(_sectionKey(section));
    if (isolated != null) {
      try {
        final decoded = jsonDecode(isolated);
        if (decoded is Map &&
            decoded['schemaVersion'] == 1 &&
            decoded['values'] is Map) {
          return Map<String, dynamic>.from(decoded['values'] as Map);
        }
        throw const FormatException('Unsupported settings section');
      } catch (error) {
        // Keep the unreadable text before a later save replaces the section.
        await _quarantine(prefs, _sectionKey(section), isolated, error);
        return <String, dynamic>{};
      }
    }

    // Legacy aggregate format. A malformed legacy blob is quarantined and
    // treated as missing; future writes migrate each section to its own key.
    final legacy = prefs.getString(key);
    if (legacy == null) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(legacy);
      if (decoded is! Map) throw const FormatException('Malformed settings');
      final values = decoded[section];
      return values is Map
          ? Map<String, dynamic>.from(values)
          : <String, dynamic>{};
    } catch (error) {
      await _quarantine(prefs, key, legacy, error);
      return <String, dynamic>{};
    }
  });

  Future<void> _quarantine(
    SharedPreferences prefs,
    String storageKey,
    String raw,
    Object error,
  ) async {
    try {
      LocalWriteSession.check(_generation);
      await LocalQuarantine.storeOnce(
        prefs,
        source: 'settings',
        raw: raw,
        reason: '$storageKey: ${DriverLog.scrub(error)}',
      );
      if (!await prefs.remove(storageKey)) {
        throw StateError('Settings recovery failed');
      }
    } catch (quarantineError) {
      DriverLog.warn('Settings quarantine failed: $quarantineError');
      rethrow;
    }
  }

  Future<void> save(String section, Map<String, dynamic> values) {
    // Capture the requested value now, before queued storage awaits. Callers
    // may keep editing nested lists/maps while an earlier write is pending.
    final String payload;
    try {
      payload = jsonEncode(<String, dynamic>{
        'schemaVersion': 1,
        'values': values,
      });
    } catch (error, stack) {
      return Future<void>.error(error, stack);
    }
    Future<void> write() async {
      final prefs = await _load();
      LocalWriteSession.check(_generation);
      if (!await prefs.setString(_sectionKey(section), payload)) {
        throw StateError('Settings save failed');
      }
    }

    return _enqueue(write);
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final previous = _pending;
    final result = previous == null ? action() : previous.then((_) => action());
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _pending = tail;
    tail.then((_) {
      if (identical(_pending, tail)) {
        _pending = null;
      }
    });
    return result;
  }
}

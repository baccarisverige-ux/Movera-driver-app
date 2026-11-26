import 'dart:convert';

import 'package:movera/core/storage/local_write_session.dart';

import 'package:movera/core/logging/driver_log.dart';
import 'package:movera/core/storage/local_quarantine.dart';
import 'package:movera/core/settings/server_settings_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings persistence: on the phone, and (BASE B13, contract v0.18.26 §47)
/// on the server for the sections [remote] handles.
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

  /// BASE B13: the server copy of Ride preferences and Emergency contacts,
  /// set by a live build (main.dart); null in the demo and in tests.
  static RemoteSettings? remote;

  /// Per local session and section: the order of server saves (review of
  /// #695 follow-up). Two Ride types screens saving at once end on the last
  /// choice the server took, whatever order the answers come in; nothing
  /// carries over to the next driver (a new local session starts afresh).
  static final Map<String, _SectionSaves> _saves = <String, _SectionSaves>{};

  _SectionSaves _savesOf(String section) {
    // A repository from before a logout never touches the current
    // session's order (its own writes fail the session check anyway).
    if (_generation != LocalWriteSession.generation) return _SectionSaves();
    final prefix = '$_generation|';
    _saves.removeWhere((key, _) => !key.startsWith(prefix));
    return _saves.putIfAbsent('$prefix$section', _SectionSaves.new);
  }

  /// The section's values: the server's when [remote] covers it and answers
  /// (the phone copy is then updated), else the phone copy.
  Future<Map<String, dynamic>> read(String section) async {
    final local = await _readLocal(section);
    final server = remote;
    if (server == null || !server.handles(section)) return local;
    try {
      final values = await server.read(section, local);
      // The save order is not touched: a refusal compares the phone text,
      // so a server copy written here is never put back by mistake.
      if (!identical(values, local)) await _saveLocal(section, values);
      return values;
    } catch (error) {
      // Offline or signed out: the phone copy is shown.
      DriverLog.warn(
        'Settings $section from server failed: ${DriverLog.scrub(error)}',
      );
      return local;
    }
  }

  Future<Map<String, dynamic>> _readLocal(String section) => _enqueue(() async {
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

  /// Saves on the phone, then on the server for a section [remote] covers;
  /// a refused server save throws, so the screen offers Retry.
  ///
  /// A refused server save puts the phone copy back to what it was before,
  /// so phone, screen (which shows the last confirmed choice again) and
  /// server agree, also after a restart offline (coordinator 2026-11-26, A).
  Future<void> save(String section, Map<String, dynamic> values) async {
    final server = remote;
    if (server == null || !server.handles(section)) {
      await _saveLocal(section, values);
      return;
    }
    final saves = _savesOf(section);
    final before = await _readLocal(section);
    // What the phone holds now is the last confirmed choice unless a save
    // of this session is still waiting with its value there.
    if (saves.phoneBy == saves.confirmedSeq) saves.confirmed = before;
    final mine = ++saves.seq;
    await _saveLocal(section, values);
    saves.phoneBy = mine;
    try {
      await server.save(section, values);
    } catch (_) {
      try {
        // Only while the phone still holds this refused value: a newer
        // save that came meanwhile keeps its own. What goes back is the
        // last choice the server took.
        final now = await _readLocal(section);
        if (saves.phoneBy == mine && jsonEncode(now) == jsonEncode(values)) {
          await _saveLocal(section, saves.confirmed ?? before);
          saves.phoneBy = saves.confirmedSeq;
        }
      } catch (error) {
        DriverLog.warn('Settings $section not put back: $error');
      }
      rethrow;
    }
    if (mine > saves.confirmedSeq) {
      // The phone follows the server's latest choice unless a newer save
      // still waits with its own value there.
      final phoneFollows =
          saves.phoneBy == saves.confirmedSeq || saves.phoneBy <= mine;
      saves.confirmedSeq = mine;
      saves.confirmed = Map<String, dynamic>.of(values);
      if (phoneFollows) {
        try {
          if (saves.phoneBy != mine) await _saveLocal(section, values);
          saves.phoneBy = mine;
        } catch (error) {
          DriverLog.warn('Settings $section not updated: $error');
        }
      }
    }
  }

  Future<void> _saveLocal(String section, Map<String, dynamic> values) {
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

/// The order of one section's server saves in one local session.
class _SectionSaves {
  /// The last save started.
  int seq = 0;

  /// The save whose value the phone holds (after a put back: the
  /// confirmed one).
  int phoneBy = 0;

  /// The newest save the server took (0: none yet; [confirmed] is then the
  /// phone copy before the first save).
  int confirmedSeq = 0;
  Map<String, dynamic>? confirmed;
}

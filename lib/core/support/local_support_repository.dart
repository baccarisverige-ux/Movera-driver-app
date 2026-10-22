import 'dart:convert';

import 'package:movera/core/storage/local_quarantine.dart';
import 'package:movera/core/storage/local_write_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-only drafts. No transport or support service is implied.
class LocalSupportRepository {
  LocalSupportRepository({Future<SharedPreferences> Function()? load})
    : _load = load ?? SharedPreferences.getInstance;
  static const key = 'movera_driver_support_drafts';
  static Future<void>? _pending;
  final Future<SharedPreferences> Function() _load;
  final int _generation = LocalWriteSession.generation;
  static Future<void> settle() async {
    await _pending;
  }

  Future<Map<String, dynamic>> read() => _enqueue(() async {
    LocalWriteSession.check(_generation);
    final prefs = await _load();
    LocalWriteSession.check(_generation);
    return _read(prefs);
  });

  Future<Map<String, dynamic>> _read(SharedPreferences prefs) async {
    final raw = prefs.getString(key);
    if (raw == null) return {};
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      decoded = null;
    }
    if (decoded is Map && decoded['schemaVersion'] == 1 && _valid(decoded)) {
      return Map<String, dynamic>.from(decoded);
    }
    LocalWriteSession.check(_generation);
    await LocalQuarantine.storeOnce(
      prefs,
      source: 'support',
      raw: raw,
      reason: 'Malformed or unsupported support data',
    );
    throw const SupportDataUnreadable();
  }

  bool _valid(Map data) {
    final draft = data['draft'];
    if (draft != null &&
        (draft is! Map ||
            ![
              'subject',
              'message',
              'category',
            ].every((key) => draft[key] == null || draft[key] is String))) {
      return false;
    }
    final tickets = data['tickets'];
    if (tickets == null) return true;
    if (tickets is! List) return false;
    for (final row in tickets) {
      if (row is! Map ||
          row['subject'] is! String ||
          row['preview'] is! String ||
          ![
            'subject',
            'preview',
            'status',
            'category',
          ].every((key) => row[key] == null || row[key] is String) ||
          (row['unread'] != null && row['unread'] is! bool)) {
        return false;
      }
      final messages = row['messages'];
      if (messages != null &&
          (messages is! List ||
              messages.any(
                (message) =>
                    message is! Map ||
                    message['text'] is! String ||
                    !['text', 'time'].every(
                      (key) => message[key] == null || message[key] is String,
                    ) ||
                    (message['support'] != null && message['support'] is! bool),
              ))) {
        return false;
      }
    }
    return true;
  }

  /// Explicitly discard an unreadable active blob only after preserving it.
  Future<void> recover() => _enqueue(() async {
    final prefs = await _load();
    LocalWriteSession.check(_generation);
    try {
      await _read(prefs);
      return;
    } on SupportDataUnreadable {
      LocalWriteSession.check(_generation);
      if (!await prefs.remove(key)) throw StateError('Support recovery failed');
    }
  });

  Future<void> update(String field, Object value) {
    // The editor can keep changing nested lists while a previous save waits.
    final Object snapshot;
    try {
      snapshot = jsonDecode(jsonEncode(value)) as Object;
    } catch (error, stack) {
      return Future<void>.error(error, stack);
    }
    return _enqueue(() async {
      final prefs = await _load();
      LocalWriteSession.check(_generation);
      final data = await _read(prefs);
      data['schemaVersion'] = 1;
      data[field] = snapshot;
      if (!_valid(data)) throw const FormatException('Invalid support data');
      LocalWriteSession.check(_generation);
      if (!await prefs.setString(key, jsonEncode(data))) {
        throw StateError('Local draft could not be saved');
      }
    });
  }

  Future<T> _enqueue<T>(Future<T> Function() write) {
    final previous = _pending;
    final result = previous == null ? write() : previous.then((_) => write());
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _pending = tail;
    tail.then((_) {
      if (identical(_pending, tail)) _pending = null;
    });
    return result;
  }
}

class SupportDataUnreadable implements Exception {
  const SupportDataUnreadable();
  @override
  String toString() => 'Local support data needs recovery; original preserved';
}

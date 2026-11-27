import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:movera/core/auth/secure_token_store.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/core/storage/local_write_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Round 4b: what the driver typed on the details step, kept on this
/// phone so a closed app does not lose it. Saved as a settings section
/// (cleared with the other sections at sign-out, so the next person on the
/// device never sees it) and forgotten the moment the server took the
/// details.
class DetailsDraft {
  DetailsDraft({SettingsRepository? repository})
    : _settings = repository ?? SettingsRepository();

  static const section = 'details_draft';

  /// Follow-up 2026-11-26 (sign-up v2): the personnummer and the street
  /// address of the draft live in the phone's Keychain / Keystore, not in
  /// the plain settings store. Elsewhere (web) they stay with the rest.
  static const secureKey = 'movera_driver_details_draft';
  static const sensitiveKeys = <String>{
    'v2.personalNumber',
    'v2.street',
    'v2.postalCode',
    'v2.city',
  };

  /// Review: a random tag kept in the plain store (wiped by an uninstall
  /// and at sign-out) and inside the secure entry. An iOS Keychain entry
  /// that outlived a reinstall, or one of another session, has no matching
  /// tag and is deleted, never restored.
  static const tagKey = 'movera_driver_details_draft_tag';

  /// The secure store (tests set a fake); null = none on this platform.
  static SecureKeyValue? secure = nativeSecureKeyValue();

  /// Forgets the secure part (sign-out clean-up). Throws when it cannot,
  /// so the clean-up counts as failed and runs again.
  static Future<void> clearSecure() async {
    final store = secure;
    if (store == null) return;
    try {
      await store.delete(secureKey);
    } catch (error) {
      throw StateError('Could not clear local data: $secureKey');
    }
  }

  final SettingsRepository _settings;
  final int _generation = LocalWriteSession.generation;
  Timer? _debounce;
  Map<String, dynamic>? _last;

  bool get _sessionOpen =>
      !LocalWriteSession.clearing &&
      _generation == LocalWriteSession.generation;

  /// The saved draft, or an empty map; an unreadable store reads as empty.
  Future<Map<String, dynamic>> restore() async {
    Map<String, dynamic> plain;
    try {
      plain = await _settings.read(section);
    } catch (_) {
      plain = const {};
    }
    final store = secure;
    if (store == null) return plain;
    Map<String, dynamic> hidden = const {};
    try {
      final raw = await store.read(secureKey);
      final decoded = raw == null ? null : jsonDecode(raw);
      final tag = (await SharedPreferences.getInstance()).getString(tagKey);
      if (decoded is Map &&
          tag != null &&
          decoded['tag'] == tag &&
          decoded['values'] is Map) {
        hidden = Map<String, dynamic>.from(decoded['values'] as Map);
      } else if (raw != null) {
        // Left by a reinstall or another session: never shown.
        await store.delete(secureKey);
      }
    } catch (_) {
      hidden = const {};
    }
    final merged = {...plain, ...hidden};
    // Review: a draft from before this version had these fields in the
    // plain store; they move to the secure store now.
    if (plain.keys.any(sensitiveKeys.contains)) await _write(merged);
    return merged;
  }

  /// Saves [values] a moment after the last change (typing is bursty).
  /// Only non-empty strings and booleans are kept.
  void save(Map<String, Object?> values) {
    final kept = <String, dynamic>{
      for (final MapEntry(:key, :value) in values.entries)
        if (value is bool || (value is String && value.trim().isNotEmpty))
          key: value,
    };
    _last = kept;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), flush);
  }

  /// Writes the last values now (the screen is leaving).
  Future<void> flush() async {
    _debounce?.cancel();
    _debounce = null;
    final values = _last;
    if (values == null) return;
    _last = null;
    await _write(values);
  }

  /// The plain part to the settings store, the sensitive part (when the
  /// phone has a secure store) to the Keychain / Keystore.
  Future<void> _write(Map<String, dynamic> values) async {
    final store = secure;
    final plain = store == null
        ? values
        : {
            for (final MapEntry(:key, :value) in values.entries)
              if (!sensitiveKeys.contains(key)) key: value,
          };
    try {
      await _settings.save(section, plain);
    } catch (_) {
      // A full or broken store: the draft is a convenience.
    }
    if (store == null) return;
    final hidden = {
      for (final MapEntry(:key, :value) in values.entries)
        if (sensitiveKeys.contains(key)) key: value,
    };
    try {
      if (hidden.isEmpty) {
        await store.delete(secureKey);
        return;
      }
      // Review: never after a sign-out began (the plain store refuses the
      // same write), so a late save cannot bring the data back.
      if (!_sessionOpen) return;
      final prefs = await SharedPreferences.getInstance();
      var tag = prefs.getString(tagKey);
      if (tag == null) {
        tag = _newTag();
        await prefs.setString(tagKey, tag);
      }
      if (!_sessionOpen) return;
      await store.write(secureKey, jsonEncode({'tag': tag, 'values': hidden}));
      // A sign-out that started during the write removes it again.
      if (!_sessionOpen) await store.delete(secureKey);
    } catch (error) {
      // Never written in plain text instead: the field is typed again.
      DriverLog.warn('details draft not kept: ${error.runtimeType}');
    }
  }

  static String _newTag() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  /// The details were sent: nothing to keep.
  Future<void> clear() async {
    _debounce?.cancel();
    _debounce = null;
    _last = null;
    await _write(const {});
  }

  void dispose() {
    _debounce?.cancel();
  }
}

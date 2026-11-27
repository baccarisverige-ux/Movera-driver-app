import 'dart:async';
import 'dart:convert';

import 'package:movera/core/auth/secure_token_store.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:movera/core/settings/settings_repository.dart';

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

  /// The secure store (tests set a fake); null = none on this platform.
  static SecureKeyValue? secure = nativeSecureKeyValue();

  /// Forgets the secure part (sign-out clean-up).
  static Future<void> clearSecure() async {
    final store = secure;
    if (store == null) return;
    try {
      await store.delete(secureKey);
    } catch (error) {
      DriverLog.warn('details draft not cleared: ${error.runtimeType}');
    }
  }

  final SettingsRepository _settings;
  Timer? _debounce;
  Map<String, dynamic>? _last;

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
    try {
      final raw = await store.read(secureKey);
      final decoded = raw == null ? null : jsonDecode(raw);
      if (decoded is! Map) return plain;
      return {...plain, ...Map<String, dynamic>.from(decoded)};
    } catch (_) {
      return plain;
    }
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
      } else {
        await store.write(secureKey, jsonEncode(hidden));
      }
    } catch (error) {
      // Never written in plain text instead: the field is typed again.
      DriverLog.warn('details draft not kept: ${error.runtimeType}');
    }
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

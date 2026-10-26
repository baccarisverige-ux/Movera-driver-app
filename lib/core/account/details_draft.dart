import 'dart:async';

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

  final SettingsRepository _settings;
  Timer? _debounce;
  Map<String, dynamic>? _last;

  /// The saved draft, or an empty map; an unreadable store reads as empty.
  Future<Map<String, dynamic>> restore() async {
    try {
      return await _settings.read(section);
    } catch (_) {
      return const {};
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
    try {
      await _settings.save(section, values);
    } catch (_) {
      // A full or broken store: the draft is a convenience.
    }
  }

  /// The details were sent: nothing to keep.
  Future<void> clear() async {
    _debounce?.cancel();
    _debounce = null;
    _last = null;
    try {
      await _settings.save(section, const {});
    } catch (_) {
      // Nothing to do.
    }
  }

  void dispose() {
    _debounce?.cancel();
  }
}

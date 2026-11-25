import 'dart:ui' show Locale;

import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/l10n/app_localizations_profile.dart';

export 'package:movera/l10n/app_localizations_profile.dart'
    show ProfileLocalizations;

/// v0.18.155 My profile texts in the driver's language (same language rule
/// as `tr`). Kept in their own class so they load with Profile (deferred)
/// and not in the first web download (tool/web_budget.json demo hard limit).
/// Read as `ptr.mppTitle`.
ProfileLocalizations get ptr => _ProfileL10n.strings;

abstract final class _ProfileL10n {
  static String? _code;
  static ProfileLocalizations? _strings;

  static ProfileLocalizations get strings {
    final code = DriverAppTexts.language;
    final cached = _strings;
    if (cached != null && code == _code) return cached;
    _code = code;
    final supported =
        ProfileLocalizations.supportedLocales.any((l) => l.languageCode == code)
        ? code
        : 'en';
    return _strings = lookupProfileLocalizations(Locale(supported));
  }
}

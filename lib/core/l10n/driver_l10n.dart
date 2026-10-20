import 'dart:ui' show Locale;

import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/l10n/app_localizations.dart';

export 'package:movera/l10n/app_localizations.dart' show AppLocalizations;

/// The app's texts in the driver's language (Round 4, owner Q48/Q49).
///
/// Read anywhere, with or without a [BuildContext]: `tr.goOnline`. The
/// language is [DriverAppTexts.language], which [DriverLanguage] sets. When
/// it changes, the app root rebuilds every screen, so a text read in
/// `build` is always in the current language.
AppLocalizations get tr => DriverL10n.strings;

abstract final class DriverL10n {
  static String? _code;
  static AppLocalizations? _strings;

  /// The texts for the current language; English for a code the app
  /// has no texts for.
  static AppLocalizations get strings {
    final code = DriverAppTexts.language;
    final cached = _strings;
    if (cached != null && code == _code) return cached;
    _code = code;
    return _strings = lookupAppLocalizations(Locale(_supported(code)));
  }

  static String _supported(String code) =>
      AppLocalizations.supportedLocales.any((l) => l.languageCode == code)
          ? code
          : 'en';
}

/// Dates and times in the driver's language. Times are 24-hour in every
/// language the app has (Sweden, France and Tunisia all read 14:05).
abstract final class DriverDates {
  static bool _ready = false;

  /// intl's locale for [DriverAppTexts.language]. English keeps the day
  /// before the month ("20 Oct"), as the app always showed it.
  static String get _locale {
    if (!_ready) {
      // The data is in the package; this fills it in at once.
      initializeDateFormatting();
      _ready = true;
    }
    return switch (DriverL10n._supported(DriverAppTexts.language)) {
      'fr' => 'fr',
      'sv' => 'sv',
      _ => 'en_GB',
    };
  }

  static bool get _english => _locale == 'en_GB';

  /// "14:05".
  static String time(DateTime at) => DateFormat('HH:mm', _locale).format(at);

  /// "20 Oct" · "20 oct." · "20 okt.".
  static String dayMonth(DateTime at) =>
      DateFormat('d MMM', _locale).format(at);

  /// "Mon 20 Oct" · "lun. 20 oct." · "mån 20 okt.".
  static String weekdayDayMonth(DateTime at) =>
      DateFormat('EEE d MMM', _locale).format(at);

  /// "Monday" · "lundi" · "måndag".
  static String weekday(DateTime at) => DateFormat('EEEE', _locale).format(at);

  /// "20/10/2026" in English (as before), "20/10/2026" in French and
  /// "2026-10-20" in Swedish.
  static String numericDate(DateTime at) => _english
      ? '${at.day}/${at.month}/${at.year}'
      : DateFormat.yMd(_locale).format(at);

  /// "10/2026" in English (as before), "octobre 2026", "oktober 2026".
  static String monthYear(DateTime at) => _english
      ? '${at.month}/${at.year}'
      : DateFormat.yMMMM(_locale).format(at);
}

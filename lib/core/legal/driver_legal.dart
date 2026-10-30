import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One legal document (`LegalDocument`): title and text in sv / fr / en,
/// paragraphs separated by a blank line.
class LegalDocument {
  const LegalDocument({required this.title, required this.text});

  factory LegalDocument.fromJson(Map<String, dynamic> json) => LegalDocument(
    title: _languages(json['title']),
    text: _languages(json['text']),
  );

  final Map<String, String> title;
  final Map<String, String> text;

  /// The title in [language], else English, else any.
  String titleIn(String language) => _pick(title, language);

  /// The text in [language], else English, else any.
  String textIn(String language) => _pick(text, language);

  /// The paragraphs of [textIn] ("\n\n" between them).
  List<String> paragraphsIn(String language) => [
    for (final part in textIn(language).split(RegExp(r'\n\s*\n')))
      if (part.trim().isNotEmpty) part.trim(),
  ];

  Map<String, dynamic> toJson() => {'title': title, 'text': text};

  static Map<String, String> _languages(Object? raw) => {
    if (raw is Map)
      for (final entry in raw.entries)
        if (entry.key is String && entry.value is String)
          entry.key as String: entry.value as String,
  };

  static String _pick(Map<String, String> values, String language) =>
      values[language] ?? values['en'] ?? values.values.firstOrNull ?? '';
}

/// Contract v0.18.5 `LegalTexts` (`GET /legal/{country}`).
class LegalTexts {
  const LegalTexts({
    required this.country,
    required this.version,
    required this.reaccept,
    required this.terms,
    required this.privacy,
    this.source = 'default',
  });

  factory LegalTexts.fromJson(Map<String, dynamic> json) => LegalTexts(
    country: (json['country'] as String? ?? '').toUpperCase(),
    version: (json['version'] as num?)?.toInt() ?? 0,
    source: json['source'] as String? ?? 'default',
    reaccept: json['reaccept'] == true,
    terms: LegalDocument.fromJson(
      Map<String, dynamic>.from(json['terms'] as Map? ?? const {}),
    ),
    privacy: LegalDocument.fromJson(
      Map<String, dynamic>.from(json['privacy'] as Map? ?? const {}),
    ),
  );

  final String country;

  /// 0 = Movera's draft texts (nothing published by the admin).
  final int version;
  final String source;

  /// The live version asks everyone to accept it again.
  final bool reaccept;
  final LegalDocument terms;
  final LegalDocument privacy;

  Map<String, dynamic> toJson() => {
    'country': country,
    'version': version,
    'source': source,
    'reaccept': reaccept,
    'terms': terms.toJson(),
    'privacy': privacy.toJson(),
  };
}

/// Where the last answers and the accepted versions are kept on the phone
/// (`legal.read`: "keep the last answer offline").
abstract class DriverLegalCache {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> state);
}

class PrefsDriverLegalCache implements DriverLegalCache {
  const PrefsDriverLegalCache();

  static const key = 'movera_driver_legal_v1';

  @override
  Future<Map<String, dynamic>?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  }

  @override
  Future<void> write(Map<String, dynamic> state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(state));
  }
}

class MemoryDriverLegalCache implements DriverLegalCache {
  Map<String, dynamic>? state;

  @override
  Future<Map<String, dynamic>?> read() async => state;

  @override
  Future<void> write(Map<String, dynamic> state) async {
    this.state = jsonDecode(jsonEncode(state)) as Map<String, dynamic>;
  }
}

/// Contract v0.18.5 `legal` (owner G1-B2 "Real texts from admin
/// (Recommended)"): the terms of use and the privacy policy of the driver's
/// country (SE or FR), read with no token from `GET /legal/{country}` on
/// app start and when the app comes back, kept for offline use. A version
/// published with `reaccept` is shown at the next app start (never during
/// a trip) until the driver accepts it (`POST /account/legal/accept`);
/// until then the server refuses going online (`terms_not_accepted`).
class DriverLegal extends ChangeNotifier {
  DriverLegal({ApiClient? api, DriverLegalCache? cache})
    : _api = api,
      _cache = cache ?? const PrefsDriverLegalCache();

  /// The app's legal texts (main.dart gives the live build its API).
  static DriverLegal instance = DriverLegal();

  static const countries = <String>['SE', 'FR'];
  static const acceptPath = '/api/v1/account/legal/accept';
  static String pathOf(String country) =>
      '/api/v1/legal/${Uri.encodeComponent(country)}';

  ApiClient? _api;
  final DriverLegalCache _cache;
  final Map<String, LegalTexts> _texts = {};
  final Map<String, int> _accepted = {};
  final Map<String, Future<LegalTexts?>> _inFlight = {};
  String _country = 'SE';
  bool _asked = false;
  bool _failed = false;

  /// The signed-in driver (`Driver.driverId`); null before sign-in and
  /// after sign-out. Checker blocker 1: nothing is asked without one.
  String? _driverId;

  /// The server refused going online with `terms_not_accepted`: the
  /// screen shows whatever this phone remembers (checker HIGH 2).
  bool _forced = false;

  /// This app run already decided whether to ask at start.
  bool _startChecked = false;

  String? get driverId => _driverId;

  /// Acceptances are kept per driver and country, so a second account on
  /// the same phone is asked on its own (checker HIGH 2).
  String _acceptKey(String country) => '${_driverId ?? ''}|$country';

  /// A live build talks to the server; the demo has none.
  bool get live => _api != null;

  set api(ApiClient? api) => _api = api;

  /// The country whose texts the app shows: the start country before
  /// sign-in, the account's after (`legal.apps`).
  String get country => _country;

  /// The texts of [country], or null before the first answer.
  LegalTexts? get current => _texts[_country];

  /// The last read failed and nothing is kept: the page says so.
  bool get failed => _failed && current == null;

  /// The live version must be accepted (it asks for it and this phone has
  /// not accepted it).
  bool get due {
    final texts = current;
    if (_driverId == null) return false;
    if (texts == null || !texts.reaccept || texts.version <= 0) return false;
    return (_accepted[_acceptKey(texts.country)] ?? -1) < texts.version;
  }

  /// The terms screen shows: only for a signed-in driver (never on the
  /// sign-in screen: "I accept" needs his token), due at this app start,
  /// or after the server refused going online for it. The gate never
  /// shows it during a trip.
  bool get screenWanted {
    final texts = current;
    if (_driverId == null || texts == null) return false;
    return _forced || (_asked && due);
  }

  /// Kept answers and accepted versions.
  Future<void> restore() async {
    try {
      final state = await _cache.read();
      final texts = state?['texts'];
      if (texts is Map) {
        for (final entry in texts.entries) {
          if (entry.value is Map) {
            _texts[entry.key as String] = LegalTexts.fromJson(
              Map<String, dynamic>.from(entry.value as Map),
            );
          }
        }
      }
      final accepted = state?['accepted'];
      if (accepted is Map) {
        for (final entry in accepted.entries) {
          if (entry.value is num) {
            _accepted[entry.key as String] = (entry.value as num).toInt();
          }
        }
      }
    } catch (error) {
      DriverLog.warn('legal.cache_read_failed: ${error.runtimeType}');
    }
    notifyListeners();
  }

  /// Picks the country to show ([countries] only; others keep Sweden's).
  void useCountry(String? country) {
    final code = country?.trim().toUpperCase();
    if (code == null || !countries.contains(code) || code == _country) return;
    _country = code;
    notifyListeners();
  }

  /// The account's country after sign-in (`legal.apps`): its texts are
  /// read when it differs from the one shown.
  void useAccountCountry(String? country) {
    final before = _country;
    useCountry(country);
    if (_country != before && live) unawaited(refresh());
  }

  /// The signed-in account (`GET /driver/profile`): its driver and
  /// country. The first time this run that the texts and the driver are
  /// both known, a due version is asked for (the "app start" check).
  void useAccount({required String driverId, String? country}) {
    if (driverId.isEmpty) return;
    final changed = _driverId != driverId;
    _driverId = driverId;
    if (changed) {
      _startChecked = false;
      _asked = false;
      _forced = false;
    }
    useAccountCountry(country);
    _checkAtStart();
    notifyListeners();
  }

  /// Sign-out (own or ended by Movera): this driver's acceptances leave
  /// the phone and nothing is asked until the next sign-in.
  Future<void> signedOut() async {
    final id = _driverId;
    _driverId = null;
    _asked = false;
    _forced = false;
    _startChecked = false;
    if (id != null) {
      _accepted.removeWhere((key, _) => key.startsWith('$id|'));
      await _save();
    }
    notifyListeners();
  }

  void _checkAtStart() {
    if (_startChecked || _driverId == null || current == null) return;
    _startChecked = true;
    if (due) _asked = true;
  }

  /// App start: the kept answer, then the server's; a due version is
  /// asked for at this start.
  Future<void> start({String? country}) async {
    useCountry(country);
    await restore();
    await refresh();
    _checkAtStart();
    notifyListeners();
  }

  /// `GET /legal/{country}` (no token). Concurrent calls share one.
  Future<LegalTexts?> refresh() {
    final country = _country;
    return _inFlight[country] ??= _fetch(country).whenComplete(() {
      // A block body: returning the removed future would make this wait
      // for itself.
      _inFlight.remove(country);
    });
  }

  Future<LegalTexts?> _fetch(String country) async {
    final api = _api;
    if (api == null) return null;
    try {
      final answer = await api.get(pathOf(country), authenticated: false);
      final texts = LegalTexts.fromJson(answer);
      _texts[country] = texts;
      _failed = false;
      _checkAtStart();
      notifyListeners();
      await _save();
      return texts;
    } catch (error) {
      DriverLog.warn('legal.fetch_failed: ${_describe(error)}');
      _failed = true;
      notifyListeners();
      return null;
    }
  }

  /// A refused go-online (`terms_not_accepted`): ask again (not during a
  /// trip; the gate decides). Reads the live version first.
  Future<void> askAgain() async {
    await refresh();
    // The server knows better than this phone: forget the acceptance and
    // show the screen (checker HIGH 2).
    final texts = current;
    if (texts != null) _accepted.remove(_acceptKey(texts.country));
    _asked = true;
    _forced = _driverId != null;
    notifyListeners();
  }

  /// `POST /account/legal/accept { country, version }` with an
  /// Idempotency-Key. A version that is no longer live (409
  /// `terms_version_not_current`) reloads the texts and stays due.
  Future<bool> accept() async {
    final texts = current;
    final api = _api;
    // Checker blocker 1: never without a signed-in driver.
    if (texts == null || api == null || _driverId == null) return false;
    try {
      await api.post(
        acceptPath,
        body: {'country': texts.country, 'version': texts.version},
      );
      _accepted[_acceptKey(texts.country)] = texts.version;
      _asked = false;
      _forced = false;
      notifyListeners();
      await _save();
      return true;
    } on ApiError catch (error) {
      DriverLog.warn('legal.accept_failed: ${error.detail}');
      if (error.detail == 'terms_version_not_current') await refresh();
      return false;
    } catch (error) {
      DriverLog.warn('legal.accept_failed: ${error.runtimeType}');
      return false;
    }
  }

  Future<void> _save() async {
    try {
      await _cache.write({
        'texts': {
          for (final entry in _texts.entries) entry.key: entry.value.toJson(),
        },
        'accepted': _accepted,
      });
    } catch (error) {
      DriverLog.warn('legal.cache_write_failed: ${error.runtimeType}');
    }
  }

  static String _describe(Object error) =>
      error is ApiError ? error.detail : '${error.runtimeType}';

  @visibleForTesting
  void reset() {
    _texts.clear();
    _accepted.clear();
    _inFlight.clear();
    _country = 'SE';
    _asked = false;
    _failed = false;
    _forced = false;
    _startChecked = false;
    _driverId = null;
    _api = null;
    notifyListeners();
  }
}

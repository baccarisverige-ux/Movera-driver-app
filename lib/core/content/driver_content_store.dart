import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:movera/core/content/driver_content.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The last content answer and the terms the driver accepted, kept on the
/// device (contract §19: the last answer is kept offline).
abstract class DriverContentCache {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> state);
}

class PrefsDriverContentCache implements DriverContentCache {
  const PrefsDriverContentCache();

  static const key = 'movera_driver_content_v1';

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

class MemoryDriverContentCache implements DriverContentCache {
  Map<String, dynamic>? state;

  @override
  Future<Map<String, dynamic>?> read() async => state;

  @override
  Future<void> write(Map<String, dynamic> state) async {
    this.state = jsonDecode(jsonEncode(state)) as Map<String, dynamic>;
  }
}

/// The driver app's content in use, its terms and app-version state. The
/// demo never fills it (Home keeps its local seed); a live build fills it
/// from `GET /driver/content` ([LiveDriverContent]).
class DriverContentStore extends ChangeNotifier {
  DriverContentStore({DriverContentCache? cache, DateTime Function()? now})
    : _cache = cache ?? const PrefsDriverContentCache(),
      _now = now ?? DateTime.now;

  /// The app's store.
  static DriverContentStore instance = DriverContentStore();

  final DriverContentCache _cache;
  final DateTime Function() _now;

  DriverContent _content = DriverContent.empty;
  int? _acceptedTerms;
  bool _termsAsked = false;
  bool _recommendedClosed = false;

  DriverContent get content => _content;
  DateTime get now => _now();

  /// The legal version the driver last accepted.
  int? get acceptedTerms => _acceptedTerms;

  /// The legal version to accept before going online, or null.
  int? get termsDue => _content.termsDue(_now(), _acceptedTerms);

  /// Until accepted the driver cannot go online.
  bool get blocksOnline => termsDue != null;

  /// The terms screen is wanted: due at this app start (or asked again by
  /// a refused go-online). The screen itself never shows during a trip.
  bool get termsScreenWanted => _termsAsked && termsDue != null;

  List<DriverContentItem> get home => _content.homeAt(_now());
  DriverContentItem? get help => _content.helpAt(_now());
  DriverContentItem? get legal => _content.legalAt(_now());
  DriverContentItem? get infoSession => _content.infoSessionAt(_now());

  UpdateNeed get updateNeed =>
      _content.updateNeed(DriverAppVersion.current, _now());

  UpdateView updateView({required bool onTrip}) => DriverContent.viewFor(
    updateNeed,
    onTrip: onTrip,
    dismissed: _recommendedClosed,
  );

  /// The driver closed the "update recommended" message.
  void closeRecommended() {
    if (_recommendedClosed) return;
    _recommendedClosed = true;
    notifyListeners();
  }

  /// Reads the last answer kept on the device.
  Future<void> restore() async {
    try {
      final state = await _cache.read();
      if (state != null) {
        _content = DriverContent.fromJson(state);
        final accepted = state['acceptedTerms'];
        _acceptedTerms = accepted is int ? accepted : null;
      }
    } catch (error) {
      DriverLog.warn('driver_content.cache_read_failed: $error');
    }
    _askAtStart();
    notifyListeners();
  }

  /// A new answer from the server; [atStart]: the app start's first answer.
  Future<void> use(DriverContent content, {bool atStart = false}) async {
    _content = content;
    if (atStart) _askAtStart();
    notifyListeners();
    await _save();
  }

  /// The terms of [version] were accepted.
  Future<void> accepted(int version) async {
    _acceptedTerms = version;
    _termsAsked = false;
    notifyListeners();
    await _save();
  }

  /// A go-online was refused for the terms: show them again (not during a
  /// trip; the gate decides).
  void askTerms() {
    if (termsDue == null) return;
    _termsAsked = true;
    notifyListeners();
  }

  /// The terms show at app start only (the kept answer or the first one);
  /// terms published later wait for the next start or a refused go-online.
  void _askAtStart() {
    if (termsDue != null) _termsAsked = true;
  }

  Future<void> _save() async {
    try {
      await _cache.write({
        'items': _content.toJsonItems(),
        if (_acceptedTerms != null) 'acceptedTerms': _acceptedTerms,
      });
    } catch (error) {
      DriverLog.warn('driver_content.cache_write_failed: $error');
    }
  }

  @visibleForTesting
  void reset() {
    _content = DriverContent.empty;
    _acceptedTerms = null;
    _termsAsked = false;
    _recommendedClosed = false;
    notifyListeners();
  }
}

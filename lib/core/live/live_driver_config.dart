import 'package:movera/core/safety/emergency_numbers.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:movera/core/admin/trip_rules_admin_config.dart';
import 'package:movera/core/contracts/driver_app_config.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The last good DriverAppConfig, kept on the device as the raw document so
/// a start without network uses yesterday's settings. G17: one copy per
/// zone (like the rider app's `RiderConfigCache`), so a restart in Tunis
/// never shows the Swedish numbers first; the last document used (any
/// zone) is kept too.
abstract class DriverConfigCache {
  /// [zoneId]'s document; without one, the last document used.
  Future<Map<String, dynamic>?> read([String? zoneId]);

  /// Keeps [document] as [zoneId]'s copy and as the last one used.
  Future<void> write(Map<String, dynamic> document, {String? zoneId});
}

/// [document]'s zone, when it names one.
String? _zoneOf(Map<dynamic, dynamic>? document) {
  final zone = document?['zoneId'];
  return zone is String && zone.trim().isNotEmpty ? zone.trim() : null;
}

class PrefsDriverConfigCache implements DriverConfigCache {
  const PrefsDriverConfigCache();

  /// The last document used (any zone); StartCountryHints reads it too.
  static const key = 'movera_driver_config_v1';

  /// G17: [zoneId]'s own copy.
  static String keyOf(String zoneId) => '${key}_$zoneId';

  @override
  Future<Map<String, dynamic>?> read([String? zoneId]) async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic>? decode(String? raw) {
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    }

    if (zoneId == null) return decode(prefs.getString(key));
    final own = decode(prefs.getString(keyOf(zoneId)));
    if (own != null) return own;
    // A copy kept before G17 (one key only) is the zone's when it says so.
    final last = decode(prefs.getString(key));
    return _zoneOf(last) == zoneId ? last : null;
  }

  @override
  Future<void> write(Map<String, dynamic> document, {String? zoneId}) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(document);
    final zone = zoneId ?? _zoneOf(document);
    if (zone != null) await prefs.setString(keyOf(zone), encoded);
    await prefs.setString(key, encoded);
  }
}

class MemoryDriverConfigCache implements DriverConfigCache {
  /// The last document used (any zone).
  Map<String, dynamic>? document;

  /// G17: one copy per zone.
  final Map<String, Map<String, dynamic>> byZone = {};

  @override
  Future<Map<String, dynamic>?> read([String? zoneId]) async {
    if (zoneId == null) return document;
    return byZone[zoneId] ?? (_zoneOf(document) == zoneId ? document : null);
  }

  @override
  Future<void> write(Map<String, dynamic> document, {String? zoneId}) async {
    final zone = zoneId ?? _zoneOf(document);
    if (zone != null) byZone[zone] = document;
    this.document = document;
  }
}

/// DriverAppConfig from the server (contract §6, owner 2026-10-27):
/// `GET /driver/config` on start and on every `config_published` from
/// `/driver/config/stream`. G17 (owner 2026-11-12): both name `?zoneId=`,
/// the zone the driver is in ([zoneId]: the active trip's zone, else the
/// open zone around the phone's position; contract v0.18.72 §89
/// `driverConfigZone.app`); with neither no zoneId is sent and the server
/// picks. A new zone is read at once ([zoneChanged]) and its stream
/// opened again.
/// Each newer document is put in use at once ([DriverAppConfig.apply]);
/// an older or equal version of the same zone is ignored. No server: the
/// last document received, else the app's own settings. Never throws to
/// its callers.
class LiveDriverConfig extends ChangeNotifier {
  LiveDriverConfig({
    required http.Client client,
    required Uri apiBase,
    required Future<String?> Function() accessToken,
    this.renewSession,
    this.onContentPublished,
    this.onZonesPublished,
    this.onEventsPublished,
    this.onReservationsChanged,
    this.onZoneChanged,
    String? Function()? zoneId,
    DriverConfigCache? cache,
    this.retryAfter = const Duration(seconds: 5),
    this.retryMax = const Duration(seconds: 60),
    math.Random? random,
    this.requestTimeout = const Duration(seconds: 60),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _random = random ?? math.Random(),
       _client = client,
       _base = apiBase,
       _token = accessToken,
       _zoneSource = zoneId ?? _noZone,
       _cache = cache ?? const PrefsDriverConfigCache();

  final DateTime Function() _now;

  static String? _noZone() => null;

  /// G17: the zone the driver is in now, or null when the app cannot tell.
  final String? Function() _zoneSource;

  /// G17: the zone the settings are read for (null: none named, the
  /// server picks, contract v0.18.72 §89 `driverConfigZone.serverDefault`).
  String? _zone;

  /// The zone of [current] (its `zoneId` as served).
  String? _currentZone;

  /// G17: called when the document in use is for another zone than
  /// before (the zone's content is read again).
  final void Function()? onZoneChanged;

  /// The zone named on the calls now (null: none, the server picks).
  String? get zoneId => _zone;

  bool _started = false;

  /// D12-5: when the open stream last sent a line (heartbeats every 15 s,
  /// D12-7); null while no stream is open.
  DateTime? _lastLine;

  /// D12-5: a stream with a line this recent is alive; a resume keeps it.
  static const freshFor = Duration(seconds: 20);

  @visibleForTesting
  bool get streamFresh {
    final last = _lastLine;
    return _stream != null &&
        last != null &&
        _now().difference(last) < freshFor;
  }

  final http.Client _client;
  final Uri _base;
  final Future<String?> Function() _token;
  final DriverConfigCache _cache;
  final Future<void> Function()? renewSession;

  /// Contract v0.10.0 §19: a `config_published` with doc `content` (the
  /// Content page published) goes here instead of a config fetch.
  final void Function()? onContentPublished;

  /// Contract v0.11.0 §21: a `config_published` with doc `zones` (a zone
  /// was created, changed, opened or closed) goes here.
  final void Function()? onZonesPublished;

  /// Contract v0.18.6 §32 (G4-F6): a `config_published` with doc `events`
  /// (an event of the driver's country was created, changed or deleted)
  /// goes here.
  final void Function()? onEventsPublished;

  /// Contract v0.18.45 §68 (L-a Q7 "Live push"): the booked rides must be
  /// read again (`GET /driver/reservations`). Called on each
  /// `driver_reservations_changed` (a hint only) and each time the stream
  /// opens, so a reconnect catches what was missed while it was down.
  final void Function()? onReservationsChanged;
  final Duration retryAfter;

  /// Owner 2026-11-10: a refused stream waits [retryAfter] (5 s), then
  /// doubles each failure (10, 20, 40) up to [retryMax] (60 s), with a
  /// small random jitter (±10 %); a successful connect starts again at 5 s.
  final Duration retryMax;
  final math.Random _random;
  int _failures = 0;

  /// The wait before the next reconnect (counts one more failure).
  Duration nextRetryWait() {
    final doubled = retryAfter * math.pow(2, math.min(_failures, 16)).toInt();
    _failures++;
    final capped = doubled > retryMax ? retryMax : doubled;
    final factor = 0.9 + 0.2 * _random.nextDouble();
    final ms = (capped.inMilliseconds * factor).round().clamp(
      retryAfter.inMilliseconds,
      retryMax.inMilliseconds,
    );
    return Duration(milliseconds: ms);
  }

  final Duration requestTimeout;

  DriverAppConfig? _current;
  final Map<String?, Future<DriverAppConfig?>> _inFlight = {};
  StreamSubscription<String>? _stream;
  Timer? _retry;
  bool _watching = false;

  /// Job 3 / L19: each [_connect] has its own number; only the newest one
  /// may keep a stream or reconnect, so a resume never leaves two open.
  int _generation = 0;
  bool _disposed = false;

  /// The document in use, or null while the app runs on its own settings.
  DriverAppConfig? get current => _current;

  Uri _uri(String path, {String? zoneId}) => _base.replace(
    path: '${_base.path}$path',
    queryParameters: zoneId == null ? null : {'zoneId': zoneId},
  );

  Future<Map<String, String>> _headers(String accept) async {
    final token = await _token();
    return {
      'Accept': accept,
      'X-Api-Version': '0.5',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Loads the last document kept on the device (the zone's own copy),
  /// then asks the server.
  Future<void> start() async {
    _started = true;
    final zone = _zoneSource();
    try {
      final cached = await _cache.read(zone);
      _zone = zone;
      if (cached != null) _take(cached);
    } catch (error) {
      _zone = zone;
      DriverLog.warn('driver_config.cache_read_failed: $error');
    }
    await refresh();
  }

  /// G17: the zone the driver is in may have changed (a trip started, a
  /// new position, the zone list arrived). Another zone than the one
  /// followed: its saved copy is put in use at once (else, for another
  /// country, the numbers go back to the default until the new document
  /// arrives), it is read from the server and the stream opens again for
  /// it. The same zone, or none known: nothing happens.
  Future<void> zoneChanged() async {
    if (!_started || _disposed) return;
    final zone = _zoneSource();
    if (zone == _zone) return;
    _zone = zone;
    Map<String, dynamic>? cached;
    try {
      // §89: no zone known: the server picks; the document stays until
      // its answer.
      if (zone != null) cached = await _cache.read(zone);
    } catch (error) {
      DriverLog.warn('driver_config.cache_read_failed: $error');
    }
    if (_zone != zone || _disposed) return;
    if (zone == null) {
      // Nothing to show first.
    } else if (cached != null) {
      _take(cached);
    } else if (_currentZone != zone && !_sameCountry(zone, _currentZone)) {
      // Never another country's numbers while the zone's own load (a
      // country the zone list does not name counts as another).
      EmergencyNumbers.reset();
    }
    if (_watching) {
      _retry?.cancel();
      _retry = null;
      unawaited(_stream?.cancel());
      _stream = null;
      _lastLine = null;
    }
    await refresh();
    if (_watching && _zone == zone && !_disposed) unawaited(_connect());
  }

  /// True only when the zone list names the same country for both.
  static bool _sameCountry(String a, String? b) {
    final country = DriverZones.byId(a)?.country;
    return country != null && country == DriverZones.byId(b)?.country;
  }

  /// Puts a kept or served [document] in use (another zone's replaces the
  /// one in use whatever its version).
  bool _take(Map<String, dynamic> document) {
    // v0.18.57 §79: the country's emergency numbers, offline too.
    EmergencyNumbers.accept(document['emergencyNumbers']);
    return _use(DriverAppConfig.fromJson(document), zone: _zoneOf(document));
  }

  /// Asks the server for the document; concurrent calls share one request.
  Future<DriverAppConfig?> refresh() {
    final zone = _zone;
    return _inFlight[zone] ??= _fetch(zone).whenComplete(() {
      // A block, not an arrow: remove() returns this future itself.
      _inFlight.remove(zone);
    });
  }

  Future<DriverAppConfig?> _fetch(String? zone) async {
    try {
      // Contract v0.18.2 `auth.beforeSignIn`: no session, no call (the
      // app's own settings are used until the driver signs in).
      final token = await _token();
      if (token == null || token.isEmpty) return _current;
      final uri = _uri('/driver/config', zoneId: zone);
      var response = await _client
          .get(uri, headers: await _headers('application/json'))
          .timeout(requestTimeout);
      if (response.statusCode == 401 && renewSession != null) {
        await renewSession!();
        // Asked again only with a renewed token: a 401 is never retried
        // with the token the server just refused.
        final renewed = await _token();
        if (renewed == null || renewed.isEmpty || renewed == token) {
          return _current;
        }
        response = await _client
            .get(uri, headers: await _headers('application/json'))
            .timeout(requestTimeout);
      }
      if (response.statusCode != 200) return _current;
      final raw = jsonDecode(response.body);
      if (raw is! Map || raw['version'] is! int) return _current;
      // G17: the zone changed while this was asked; its own read follows.
      if (zone != _zone || _disposed) return _current;
      final document = Map<String, dynamic>.from(raw);
      if (_take(document)) {
        try {
          await _cache.write(document, zoneId: _zoneOf(document) ?? zone);
        } catch (error) {
          DriverLog.warn('driver_config.cache_write_failed: $error');
        }
      }
    } catch (error) {
      DriverLog.warn('driver_config.fetch_failed: $error');
    }
    return _current;
  }

  /// Puts [next] in use unless the app has the same or a newer version of
  /// the same zone (G17: another zone's document always replaces it).
  bool _use(DriverAppConfig next, {String? zone}) {
    final known = _current;
    final sameZone = known == null || zone == null || zone == _currentZone;
    if (known != null && sameZone && known.version >= next.version) {
      return false;
    }
    final moved = known != null && !sameZone;
    _current = next;
    _currentZone = zone ?? _currentZone;
    next.apply();
    if (!_disposed) notifyListeners();
    if (moved) onZoneChanged?.call();
    return true;
  }

  /// Follows `config_published` and fetches each newer document at once;
  /// reconnects after [retryAfter] when the stream ends or fails.
  Future<void> watch() async {
    if (_watching) return;
    _watching = true;
    await _connect();
  }

  Future<void> _connect() async {
    if (_disposed || !_watching) return;
    final generation = ++_generation;
    bool stale() => generation != _generation || _disposed || !_watching;
    try {
      // Contract v0.18.2 `auth.beforeSignIn`: no session, no stream; the
      // app starts watching again once the driver signs in ([watch]).
      final token = await _token();
      if (token == null || token.isEmpty) {
        stop();
        return;
      }
      final zone = _zone;
      final request =
          http.Request('GET', _uri('/driver/config/stream', zoneId: zone))
            ..headers.addAll({
              ...await _headers('text/event-stream'),
              // §89: versions are counted per zone. Only the version of
              // the zone asked for (never another zone's, and none when
              // the server picks the zone).
              if (_current != null && zone != null && zone == _currentZone)
                'Last-Event-ID': '${_current!.version}',
            });
      final response = await _client.send(request).timeout(requestTimeout);
      if (stale()) {
        // A newer connect (or stop) took over while this one waited: its
        // response is closed at once, never kept open beside the new one.
        unawaited(response.stream.listen(null).cancel());
        return;
      }
      if (response.statusCode != 200) {
        unawaited(response.stream.drain<void>().catchError((_) {}));
        if (response.statusCode == 401) {
          await renewSession?.call();
          // A 401 is never retried in a loop: the stream opens again only
          // with a renewed token, else after the next sign-in.
          final renewed = await _token();
          if (renewed == null || renewed.isEmpty || renewed == token) {
            stop();
            return;
          }
        }
        _reconnect();
        return;
      }
      final data = StringBuffer();
      _failures = 0;
      // §68: every (re)connect reads the booked rides again.
      onReservationsChanged?.call();
      // D12-5: only a received line shows the stream is alive.
      _lastLine = null;
      _stream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              _lastLine = _now();
              if (line.startsWith('data:')) {
                data.write(line.substring(5).trim());
                return;
              }
              if (line.isNotEmpty || data.isEmpty) return;
              final raw = data.toString();
              data.clear();
              try {
                final event = jsonDecode(raw);
                if (event is Map &&
                    event['kind'] == 'driver_reservations_changed') {
                  onReservationsChanged?.call();
                  return;
                }
                if (event is! Map || event['kind'] != 'config_published') {
                  return;
                }
                if (event['doc'] == 'content') {
                  onContentPublished?.call();
                  return;
                }
                if (event['doc'] == 'zones') {
                  onZonesPublished?.call();
                  return;
                }
                if (event['doc'] == 'events') {
                  onEventsPublished?.call();
                  return;
                }
                final version = event['version'];
                // §89: "newer" only within the same zone.
                final eventZone = event['zoneId'];
                final otherZone =
                    (eventZone is String && eventZone != _currentZone) ||
                    (_zone != null && _zone != _currentZone);
                if (version is! int ||
                    otherZone ||
                    version > (_current?.version ?? 0)) {
                  unawaited(refresh());
                }
              } on FormatException {
                // A broken event is skipped; the next one or a restart fixes it.
              }
            },
            onDone: () {
              if (!stale()) _reconnect();
            },
            onError: (Object _) {
              if (!stale()) _reconnect();
            },
            cancelOnError: true,
          );
    } catch (error) {
      DriverLog.warn('driver_config.stream_failed: $error');
      if (!stale()) _reconnect();
    }
  }

  /// Job 3 / L19: the app is on screen again. The settings are read again
  /// (a phone in the background may have missed `config_published`, and
  /// its stream may have died without a word); a followed stream opens
  /// again at once.
  Future<DriverAppConfig?> resumed() {
    // G17: the phone may be in another zone than when it went away.
    unawaited(zoneChanged());
    // D12-5: a stream that sent a line in the last [freshFor] missed
    // nothing; keep it and skip the read (a short trip out of the app).
    if (_watching && !_disposed && streamFresh) {
      return Future<DriverAppConfig?>.value(current);
    }
    if (_watching && !_disposed) {
      _retry?.cancel();
      _retry = null;
      unawaited(_stream?.cancel());
      _stream = null;
      unawaited(_connect());
    }
    return refresh();
  }

  /// Stops following the stream (signed out, or the server refused the
  /// session); [watch] starts it again.
  void stop() {
    _watching = false;
    _generation++;
    _retry?.cancel();
    _retry = null;
    unawaited(_stream?.cancel());
    _stream = null;
  }

  void _reconnect() {
    _stream = null;
    if (_disposed || !_watching) return;
    _retry?.cancel();
    _retry = Timer(nextRetryWait(), () {
      unawaited(refresh());
      unawaited(_connect());
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _watching = false;
    _retry?.cancel();
    unawaited(_stream?.cancel());
    super.dispose();
  }
}

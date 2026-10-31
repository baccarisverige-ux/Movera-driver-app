import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:movera/core/contracts/driver_app_config.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The last good DriverAppConfig, kept on the device as the raw document so
/// a start without network uses yesterday's settings.
abstract class DriverConfigCache {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> document);
}

class PrefsDriverConfigCache implements DriverConfigCache {
  const PrefsDriverConfigCache();

  static const key = 'movera_driver_config_v1';

  @override
  Future<Map<String, dynamic>?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  }

  @override
  Future<void> write(Map<String, dynamic> document) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(document));
  }
}

class MemoryDriverConfigCache implements DriverConfigCache {
  Map<String, dynamic>? document;

  @override
  Future<Map<String, dynamic>?> read() async => document;

  @override
  Future<void> write(Map<String, dynamic> document) async {
    this.document = document;
  }
}

/// DriverAppConfig from the server (contract §6, owner 2026-10-27):
/// `GET /driver/config` (the driver's zone) on start and on every
/// `config_published` from `/driver/config/stream`. Each newer document is
/// put in use at once ([DriverAppConfig.apply]); an older or equal version
/// is ignored. No server: the last document received, else the app's own
/// settings. Never throws to its callers.
class LiveDriverConfig extends ChangeNotifier {
  LiveDriverConfig({
    required http.Client client,
    required Uri apiBase,
    required Future<String?> Function() accessToken,
    this.renewSession,
    this.onContentPublished,
    this.onZonesPublished,
    this.onEventsPublished,
    DriverConfigCache? cache,
    this.retryAfter = const Duration(seconds: 5),
    this.requestTimeout = const Duration(seconds: 60),
  }) : _client = client,
       _base = apiBase,
       _token = accessToken,
       _cache = cache ?? const PrefsDriverConfigCache();

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
  final Duration retryAfter;
  final Duration requestTimeout;

  DriverAppConfig? _current;
  Future<DriverAppConfig?>? _inFlight;
  StreamSubscription<String>? _stream;
  Timer? _retry;
  bool _watching = false;
  bool _disposed = false;

  /// The document in use, or null while the app runs on its own settings.
  DriverAppConfig? get current => _current;

  Uri _uri(String path) => _base.replace(path: '${_base.path}$path');

  Future<Map<String, String>> _headers(String accept) async {
    final token = await _token();
    return {
      'Accept': accept,
      'X-Api-Version': '0.5',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Loads the last document kept on the device, then asks the server.
  Future<void> start() async {
    try {
      final cached = await _cache.read();
      if (cached != null) _use(DriverAppConfig.fromJson(cached));
    } catch (error) {
      DriverLog.warn('driver_config.cache_read_failed: $error');
    }
    await refresh();
  }

  /// Asks the server for the document; concurrent calls share one request.
  Future<DriverAppConfig?> refresh() {
    return _inFlight ??= _fetch().whenComplete(() {
      _inFlight = null;
    });
  }

  Future<DriverAppConfig?> _fetch() async {
    try {
      // Contract v0.18.2 `auth.beforeSignIn`: no session, no call (the
      // app's own settings are used until the driver signs in).
      final token = await _token();
      if (token == null || token.isEmpty) return _current;
      var response = await _client
          .get(
            _uri('/driver/config'),
            headers: await _headers('application/json'),
          )
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
            .get(
              _uri('/driver/config'),
              headers: await _headers('application/json'),
            )
            .timeout(requestTimeout);
      }
      if (response.statusCode != 200) return _current;
      final raw = jsonDecode(response.body);
      if (raw is! Map || raw['version'] is! int) return _current;
      final document = Map<String, dynamic>.from(raw);
      if (_use(DriverAppConfig.fromJson(document))) {
        try {
          await _cache.write(document);
        } catch (error) {
          DriverLog.warn('driver_config.cache_write_failed: $error');
        }
      }
    } catch (error) {
      DriverLog.warn('driver_config.fetch_failed: $error');
    }
    return _current;
  }

  /// Puts [next] in use unless the app has the same or a newer version.
  bool _use(DriverAppConfig next) {
    final known = _current;
    if (known != null && known.version >= next.version) return false;
    _current = next;
    next.apply();
    if (!_disposed) notifyListeners();
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
    try {
      // Contract v0.18.2 `auth.beforeSignIn`: no session, no stream; the
      // app starts watching again once the driver signs in ([watch]).
      final token = await _token();
      if (token == null || token.isEmpty) {
        stop();
        return;
      }
      final request = http.Request('GET', _uri('/driver/config/stream'))
        ..headers.addAll({
          ...await _headers('text/event-stream'),
          if (_current != null) 'Last-Event-ID': '${_current!.version}',
        });
      final response = await _client.send(request).timeout(requestTimeout);
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
      _stream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (line.startsWith('data:')) {
                data.write(line.substring(5).trim());
                return;
              }
              if (line.isNotEmpty || data.isEmpty) return;
              final raw = data.toString();
              data.clear();
              try {
                final event = jsonDecode(raw);
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
                if (version is! int || version > (_current?.version ?? 0)) {
                  unawaited(refresh());
                }
              } on FormatException {
                // A broken event is skipped; the next one or a restart fixes it.
              }
            },
            onDone: _reconnect,
            onError: (Object _) => _reconnect(),
            cancelOnError: true,
          );
    } catch (error) {
      DriverLog.warn('driver_config.stream_failed: $error');
      _reconnect();
    }
  }

  /// Stops following the stream (signed out, or the server refused the
  /// session); [watch] starts it again.
  void stop() {
    _watching = false;
    _retry?.cancel();
    _retry = null;
    unawaited(_stream?.cancel());
    _stream = null;
  }

  void _reconnect() {
    _stream = null;
    if (_disposed || !_watching) return;
    _retry?.cancel();
    _retry = Timer(retryAfter, () {
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

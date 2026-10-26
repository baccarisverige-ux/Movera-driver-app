import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/live/api_driver_realtime.dart';
import 'package:movera/core/live/live_error_message.dart';
import 'package:movera/core/live/live_trip_chat.dart';
import 'package:movera/core/live/live_trip_commands.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/session/driver_session_controller.dart';

/// A live build's link to movera-server (`MOVERA_AUTH_REQUIRED=true`):
/// dispatch over the offer endpoints, the driver's availability and
/// location, and the trip's commands and live events. The app root
/// creates it and sets [instance]; the demo (GitHub Pages) never does, so
/// every screen keeps its in-process demo there.
class LiveDriverServices {
  LiveDriverServices({
    required http.Client client,
    required Uri origin,
    required TokenStore tokens,
    required ApiClient api,
    required DriverLocationRepository location,
    Duration locationEvery = LiveLocationReporter.defaultEvery,
  }) : _client = client,
       _tokens = tokens,
       _api = api,
       apiBase = _withPrefix(origin) {
    reporter = LiveLocationReporter(
      api: api,
      location: location,
      every: locationEvery,
    );
    trips = LiveTripCommands(api: api, lastFix: () => reporter.lastFix);
    chat = LiveTripChat(api: api);
    places = LiveAddressLookup(api: api);
    dispatch = ApiDispatchRepository(
      client: client,
      baseUri: apiBase,
      accessToken: tokens.readAccess,
      renewSession: api.renewAccess,
      onAccepted: trips.observe,
    );
    presence = LivePresence(api: api, dispatch: dispatch, reporter: reporter);
  }

  /// Set by the app root in a live build; null in the demo.
  static LiveDriverServices? instance;

  /// True in a live build.
  static bool get active => instance != null;

  final http.Client _client;
  final TokenStore _tokens;
  final ApiClient _api;

  /// The origin plus `/api/v1` (contract `servers`).
  final Uri apiBase;

  late final LiveLocationReporter reporter;
  late final LiveTripCommands trips;

  /// The trip's chat with the rider (messages and unread count per trip).
  late final LiveTripChat chat;

  /// Addresses for points the offer came without (owner N11).
  late final LiveAddressLookup places;
  late final ApiDispatchRepository dispatch;
  late final LivePresence presence;

  static Uri _withPrefix(Uri origin) => origin.replace(
    path: '${origin.path.replaceFirst(RegExp(r'/$'), '')}/api/v1',
  );

  /// A trip screen's live events (it disposes the transport it gets).
  DriverRealtime realtime() => ApiDriverRealtime(
    client: _client,
    apiBase: apiBase,
    accessToken: _tokens.readAccess,
    renewSession: _api.renewAccess,
    trips: trips,
    chat: chat,
  );

  /// Follows the app's availability: the feed and location run while the
  /// driver is online or on a trip, and the server hears an offline that
  /// did not come from Home's switch (after a trip, a hold, sign-out).
  void attach(DriverSessionController session) => presence.attach(session);

  Future<void> dispose() async {
    presence.detach();
    reporter.stop();
    await dispatch.dispose();
  }
}

/// `POST /locations/reverse-geocode` (contract §10): the address at a point,
/// in the driver's language. For a pickup an offer named only by its
/// coordinates (owner N11, live test 2026-10-26).
class LiveAddressLookup {
  LiveAddressLookup({required ApiClient api}) : _api = api;

  final ApiClient _api;

  static const path = '/api/v1/locations/reverse-geocode';

  /// A bare coordinate pair ("59.195885, 17.597423", "59.2,17.6").
  static final RegExp _coordinates =
      RegExp(r'^-?\d{1,3}(\.\d+)?\s*,\s*-?\d{1,3}(\.\d+)?$');

  /// True when [address] names no place: empty, or only coordinates.
  static bool unnamed(String address) {
    final text = address.trim();
    return text.isEmpty || _coordinates.hasMatch(text);
  }

  /// The address at the point, or null when the server has none (or
  /// could not be asked); the caller keeps what it had.
  Future<String?> reverseGeocode(double latitude, double longitude) async {
    try {
      final found = await _api.post(path, body: {
        'latitude': latitude,
        'longitude': longitude,
      });
      final address = found['address'];
      return address is String && address.trim().isNotEmpty ? address.trim() : null;
    } catch (error) {
      DriverLog.warn('reverse geocode failed: $error', name: 'live');
      return null;
    }
  }
}

/// `POST /driver/availability` (contract §3.3) with the profile's
/// `expectedVersion`, and the offer feed and location that go with it.
class LivePresence {
  LivePresence({
    required ApiClient api,
    required ApiDispatchRepository dispatch,
    required LiveLocationReporter reporter,
  }) : _api = api,
       _dispatch = dispatch,
       _reporter = reporter;

  final ApiClient _api;
  final ApiDispatchRepository _dispatch;
  final LiveLocationReporter _reporter;

  static const profilePath = '/api/v1/driver/profile';
  static const availabilityPath = '/api/v1/driver/availability';

  DriverSessionController? _session;
  Future<void> _queue = Future<void>.value();

  /// What the driver last asked for; the server follows it in order.
  bool _wantOnline = false;

  /// What the server last said (online or on a trip).
  bool serverOnline = false;

  void attach(DriverSessionController session) {
    detach();
    _session = session..addListener(_onSession);
  }

  void detach() {
    _session?.removeListener(_onSession);
    _session = null;
  }

  void _onSession() {
    final session = _session;
    if (session == null) return;
    switch (session.status) {
      case DriverOnlineStatus.onTrip:
        // A trip (also one restored after a restart) sends its fixes: the
        // server checks the pickup and the drop-off from them.
        _reporter.start();
      case DriverOnlineStatus.online:
        if (serverOnline) _startOnline();
      case DriverOnlineStatus.offline || DriverOnlineStatus.suspended:
        // Offline after a trip, on hold, the driving limit…: the server
        // hears it too. Home's own switch already asked ([goOffline]).
        if (_wantOnline) unawaited(goOffline());
      case DriverOnlineStatus.goingOnline:
        break;
    }
  }

  Future<T> _serial<T>(Future<T> Function() run) {
    final result = _queue.then((_) => run());
    _queue = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  /// Goes online on the server. Null when done; else what to tell the
  /// driver (no car, fleet not approved, no connection…).
  Future<String?> goOnline() {
    _wantOnline = true;
    return _serial(() async {
      if (!_wantOnline) return null;
      try {
        final fix = await _reporter.freshFix();
        var profile = await _api.get(profilePath);
        for (var attempt = 0; attempt < 3; attempt++) {
          final status = profile['onlineStatus'];
          if (status == 'online' || status == 'on_trip') break;
          try {
            profile = await _api.post(availabilityPath, body: {
              'expectedVersion': profile['version'],
              'onlineStatus': 'online',
              if (fix != null) 'location': fix,
            });
          } on ApiError catch (error) {
            final current = error.projection;
            if (error.code != 'version_mismatch' || current == null) rethrow;
            profile = current;
          }
        }
        final status = profile['onlineStatus'];
        if (status != 'online' && status != 'on_trip') {
          _wantOnline = false;
          return tr.liveOnlineFailed;
        }
        serverOnline = true;
        _startOnline();
        return null;
      } catch (error) {
        _wantOnline = false;
        DriverLog.warn('online refused: ${_detail(error)}', name: 'live');
        return liveAvailabilityErrorMessage(error, online: true);
      }
    });
  }

  /// Goes offline on the server; the feed and location stop at once.
  /// Null when done; else what to tell the driver.
  Future<String?> goOffline() {
    _wantOnline = false;
    _stopOnline();
    return _serial(() async {
      if (_wantOnline || !serverOnline) return null;
      try {
        var profile = await _api.get(profilePath);
        for (var attempt = 0; attempt < 3; attempt++) {
          if (profile['onlineStatus'] == 'offline') break;
          try {
            profile = await _api.post(availabilityPath, body: {
              'expectedVersion': profile['version'],
              'onlineStatus': 'offline',
            });
          } on ApiError catch (error) {
            final current = error.projection;
            if (error.code != 'version_mismatch' || current == null) rethrow;
            profile = current;
          }
        }
        serverOnline = profile['onlineStatus'] != 'offline';
        return serverOnline ? tr.liveOfflineFailed : null;
      } catch (error) {
        DriverLog.warn('offline refused: ${_detail(error)}', name: 'live');
        return liveAvailabilityErrorMessage(error, online: false);
      }
    });
  }

  /// The feed is open (or reconnecting by itself) until [_stopOnline].
  bool _feedOpen = false;

  void _startOnline() {
    _reporter.start();
    if (_feedOpen) return;
    _feedOpen = true;
    unawaited(_dispatch.connect());
    _dispatch.refreshOffers();
  }

  void _stopOnline() {
    if (_session?.status != DriverOnlineStatus.onTrip) _reporter.stop();
    _feedOpen = false;
    unawaited(_dispatch.disconnect());
  }

  static String _detail(Object error) =>
      error is ApiError ? error.detail : error.runtimeType.toString();
}

/// Location batches while online (`POST /driver/location`, contract §3.3):
/// one fix every [every]. Dispatch only offers to a driver whose last fix
/// arrived in the last 120 s.
class LiveLocationReporter {
  LiveLocationReporter({
    required ApiClient api,
    required DriverLocationRepository location,
    this.every = defaultEvery,
    DateTime Function()? now,
  }) : _api = api,
       _location = location,
       _now = now ?? DateTime.now;

  static const defaultEvery = Duration(seconds: 10);
  static const locationPath = '/api/v1/driver/location';

  /// The longest one GPS read may take.
  static const readTimeout = Duration(seconds: 8);

  final ApiClient _api;
  final DriverLocationRepository _location;
  final DateTime Function() _now;
  final Duration every;

  Timer? _timer;
  bool _sending = false;

  /// The last fix sent, as the contract's `GeoFix`.
  LiveFix? lastFix;

  /// Where the phone last was, from [lastFix]: a screen that opens before its
  /// own GPS read lands (the trip screen right after an accept) starts the
  /// car here instead of at a fixed point in Stockholm.
  GeoPoint? get lastKnownPoint {
    final fix = lastFix;
    final lat = fix?['lat'];
    final lng = fix?['lng'];
    if (lat is! num || lng is! num) return null;
    final point = GeoPoint(lat.toDouble(), lng.toDouble());
    return point.isValid ? point : null;
  }

  bool get running => _timer != null;

  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(every, (_) => unawaited(sendNow()));
    unawaited(sendNow());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// A fix read now, or null when the phone has none (no permission, no
  /// signal) within [readTimeout].
  Future<LiveFix?> freshFix() async {
    try {
      return _wire(await _location.getCurrentPosition().timeout(readTimeout));
    } catch (_) {
      return null;
    }
  }

  /// Reads the position and sends it; a failure waits for the next tick.
  Future<bool> sendNow() async {
    if (_sending) return false;
    _sending = true;
    try {
      final fix = await freshFix();
      if (fix == null) return false;
      await _api.post(locationPath, body: {
        'fixes': [fix],
      });
      lastFix = fix;
      return true;
    } catch (error) {
      DriverLog.warn('location not sent: ${error.runtimeType}', name: 'live');
      return false;
    } finally {
      _sending = false;
    }
  }

  LiveFix? _wire(DriverLocation location) {
    final point = location.point;
    if (!point.isValid) return null;
    final heading = location.headingDegrees;
    final speed = location.speedMetersPerSecond;
    final accuracy = location.accuracyMeters;
    return {
      'lat': point.latitude,
      'lng': point.longitude,
      'accuracy': accuracy != null && accuracy.isFinite && accuracy >= 0
          ? accuracy
          : 100.0,
      if (heading.isFinite && heading >= 0 && heading < 360) 'heading': heading,
      if (speed != null && speed.isFinite && speed >= 0) 'speedMps': speed,
      if (speed != null && speed.isFinite) 'moving': speed >= 1,
      'measuredAt': (location.measuredAt ?? _now()).toUtc().toIso8601String(),
    };
  }
}

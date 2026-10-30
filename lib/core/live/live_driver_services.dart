import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/live/api_driver_realtime.dart';
import 'package:movera/core/live/live_active_trip.dart';
import 'package:movera/core/live/live_driver_config.dart';
import 'package:movera/core/live/live_driver_content.dart';
import 'package:movera/core/live/live_driver_zones.dart';
import 'package:movera/core/content/driver_content_store.dart';
import 'package:movera/core/contracts/driver_app_config.dart';
import 'package:movera/core/live/live_earnings.dart';
import 'package:movera/core/live/live_error_message.dart';
import 'package:movera/core/live/live_trip_chat.dart';
import 'package:movera/core/live/live_trip_commands.dart';
import 'package:movera/core/live/page_visibility.dart';
import 'package:movera/core/driver/driver_home_notices.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/location/driver_location_service.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/surge/api_surge_map.dart';
import 'package:movera/core/legal/driver_legal.dart';

export 'package:movera/core/live/live_trip_money.dart' show LiveTripMoney;

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
      noFixMinutes: () =>
          config.current?.noFixMinutes ?? DriverAppConfig.defaultNoFixMinutes,
      // Decision 1: while sending, the phone keeps sending when locked.
      onRunning: location is DriverLocationService
          ? (running) => unawaited(
              DriverLocationService.setOnlineBackground(
                running
                    ? (
                        title: tr.backgroundLocationTitle,
                        text: tr.backgroundLocationBody,
                      )
                    : null,
              ),
            )
          : null,
    );
    chat = LiveTripChat(api: api);
    trips = LiveTripCommands(
      api: api,
      lastFix: () => reporter.lastFix,
      onEnded: chat.markClosed,
    );
    places = LiveAddressLookup(api: api);
    activeTrip = LiveActiveTrip(api: api);
    earnings = LiveEarnings(api: api);
    surgeMap = ApiSurgeMapSource(api: api);
    dispatch = ApiDispatchRepository(
      client: client,
      baseUri: apiBase,
      accessToken: tokens.readAccess,
      renewSession: api.renewAccess,
      onAccepted: trips.observe,
    );
    presence = LivePresence(
      api: api,
      dispatch: dispatch,
      reporter: reporter,
      // Live test 2026-10-30: the phone's own location state, not only
      // the server's last fix, decides whether the driver may go online.
      locationBlock: location is DriverLocationService
          ? DriverLocationService.locationBlock
          : null,
    );
    content = LiveDriverContent(api: api, zoneId: () => config.current?.zoneId);
    zones = LiveDriverZones(api: api);
    config = LiveDriverConfig(
      client: client,
      apiBase: apiBase,
      accessToken: tokens.readAccess,
      renewSession: api.renewAccess,
      onContentPublished: () => unawaited(content.refresh()),
      onZonesPublished: () => unawaited(zones.refresh()),
    );
  }

  /// Set by the app root in a live build; null in the demo.
  static LiveDriverServices? instance;

  /// True in a live build.
  static bool get active => instance != null;

  final http.Client _client;
  final TokenStore _tokens;
  final ApiClient _api;

  /// The signed API client (driving routes go through it).
  ApiClient get api => _api;

  /// The origin plus `/api/v1` (contract `servers`).
  final Uri apiBase;

  late final LiveLocationReporter reporter;
  late final LiveTripCommands trips;

  /// The trip's chat with the rider (messages and unread count per trip).
  late final LiveTripChat chat;

  /// Addresses for points the offer came without (owner N11).
  late final LiveAddressLookup places;

  /// The trip the server holds for this driver (D-3).
  late final LiveActiveTrip activeTrip;

  /// Today's earnings from the server (audit R3).
  late final LiveEarnings earnings;

  /// The coloured surge zones of Home's map (contract v0.7.2 §17).
  late final ApiSurgeMapSource surgeMap;
  late final ApiDispatchRepository dispatch;
  late final LivePresence presence;

  /// The published DriverAppConfig (owner 2026-10-27): read on start, again
  /// on each config_published, put in use at once; last good kept.
  late final LiveDriverConfig config;

  /// The Content page's texts, terms and app versions (contract §19).
  late final LiveDriverContent content;

  /// The open zones with outline and names (contract v0.11.0 §21): read on
  /// start, again on config_published doc zones; last answer kept.
  late final LiveDriverZones zones;

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
  void attach(DriverSessionController session) {
    presence.attach(session);
    dispatch.onDriverOffline = () => session.setOnline(false);
    // Contract v0.18.2 `auth.beforeSignIn` (owner 2026-10-30, "Yes, stop
    // it"): the settings, their stream, the zones and the content need the
    // driver's session. Without one nothing is asked; [signedIn] starts
    // them right after the sign-in.
    unawaited(
      _tokens.readAccess().then((access) {
        if (access != null && access.isNotEmpty) signedIn();
      }, onError: (Object _) {}),
    );
  }

  bool _signedInStarted = false;

  /// Set by the app root: runs once per session start (push, R7).
  void Function()? afterSignedIn;

  /// The driver has a session (a sign-in, or one kept from before): the
  /// zones, the settings with their stream and the content are read now.
  /// Once per session.
  void signedIn() {
    if (_signedInStarted) return;
    _signedInStarted = true;
    // Contract v0.18.3 R7: push is set up once there is a session.
    afterSignedIn?.call();
    unawaited(zones.start());
    unawaited(
      config.start().then((_) {
        unawaited(content.start());
        return config.watch();
      }),
    );
  }

  /// The session ended (sign-out, or refused by the server): the settings
  /// stream stops until the next [signedIn].
  void signedOut() {
    _signedInStarted = false;
    config.stop();
  }

  /// The app is on screen again ([LivePresence.resumed]).
  void resumed() => presence.resumed();

  Future<void> dispose() async {
    presence.detach();
    reporter.stop();
    config.dispose();
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
  static final RegExp _coordinates = RegExp(
    r'^-?\d{1,3}(\.\d+)?\s*,\s*-?\d{1,3}(\.\d+)?$',
  );

  /// True when [address] names no place: empty, or only coordinates.
  static bool unnamed(String address) {
    final text = address.trim();
    return text.isEmpty || _coordinates.hasMatch(text);
  }

  /// The address at the point, or null when the server has none (or
  /// could not be asked); the caller keeps what it had.
  Future<String?> reverseGeocode(double latitude, double longitude) async {
    try {
      final found = await _api.post(
        path,
        body: {'latitude': latitude, 'longitude': longitude},
      );
      final address = found['address'];
      return address is String && address.trim().isNotEmpty
          ? address.trim()
          : null;
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
    Future<Object?> Function()? locationBlock,
  }) : _api = api,
       _dispatch = dispatch,
       _reporter = reporter,
       _locationBlock = locationBlock;

  final ApiClient _api;
  final ApiDispatchRepository _dispatch;
  final LiveLocationReporter _reporter;

  /// Decision 2 (live test 2026-10-30: a driver with location blocked went
  /// online because the server still had a fix under 2 min old): the
  /// phone's location off or not allowed, read without asking; null when
  /// it is on and allowed (or the platform cannot tell).
  final Future<Object?> Function()? _locationBlock;

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
    // Contract §19: until the new terms are accepted the driver cannot go
    // online (the server refuses too); the terms screen shows again.
    final terms = DriverContentStore.instance;
    if (terms.blocksOnline) {
      _wantOnline = false;
      terms.askTerms();
      return Future<String?>.value(tr.contentTermsBlockOnline);
    }
    // Contract v0.18.5 `legal.accept` (G1-B2): the same for a new version
    // of the country's terms (`GET /legal/{country}` with reaccept).
    final legal = DriverLegal.instance;
    if (legal.due) {
      _wantOnline = false;
      unawaited(legal.askAgain());
      return Future<String?>.value(tr.contentTermsBlockOnline);
    }
    return _serial(() async {
      if (!_wantOnline) return null;
      try {
        // Decision 2: location off or not allowed on the phone keeps the
        // driver offline, and the server is not asked at all.
        final block = await _locationBlock?.call();
        if (block != null) {
          _wantOnline = false;
          return tr.locationRequired;
        }
        final fix = await _reporter.freshFix();
        // G3 live check (after 03c): going online without a position is
        // always refused (409 location_required), so it is not sent at all
        // (a long press, a reload while the GPS was still waking up).
        if (fix == null) {
          _wantOnline = false;
          return tr.locationRequired;
        }
        // v0.18.4 `auth.slowStart` covers going online: a sleeping server
        // answers after about 50 s, so wait up to 60 s.
        var profile = await _api.get(
          profilePath,
          timeout: ApiClient.signInTimeout,
        );
        for (var attempt = 0; attempt < 3; attempt++) {
          final status = profile['onlineStatus'];
          if (status == 'online' || status == 'on_trip') break;
          try {
            profile = await _api.post(
              availabilityPath,
              body: {
                'expectedVersion': profile['version'],
                'onlineStatus': 'online',
                'location': fix,
              },
              timeout: ApiClient.signInTimeout,
            );
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
        // Live test 2026-10-30: an old "set offline" the feed replays must
        // not undo this Go online a second later.
        _dispatch.markOnline();
        final version = profile['version'];
        _onlineVersion = version is num ? version.toInt() : null;
        DriverSetOfflineNotice.instance.clear();
        // G3-R2: online, but outside his zones the popup says so.
        DriverAreaWatch.instance.observe(profile);
        _startOnline();
        return null;
      } catch (error) {
        _wantOnline = false;
        DriverLog.warn('online refused: ${_detail(error)}', name: 'live');
        if (error is ApiError && error.detail == 'terms_not_accepted') {
          unawaited(DriverLegal.instance.askAgain());
        }
        return liveAvailabilityErrorMessage(error, online: true);
      }
    });
  }

  /// The Driver.version of the going-online answer.
  int? _onlineVersion;

  /// G3-R1: a profile read after going online says the server set the
  /// driver offline (no position for `autoOffline.noFixMinutes`).
  bool serverSetOffline({required String? onlineStatus, required int version}) {
    final since = _onlineVersion;
    return serverOnline &&
        _wantOnline &&
        since != null &&
        version > since &&
        onlineStatus == 'offline';
  }

  bool _settled = false;

  /// D11: the app starts offline after a restart (a reload of the web
  /// build, a crash, a cold start), but the server may still hold the
  /// driver `online` from before: it kept offering trips, and the admin
  /// saw the driver online, while the app showed the radar off with no
  /// feed and no location. Once per start, before the driver goes online,
  /// such a server state is turned offline. A trip under way (`on_trip`)
  /// is left alone.
  Future<void> settleAfterStart() {
    if (_settled) return Future<void>.value();
    _settled = true;
    return _serial(() async {
      if (_wantOnline || serverOnline) return;
      try {
        var profile = await _api.get(profilePath);
        for (var attempt = 0; attempt < 3; attempt++) {
          if (_wantOnline || profile['onlineStatus'] != 'online') return;
          try {
            profile = await _api.post(
              availabilityPath,
              body: {
                'expectedVersion': profile['version'],
                'onlineStatus': 'offline',
              },
            );
            // Decision 3: "You were set offline – tap to go online again".
            if (profile['onlineStatus'] == 'offline') {
              DriverSetOfflineNotice.instance.show();
            }
          } on ApiError catch (error) {
            final current = error.projection;
            if (error.code != 'version_mismatch' || current == null) rethrow;
            profile = current;
          }
        }
      } catch (error) {
        DriverLog.warn(
          'start offline refused: ${_detail(error)}',
          name: 'live',
        );
      }
    });
  }

  /// Goes offline on the server; the feed and location stop at once.
  /// Null when done; else what to tell the driver.
  Future<String?> goOffline() {
    _wantOnline = false;
    _onlineVersion = null;
    DriverAreaWatch.instance.reset();
    _stopOnline();
    return _serial(() async {
      if (_wantOnline || !serverOnline) return null;
      try {
        var profile = await _api.get(profilePath);
        for (var attempt = 0; attempt < 3; attempt++) {
          if (profile['onlineStatus'] == 'offline') break;
          try {
            profile = await _api.post(
              availabilityPath,
              body: {
                'expectedVersion': profile['version'],
                'onlineStatus': 'offline',
              },
            );
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

  /// Back on screen (owner, live test 2026-10-26: "driver don't receive
  /// offers"). A locked phone may have lost the offer feed without it
  /// closing and sent no position for minutes, so the server stopped
  /// choosing the driver. While online the feed is opened again from its
  /// last sequence, the open offers are read, and a fix goes out now
  /// rather than at the next tick.
  void resumed() {
    if (!_feedOpen) return;
    unawaited(_reporter.sendNow());
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
    bool? restampHeldFix,
    PageVisibility? visibility,
    int Function()? noFixMinutes,
    this.onRunning,
  }) : _api = api,
       _location = location,
       _now = now ?? DateTime.now,
       _restamp = restampHeldFix ?? kIsWeb,
       _visibility = visibility ?? PageVisibility.platform(),
       _noFixMinutes = noFixMinutes;

  static const defaultEvery = Duration(seconds: 10);

  /// A fix from the position stream younger than this goes out as it is.
  static const heldFresh = Duration(seconds: 20);

  /// Driver group 3 (live test 2026-10-30: one position after going
  /// online, then "No recent accurate GPS fix" every tick): the reporter
  /// no longer asks for a brand-new one-shot fix every 10 s, which a
  /// browser (and a phone indoors) cannot give in time. It keeps the
  /// position stream open while running and sends its latest fix.
  /// A browser's stream reports only when the position changes, so a
  /// laptop standing still sends no new fix. On the web ([_restamp]) the
  /// last real fix is sent again stamped now, but only (checker, PR #412)
  /// while the page is visible ([_visibility]) and for at most
  /// `autoOffline.noFixMinutes` ([_noFixMinutes]) after that real fix.
  /// A hidden tab sends nothing at all: Chrome throttles its timer and its
  /// geolocation watch goes quiet without an error, so re-sending there
  /// would keep a driver who left the laptop online forever and defeat
  /// G3-R1 (offline after `noFixMinutes` without a position). When the tab
  /// shows again a fresh fix is asked for at once.
  ///
  /// Trade-off: the contract's GeoFix has one timestamp (`measuredAt`) and
  /// no field for "re-sent", so a re-sent fix carries the send time, up to
  /// `noFixMinutes` later than the real measurement. This is accepted only
  /// for a visible, stationary tab, where the driver is still at that
  /// point; after the limit only real measurements (a one-shot read with
  /// its own time) go out, so the server's auto-offline still works.
  final bool _restamp;

  /// The page's visibility on the web; null elsewhere (always visible).
  final PageVisibility? _visibility;

  /// The published `autoOffline.noFixMinutes` (default 5).
  final int Function()? _noFixMinutes;

  StreamSubscription<bool>? _visibilityWatch;

  /// When the held fix was really measured (or received, if undated).
  DateTime? _heldAt;

  bool get _pageVisible => _visibility?.visible ?? true;

  Duration get _restampLimit {
    final minutes =
        _noFixMinutes?.call() ?? DriverAppConfig.defaultNoFixMinutes;
    return Duration(
      minutes: minutes > 0 ? minutes : DriverAppConfig.defaultNoFixMinutes,
    );
  }

  /// Called with true when sending starts and false when it stops
  /// (decision 1: the background location mode follows it).
  final void Function(bool running)? onRunning;

  StreamSubscription<DriverLocation>? _watch;
  DriverLocation? _held;
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
    onRunning?.call(true);
    _openWatch();
    _visibilityWatch = _visibility?.changes.listen((visible) {
      // Back on screen: ask for a fresh fix now, not the held one.
      if (visible && running) unawaited(sendNow(fresh: true));
    });
    unawaited(sendNow());
  }

  void stop() {
    if (_timer == null) return;
    _timer?.cancel();
    _timer = null;
    unawaited(_watch?.cancel());
    _watch = null;
    unawaited(_visibilityWatch?.cancel());
    _visibilityWatch = null;
    _held = null;
    _heldAt = null;
    onRunning?.call(false);
  }

  void _openWatch() {
    _watch = _location
        .watchPosition(distanceFilterMeters: 0)
        .listen(
          _hold,
          // No signal or no permission: the next tick reads once instead.
          onError: (Object _) {
            _held = null;
            _heldAt = null;
          },
          cancelOnError: false,
        );
  }

  void _hold(DriverLocation location) {
    _held = location;
    _heldAt = location.measuredAt ?? _now();
  }

  /// The stream's latest fix when it can go out now, else null.
  LiveFix? _heldFix() {
    final held = _held;
    if (held == null) return null;
    final at = held.measuredAt;
    final age = at == null ? null : _now().difference(at);
    if (age != null && age <= heldFresh && age >= -gpsClockSkewTolerance) {
      return _wire(held);
    }
    if (!_restamp || !_pageVisible) return null;
    final since = _heldAt;
    if (since == null || _now().difference(since) > _restampLimit) return null;
    return _wire(held, measuredAt: _now());
  }

  /// A fix read now, or null when the phone has none (no permission, no
  /// signal) within [readTimeout].
  ///
  /// G3 live check (after 03c, "after a reload Go online is refused"): a
  /// browser answers this one-shot from its own fix of the last 30 s, but
  /// may stamp it with the time it first had it — before the reload — and
  /// the server refuses a fix older than 2 minutes. In the browser
  /// ([_restamp]) the answer to "where am I now" is stamped now; the old
  /// held fix of the stream is never used for going online.
  Future<LiveFix?> freshFix() async {
    final read = await _readOnce();
    if (read == null) return null;
    final at = read.measuredAt;
    final stale = at == null || _now().difference(at) > heldFresh;
    return _wire(read, measuredAt: _restamp && stale ? _now() : null);
  }

  Future<DriverLocation?> _readOnce() async {
    try {
      return await _location.getCurrentPosition().timeout(readTimeout);
    } catch (_) {
      return null;
    }
  }

  /// Reads the position and sends it; a failure waits for the next tick.
  /// With [fresh] the held fix is skipped and a new one is read.
  Future<bool> sendNow({bool fresh = false}) async {
    // A hidden web tab sends nothing, so the server's auto-offline works.
    if (_restamp && !_pageVisible) return false;
    if (_sending) return false;
    _sending = true;
    try {
      var fix = fresh ? null : _heldFix();
      if (fix == null) {
        final read = await _readOnce();
        if (read != null && _restamp) _hold(read);
        fix = read == null ? null : _wire(read);
      }
      if (fix == null) return false;
      final ack = await _api.post(
        locationPath,
        body: {
          'fixes': [fix],
        },
      );
      lastFix = fix;
      // G3-R2: "You are not eligible to drive in this area" once per entry.
      DriverAreaWatch.instance.observe(ack);
      return true;
    } catch (error) {
      DriverLog.warn('location not sent: ${error.runtimeType}', name: 'live');
      return false;
    } finally {
      _sending = false;
    }
  }

  LiveFix? _wire(DriverLocation location, {DateTime? measuredAt}) {
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
      'measuredAt': (measuredAt ?? location.measuredAt ?? _now())
          .toUtc()
          .toIso8601String(),
    };
  }
}

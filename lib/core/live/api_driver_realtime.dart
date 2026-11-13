import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:movera/core/realtime/reconnect_backoff.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/live/live_trip_calls.dart';
import 'package:movera/core/live/live_trip_chat.dart';
import 'package:movera/core/live/live_trip_commands.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:movera/core/realtime/driver_realtime.dart';

/// The trip's live events from the server: `GET /trips/{tripId}/events`
/// with `Accept: text/event-stream` (contract §4). `id:` is the trip's
/// sequence; a dropped stream resumes from the last one (`?after=`,
/// `Last-Event-ID`), with backoff.
///
/// Every projection it reads goes to [LiveTripCommands], so the next
/// command sends the server's version. The echo of this phone's own
/// command (arrived after Arrive, completed after Finish…) is not passed
/// on: the screen already moved, and a terminal echo would otherwise end
/// the trip a second time. A rider cancel, an admin's change or anything
/// else comes through to the screen as before. A chat message
/// (`kind: message`) goes to [LiveTripChat] as well.
class ApiDriverRealtime implements DriverRealtime {
  ApiDriverRealtime({
    required http.Client client,
    required Uri apiBase,
    required Future<String?> Function() accessToken,
    this.renewSession,
    LiveTripCommands? trips,
    LiveTripChat? chat,
    LiveTripCalls? calls,
    Duration Function(int attempt)? reconnectDelay,
    this.streamIdleTimeout = defaultStreamIdleTimeout,
    DateTime Function()? now,
  }) : _client = client,
       _calls = calls,
       _base = apiBase,
       _token = accessToken,
       _trips = trips,
       _chat = chat,
       _delay = reconnectDelay ?? _backoff,
       _now = now ?? DateTime.now;

  final http.Client _client;
  final Uri _base;
  final Future<String?> Function() _token;
  final LiveTripCommands? _trips;
  final LiveTripChat? _chat;
  final LiveTripCalls? _calls;
  final Duration Function(int attempt) _delay;
  final Future<void> Function()? renewSession;
  final DateTime Function() _now;

  /// Finder D2 (2026-11-07), like the offer feed's `feedIdleTimeout`: a
  /// stream that goes silent without closing (an iPhone that locked or
  /// changed network leaves the socket half open) is closed and opened
  /// again after this long with nothing on it. The server sends
  /// `: heartbeat` every 15 s, so a healthy stream is never this quiet.
  final Duration streamIdleTimeout;

  static const defaultStreamIdleTimeout = Duration(seconds: 45);

  final StreamController<DriverRealtimeEvent> _out =
      StreamController<DriverRealtimeEvent>.broadcast();
  String? _tripId;
  int _last = 0;
  int _attempts = 0;
  int _generation = 0;
  bool _open = false;
  bool _disposed = false;
  StreamSubscription<String>? _feed;
  Timer? _retry;
  Timer? _idle;
  DateTime? _lastLineAt;

  static Duration _backoff(int attempt) => reconnectBackoff(attempt);

  /// True while the stream is open.
  bool get connected => _open;

  /// The last trip sequence read.
  int get lastSequence => _last;

  @override
  Stream<DriverRealtimeEvent> subscribe(String tripId) {
    if (_disposed) throw StateError('Realtime disposed');
    if (tripId.trim().isEmpty) {
      throw ArgumentError.value(tripId, 'tripId', 'Trip ID is required');
    }
    if (_tripId != tripId) {
      _close();
      _tripId = tripId;
      _last = 0;
      _attempts = 0;
      unawaited(_connect());
    }
    return _out.stream.where((event) => event.tripId == tripId);
  }

  /// The stream resumes by itself; a resync asked while it is down opens
  /// it now instead of after the backoff. An "open" stream with nothing on
  /// it for [streamIdleTimeout] (the watchdog timer may not have run while
  /// the phone was locked) counts as down.
  ///
  /// S6 I-2 (2026-11-07): [reopen] after the app was hidden: a lock or an
  /// app switch of a few seconds leaves the socket half open with no way
  /// to tell, and the watchdog would only see it after
  /// [streamIdleTimeout] (a status up to 45 s late on screen). The stream
  /// is opened again with `after=` the last sequence, so only what was
  /// missed is replayed.
  @override
  Future<void> reconnectAndResync(String tripId, {bool reopen = false}) async {
    if (_disposed || _tripId != tripId) return;
    if (_open && !reopen && !_silentTooLong) return;
    _retry?.cancel();
    await _connect();
  }

  bool get _silentTooLong {
    final last = _lastLineAt;
    return last != null && _now().difference(last) >= streamIdleTimeout;
  }

  /// The server sends its own events for every command (arrive, start…).
  @override
  Future<void> sendSignal({
    required String tripId,
    required DriverRealtimeKind kind,
    String? message,
  }) async {}

  Uri _uri(String tripId) => _base.replace(
    path:
        '${_base.path.replaceFirst(RegExp(r'/$'), '')}/trips/${Uri.encodeComponent(tripId)}/events',
    queryParameters: {if (_last > 0) 'after': '$_last'},
  );

  Future<void> _connect() async {
    final tripId = _tripId;
    if (_disposed || tripId == null) return;
    final generation = ++_generation;
    // A stream opened again (a resume) keeps the credit of its time up.
    _endUptime();
    _idle?.cancel();
    _idle = null;
    // A half-open stream's cancel may never complete: it must not hold up
    // the new stream.
    final old = _feed;
    _feed = null;
    unawaited(old?.cancel());
    _open = false;
    // The stream replays the trip from its first event. What this phone
    // already knows (the accept answer, or the trip read here) tells the
    // replay of history from news; see [ingest].
    if (_last == 0) await _trips?.ensureKnown(tripId);
    if (generation != _generation || _disposed) return;
    final http.StreamedResponse response;
    try {
      final token = await _token();
      final request = http.Request('GET', _uri(tripId))
        ..headers.addAll({
          'Accept': 'text/event-stream',
          'X-Api-Version': ApiClient.apiVersion,
          'X-Request-Id': ApiClient.randomKey(),
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
          if (_last > 0) 'Last-Event-ID': '$_last',
        });
      response = await _client.send(request).timeout(ApiClient.requestTimeout);
    } catch (error) {
      if (generation == _generation) _lost();
      return;
    }
    if (generation != _generation || _disposed) {
      unawaited(response.stream.drain<void>().catchError((_) {}));
      return;
    }
    if (response.statusCode != 200) {
      unawaited(response.stream.drain<void>().catchError((_) {}));
      DriverLog.warn('trip events ${response.statusCode}', name: 'live');
      if (response.statusCode == 404 || response.statusCode == 403) {
        // The trip is not this driver's any more (given to another
        // driver, or taken back by Movera): it is over here.
        _released(tripId);
        return;
      }
      if (response.statusCode == 401) {
        try {
          await renewSession?.call();
        } catch (_) {
          // The next try asks again.
        }
      }
      _lost();
      return;
    }
    _open = true;
    // Back after a drop: a message may have passed while the stream was
    // down, so the chat reads its history again.
    if (_attempts > 0) unawaited(_chat?.reconcile(tripId));
    // D2 (fix plan 2026-11-13, owner R3, as the offer feed): a 200 alone
    // is not "connected". The backoff starts again only after an event or
    // 30 s up ([streamConnectedAfter]); a stream the busy server ends
    // right after it opened is one more failed try.
    _openedAt = _now();
    final data = StringBuffer();
    void quiet() {
      if (generation != _generation) return;
      final feed = _feed;
      _feed = null;
      unawaited(feed?.cancel());
      DriverLog.warn('trip events silent, reopening', name: 'live');
      _lost();
    }

    void alive() {
      _lastLineAt = _now();
      _idle?.cancel();
      _idle = Timer(streamIdleTimeout, quiet);
    }

    alive();
    _feed = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            // Any line, the heartbeat comment too, shows the stream is
            // alive.
            if (generation == _generation) alive();
            if (line.startsWith('data:')) {
              data.write(line.substring(5).trim());
            } else if (line.isEmpty && data.isNotEmpty) {
              final raw = data.toString();
              data.clear();
              try {
                final json = jsonDecode(raw);
                if (json is Map) {
                  // A real event: the stream is connected (owner R3).
                  if (generation == _generation) _attempts = 0;
                  ingest(Map<String, dynamic>.from(json));
                }
              } on FormatException {
                // A broken event is skipped; the next one carries the state.
              }
            }
          },
          onError: (Object _) {
            if (generation == _generation) _lost();
          },
          onDone: () {
            if (generation == _generation) _lost();
          },
          cancelOnError: true,
        );
  }

  /// One envelope from the stream (public for tests).
  void ingest(Map<String, dynamic> json) {
    final tripId = json['tripId'];
    final sequence = json['sequence'];
    if (tripId is! String || tripId != _tripId || sequence is! num) return;
    if (sequence.toInt() <= _last) return;
    _last = sequence.toInt();
    final projection = json['projection'];
    final status = projection is Map ? projection['status'] as String? : null;
    final version = json['version'];
    // The replay of the trip's history (requested, searching, offered…
    // before this driver's accept): older than what this phone knows, so
    // not news. Passing it on would read as the trip taken back. A chat
    // message never changes the trip, so its version says nothing about
    // that: it always comes through (a replay after a drop carries the
    // version of its time).
    // v0.18.38 §62: a call event never changes the trip either.
    final kind = json['kind'];
    final isCall = kind is String && kind.startsWith('call_');
    final isMessage = kind == 'message' || isCall;
    if (isCall) {
      final payload = json[kind == 'call_signal' ? 'signal' : 'call'];
      if (payload is Map) {
        _calls?.receive(tripId, kind, Map<String, dynamic>.from(payload));
      }
    }
    final known = _trips?.versionOf(tripId);
    if (!isMessage &&
        version is num &&
        known != null &&
        version.toInt() < known) {
      return;
    }
    if (projection is Map && version is num) {
      _trips?.observe({
        ...Map<String, dynamic>.from(projection),
        'tripId': tripId,
        'version': version,
      });
    }
    // Contract v0.18.5 `chat.appStorage`: no chat is kept after the trip
    // (also when the end is this driver's own step, echoed below).
    if (status != null && _isTerminal(status)) _chat?.tripEnded(tripId);
    // v0.18.50 §72 L7: the rider's stream hears this driver's own cancel
    // as driver_cancelled; on his phone it is his own echo, like the
    // trip_projection one.
    if ((kind == 'trip_projection' || kind == 'driver_cancelled') &&
        (_trips?.isOwnEcho(
              tripId,
              status,
              version: version is num ? version.toInt() : null,
            ) ??
            false)) {
      return;
    }
    final event = DriverRealtimeEvent.tryParse(json);
    if (event == null) return;
    // The screen still hears it (its sequence gate counts every event);
    // the chat shows it and counts it as unread.
    if (event.chat case final message?) _chat?.receive(tripId, message);
    if (!_out.isClosed) _out.add(event);
  }

  /// The trip left this driver without an event they could read: the
  /// screen hears it as a trip back with dispatch.
  void _released(String tripId) {
    _open = false;
    _idle?.cancel();
    _idle = null;
    // This driver's own cancel handed it back: the screen already knows.
    if (_out.isClosed ||
        (_trips?.isOwnEcho(tripId, 'searching') ?? false) ||
        (_trips?.isOwnEcho(tripId, 'requested') ?? false)) {
      return;
    }
    final now = DateTime.now().toUtc();
    _out.add(
      DriverRealtimeEvent(
        eventId: 'released-$tripId-${_last + 1}',
        tripId: tripId,
        kind: DriverRealtimeKind.tripProjection,
        sequence: ++_last,
        at: now,
        serverTime: now,
        status: TripStatus.searching,
      ),
    );
  }

  /// When the open stream answered 200; null while none is open.
  DateTime? _openedAt;

  /// Owner R3: a stream that stayed open [streamConnectedAfter] was
  /// connected, so the next wait is the shortest again.
  void _endUptime() {
    final opened = _openedAt;
    _openedAt = null;
    if (opened != null && _now().difference(opened) >= streamConnectedAfter) {
      _attempts = 0;
    }
  }

  void _lost() {
    _open = false;
    _endUptime();
    _idle?.cancel();
    _idle = null;
    if (_disposed || _tripId == null) return;
    _retry?.cancel();
    _retry = Timer(_delay(_attempts++), () => unawaited(_connect()));
  }

  void _close() {
    _generation++;
    _openedAt = null;
    _retry?.cancel();
    _retry = null;
    _idle?.cancel();
    _idle = null;
    _lastLineAt = null;
    final feed = _feed;
    _feed = null;
    _open = false;
    unawaited(feed?.cancel());
  }

  @override
  void unsubscribe() {
    _close();
    _tripId = null;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unsubscribe();
    unawaited(_out.close());
  }
}

bool _isTerminal(String wire) =>
    TripStatusWire.tryParse(wire)?.isTerminal ?? false;

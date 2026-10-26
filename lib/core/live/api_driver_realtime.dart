import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/contracts/trip_status.dart';
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
    Duration Function(int attempt)? reconnectDelay,
  }) : _client = client,
       _base = apiBase,
       _token = accessToken,
       _trips = trips,
       _chat = chat,
       _delay = reconnectDelay ?? _backoff;

  final http.Client _client;
  final Uri _base;
  final Future<String?> Function() _token;
  final LiveTripCommands? _trips;
  final LiveTripChat? _chat;
  final Duration Function(int attempt) _delay;
  final Future<void> Function()? renewSession;

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

  static Duration _backoff(int attempt) =>
      Duration(seconds: math.min(30, 1 << math.min(attempt, 5)));

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
  /// it now instead of after the backoff.
  @override
  Future<void> reconnectAndResync(String tripId) async {
    if (_disposed || _tripId != tripId || _open) return;
    _retry?.cancel();
    await _connect();
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
    await _feed?.cancel();
    _feed = null;
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
    _attempts = 0;
    final data = StringBuffer();
    _feed = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (line.startsWith('data:')) {
              data.write(line.substring(5).trim());
            } else if (line.isEmpty && data.isNotEmpty) {
              final raw = data.toString();
              data.clear();
              try {
                final json = jsonDecode(raw);
                if (json is Map) ingest(Map<String, dynamic>.from(json));
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
    final isMessage = json['kind'] == 'message';
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
    if (json['kind'] == 'trip_projection' &&
        (_trips?.isOwnEcho(tripId, status) ?? false)) {
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

  void _lost() {
    _open = false;
    if (_disposed || _tripId == null) return;
    _retry?.cancel();
    _retry = Timer(_delay(_attempts++), () => unawaited(_connect()));
  }

  void _close() {
    _generation++;
    _retry?.cancel();
    _retry = null;
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

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// One call the app made through its HTTP client: what and how it ended.
///
/// Only the method, the path, the query parameter NAMES and the status are
/// kept for the report: never a body, a header or a query value (bodies and
/// headers hold the phone number, the code and the session token).
class RecordedCall {
  RecordedCall({
    required this.at,
    required this.method,
    required this.path,
    required this.queryNames,
  });

  final DateTime at;
  final String method;
  final String path;
  final List<String> queryNames;

  /// The answer's status, or null while waiting / when the call threw.
  int? status;

  /// The error type when the call threw (no message: it may hold a URL).
  String? error;

  Duration? took;

  /// The zone the call named (`?zoneId=`), kept for the G17 check; a zone
  /// id is not personal data.
  String? zoneId;

  /// The decoded answer, only for [RecordingClient.kept] paths (in memory
  /// for the checks; never printed).
  Object? answer;

  /// L20 wire log only (`/driver/stream`, `/driver/config*`): the full
  /// path + query (secret-looking values stripped) and the Last-Event-ID
  /// header value. Never the Authorization header.
  String? wire;

  bool get failed => error != null || (status != null && status! >= 400);

  /// Location sends and long-lived event streams are not "page reads".
  bool get isBackground =>
      path.endsWith('/stream') ||
      path.endsWith('/events') ||
      path == '/api/v1/driver/location';

  String get label {
    if (wire != null) return '$method $wire';
    final names = queryNames.isEmpty ? '' : '?${queryNames.join('&')}';
    return '$method $path$names';
  }

  @override
  String toString() =>
      '$label -> ${error ?? status ?? 'pending'}'
      '${took == null ? '' : ' (${took!.inMilliseconds} ms)'}';
}

/// The app's own HTTP client, recording every call it makes (G24 location
/// sends, G27 re-reads after Back) and keeping the last JSON answer of a
/// few read-only resources for the checks to compare against.
class RecordingClient extends http.BaseClient {
  RecordingClient(this._inner, {required this.apiHost});

  final http.Client _inner;

  /// Only this host's calls carry the session token the checks re-use.
  final String apiHost;

  final List<RecordedCall> calls = <RecordedCall>[];

  /// Last decoded JSON answer per path, for these paths only.
  static const Set<String> kept = <String>{
    '/api/v1/driver/zones',
    '/api/v1/driver/config',
    '/api/v1/driver/profile',
    '/api/v1/driver/availability',
    '/api/v1/driver/location',
  };

  /// Kept too: the trip test's money and call checks (the preview the
  /// cash screen shows, the server's answer to the app's own call, the
  /// trip itself, the earnings report).
  static bool keeps(String path) =>
      kept.contains(path) ||
      path == '/api/v1/driver/earnings' ||
      path.endsWith('/complete-preview') ||
      (path.startsWith('/api/v1/trips/') &&
          (path.endsWith('/call') || path.endsWith('/rating'))) ||
      path.startsWith('/api/v1/offers/');

  final Map<String, Object?> lastAnswer = <String, Object?>{};

  /// The session's `Authorization` header, in memory only (never logged),
  /// so a check can ask the server the same question itself.
  String? _authorization;

  String? get authorization => _authorization;

  int get length => calls.length;

  /// Calls made since [mark] (an earlier [length]).
  List<RecordedCall> since(int mark) => calls.sublist(mark);

  // ---- L20 one stream (test only; `trip-one-stream` scenario) ----------

  static const String oneStreamPath = '/api/v1/driver/stream';

  /// Test seam (no production switch): every `GET /driver/config` answer
  /// the app reads says `realtime.oneStream: true`, as if an admin had
  /// turned the zone's switch on. Staging is not changed; only this
  /// phone's copy of the answer.
  bool forceOneStream = false;

  /// What the server itself last said (`realtime.oneStream`, `version`)
  /// before any patch, for the report.
  Object? serverOneStream;
  Object? serverConfigVersion;

  /// Arm once: the next `GET /driver/stream` that carries a cursor
  /// `<offer seq>.<config version>` asks from config version - 1, so the
  /// server sends the live settings (`config_published`) on the one stream.
  bool lowerConfigCursorOnce = false;

  /// The cursor the test lowered (offer half kept), null when not yet.
  String? loweredCursor;

  /// Event kinds that arrived on `GET /driver/stream` (in order), with the
  /// time each came; never the event body.
  final List<(DateTime, String)> oneStreamKinds = <(DateTime, String)>[];

  /// Long-lived streams now open, by path (`.../stream`, `.../events`).
  final Map<String, int> openStreams = <String, int>{};

  final List<StreamController<List<int>>> _oneStreamPipes =
      <StreamController<List<int>>>[];

  /// Raw SSE lines per stream response (first [streamLogLimit] bytes of
  /// each), with a timestamp, for `streams.txt`. Data lines on these
  /// streams carry offers/config, never a token.
  final List<String> streamLog = <String>[];
  static const int streamLogLimit = 2048;
  int _streamSeq = 0;

  static bool wired(String path) =>
      path == oneStreamPath || path.startsWith('/api/v1/driver/config');

  static final RegExp _secretName = RegExp(
    r'token|auth|key|secret|code|password|sig',
    caseSensitive: false,
  );

  static String wireOf(http.BaseRequest request) {
    final url = request.url;
    final query = <String, String>{
      for (final e in url.queryParameters.entries)
        e.key: _secretName.hasMatch(e.key) ? '[stripped]' : e.value,
    };
    String? lastId;
    request.headers.forEach((k, v) {
      if (k.toLowerCase() == 'last-event-id') lastId = v;
    });
    final q = query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
    return '${url.path}$q [Last-Event-ID: ${lastId ?? '-'}]';
  }

  int openCount(String path) => openStreams[path] ?? 0;

  /// Ends the one stream as a network drop would (the app reconnects).
  Future<void> cutOneStream() async {
    for (final pipe in List.of(_oneStreamPipes)) {
      await pipe.close();
    }
  }

  http.BaseRequest _lowered(http.BaseRequest request) {
    final url = request.url;
    final after = url.queryParameters['after'];
    final parts = after == null
        ? null
        : RegExp(r'^(\d+)\.(\d+)$').firstMatch(after);
    final version = parts == null ? null : int.parse(parts.group(2)!);
    if (parts == null || version == null || version < 1) return request;
    lowerConfigCursorOnce = false;
    final cursor = '${parts.group(1)}.${version - 1}';
    loweredCursor = cursor;
    final copy = http.Request(
      request.method,
      url.replace(queryParameters: {...url.queryParameters, 'after': cursor}),
    )..headers.addAll(request.headers);
    copy.headers.removeWhere((k, _) => k.toLowerCase() == 'last-event-id');
    copy.headers['Last-Event-ID'] = cursor;
    return copy;
  }

  http.StreamedResponse _watchStream(
    String path,
    http.StreamedResponse response,
  ) {
    openStreams[path] = openCount(path) + 1;
    final one = path == oneStreamPath;
    var closed = false;
    void done() {
      if (closed) return;
      closed = true;
      openStreams[path] = openCount(path) - 1;
    }

    final wire = wired(path);
    final id = ++_streamSeq;
    var logged = 0;
    final rawRest = StringBuffer();
    if (wire) {
      streamLog.add(
        '${DateTime.now().toUtc().toIso8601String()} #$id OPEN $path '
        'status=${response.statusCode}',
      );
    }
    void raw(List<int> chunk) {
      if (!wire || logged >= streamLogLimit) return;
      final take = chunk.length > streamLogLimit - logged
          ? chunk.sublist(0, streamLogLimit - logged)
          : chunk;
      logged += take.length;
      rawRest.write(utf8.decode(take, allowMalformed: true));
      final text = rawRest.toString();
      final cut = text.lastIndexOf('\n');
      final now = DateTime.now().toUtc().toIso8601String();
      streamLog.add('$now #$id CHUNK ${chunk.length} bytes');
      if (cut >= 0) {
        rawRest
          ..clear()
          ..write(text.substring(cut + 1));
        for (final line in text.substring(0, cut).split('\n')) {
          streamLog.add('$now #$id | ${line.replaceAll('\r', '')}');
        }
      }
      if (logged >= streamLogLimit) {
        streamLog.add('$now #$id (2 KB log limit reached)');
      }
    }

    late final StreamController<List<int>> pipe;
    StreamSubscription<List<int>>? sub;
    final lines = StringBuffer();
    void read(List<int> chunk) {
      if (!one) return;
      lines.write(utf8.decode(chunk, allowMalformed: true));
      final text = lines.toString();
      final cut = text.lastIndexOf('\n');
      if (cut < 0) return;
      lines
        ..clear()
        ..write(text.substring(cut + 1));
      for (final line in text.substring(0, cut).split('\n')) {
        if (!line.startsWith('data:')) continue;
        try {
          final event = jsonDecode(line.substring(5).trim());
          if (event is Map && event['kind'] is String) {
            oneStreamKinds.add((DateTime.now(), event['kind'] as String));
          }
        } catch (_) {
          // A data line split over lines: not counted.
        }
      }
    }

    pipe = StreamController<List<int>>(
      onListen: () {
        sub = response.stream.listen(
          (chunk) {
            raw(chunk);
            read(chunk);
            if (!pipe.isClosed) pipe.add(chunk);
          },
          onError: (Object e, StackTrace s) {
            if (!pipe.isClosed) pipe.addError(e, s);
          },
          onDone: () {
            if (wire) {
              streamLog.add(
                '${DateTime.now().toUtc().toIso8601String()} #$id DONE '
                '(server ended)',
              );
            }
            if (!pipe.isClosed) unawaited(pipe.close());
          },
        );
      },
      onCancel: () async {
        if (wire) {
          streamLog.add(
            '${DateTime.now().toUtc().toIso8601String()} #$id CANCEL '
            '(app stopped listening)',
          );
        }
        done();
        _oneStreamPipes.remove(pipe);
        await sub?.cancel();
      },
    );
    unawaited(
      pipe.done.whenComplete(() {
        done();
        _oneStreamPipes.remove(pipe);
        unawaited(sub?.cancel());
      }),
    );
    if (one) _oneStreamPipes.add(pipe);
    return http.StreamedResponse(
      pipe.stream,
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest original) async {
    final request =
        lowerConfigCursorOnce &&
            original.url.path == oneStreamPath &&
            original.url.host == apiHost
        ? _lowered(original)
        : original;
    final url = request.url;
    final call = RecordedCall(
      at: DateTime.now(),
      method: request.method,
      path: url.path,
      queryNames: url.queryParameters.keys.toList()..sort(),
    )..zoneId = url.queryParameters['zoneId'];
    if (url.host == apiHost && wired(url.path)) {
      call.wire = wireOf(request);
      final note = identical(request, original)
          ? ''
          : ' (lowered by test; app sent ${wireOf(original)})';
      streamLog.add(
        '${call.at.toUtc().toIso8601String()} REQUEST ${request.method} '
        '${call.wire}$note',
      );
    }
    calls.add(call);
    if (url.host == apiHost) {
      final auth =
          request.headers['Authorization'] ?? request.headers['authorization'];
      if (auth != null && auth.startsWith('Bearer ')) _authorization = auth;
    }
    final watch = Stopwatch()..start();
    http.StreamedResponse response;
    try {
      response = await _inner.send(request);
    } catch (error) {
      if (call.wire != null) {
        streamLog.add(
          '${DateTime.now().toUtc().toIso8601String()} ERROR ${call.wire} '
          '${error.runtimeType}',
        );
      }
      call
        ..error = error.runtimeType.toString()
        ..took = watch.elapsed;
      rethrow;
    }
    call
      ..status = response.statusCode
      ..took = watch.elapsed;
    final type = response.headers['content-type'] ?? '';
    if (url.host == apiHost &&
        response.statusCode == 200 &&
        type.contains('event-stream')) {
      return _watchStream(url.path, response);
    }
    final keep =
        url.host == apiHost &&
        keeps(url.path) &&
        type.contains('json') &&
        (response.contentLength ?? 0) < 1 << 20;
    if (!keep) return response;
    // Read the (small) JSON answer once and hand the app the same bytes.
    final bytes = await response.stream.toBytes();
    try {
      var decoded = jsonDecode(utf8.decode(bytes));
      if (url.path == '/api/v1/driver/config' && decoded is Map) {
        final realtime = decoded['realtime'];
        serverOneStream = realtime is Map ? realtime['oneStream'] : null;
        serverConfigVersion = decoded['version'];
      }
      if (forceOneStream &&
          url.path == '/api/v1/driver/config' &&
          decoded is Map<String, dynamic> &&
          response.statusCode == 200) {
        final realtime = decoded['realtime'];
        decoded = <String, dynamic>{
          ...decoded,
          'realtime': <String, dynamic>{
            if (realtime is Map) ...Map<String, dynamic>.from(realtime),
            'oneStream': true,
          },
        };
        final patched = utf8.encode(jsonEncode(decoded));
        call.answer = decoded;
        lastAnswer[url.path] = decoded;
        final headers = Map<String, String>.from(response.headers)
          ..remove('content-length');
        return http.StreamedResponse(
          Stream<List<int>>.value(patched),
          response.statusCode,
          contentLength: patched.length,
          request: response.request,
          headers: headers,
          isRedirect: response.isRedirect,
          persistentConnection: response.persistentConnection,
          reasonPhrase: response.reasonPhrase,
        );
      }
      call.answer = decoded;
      lastAnswer[url.path] = decoded;
    } catch (_) {
      // Not JSON after all: the app sees it as it came.
    }
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      response.statusCode,
      contentLength: bytes.length,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() => _inner.close();
}

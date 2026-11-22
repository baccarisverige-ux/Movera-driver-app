import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

/// A small HTTP client for the staging API, used by the device tests to
/// play the OTHER side of a trip (the rider while the driver app is on the
/// phone; later the driver while the rider app is on it).
///
/// App-agnostic on purpose (no `package:movera` import): the rider repo
/// can copy this file and check_log.dart as they are (owner 2026-11-12,
/// "the same suite must also run with the RIDER app on the phone").
///
/// Logs one thing only: a line per retried call (see [MoveraApi._send]),
/// with the method, the path and the exception type. Bodies, tokens, phone
/// numbers and codes stay in memory; callers print only statuses, reasons
/// and ids.

/// One answer: status (0 = no answer / timeout) and the decoded body.
class ApiAnswer {
  const ApiAnswer(this.status, this.body, {this.error});

  final int status;
  final Object? body;

  /// The exception type when the call threw (never its message).
  final String? error;

  bool get ok => status >= 200 && status < 300;

  Map<String, dynamic>? get map =>
      body is Map ? Map<String, dynamic>.from(body! as Map) : null;

  /// `reason` (else `code`) of an error answer; safe to print.
  String? get reason {
    final m = map;
    if (m == null) return null;
    final r = m['reason'] ?? m['code'];
    return r is String ? r : null;
  }

  /// "201", "409 invalid_transition", "0 TimeoutException": safe to print.
  String get short =>
      '$status${reason == null ? '' : ' $reason'}${error == null ? '' : ' $error'}';
}

class MoveraApi {
  MoveraApi(
    this.base, {
    http.Client? client,
    this.apiVersion = '0.5',
    this.contractVersion,
    String? Function()? authorization,
    this.retryDelays = const <Duration>[
      Duration(milliseconds: 500),
      Duration(milliseconds: 1500),
    ],
    void Function(String line)? onRetry,
  }) : _client = client ?? http.Client(),
       _authorization = authorization,
       _onRetry = onRetry ?? print;

  /// The waits before the 2nd and 3rd try of a call that got no answer
  /// (see [_send]); its length is the number of extra tries. Empty: none.
  final List<Duration> retryDelays;
  final void Function(String line) _onRetry;

  /// Server root, e.g. https://host (paths below start with /api/v1).
  final Uri base;
  final String apiVersion;

  /// `X-Contract-Version` (the driver app sends it; without it the server
  /// skips the pickup PIN).
  final String? contractVersion;
  final http.Client _client;
  final String? Function()? _authorization;

  /// `Bearer …` of this side after [signIn]; in memory only.
  String? token;

  static final math.Random _random = math.Random.secure();

  /// 32 hex characters (`Idempotency-Key`, `X-Request-Id`).
  static String key() => List<String>.generate(
    32,
    (_) => _random.nextInt(16).toRadixString(16),
  ).join();

  String? get _auth => token ?? _authorization?.call();

  bool get signedIn => _auth != null;

  Map<String, String> _headers({bool write = false}) => <String, String>{
    'Accept': 'application/json',
    'X-Api-Version': apiVersion,
    'X-Request-Id': key(),
    'X-Contract-Version': ?contractVersion,
    if (write) 'Content-Type': 'application/json',
    if (write) 'Idempotency-Key': key(),
    'Authorization': ?_auth,
  };

  Future<ApiAnswer> get(
    String path, {
    Map<String, String>? query,
    Duration timeout = const Duration(seconds: 30),
  }) {
    final headers = _headers();
    return _send(
      'GET',
      path,
      () => _client.get(
        base.replace(path: path, queryParameters: query),
        headers: headers,
      ),
      timeout,
    );
  }

  Future<ApiAnswer> post(
    String path, [
    Object? body,
    Duration timeout = const Duration(seconds: 30),
  ]) {
    // Built once: every try of this call carries the SAME Idempotency-Key
    // (and X-Request-Id), so the server answers a repeated write once.
    final headers = _headers(write: true);
    return _send(
      'POST',
      path,
      () => _client.post(
        base.replace(path: path),
        headers: headers,
        body: jsonEncode(body ?? const <String, Object>{}),
      ),
      timeout,
    );
  }

  /// A connection error: the call threw before any HTTP answer came back
  /// (socket, DNS, TLS, connection closed). A timeout is NOT one: the
  /// server may still be working on the request.
  static bool _noAnswer(Object error) =>
      error is! TimeoutException &&
      (error is http.ClientException || error is IOException);

  /// One call, tried again up to [retryDelays].length more times (2 by
  /// default, after 0.5 s and 1.5 s) when it got NO answer at all (run 47:
  /// one `_ClientSocketException` on the first call failed a whole device
  /// run).
  ///
  /// What is and is not tried again, per call:
  ///  * any real HTTP answer (2xx, 4xx, 429, 5xx): never; it is returned
  ///    and still fails the step;
  ///  * a timeout: never (GET or POST): the call already waited its whole
  ///    limit and the server may still be working on it;
  ///  * every GET (trip, messages, call, config, receipt, history, active
  ///    and scheduled trips): a read, safe to repeat;
  ///  * every POST (quote, book, cancel, sendMessage, answerCall, endCall,
  ///    otp/request, otp/verify): repeated with the SAME Idempotency-Key as
  ///    the first try, and only after a connection error, so a write the
  ///    server did get is not done twice. The two sign-in calls are safe to
  ///    repeat in any case: a second code request only opens a new session
  ///    (its id is read from the answer), and a second verify of a used
  ///    session gets a 4xx, which fails the step as before.
  ///
  /// Each retry prints one line: method, path, try number, exception type.
  Future<ApiAnswer> _send(
    String method,
    String path,
    Future<http.Response> Function() call,
    Duration timeout,
  ) async {
    for (var attempt = 0; ; attempt++) {
      try {
        final response = await call().timeout(timeout);
        Object? body;
        try {
          body = response.body.isEmpty ? null : jsonDecode(response.body);
        } catch (_) {}
        return ApiAnswer(response.statusCode, body);
      } catch (error) {
        final type = error.runtimeType.toString();
        if (attempt >= retryDelays.length || !_noAnswer(error)) {
          return ApiAnswer(0, null, error: type);
        }
        _onRetry(
          'API-RETRY $method $path: no answer ($type), '
          'try ${attempt + 2} of ${retryDelays.length + 1}',
        );
        await Future<void>.delayed(retryDelays[attempt]);
      }
    }
  }

  /// Phone sign-in with a staging test number (no SMS, fixed code).
  /// Null when signed in, else why not (never the number or the code).
  Future<String?> signIn({
    required String phone,
    required String code,
    required String app,
  }) async {
    const slow = Duration(seconds: 70);
    final asked = await post('/api/v1/auth/otp/request', {
      'phone': phone,
      'app': app,
    }, slow);
    final session = asked.map?['sessionId'];
    if (!asked.ok || session is! String) {
      return 'code request ${asked.short}';
    }
    final verified = await post('/api/v1/auth/otp/verify', {
      'phone': phone,
      'sessionId': session,
      'code': code,
    }, slow);
    final access = verified.map?['accessToken'];
    if (!verified.ok || access is! String || access.isEmpty) {
      return 'code verify ${verified.short}';
    }
    token = 'Bearer $access';
    return null;
  }

  void close() => _client.close();

  // ---- the trip, any side (own trip only) --------------------------------

  Future<ApiAnswer> trip(String id) =>
      get('/api/v1/trips/${Uri.encodeComponent(id)}');

  Future<ApiAnswer> cancel(String id, int version, String reasonCode) => post(
    '/api/v1/trips/${Uri.encodeComponent(id)}/cancel',
    {'expectedVersion': version, 'reasonCode': reasonCode},
  );

  Future<ApiAnswer> messages(String id) =>
      get('/api/v1/trips/${Uri.encodeComponent(id)}/messages');

  Future<ApiAnswer> sendMessage(String id, String text) =>
      post('/api/v1/trips/${Uri.encodeComponent(id)}/messages', {'text': text});

  Future<ApiAnswer> answerCall(String callId) =>
      post('/api/v1/calls/${Uri.encodeComponent(callId)}/answer');

  Future<ApiAnswer> endCall(String callId, String reason) => post(
    '/api/v1/calls/${Uri.encodeComponent(callId)}/end',
    {'reason': reason},
  );

  /// `POST /trips/{id}/call`: the caller's side starts a call; a second
  /// one answers 409 call_busy with the live call id in `details`.
  Future<ApiAnswer> call(String id) =>
      post('/api/v1/trips/${Uri.encodeComponent(id)}/call');
}

/// The rider's side of a trip over HTTP.
class RiderApi extends MoveraApi {
  RiderApi(super.base, {super.client});

  Future<ApiAnswer> activeTrip() => get('/api/v1/rider/trips/active');

  Future<ApiAnswer> quote({
    required Map<String, Object> pickup,
    required Map<String, Object> dropoff,
    String paymentMethod = 'cash',
    DateTime? scheduledAt,
  }) => post('/api/v1/quotes', {
    'pickup': pickup,
    'dropoff': dropoff,
    'stops': const <Object>[],
    'kind': scheduledAt == null ? 'live' : 'scheduled',
    'scheduledAt': ?scheduledAt?.toUtc().toIso8601String(),
    'paymentMethod': paymentMethod,
  });

  /// GET /rider/config (booking.minAheadMin and the cancel rules).
  Future<ApiAnswer> config() => get('/api/v1/rider/config');

  Future<ApiAnswer> book(
    Map<String, dynamic> quote, {
    String paymentMethod = 'cash',
    DateTime? scheduledAt,
  }) => post('/api/v1/trips', {
    'quoteId': quote['quoteId'],
    'categoryId': quote['categoryId'],
    'pickup': quote['pickup'],
    'dropoff': quote['dropoff'],
    'stops': quote['stops'] ?? const <Object>[],
    'kind': scheduledAt == null ? 'live' : 'scheduled',
    'scheduledAt': ?scheduledAt?.toUtc().toIso8601String(),
    'paymentMethod': paymentMethod,
    // The whole fare in cash: the cash screen must show the fare itself.
    'walletFirst': false,
  });

  Future<ApiAnswer> receipt(String id) =>
      get('/api/v1/trips/${Uri.encodeComponent(id)}/receipt');

  Future<ApiAnswer> history() =>
      get('/api/v1/rider/trips', query: const {'limit': '20'});

  /// GET /rider/trips?kind=scheduled: the rider's booked-for-later rides
  /// (`/rider/trips/active` lists one only once its driver is driving).
  Future<ApiAnswer> scheduledTrips() => get(
    '/api/v1/rider/trips',
    query: const {'kind': 'scheduled', 'limit': '50'},
  );

  /// Ids of the rider's open (non-terminal) trips the contract lists:
  /// the active trip and the booked rides. Null when a read failed (the
  /// caller must not treat "unknown" as "none").
  Future<Set<String>?> openTripIds() async {
    final active = await activeTrip();
    final booked = await scheduledTrips();
    if ((active.status != 200 && active.status != 204) || !booked.ok) {
      return null;
    }
    bool open(Object? t) =>
        t is Map &&
        t['tripId'] is String &&
        !terminalStatuses.contains(t['status']);
    final items = booked.map?['items'];
    return <String>{
      if (open(active.map)) active.map!['tripId'] as String,
      if (items is List)
        for (final t in items)
          if (open(t)) (t as Map)['tripId'] as String,
    };
  }
}

/// Status groups of contract.json TripStatus.
const Set<String> terminalStatuses = <String>{
  'completed',
  'cancelled_by_rider',
  'cancelled_by_driver',
  'cancelled_by_admin',
  'cancelled_by_system',
  'no_show',
  'expired',
  'failed',
};

/// The rider may cancel (POST /trips/{id}/cancel) up to the arrival.
const Set<String> riderCancellable = <String>{
  'requested',
  'searching',
  'offered',
  'accepted',
  'driver_to_pickup',
  'arrived',
};

const Set<String> onBoardStatuses = <String>{
  'rider_onboard',
  'in_trip',
  'approaching_dropoff',
};

/// Money on the wire (`{amountMinor, currency}`) -> (minor, currency).
(int, String)? moneyOf(Object? json) {
  if (json is! Map) return null;
  final minor = json['amountMinor'];
  final currency = json['currency'];
  if (minor is! num || currency is! String) return null;
  return (minor.toInt(), currency);
}

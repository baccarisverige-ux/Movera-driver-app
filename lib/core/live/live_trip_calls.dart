import 'package:flutter/foundation.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/calls/call_engine.dart';
import 'package:movera/core/calls/trip_call_session.dart';
import 'package:movera/core/calls/webrtc_call_engine.dart';
import 'package:movera/core/logging/driver_log.dart';

/// v0.18.38 §62 (fix job 8, contract.json#inAppCalls; owner G15
/// 2026-11-05 "In-app calls only", "Both rider and driver"): the driver's
/// in-app calls. Holds the one call of this phone ([current]); the trip
/// stream's `call_*` events come in through [receive]; a `call_ringing`
/// for the driver becomes [incoming] (the app shows the incoming-call
/// sheet). No call state is kept on the phone after the call.
class LiveTripCalls implements CallApi {
  LiveTripCalls({required ApiClient api, CallEngine Function()? engine})
    : _api = api,
      _engine = engine ?? WebRtcCallEngine.new;

  final ApiClient _api;
  final CallEngine Function() _engine;
  static const _side = 'driver';

  /// The call on this phone now (outgoing, ringing or connected).
  TripCallSession? current;

  /// A rider's call waiting for Answer / Decline.
  final ValueNotifier<TripCallSession?> incoming = ValueNotifier(null);

  /// Shows the incoming-call sheet (main.dart sets it).
  void Function(TripCallSession session)? onIncoming;

  @override
  Future<Map<String, dynamic>> start(String tripId) =>
      _api.post('/api/v1/trips/${Uri.encodeComponent(tripId)}/call');

  @override
  Future<Map<String, dynamic>> answer(String callId) =>
      _api.post('/api/v1/calls/${Uri.encodeComponent(callId)}/answer');

  @override
  Future<void> end(String callId, String reason) => _api.post(
    '/api/v1/calls/${Uri.encodeComponent(callId)}/end',
    body: {'reason': reason},
  );

  @override
  Future<void> signal(String callId, Map<String, dynamic> body) => _api.post(
    '/api/v1/calls/${Uri.encodeComponent(callId)}/signal',
    body: body,
  );

  /// A new outgoing call to the rider of [tripId].
  TripCallSession outgoing(String tripId) {
    final session = TripCallSession.outgoing(
      api: this,
      engine: _engine(),
      tripId: tripId,
      side: _side,
    );
    _hold(session);
    return session;
  }

  void _hold(TripCallSession session) {
    current = session;
    session.addListener(() {
      if (session.over && identical(current, session)) current = null;
      if (session.over && identical(incoming.value, session)) {
        incoming.value = null;
      }
    });
  }

  /// A `call_*` event of a trip stream.
  void receive(String tripId, String kind, Map<String, dynamic> payload) {
    final now = current;
    if (now != null && !now.over) {
      if (payload['callId'] == now.callId) {
        now.receive(kind, payload);
        return;
      }
      // Busy with another call: the server keeps one live call per trip;
      // a second trip's ring is declined.
      if (kind == 'call_ringing' && payload['to'] == _side) {
        final id = payload['callId'];
        if (id is String) end(id, 'declined').catchError((Object _) {});
      }
      return;
    }
    if (kind != 'call_ringing' || payload['to'] != _side) return;
    try {
      final session = TripCallSession.incoming(
        api: this,
        engine: _engine(),
        call: IncomingCall.fromJson(payload),
        side: _side,
        ice: const [],
      );
      _hold(session);
      incoming.value = session;
      onIncoming?.call(session);
    } on TypeError {
      DriverLog.warn('call event unreadable', name: 'live');
    }
  }
}

import 'package:flutter/material.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/calls/call_engine.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/live/live_trip_calls.dart';
import 'package:movera/core/live/live_trip_chat.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:movera/presentation/common/chat/call_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the dialer with a number. A seam so tests never dial.
typedef TripCallDialer = Future<bool> Function(Uri uri);

Future<bool> _launchDialer(Uri uri) => launchUrl(uri);

/// Calls the rider. v0.18.38 §62 (fix job 8, owner G15 2026-11-05 "In-app
/// calls only", "Just 'Call failed'"): `POST /trips/{tripId}/call` answers
/// `mode: in_app` and the in-app call screen opens (WebRTC). Only when the
/// country runs calls through a phone company (`mode: phone`, contract
/// v0.13.0) the dialer opens with the masked `proxyNumber`. A call that
/// cannot start says only "Call failed". The rider's real number is never
/// asked for or shown.
Future<void> callRider(
  BuildContext context, {
  required String? tripId,
  LiveTripChat? chat,
  LiveTripCalls? calls,
  CallEngine Function()? engine,
  String? riderName,
  TripCallDialer dial = _launchDialer,
  SnackBar Function(String text)? snackBar,
  void Function(String text)? onSay,
}) async {
  final live = chat ?? LiveDriverServices.instance?.chat;
  final hub =
      calls ??
      (engine == null ? LiveDriverServices.instance?.calls : null) ??
      (live == null ? null : LiveTripCalls(api: live.api, engine: engine));
  final messenger = ScaffoldMessenger.maybeOf(context);
  // In Chat the text shows above the write field ([onSay]) so it never
  // covers the field or the send button (G9 live 2026-11-02).
  void say(String text) {
    if (onSay != null) return onSay(text);
    messenger?.showSnackBar(
      snackBar?.call(text) ?? SnackBar(content: Text(text)),
    );
  }

  if (hub == null || tripId == null || tripId.isEmpty) {
    say(tr.callFailed);
    return;
  }
  final Map<String, dynamic> answer;
  try {
    answer = await hub.start(tripId);
  } catch (error) {
    DriverLog.warn('trip call failed: $error', name: 'live');
    // An older server closed calls with the chat at drop-off.
    if (error is ApiError && error.reason == 'chat_closed') {
      live?.markClosed(tripId);
      say(tr.chatClosedAfterTrip);
      return;
    }
    say(tr.callFailed);
    return;
  }
  final proxy = answer['proxyNumber'];
  if (answer['mode'] != 'in_app' && proxy is String) {
    await dial(Uri(scheme: 'tel', path: proxy));
    return;
  }
  final session = hub.outgoing(tripId);
  await session.begin(answer);
  if (!context.mounted) return;
  await TripCallScreen.open(context, session, name: riderName);
}

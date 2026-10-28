import 'package:flutter/material.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/live/live_trip_chat.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the dialer with a number. A seam so tests never dial.
typedef TripCallDialer = Future<bool> Function(Uri uri);

Future<bool> _launchDialer(Uri uri) => launchUrl(uri);

/// Calls the rider through the trip's masked number (contract v0.13.0
/// §22): `POST /trips/{tripId}/call`, then the dialer with the
/// `proxyNumber`. The rider's real number is never asked for or shown.
/// Without a provider (`503 call_unavailable`, today) or in the demo the
/// driver is told to use the chat; after drop-off (`409 chat_closed`) the
/// chat is closed.
Future<void> callRider(
  BuildContext context, {
  required String? tripId,
  LiveTripChat? chat,
  TripCallDialer dial = _launchDialer,
  SnackBar Function(String text)? snackBar,
}) async {
  final live = chat ?? LiveDriverServices.instance?.chat;
  final messenger = ScaffoldMessenger.maybeOf(context);
  void say(String text) => messenger?.showSnackBar(
    snackBar?.call(text) ?? SnackBar(content: Text(text)),
  );
  if (live == null || tripId == null || tripId.isEmpty) {
    say(tr.callUnavailableUseChat);
    return;
  }
  try {
    final number = await live.call(tripId);
    await dial(Uri(scheme: 'tel', path: number));
  } catch (error) {
    DriverLog.warn('trip call failed: $error', name: 'live');
    if (error is ApiError && error.reason == 'chat_closed') {
      say(tr.chatClosedAfterTrip);
      return;
    }
    say(tr.callUnavailableUseChat);
  }
}

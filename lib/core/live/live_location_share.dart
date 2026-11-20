import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/geo/geo_point.dart';

/// Contract v0.18.144 (`contract.json#liveLocation`, owner 2026-11-20 "on
/// driver app on map he can see the rider prescise location when rider
/// share his location"): the rider's live point from the trip stream's
/// `event: live_location` frame (no id). In memory only, never stored.
class RiderLiveDot {
  const RiderLiveDot({
    required this.tripId,
    required this.point,
    required this.at,
    this.accuracyM,
  });

  final String tripId;
  final GeoPoint point;
  final double? accuracyM;
  final DateTime at;
}

abstract final class LiveLocationHub {
  /// The rider's latest live point; null when the rider is not sharing.
  static final ValueNotifier<RiderLiveDot?> riderDot =
      ValueNotifier<RiderLiveDot?>(null);

  /// The rider's first name for the map label (set by the trip card).
  static String riderLabel = '';

  /// A point older than this is gone (3 × the 8 s send).
  static const staleAfter = Duration(seconds: 24);

  /// True when [json] was a live frame (then it is not a trip event).
  static bool offer(Map<String, dynamic> json, {DateTime? now}) {
    if (json.containsKey('eventId') || json.containsKey('sequence')) {
      return false;
    }
    final tripId = json['tripId'];
    final side = json['side'];
    final sharing = json['sharing'];
    if (tripId is! String ||
        (side != 'rider' && side != 'driver') ||
        sharing is! bool) {
      return false;
    }
    // The driver's own point echo: ignored here.
    if (side != 'rider') return true;
    final lat = json['lat'];
    final lng = json['lng'];
    if (!sharing || lat is! num || lng is! num) {
      riderDot.value = null;
      return true;
    }
    final accuracy = json['accuracyM'];
    riderDot.value = RiderLiveDot(
      tripId: tripId,
      point: GeoPoint(lat.toDouble(), lng.toDouble()),
      accuracyM: accuracy is num ? accuracy.toDouble() : null,
      at: now ?? DateTime.now(),
    );
    return true;
  }

  /// The trip ended or the screen closed: forget the point.
  static void clear() => riderDot.value = null;

  /// The fresh point of [tripId], or null.
  static RiderLiveDot? freshFor(String? tripId, {DateTime? now}) {
    final dot = riderDot.value;
    if (dot == null || dot.tripId != tripId) return null;
    return (now ?? DateTime.now()).difference(dot.at) > staleAfter ? null : dot;
  }
}

enum LiveShareStop { zoneOff, rideOver }

/// The driver's "Share my location" switch: `PUT /trips/{tripId}/
/// live-location` every [every] (5–10 s) only while the trip screen is open.
class LiveLocationSender {
  LiveLocationSender({
    required ApiClient api,
    required this.tripId,
    required this.position,
    this.every = const Duration(seconds: 8),
    this.onStopped,
  }) : _api = api;

  final ApiClient _api;
  final String tripId;
  final Duration every;
  final GeoPoint? Function() position;
  final void Function(LiveShareStop why)? onStopped;
  Timer? _timer;
  bool _sending = false;

  bool get running => _timer != null;
  String get _path =>
      '/api/v1/trips/${Uri.encodeComponent(tripId)}/live-location';

  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(every, (_) => unawaited(tick()));
    unawaited(tick());
  }

  Future<void> stop({bool tellServer = true}) async {
    final was = _timer != null;
    _timer?.cancel();
    _timer = null;
    if (!was || !tellServer) return;
    try {
      await _api.put(_path, body: {'sharing': false});
    } catch (_) {
      // The rider drops a point older than 3 × every anyway.
    }
  }

  Future<void> tick() async {
    if (_sending || _timer == null) return;
    final at = position();
    if (at == null) return;
    _sending = true;
    try {
      await _api.put(
        _path,
        body: {'sharing': true, 'lat': at.latitude, 'lng': at.longitude},
      );
    } on ApiError catch (error) {
      final stop = switch (error.reason) {
        'live_location_off' => LiveShareStop.zoneOff,
        'live_location_not_active' => LiveShareStop.rideOver,
        _ => null,
      };
      if (stop != null) {
        await this.stop(tellServer: false);
        onStopped?.call(stop);
      }
    } catch (_) {
      // Network: the next tick tries again.
    } finally {
      _sending = false;
    }
  }
}

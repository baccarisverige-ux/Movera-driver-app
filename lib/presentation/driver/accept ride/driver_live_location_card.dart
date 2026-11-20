import 'dart:async';

import 'package:flutter/material.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_location_share.dart';

/// Contract v0.18.144 (owner 2026-11-20; approved mockup screen 8): on the
/// way to the pickup the driver's "Share my location" switch (default on
/// once the zone allows it) and "Sara is sharing her location (12 m from
/// pickup)" while the rider shares. Lives only while the trip screen shows
/// it; sharing stops with it.
class DriverLiveLocationCard extends StatefulWidget {
  const DriverLiveLocationCard({
    super.key,
    required this.api,
    required this.tripId,
    required this.riderName,
    required this.pickup,
    required this.position,
    this.every = const Duration(seconds: 8),
  });

  final ApiClient api;
  final String tripId;
  final String riderName;
  final GeoPoint pickup;
  final GeoPoint? Function() position;
  final Duration every;

  @override
  State<DriverLiveLocationCard> createState() => _DriverLiveLocationCardState();
}

class _DriverLiveLocationCardState extends State<DriverLiveLocationCard> {
  /// null until the server said whether the zone allows sharing.
  bool? _allowed;
  bool _sharing = false;
  LiveLocationSender? _sender;
  Timer? _fresh;

  @override
  void initState() {
    super.initState();
    LiveLocationHub.riderLabel = widget.riderName.split(' ').first;
    unawaited(_probe());
    // Re-draw so a point that went stale disappears.
    _fresh = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) setState(() {});
    });
  }

  /// One `sharing: false` tells whether the zone's switch is on (200) or
  /// off (409 live_location_off), without sending a point.
  Future<void> _probe() async {
    try {
      await widget.api.put(
        '/api/v1/trips/${Uri.encodeComponent(widget.tripId)}/live-location',
        body: {'sharing': false},
      );
      if (!mounted) return;
      setState(() => _allowed = true);
      _set(true);
    } on ApiError catch (_) {
      if (mounted) setState(() => _allowed = false);
    } catch (_) {
      // No answer: the card stays hidden on this screen.
    }
  }

  void _set(bool on) {
    if (on) {
      _sender = LiveLocationSender(
        api: widget.api,
        tripId: widget.tripId,
        every: widget.every,
        position: widget.position,
        onStopped: (why) {
          if (!mounted) return;
          setState(() {
            _sharing = false;
            if (why == LiveShareStop.zoneOff) _allowed = false;
          });
        },
      )..start();
    } else {
      final sender = _sender;
      _sender = null;
      unawaited(sender?.stop());
    }
    setState(() => _sharing = on);
  }

  @override
  void dispose() {
    _fresh?.cancel();
    unawaited(_sender?.stop());
    LiveLocationHub.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_allowed != true) return const SizedBox.shrink();
    final first = widget.riderName.split(' ').first;
    return Padding(
      key: const ValueKey<String>('driver-live-location-card'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ValueListenableBuilder<RiderLiveDot?>(
            valueListenable: LiveLocationHub.riderDot,
            builder: (context, _, __) {
              final dot = LiveLocationHub.freshFor(widget.tripId);
              if (dot == null) return const SizedBox.shrink();
              final meters = dot.point.distanceMetersTo(widget.pickup).round();
              return Container(
                key: const ValueKey<String>('rider-sharing-banner'),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5EC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.circle,
                      size: 10,
                      color: Color(0xFF1E9E53),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(tr.liveRiderSharing(first, '$meters')),
                    ),
                  ],
                ),
              );
            },
          ),
          Row(
            children: [
              const Icon(Icons.my_location_rounded, color: Color(0xFF2D5878)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr.liveShareSwitch,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      tr.liveDriverShareBody(first),
                      style: const TextStyle(color: Color(0xFF5C656C)),
                    ),
                    Text(
                      tr.liveDriverPrivacyNote,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6E777F),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                key: const ValueKey<String>('driver-share-location-switch'),
                value: _sharing,
                onChanged: _set,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

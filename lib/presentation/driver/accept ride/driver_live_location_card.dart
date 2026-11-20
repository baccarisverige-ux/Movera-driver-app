import 'dart:async';

import 'package:flutter/material.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_location_share.dart';

/// Contract v0.18.144 (owner 2026-11-20; approved mockup screen 8): on the
/// way to the pickup the driver's opt-in "Share my location" switch (starts
/// off; the driver taps it) and "Sara is sharing her location (12 m from
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
  });

  final ApiClient api;
  final String tripId;
  final String riderName;
  final GeoPoint pickup;
  final GeoPoint? Function() position;

  @override
  State<DriverLiveLocationCard> createState() => _DriverLiveLocationCardState();
}

class _DriverLiveLocationCardState extends State<DriverLiveLocationCard>
    with WidgetsBindingObserver {
  /// null until the server said whether the zone allows sharing.
  bool? _allowed;
  bool _sharing = false;
  LiveLocationSender? _sender;
  Timer? _fresh;
  Timer? _again;

  /// The zone's `liveLocation.sendEverySeconds` from the probe's answer.
  Duration _every = const Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LiveLocationHub.riderLabel = widget.riderName.split(' ').first;
    unawaited(_probe());
    // Re-draw so a point that went stale disappears.
    _fresh = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) setState(() {});
    });
  }

  /// One `sharing: false` tells whether the zone's switch is on (200) or
  /// off (409), without sending a point. The switch then starts OFF: the
  /// driver opts in himself (decision: "opt-in by each person"). A 429,
  /// 5xx or no answer asks again in 30 s; only a 409 hides the card.
  Future<void> _probe() async {
    try {
      final answer = await widget.api.put(
        '/api/v1/trips/${Uri.encodeComponent(widget.tripId)}/live-location',
        body: {'sharing': false},
      );
      if (!mounted) return;
      final every = answer['sendEverySeconds'];
      setState(() {
        _allowed = true;
        if (every is int && every >= 5 && every <= 10) {
          _every = Duration(seconds: every);
        }
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      if (error.statusCode == 409) {
        setState(() => _allowed = false);
      } else {
        _retryProbe();
      }
    } catch (_) {
      if (mounted) _retryProbe();
    }
  }

  void _retryProbe() {
    _again?.cancel();
    _again = Timer(const Duration(seconds: 30), () => unawaited(_probe()));
  }

  void _set(bool on) {
    if (on) {
      _sender = LiveLocationSender(
        api: widget.api,
        tripId: widget.tripId,
        every: _every,
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

  /// Hidden, paused or closed: sharing stops and the switch shows off; it
  /// comes back only when the driver taps it again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final away =
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
    if (away && (_sharing || _sender != null)) _set(false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fresh?.cancel();
    _again?.cancel();
    unawaited(_sender?.stop());
    if (LiveLocationHub.riderDot.value?.tripId == widget.tripId) {
      LiveLocationHub.clear();
    }
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

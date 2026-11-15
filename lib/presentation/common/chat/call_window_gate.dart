import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:movera/core/live/live_driver_services.dart';

/// v0.18.113 BQ-S13 (owner 2026-11-01 "Keep call open for 1 hour but not
/// chat", Rules decisions/driver-g9.md:38; contract.json#inAppCalls.
/// callOpenUntil): a finished trip shows its call button until the
/// server's `TripProjection.callOpenUntil` (drop-off + the country's
/// "Call window after the trip", default 60 min) and hides it by itself
/// when that passes. The trip is read once (`GET /trips/{tripId}`); no
/// `callOpenUntil` (calls off, no live build, a failed read) → no button.
/// Chat stays closed.
class CallWindowGate extends StatefulWidget {
  const CallWindowGate({super.key, required this.tripId, required this.child});

  final String tripId;
  final Widget child;

  @override
  State<CallWindowGate> createState() => _CallWindowGateState();
}

class _CallWindowGateState extends State<CallWindowGate> {
  bool _open = false;
  Timer? _close;

  @override
  void initState() {
    super.initState();
    unawaited(_read());
  }

  Future<void> _read() async {
    final api = LiveDriverServices.instance?.api;
    if (api == null) return;
    DateTime? until;
    try {
      final trip = await api.get(
        '/api/v1/trips/${Uri.encodeComponent(widget.tripId)}',
      );
      until = DateTime.tryParse('${trip['callOpenUntil']}');
    } catch (_) {}
    final left = until?.difference(DateTime.now());
    if (!mounted || left == null || left.isNegative) return;
    setState(() => _open = true);
    _close = Timer(left, () {
      if (mounted) setState(() => _open = false);
    });
  }

  @override
  void dispose() {
    _close?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _open ? widget.child : const SizedBox.shrink();
}

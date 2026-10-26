import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:movera/core/geo/geo_point.dart';

class LiveVehiclePose {
  const LiveVehiclePose({required this.position, required this.headingDegrees});

  final LatLng position;
  final double headingDegrees;
}

/// Smoothly interpolates the on-map car between GPS samples.
class LiveVehicleAnimator {
  LiveVehicleAnimator({
    required TickerProvider vsync,
    LiveVehiclePose? initial,
    this.reduceMotion,
  }) : pose = ValueNotifier<LiveVehiclePose>(
         initial ??
             const LiveVehiclePose(
               position: LatLng(59.3262, 18.0595),
               headingDegrees: 0,
             ),
       ),
       _controller = AnimationController(
         vsync: vsync,
         duration: const Duration(milliseconds: 320),
       ) {
    _from = pose.value;
    _to = pose.value;
    _controller.addListener(_handleTick);
  }

  final bool Function()? reduceMotion;
  final ValueNotifier<LiveVehiclePose> pose;
  final AnimationController _controller;
  late LiveVehiclePose _from;
  late LiveVehiclePose _to;
  bool _hasPose = false;

  LiveVehiclePose get current => pose.value;

  void snapTo(LatLng target, double headingDegrees) {
    _controller.stop();
    _hasPose = true;
    final next = LiveVehiclePose(
      position: target,
      headingDegrees: headingDegrees,
    );
    _from = next;
    _to = next;
    pose.value = next;
  }

  void moveTo(LatLng target, double headingDegrees) {
    if (!_hasPose || reduceMotion?.call() == true) {
      snapTo(target, headingDegrees);
      return;
    }
    _from = pose.value;
    _to = LiveVehiclePose(position: target, headingDegrees: headingDegrees);
    _controller.forward(from: 0);
  }

  void _handleTick() {
    final t = Curves.easeOutCubic.transform(_controller.value.clamp(0.0, 1.0));
    final from = _from.position;
    final to = _to.position;
    pose.value = LiveVehiclePose(
      position: LatLng(
        from.latitude + (to.latitude - from.latitude) * t,
        from.longitude + (to.longitude - from.longitude) * t,
      ),
      headingDegrees: GeoPoint.shortestAngleLerp(
        _from.headingDegrees,
        _to.headingDegrees,
        t,
      ),
    );
  }

  void dispose() {
    _controller.dispose();
    pose.dispose();
  }
}

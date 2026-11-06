part of 'scheduled_rides.dart';

// Base job B8 (2026-11-04): moved word for word out of scheduled_rides.dart
// (no behaviour change).

class _ScheduledRideCard extends StatelessWidget {
  const _ScheduledRideCard({
    required this.ride,
    required this.onTap,
    this.claiming = false,
  });

  final _ScheduledRide ride;
  final VoidCallback? onTap;

  /// Its claim is with the server: tr.islandMatching until the answer comes.
  final bool claiming;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 14, 13),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              ride.price,
                              style: const TextStyle(
                                color: Color(0xFF252E3A),
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            // Owner 2026-11-03: a booked ride always
                            // shows its badge, here too.
                            OfferBadge.reservation(
                              RegExp(
                                r'\d{1,2}:\d{2}',
                              ).firstMatch(ride.time)?.group(0),
                              key: ValueKey<String>(
                                'scheduled-booked-${ride.pickup}',
                              ),
                            ),
                            // Admin raised the fare; the price has it.
                            if (ride.route?.fareBoost case final boost?)
                              OfferBadge.boost(
                                boost,
                                key: ValueKey<String>(
                                  'scheduled-boost-${ride.pickup}',
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (claiming)
                        Row(
                          key: ValueKey<String>('scheduled-ride-matching'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.6,
                                color: Color(0xFF4E5A61),
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              tr.islandMatching,
                              style: TextStyle(
                                color: Color(0xFF4E5A61),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        )
                      else
                        _solar(
                          AppAssets.solarAltArrowRight,
                          const Color(0xFFA3ADB2),
                          18,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _solar(
                        AppAssets.solarClockCircle,
                        const Color(0xFF19865C),
                        17,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          ride.when,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF4E5A61),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Flexible(
                        child: _RideMeta(
                          icon: AppAssets.solarCar,
                          label: categoryNameText(ride.category),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: _RideMeta(
                          icon: AppAssets.solarRoute,
                          label: ride.distance,
                        ),
                      ),
                      if (ride.assigned) ...[
                        const SizedBox(width: 12),
                        Flexible(
                          child: _RideMeta(
                            icon: AppAssets.solarBolt,
                            label: tr.assignedByMovera,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            _RoutePreview(accepted: ride.accepted),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 17),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Column(
                      children: [
                        Container(
                          height: 14,
                          width: 14,
                          margin: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF2FBE7B),
                              width: 3,
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 27,
                          child: VerticalDivider(
                            color: Color(0xFFCAD2D6),
                            thickness: 1.4,
                          ),
                        ),
                        _solar(
                          AppAssets.solarMapPoint,
                          const Color(0xFFDF5A62),
                          18,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ride.pickup,
                          style: const TextStyle(
                            color: Color(0xFF344047),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          ride.destination,
                          style: const TextStyle(
                            color: Color(0xFF344047),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RideMeta extends StatelessWidget {
  const _RideMeta({required this.icon, required this.label});

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _solar(icon, const Color(0xFF89949B), 15),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF89949B),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _RoutePreview extends StatelessWidget {
  const _RoutePreview({required this.accepted});

  final bool accepted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      width: double.infinity,
      child: CustomPaint(
        painter: _RoutePreviewPainter(accepted: accepted),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: accepted
                  ? const Color(0xFF252E3A)
                  : const Color(0xFF19865C),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1A2730).withValues(alpha: 0.16),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              accepted ? tr.schedAcceptedBadge : tr.scheduled,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoutePreviewPainter extends CustomPainter {
  const _RoutePreviewPainter({required this.accepted});

  final bool accepted;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Movera map colours (MoveraMapPalette): near-white land, grey blocks,
    // a park with a path, water in the corner, grey streets and one darker
    // highway.
    canvas.drawRect(Offset.zero & size, Paint()..color = MoveraMapPalette.land);
    final blocks = Paint()..color = MoveraMapPalette.building;
    for (final block in [
      Rect.fromLTWH(w * 0.03, h * 0.42, w * 0.1, h * 0.18),
      Rect.fromLTWH(w * 0.42, h * 0.12, w * 0.1, h * 0.16),
      Rect.fromLTWH(w * 0.66, h * 0.6, w * 0.12, h * 0.2),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(block, const Radius.circular(2)),
        blocks,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.42, h * 0.56, w * 0.2, h * 0.5),
        const Radius.circular(10),
      ),
      Paint()..color = MoveraMapPalette.park,
    );
    canvas.drawLine(
      Offset(w * 0.45, h * 0.62),
      Offset(w * 0.6, h * 0.98),
      MoveraMapPalette.footpath(1.5),
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.86, -2)
        ..quadraticBezierTo(w * 0.9, h * 0.45, w + 2, h * 0.62)
        ..lineTo(w + 2, -2)
        ..close(),
      Paint()..color = MoveraMapPalette.water,
    );

    final street = MoveraMapPalette.street(3);
    canvas
      ..drawLine(Offset(w * 0.18, -5), Offset(w * 0.36, h + 5), street)
      ..drawLine(Offset(w * 0.72, -5), Offset(w * 0.58, h + 5), street)
      ..drawLine(
        Offset(-5, h * 0.72),
        Offset(w + 5, h * 0.88),
        MoveraMapPalette.mainStreet(3),
      );
    MoveraMapPalette.drawHighway(
      canvas,
      Path()
        ..moveTo(-10, h * 0.28)
        ..quadraticBezierTo(w * 0.28, h * 0.05, w * 0.58, h * 0.38)
        ..quadraticBezierTo(w * 0.78, h * 0.58, w + 12, h * 0.22),
      4,
    );

    final pickup = Offset(w * 0.19, h * 0.70);
    final dropoff = Offset(w * 0.82, h * 0.31);
    DriverRouteStyle.paintOn(
      canvas,
      Path()
        ..moveTo(pickup.dx, pickup.dy)
        ..cubicTo(
          w * 0.30,
          h * 0.22,
          w * 0.64,
          h * 0.82,
          dropoff.dx,
          dropoff.dy,
        ),
    );
    RouteMarkPins.paintMark(canvas, pickup, RouteMarkKind.pickup);
    RouteMarkPins.paintMark(canvas, dropoff, RouteMarkKind.dropoff);
  }

  @override
  bool shouldRepaint(covariant _RoutePreviewPainter oldDelegate) {
    return oldDelegate.accepted != accepted;
  }
}

class _ScheduledRide {
  const _ScheduledRide({
    required this.price,
    required this.time,
    required this.category,
    this.fixedDistance,
    required this.pickup,
    required this.destination,
    this.accepted = false,
    this.assigned = false,
    this.route,
    this.window,
  });

  /// An accepted ride built from its route details. Its price is the
  /// driver's share of the fare (owner decision 2026-10-26).
  factory _ScheduledRide.fromRoute(
    ReservationRequestPreview route, {
    bool assigned = false,
  }) => _ScheduledRide(
    price: route.driverPayLabel,
    time: _timeOf(route, ReservationWhen.dayWord(route.pickupDay), null),
    category: route.category,
    pickup: route.pickupAddress,
    destination: route.dropoffAddress,
    accepted: true,
    assigned: assigned,
    route: route,
  );

  /// An open request: "Today, 07:40–07:45", its pickup [window].
  factory _ScheduledRide.request(
    ReservationRequestPreview route, {
    Duration window = const Duration(minutes: 5),
    String? distance,
  }) {
    return _ScheduledRide(
      price: route.driverPayLabel,
      time: _timeOf(route, ReservationWhen.dayWord(route.pickupDay), window),
      window: window,
      category: route.category,
      fixedDistance: distance,
      pickup: route.pickupAddress,
      destination: route.dropoffAddress,
      route: route,
    );
  }

  /// "Today, 07:40", with the pickup [window] when there is one:
  /// "Today, 07:40–07:45".
  static String _timeOf(
    ReservationRequestPreview route,
    String day,
    Duration? window,
  ) {
    final start = route.minuteOfDay;
    final time = tr.schedSeedTime(day, route.pickupTime);
    if (start == null || window == null) {
      return time;
    }
    final end = (start + window.inMinutes) % (24 * 60);
    String two(int v) => v.toString().padLeft(2, '0');
    return '$time–${two(end ~/ 60)}:${two(end % 60)}';
  }

  /// Movera assigned it to this driver (Q29).
  final bool assigned;

  final String price;

  /// The card's time as written when the ride was booked; see [when].
  final String time;

  /// The pickup window of an open request, else null.
  final Duration? window;

  /// The card's time seen now, in the driver's language now
  /// (driver-u145): a ride booked for a date says "Today" once its
  /// "Tomorrow" has come (driver-u142).
  String get when {
    final route = this.route;
    if (route == null) {
      return time;
    }
    final day = route.scheduledAt == null
        ? route.pickupDay
        : route.pickupDayAt(ScheduledRideStore._now);
    return _timeOf(route, ReservationWhen.dayWord(day), window);
  }

  final String category;

  /// A distance given as text ("12 km"); null: the route's.
  final String? fixedDistance;

  /// "9.4 km" ("9,4 km" in French and Swedish), written when shown.
  String get distance =>
      fixedDistance ?? (route == null ? '' : driverDistanceKm(route!.tripKm));
  final String pickup;
  final String destination;
  final bool accepted;

  /// Route details for the full route screen, when known.
  final ReservationRequestPreview? route;

  /// Dispatch id of an open reservation; empty for a sample ride.
  String get id => route?.id ?? '';

  _ScheduledRide copyWith({bool? accepted, String? price}) {
    return _ScheduledRide(
      price: price ?? this.price,
      time: time,
      category: category,
      fixedDistance: fixedDistance,
      pickup: pickup,
      destination: destination,
      accepted: accepted ?? this.accepted,
      assigned: assigned,
      route: route,
      window: window,
    );
  }
}

enum _ScheduledRideAction { accepted, cancelled }

part of 'scheduled_rides.dart';

// Base job B8 (2026-11-04): moved word for word out of scheduled_rides.dart
// (no behaviour change).

class _ScheduledRideDetailsScreen extends StatelessWidget {
  const _ScheduledRideDetailsScreen({required this.ride});

  final _ScheduledRide ride;

  static const _ink = Color(0xFF252E3A);
  static const _muted = Color(0xFF7F8A91);
  static const _surface = Color(0xFFF3F5F6);
  static const _green = Color(0xFF19865C);
  static const _red = Color(0xFFC84E58);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: tr.back,
          onPressed: () => _popScheduledRoute<void>(context),
          icon: _solar(AppAssets.solarArrowLeft, _ink, 24),
        ),
        titleSpacing: 0,
        title: Text(
          ride.accepted && ride.id.isEmpty
              ? tr.schedSampleReservation
              : tr.schedReservationDetails,
          style: const TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                children: [
                  if (ScheduledRideStore.serverRow(ride.id) case final row?
                      when row.asksToKeep) ...[
                    _KeepCard(ride: row),
                    const SizedBox(height: 14),
                  ],
                  if (ScheduledRideStore.serverRow(ride.id) case final row?
                      when row.accepted && row.leaveAt != null) ...[
                    LeaveCountdown(
                      leaveAt: row.leaveAt!,
                      pickupAt: row.scheduledAt,
                      // What the server planned: pickup − drive − leaveAt.
                      earlyMin:
                          (row.scheduledAt.difference(row.leaveAt!).inSeconds -
                              (row.driveSeconds ?? 0)) ~/
                          60,
                    ),
                    const SizedBox(height: 14),
                  ],
                  _buildHero(),
                  const SizedBox(height: 14),
                  _buildRouteMap(context),
                  const SizedBox(height: 14),
                  _buildRouteCard(),
                  const SizedBox(height: 14),
                  _buildPlanCard(),
                  if (ride.accepted) ...[
                    const SizedBox(height: 14),
                    _buildCommitmentCard(),
                  ],
                ],
              ),
            ),
            _buildBottomAction(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteMap(BuildContext context) {
    final route = ride.route;
    // Live test 2026-11-03 HIGH 3: a real booking shows the real map with
    // its road route (the same map as the Home popup and the route screen),
    // never the illustrated sample.
    if (route != null && ride.id.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          key: const ValueKey<String>('scheduled-details-real-map'),
          height: 220 * MediaQuery.textScalerOf(context).scale(11) / 11,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _RealReservationMap(request: route),
              // Tapping the map opens the same full route screen as the
              // Home reservation popup (notes R26), as before.
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: Semantics(
                    label: tr.schedViewRoute,
                    button: true,
                    child: InkWell(
                      key: const ValueKey<String>('scheduled-route-open'),
                      onTap: () => openReservationRoute(context, route),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 176 * MediaQuery.textScalerOf(context).scale(11) / 11,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _RoutePreviewPainter(accepted: ride.accepted)),
            Positioned(
              left: 14,
              right: 66,
              top: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1A2730).withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _solar(AppAssets.solarRoute, _green, 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        tr.schedIllustrativeRoute,
                        style: TextStyle(
                          color: _ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 14,
              top: 14,
              child: Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1A2730).withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: _solar(AppAssets.solarGps, _ink, 19),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 13,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF24333A).withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    Container(
                      height: 8,
                      width: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF35C487),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        ride.pickup,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _solar(
                        AppAssets.solarArrowRight,
                        const Color(0xFFB9C4C8),
                        14,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        ride.destination,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Container(
                      height: 8,
                      width: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDF5A62),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 14,
              bottom: 61,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${ride.distance} • ${categoryNameText(ride.category)}',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            // Tapping the map opens the same full route screen as the Home
            // reservation popup (notes R26).
            if (route != null)
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: Semantics(
                    label: tr.schedViewRoute,
                    button: true,
                    child: InkWell(
                      key: const ValueKey<String>('scheduled-route-open'),
                      onTap: () => openReservationRoute(context, route),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: ride.accepted
                                  ? const Color(0xFFE9F4EF)
                                  : const Color(0xFFF0F2F3),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _solar(
                                  ride.accepted
                                      ? AppAssets.solarCheckCircle
                                      : AppAssets.solarClockCircle,
                                  ride.accepted ? _green : _muted,
                                  15,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    ride.accepted
                                        ? (ride.id.isEmpty
                                              ? tr.schedDemoAccepted
                                              : tr.schedAcceptedBadge)
                                        : tr.schedAvailable,
                                    style: TextStyle(
                                      color: ride.accepted ? _green : _muted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          ride.price,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 31,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        if (ride.route?.fareBoost case final boost?)
                          OfferBadge.boost(boost),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      ride.when,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F3),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: _solar(AppAssets.solarCalendarMark, _green, 27),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFFE9ECEE)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _DetailMetric(
                  icon: AppAssets.solarCar,
                  label: tr.rideTypeLabel,
                  value: ride.category,
                ),
              ),
              Container(height: 34, width: 1, color: const Color(0xFFE5E9EB)),
              Expanded(
                child: _DetailMetric(
                  icon: AppAssets.solarRoute,
                  label: tr.trip2,
                  value: ride.distance,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr.route,
            style: TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    Container(
                      height: 14,
                      width: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _green, width: 3),
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 58,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8DEE1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    _solar(
                      AppAssets.solarMapPoint,
                      const Color(0xFFDF5A62),
                      19,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr.pickup,
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ride.pickup,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 27),
                    Text(
                      tr.dropOff,
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ride.destination,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF26343A),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ride.accepted ? tr.schedBeforeThisRide : tr.goodToKnow,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          _PlanRow(
            icon: AppAssets.solarAlarm,
            title: tr.schedBeReadyEarly,
            body: tr.schedGoOnlineMinBefore('${_onlineBefore()}'),
          ),
          const SizedBox(height: 15),
          _PlanRow(
            icon: AppAssets.solarRouting2,
            title: tr.schedTripsOnTheWay,
            body: ScheduledRideRules.current.towardPickupBeforeRide
                ? tr.schedOnlyTripsToward
                : tr.schedStillReceiveRides,
          ),
          const SizedBox(height: 15),
          _PlanRow(
            icon: AppAssets.solarCalendarMinimalistic,
            title: tr.schedPlansChanged,
            // W1: the preview words are the demo's only, never live.
            body: ride.accepted || LiveDriverServices.active
                ? tr.schedDriversNeverPay(_freeCancelLine(ride.route))
                : tr.schedLocalPreviewCancel,
          ),
        ],
      ),
    );
  }

  /// Minutes to be online before pickup for this kind of ride (Q10 S4).
  int _onlineBefore() {
    final route = ride.route;
    final rules = ScheduledRideRules.current;
    return route == null
        ? rules.ruleFor(ScheduledRideKind.normal).onlineBeforeMinutes
        : SmartGap.ruleOf(route, rules).onlineBeforeMinutes;
  }

  Widget _buildCommitmentCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1E4CE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _solar(AppAssets.solarBellBing, const Color(0xFF9B6B24), 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr.schedReservedForYou,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  tr.schedKeepInAccepted,
                  style: TextStyle(
                    color: Color(0xFF6F777C),
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: const Color(0xFFE8EBED).withValues(alpha: 0.9),
          ),
        ),
      ),
      child: ride.accepted
          ? SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _showCancelReasons(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  foregroundColor: _red,
                  side: const BorderSide(color: Color(0xFFE7C6C9)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                child: Text(
                  tr.schedCancelReservation,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            )
          : SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    _popScheduledRoute(context, _ScheduledRideAction.accepted),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: _ink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                child: Text(
                  tr.schedAcceptPrice(ride.price),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _showCancelReasons(BuildContext context) async {
    if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final reason = await showModalBottomSheet<CancelReason>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _CancelReasonSheet(ride: ride.route),
    );

    if (reason == null ||
        !context.mounted ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _AtFreeCancelEnd(
        ride: ride.route,
        child: () => _CancelConfirmationSheet(reason: reason, ride: ride.route),
      ),
    );

    if (confirmed == true && context.mounted) {
      ScheduledRideStore.lastGiveBackReason = reason.code;
      // L-c (owner 2026-11-06): every give-back counts.
      _popScheduledRoute(context, _ScheduledRideAction.cancelled);
    }
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F3),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: _solar(icon, const Color(0xFF19865C), 18),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF8A959B),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF252E3A),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.icon, required this.title, required this.body});

  final String icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(13),
          ),
          alignment: Alignment.center,
          child: _solar(icon, Colors.white, 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontSize: 11,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

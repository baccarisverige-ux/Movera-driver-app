part of 'scheduled_rides.dart';

// Base job B8 (2026-11-04): moved word for word out of scheduled_rides.dart
// (no behaviour change).

class _CancelReasonSheet extends StatefulWidget {
  const _CancelReasonSheet({this.ride});

  /// The ride being cancelled, for its free-cancel time.
  final ReservationRequestPreview? ride;

  @override
  State<_CancelReasonSheet> createState() => _CancelReasonSheetState();
}

class _CancelReasonSheetState extends State<_CancelReasonSheet> {
  CancelReason? _selected;

  /// Q21: from the admin's list for this country and language.
  List<CancelReason> get _reasons =>
      CancelReasons.current.of(CancelReasonGroup.scheduled);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.84,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFF7F8F8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                height: 4,
                width: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFD3D8DB),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 14, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr.whyAreYouCancellingQuestion,
                            style: TextStyle(
                              color: Color(0xFF252E3A),
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            tr.chooseBestReason,
                            style: TextStyle(
                              color: Color(0xFF7D888E),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: tr.close,
                      onPressed: () => _popScheduledRoute<void>(context),
                      icon: const Icon(Icons.close_rounded),
                      color: const Color(0xFF39444A),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: _AtFreeCancelEnd(
                  ride: widget.ride,
                  child: () => _CancelRulesBox(ride: widget.ride),
                ),
              ),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                itemCount: _reasons.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final reason = _reasons[index];
                  final selected = reason == _selected;
                  return Material(
                    color: selected ? Colors.white : const Color(0xFFF0F2F3),
                    borderRadius: BorderRadius.circular(17),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(17),
                      onTap: () => setState(() => _selected = reason),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF8AB7A3)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              height: 22,
                              width: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected
                                    ? const Color(0xFF19865C)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFF19865C)
                                      : const Color(0xFFAFB8BD),
                                  width: 1.5,
                                ),
                              ),
                              child: selected
                                  ? const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 15,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    reason.title,
                                    style: TextStyle(
                                      color: const Color(0xFF303B42),
                                      fontSize: 13,
                                      fontWeight: selected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                    ),
                                  ),
                                  if (!reason.counts) const _NotCountedTag(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                color: Colors.white,
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _selected == null
                        ? null
                        : () => _popScheduledRoute(context, _selected),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF252E3A),
                      disabledBackgroundColor: const Color(0xFFDCE1E3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    child: Text(
                      tr.navContinue,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CancelConfirmationSheet extends StatelessWidget {
  const _CancelConfirmationSheet({required this.reason, this.ride});

  final CancelReason reason;
  final ReservationRequestPreview? ride;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  height: 4,
                  width: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD3D8DB),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDEF),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.event_busy_rounded,
                  color: Color(0xFFC84E58),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                tr.schedCancelThisReservation,
                style: TextStyle(
                  color: Color(0xFF252E3A),
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                reason.title,
                style: const TextStyle(
                  color: Color(0xFF59656C),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!reason.counts) ...[
                const SizedBox(height: 12),
                Text(
                  tr.schedReasonDoesntCount,
                  key: ValueKey<String>('scheduled-cancel-not-counted'),
                  style: TextStyle(
                    color: Color(0xFF19865C),
                    fontSize: 12.5,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ] else if (ScheduledRideStore.isLateCancel(ride)) ...[
                const SizedBox(height: 12),
                _LateCancelWarning(ride: ride),
              ],
              if ((ride?.id ?? "").isEmpty) const SizedBox(height: 8),
              if ((ride?.id ?? "").isEmpty)
                Text(
                  tr.schedRemovesSample,
                  style: TextStyle(
                    color: Color(0xFF7D888E),
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _popScheduledRoute(context, true),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: const Color(0xFF252E3A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  child: Text(
                    tr.schedCancelReservation,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 9),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => _popScheduledRoute(context, false),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(
                    tr.schedKeepReservation,
                    style: TextStyle(
                      color: Color(0xFF354047),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The real map of a live booking: the road route loads once, the waypoints
/// show meanwhile (and when routing is off or fails).
class _RealReservationMap extends StatefulWidget {
  const _RealReservationMap({required this.request});

  final ReservationRequestPreview request;

  @override
  State<_RealReservationMap> createState() => _RealReservationMapState();
}

class _RealReservationMapState extends State<_RealReservationMap> {
  late final Future<List<GeoPoint>> _route = _load();

  Future<List<GeoPoint>> _load() {
    final routes = DriverRuntimeConfig.current.externalRouting
        ? RoadRouteService(api: LiveDriverServices.instance?.api)
        : null;
    final loaded = loadReservationRoute(widget.request, routes);
    if (routes != null) unawaited(loaded.whenComplete(routes.dispose));
    return loaded;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<GeoPoint>>(
      future: _route,
      initialData: reservationWaypoints(widget.request),
      builder: (context, snapshot) => ReservationRouteMap(
        request: widget.request,
        route: snapshot.data ?? reservationWaypoints(widget.request),
        labelled: true,
        fitPadding: 36,
      ),
    );
  }
}

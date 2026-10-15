part of 'accept_ride.dart';

// Sheet, panel, and rider-contact presentation for AcceptRide.
// Trip lifecycle stays in the trip extension. This file does not change geometry.

extension _AcceptRidePanel on _AcceptRideState {
    void _setMapGesturesBlocked(bool value) {
      if (!mounted || _blockMapGestures == value) { return; }
      _rebuild(() {
        _blockMapGestures = value;
      });
    }
    Widget _mapOverlay({required Widget child}) {
      return PointerInterceptor(
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => _setMapGesturesBlocked(true),
          onPointerUp: (_) => _setMapGesturesBlocked(false),
          onPointerCancel: (_) => _setMapGesturesBlocked(false),
          child: child,
        ),
      );
    }
    void _onRideSheetPointerDown(PointerDownEvent event) {
      _sheetTrace.down();
      _ridePointerActive = true;
      _ridePointerLastY = event.position.dy;
      _ridePointerLastMs = DateTime.now().millisecondsSinceEpoch;
      _ridePointerVelocity = 0;
      _ridePointerTravel = 0;
      _ridePointerStartPos =
          _ridePanelController.isAttached ? _ridePanelController.panelPosition : 0;
      _snapSheet.stopSpring();
      _setMapGesturesBlocked(true);
    }
    void _onRideSheetPointerMove(PointerEvent event) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (_ridePointerLastMs != 0) {
        final dt = math.max(1, now - _ridePointerLastMs);
        _ridePointerVelocity =
            (event.position.dy - _ridePointerLastY) / dt * 1000;
      }
      _ridePointerTravel += (event.position.dy - _ridePointerLastY).abs();
      _ridePointerLastY = event.position.dy;
      _ridePointerLastMs = now;
    }
    void _onRideSheetPointerEnd(PointerEvent event) {
      _sheetTrace.up(_ridePointerVelocity);
      _onRideSheetPointerMove(event);
      _ridePointerActive = false;
      // A drag settles at once, toward where the finger went; a tap is
      // left to the buttons it hit.
      if (_ridePointerTravel > 6 && _ridePanelController.isAttached) {
        unawaited(_snapRideSheet(velocity: _ridePointerVelocity));
      }
    }
    void _scheduleRideSheetPositionGuard({
      Duration delay = const Duration(milliseconds: 180),
    }) {
      _rideSheetPositionGuardTimer?.cancel();
      _rideSheetPositionGuardTimer = Timer(delay, () {
        if (!mounted ||
            _ridePointerActive ||
            !_ridePanelController.isAttached) {
          return;
        }

        final snap = _rideSnapPoint(context);
        final position = _ridePanelController.panelPosition.clamp(0.0, 1.0);
        final nearestDistance = math.min(
          position.abs(),
          math.min((position - snap).abs(), (1 - position).abs()),
        );
        if (nearestDistance <= 0.025) { return; }
        unawaited(_snapRideSheet(velocity: 0));
      });
    }
    double _rideExpandedHeight(BuildContext context) {
      final viewport = MediaQuery.sizeOf(context).height;
      final collapsed = MoveraSheetMetrics.activeCollapsedTotal(
            MediaQuery.paddingOf(context).bottom,
          );
      final bannerReserve = MediaQuery.paddingOf(context).top + 210;
      return math.min(
        MoveraSheetMetrics.expandedHeight(viewport),
        math.max(collapsed + 160, viewport - bannerReserve),
      );
    }
    /// Panel position of the middle sheet: header, rider and slide action.
    double _rideSnapPoint(BuildContext context) {
      final safeBottom = MediaQuery.paddingOf(context).bottom;
      return MoveraSheetMetrics.activeSnapPoint(
        collapsed: MoveraSheetMetrics.activeCollapsedTotal(safeBottom),
        middle: _rideMiddleTotal(context),
        expanded: _rideExpandedHeight(context),
      );
    }
    /// Middle sheet height: down to the stage's main action (I've arrived,
    /// a slide), measured once laid out.
    double _rideMiddleTotal(BuildContext context) =>
        _middleMeasured ??
        MoveraSheetMetrics.activeMiddleTotal(MediaQuery.paddingOf(context).bottom);
    void _measureRideMiddle() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) { return; }
        final action = _middleActionKey.currentContext?.findRenderObject();
        final panel = _ridePanelKey.currentContext?.findRenderObject();
        if (action is! RenderBox || panel is! RenderBox ||
            !action.attached || !panel.attached) {
          return;
        }
        final bottom = action.localToGlobal(Offset(0, action.size.height)).dy -
            panel.localToGlobal(Offset.zero).dy;
        final safeBottom = MediaQuery.paddingOf(context).bottom;
        final measured = bottom + 14 + math.max(safeBottom, 10);
        final old = _middleMeasured;
        if (old != null && (old - measured).abs() < 2) { return; }
        final wasAtMiddle = _ridePanelController.isAttached &&
            (_ridePanelController.panelPosition - _rideSnapPoint(context)).abs() < 0.02;
        _rebuild(() => _middleMeasured = measured);
        // Resting on the middle: stay on it at its new height.
        if (wasAtMiddle && _ridePanelController.isAttached) {
          _ridePanelController.panelPosition = _rideSnapPoint(context);
        }
      });
    }
    void _showRideMiddle() {
      if (!_ridePanelController.isAttached) { return; }
      _snapSheet.rangePx = _rideRangePx(context);
      // Same spring as a drag, so a tap and a slide feel the same.
      unawaited(_snapSheet.springTo(_rideSnapPoint(context)));
    }
    void _showRideFull() {
      if (!_ridePanelController.isAttached) { return; }
      _snapSheet.stopSpring();
      _rideSheetPositionGuardTimer?.cancel();
      unawaited(_ridePanelController.open());
    }
    double _rideRangePx(BuildContext context) =>
        _rideExpandedHeight(context) -
        MoveraSheetMetrics.activeCollapsedTotal(MediaQuery.paddingOf(context).bottom);
    Future<void> _snapRideSheet({double? velocity}) async {
      if (!_ridePanelController.isAttached) { return; }
      _snapSheet.rangePx = _rideRangePx(context);
      final snap = _rideSnapPoint(context);
      final pos = _ridePanelController.panelPosition.clamp(0.0, 1.0);
      final v = velocity ?? _ridePointerVelocity;
      await _snapSheet.springTo(
        _rideTarget(_ridePointerStartPos, pos, v, snap),
        velocityPxPerSec: v,
      );
    }
    double _rideTarget(double start, double pos, double v, double snap) =>
        MoveraSheetMetrics.directionalTarget(
          start: start,
          position: pos,
          velocityPxPerSec: v,
          snap: snap,
        );
    /// The trip's step on the island, e.g. "Waiting for Angelica".
    String get _islandStatus {
      final first = widget.riderName.split(' ').first;
      return switch (_stage) {
        ActiveRideStage.headingToPickup => 'Heading to pickup',
        ActiveRideStage.waitingForRider => 'Waiting for $first',
        _ => _stopCursor < widget.stopAddresses.length
            ? 'To next stop'
            : 'To drop-off',
      };
    }
    void _openDestinationPicker() {
      Navigator.of(context)
          .push<DriverDestinationResult>(
            MaterialPageRoute(builder: (_) => const DriverDestinationPicker()),
          )
          .then((result) {
            if (!mounted || result == null) { return; }
            _rebuild(() {
              _destinationActive = true;
              _destinationAddress = result.address;
              _destinationPosition = result.position;
            });
          });
    }
    Widget _buildIncomingRideCard() {
      final offer = _nextTripRadarOffer;
      if (offer == null) { return const SizedBox.shrink(); }
      const alertCoral = Color(0xFFFF765C);

      return Material(
        key: const ValueKey<String>('on-trip-radar-offer-button'),
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: alertCoral.withValues(alpha: 0.55), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: alertCoral.withValues(alpha: 0.12),
                blurRadius: 22,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: const Color(0xFF11181C).withValues(alpha: 0.14),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9EEF1),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      offer.category,
                      style: const TextStyle(
                        color: _AcceptRideState._ink,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_destinationActive) ...[
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: _AcceptRideState._ink,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Text(
                        'On your way',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 7),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(
                        color: alertCoral.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Text(
                        'After this drop-off',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFFB84F3D),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Q18: while driving a rider, only Exclusive offers.
              Row(
                children: [
                  const OfferBadge.exclusive(
                    key: ValueKey<String>('on-trip-exclusive-mark'),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      ExclusiveReasons.text(ExclusiveReasons.finishingNearby),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF5F6B72),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      offer.fare,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _AcceptRideState._ink,
                        fontSize: 30,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.9,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const MoveraLineIcon(
                    mark: MoveraMark.star,
                    color: Color(0xFFD7A02C),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    offer.rating.toStringAsFixed(2),
                    style: const TextStyle(
                      color: Color(0xFF6F7B82),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              const Text(
                'Available after your current drop-off',
                style: TextStyle(
                  color: _AcceptRideState._muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              TweenAnimationBuilder<double>(
                key: ValueKey<String>('on-trip-offer-${offer.id}'),
                tween: Tween<double>(begin: 1, end: 0),
                duration: _AcceptRideState._onTripOfferLifetime,
                builder: (context, remaining, _) {
                  final seconds =
                      (remaining * (_AcceptRideState._onTripOfferLifetime.inMilliseconds / 1000))
                          .ceil();
                  return Column(
                    children: [
                      Row(
                        children: [
                          const MoveraLineIcon(
                            mark: MoveraMark.timer,
                            color: _AcceptRideState._ink,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Exclusive · ${seconds}s',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _AcceptRideState._ink,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Flexible(
                            child: Text(
                              'On this ride',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Color(0xFF8A9499),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          minHeight: 3,
                          value: remaining,
                          backgroundColor: const Color(0xFFF0E8E5),
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(alertCoral),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFE4E8EA)),
              const SizedBox(height: 11),
              _offerLocationRow(
                color: const Color(0xFF215277),
                title: '${offer.pickupMinutes} min away',
                subtitle: offer.pickup,
              ),
              const SizedBox(height: 9),
              _offerLocationRow(
                color: _AcceptRideState._ink,
                title: '${offer.tripMinutes} min trip',
                subtitle: offer.dropoff,
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey<String>('on-trip-radar-deny'),
                      onPressed: _AcceptRideTrip(this)._denyNextTripRadar,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _AcceptRideState._ink,
                        side: const BorderSide(color: Color(0xFFD5DCDF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        minimumSize: const Size(0, 42),
                      ),
                      child: const Text(
                        'Deny',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey<String>('on-trip-radar-match-next'),
                      onPressed: _AcceptRideTrip(this)._acceptNextTripRadar,
                      style: FilledButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFF252E3A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        minimumSize: const Size(0, 42),
                      ),
                      child: const Text(
                        'Accept',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    Widget _offerLocationRow({
      required Color color,
      required String title,
      required String subtitle,
    }) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2.5),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AcceptRideState._ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AcceptRideState._muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    Widget _buildSecuredNextTripDetails() {
      final offer = _nextTripRadarOffer;
      if (_stage != ActiveRideStage.onTrip ||
          _onTripRadarState != _OnTripRadarState.secured ||
          offer == null) {
        return const SizedBox.shrink();
      }

      return Container(
        key: const ValueKey<String>('secured-next-trip-details'),
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAF9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDDE8E3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Next trip secured',
                    style: TextStyle(
                      color: _AcceptRideState._ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  offer.fare,
                  style: const TextStyle(
                    color: _AcceptRideState._ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            _nextTripLocationRow(
              color: _AcceptRideState._green,
              label: 'Pickup · ${offer.pickupMinutes} min',
              address: offer.pickup,
            ),
            const SizedBox(height: 9),
            _nextTripLocationRow(
              color: _AcceptRideState._ink,
              label: 'Drop-off · ${offer.tripMinutes} min trip',
              address: offer.dropoff,
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${offer.category} · ${offer.riderName}',
                    style: const TextStyle(
                      color: _AcceptRideState._muted,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey<String>('next-trip-waybill'),
                  onPressed: () {
                    final record = _waybills.next;
                    if (record != null) {
                      showMoveraWaybillSheet(
                        context,
                        record,
                        title: 'Next trip waybill',
                      );
                    }
                  },
                  icon: const MoveraLineIcon(
                    mark: MoveraMark.receipt,
                    size: 15,
                    color: Color(0xFF1C242C),
                  ),
                  label: const Text('Waybill'),
                  style: TextButton.styleFrom(
                    foregroundColor: _AcceptRideState._ink,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    Widget _nextTripLocationRow({
      required Color color,
      required String label,
      required String address,
    }) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _AcceptRideState._muted,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  address,
                  style: const TextStyle(
                    color: _AcceptRideState._ink,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    void _openWaitingTime() {
      if (!_countingWait) { return; }
      showWaitingTimeSheet(
        context,
        readSeconds: () => _waitSeconds,
        fullyPaid: _paidStopWait,
        terms: _waitTerms,
        onNoShow: _paidStopWait
            ? null
            : () {
                if (_waitSeconds < _noShowWaitSeconds || !mounted) { return; }
                _AcceptRideTrip(this)._confirmCancellationReason(_AcceptRideState._noShowReason);
              },
      );
    }
    void _openRidePreferences() {
      pushSingle(
        context,
        MaterialPageRoute<void>(builder: (_) => const Preferences()),
      );
    }
    Widget _buildMapControls() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(_freshRadarLocation ? 'Demo offers' : 'Demo offers — live location unavailable/stale', style: const TextStyle(fontSize: 10)),
          const SizedBox(height: 4),
          MapControlButton(
            key: const ValueKey<String>('active-ride-safety-button'),
            tooltip: 'Safety toolkit',
            size: 50,
            onTap: () => showSafetyToolKitSheet(context),
            child: SvgPicture.asset(AppAssets.mapSafety, width: 26, height: 26),
          ),
          if (!_browsing) ...[
          const SizedBox(height: 12),
          MapControlButton(
            key: const ValueKey<String>('active-ride-google-maps-button'),
            tooltip: 'Navigate with Google Maps',
            size: 56,
            fill: MapControlButton.googleGrey,
            onTap: _openGoogleMaps,
            child: SvgPicture.asset(AppAssets.mapGoogle, width: 26, height: 26),
          ),
          ],
          const SizedBox(height: 12),
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
          // Browsing: a soft ring grows and fades around recenter.
          if (_camera.mode == DriverCameraMode.browsing)
            Positioned(
              left: -18,
              right: -18,
              top: -18,
              bottom: -18,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _browsePulse,
                  builder: (context, _) {
                    final t = Curves.easeOutCubic.transform(_browsePulse.value);
                    const blue = Color(0xFF3B7DD8);
                    final size = 56 + 36 * t;
                    return Center(
                      key: const ValueKey<String>('active-ride-recenter-pulse'),
                      child: Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: blue.withValues(alpha: 0.16 * (1 - t)),
                          border: Border.all(
                            color: blue.withValues(alpha: 0.42 * (1 - t)),
                            width: 1.5,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          MapControlButton(
            key: const ValueKey<String>('active-ride-recenter-button'),
            tooltip: 'Recenter',
            size: 56,
            fill: MapControlButton.recenterBlue,
            onTap: () {
              if (_browsing) {
                // Follows the car again and brings the sheet back.
                _AcceptRideTrip(this)._exitBrowse();
                return;
              }
              // Same quiet window as leaving browse: the fly-back is ours.
              _AcceptRideTrip(this)._exitBrowse();
            },
            child: SvgPicture.asset(AppAssets.mapRecenter, width: 24, height: 24),
          ),
            ],
          ),
        ],
      );
    }
    Future<void> _openGoogleMaps() async {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      final target = _approachTarget ?? widget.dropoffPosition;
      final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=${target.latitude},${target.longitude}&travelmode=driving',
      );
      final opened = await _externalMapAction.run(context,
        () => widget.launchExternalMap?.call(uri) ?? launchUrl(uri, mode: LaunchMode.externalApplication));
      if (opened == false && mounted && ModalRoute.of(context)?.isCurrent == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Maps is unavailable.')),
        );
      }
    }
    Widget _buildRidePanel() {
      return ValueListenableBuilder<double>(
        valueListenable: _ridePanelPosition,
        builder: (context, pos, _) {
          final snap = _rideSnapPoint(context);
          // Three states: the flat bar, the middle sheet with the rider and
          // the next action, and the clean full sheet with trip details.
          final compact = pos < snap * 0.5;
          final full = pos > snap + (1 - snap) * 0.35;
          if (!compact && !full) { _measureRideMiddle(); }
          return Container(
            key: const ValueKey<String>('active-ride-panel'),
            decoration: BoxDecoration(
              color: _AcceptRideState._panel,
              // Flat and square like the bar; rounded only when full.
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(full ? 24 : 0),
              ),
              border: Border(top: BorderSide(color: _AcceptRideState._line)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF172027).withValues(alpha: 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  KeyedSubtree(
                    key: ValueKey<String>('active-ride-panel-${_stage.name}'),
                    child: const SizedBox.shrink(),
                  ),
                  if (compact)
                    TripBottomBar(
                      key: const ValueKey<String>('active-ride-compact-dock'),
                      instruction: _tripBarInstruction,
                      address: _tripBarAddress,
                      onPreferences: _openRidePreferences,
                      onTap: _showRideMiddle,
                    )
                  else ...[
                    // Grip line: the sheet can be pulled up for details.
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD8DEDF),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    TripBottomBar(
                      key: const ValueKey<String>('active-ride-expanded-header'),
                      instruction: _tripBarInstruction,
                      address: _tripBarAddress,
                      onPreferences: _openRidePreferences,
                      onTap: full ? _showRideMiddle : _showRideFull,
                    ),
                    if (!full) ...[
                      _buildRiderRow(),
                      Padding(
                        key: _middleActionKey,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        child: _buildPrimaryAction(),
                      ),
                    ] else
                      Expanded(
                        child: SingleChildScrollView(
                          key: const PageStorageKey<String>('active-ride-scroll'),
                          padding: const EdgeInsets.only(bottom: 16),
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildRiderRow(),
                              const SizedBox(height: 6),
                              _sheetDivider(),
                              _buildRouteList(),
                              _sheetDivider(),
                              _buildCurrentWaybillShortcut(),
                              _sheetRow(
                                key: const ValueKey<String>('active-ride-safety-tile'),
                                label: 'Safety',
                                onTap: () => showSafetyToolKitSheet(context),
                              ),
                              _sheetDivider(),
                              _sheetRow(
                                key: const ValueKey<String>('active-ride-trip-options'),
                                label: 'Trip options',
                                onTap: _showTripOptions,
                              ),
                              if (_stage == ActiveRideStage.onTrip)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: _buildSecuredNextTripDetails(),
                                ),
                              if (_countingWait) ...[
                                const SizedBox(height: 12),
                                Center(child: _waitPhaseChip()),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    }
    /// Every point of the trip as a plain list, a small dot before each.
    Widget _buildRouteList() {
      final points = <String>[
        widget.pickupAddress,
        ...widget.stopAddresses,
        widget.dropoffAddress,
      ];
      return Padding(
        key: const ValueKey<String>('active-ride-journey-card'),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        child: Column(
          children: [
            for (final point in points)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: _AcceptRideState._ink,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        point,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _AcceptRideState._ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }
    Widget _waitPhaseChip() {
      final color = _waitBarColor;
      return InkWell(
        key: const ValueKey<String>('active-ride-wait-phase'),
        onTap: _openWaitingTime,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            _waitBarStatus,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }
    /// Rider row of the middle and full sheet: the name (opens the profile)
    /// on the left, plain call and message icons on the right.
    Widget _buildRiderRow() {
      return Padding(
        key: const ValueKey<String>('active-ride-rider-card'),
        padding: const EdgeInsets.fromLTRB(12, 2, 8, 2),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _showRiderProfile,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Text(
                    widget.riderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _AcceptRideState._ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            _riderAction(
              key: const ValueKey<String>('active-ride-call-rider'),
              tooltip: 'Call rider',
              onTap: _callRider,
              asset: AppAssets.tripCall,
            ),
            _riderAction(
              key: const ValueKey<String>('active-ride-message-rider'),
              tooltip: 'Message rider',
              onTap: _messageRider,
              asset: AppAssets.tripMessage,
            ),
          ],
        ),
      );
    }
    Widget _riderAction({
      required Key key,
      required String tooltip,
      required VoidCallback onTap,
      required String asset,
    }) {
      return Tooltip(
        key: key,
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: SvgPicture.asset(
                  asset,
                  width: 23,
                  height: 23,
                  colorFilter: const ColorFilter.mode(
                    _AcceptRideState._ink,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    void _callRider() {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(RiderContactPolicy.unavailableMessage),
          backgroundColor: _AcceptRideState._ink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }
    void _messageRider() {
      pushSingle(
        context,
        BottomToTopTransition(
          Chat(riderDisplayName: widget.riderName),
        ),
      );
    }
    Widget _sheetDivider() =>
        const Divider(height: 1, thickness: 1, color: Color(0xFFECEEEF));
    /// A plain text row of the full sheet.
    Widget _sheetRow({
      required Key key,
      required String label,
      required VoidCallback onTap,
    }) {
      return InkWell(
        key: key,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: _AcceptRideState._ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    /// "Waybill" row, shown once the trip has one.
    Widget _buildCurrentWaybillShortcut() {
      return ValueListenableBuilder<WaybillRecord?>(
        valueListenable: _waybills.currentListenable,
        builder: (context, record, _) {
          if (record == null) { return const SizedBox.shrink(); }
          return Column(
            children: [
              _sheetRow(
                key: const ValueKey<String>('current-waybill-shortcut'),
                label: 'Waybill',
                onTap: () => showMoveraWaybillSheet(context, record),
              ),
              _sheetDivider(),
            ],
          );
        },
      );
    }
    Widget _buildPrimaryAction() {
      final accent = switch (_stage) {
        ActiveRideStage.headingToPickup => const Color(0xFF1C242C),
        ActiveRideStage.waitingForRider => const Color(0xFF146B45),
        ActiveRideStage.onTrip => const Color(0xFF1B3F6F),
      };

      // Arriving is a plain button; only trip steps after it slide.
      final arrival = _stage == ActiveRideStage.headingToPickup ||
          (_stage == ActiveRideStage.onTrip &&
           !_paidStopWait &&
           _stopCursor < widget.stopAddresses.length);
      if (arrival) {
        final near = _nearArrivalTarget;
        return SizedBox(
          width: double.infinity,
          height: 58,
          child: FilledButton(
            key: const ValueKey<String>('active-ride-arrived-button'),
            onPressed: () {
              _setMapGesturesBlocked(false);
              unawaited(_AcceptRideTrip(this)._onArrivedTap());
            },
            style: FilledButton.styleFrom(
              elevation: 0,
              backgroundColor: near ? const Color(0xFF111614) : const Color(0xFFEEEFF1),
              foregroundColor: near ? Colors.white : const Color(0xFF8E979B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              "I've arrived",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
        );
      }

      // Q24: at the drop-off of a cash trip, collect the cash first; the
      // amount shows, then "Complete ride".
      if (_collectsCashNow) {
        return SizedBox(
          width: double.infinity,
          height: 58,
          child: FilledButton(
            key: const ValueKey<String>('active-ride-collect-cash'),
            onPressed: () {
              _setMapGesturesBlocked(false);
              unawaited(_AcceptRideTrip(this)._collectCash());
            },
            style: FilledButton.styleFrom(
              elevation: 0,
              backgroundColor: const Color(0xFF7A5200),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Collect cash',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
        );
      }

      return _SlideRideAction(
        key: const ValueKey<String>('active-ride-slide-action'),
        semanticsKey: const ValueKey<String>('active-ride-primary-action'),
        label: _slideLabel,
        confirmedLabel: _slideConfirmedLabel,
        accent: accent,
        onConfirmed: () async {
          _setMapGesturesBlocked(false);
          await _AcceptRideTrip(this)._advanceRide();
        },
      );
    }
    Future<void> _showRiderProfile() async {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.35),
        builder: (sheetContext) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
            ),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            decoration: const BoxDecoration(
              color: Color(0xFFF7F9F8),
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                      radius: 34,
                      backgroundImage: AssetImage(AppAssets.profileImg),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.riderName,
                      style: const TextStyle(
                        color: _AcceptRideState._ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${widget.riderRating.toStringAsFixed(1)} ★ · '
                      '${widget.riderTrips} rides',
                      style: const TextStyle(
                        color: _AcceptRideState._muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _AcceptRideState._line),
                      ),
                      child: const Text(
                        'Rider details from the booking will appear here when the backend profile is connected.',
                        style: TextStyle(
                          color: _AcceptRideState._muted,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }
    Future<void> _showTripOptions() async {
      final onTrip = _stage == ActiveRideStage.onTrip;
      final showNext = _onTripRadarState == _OnTripRadarState.secured &&
          _waybills.next != null;
      await showMoveraModalSheet<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.35),
        heightFactor: 0.78,
        fitContent: true,
        builder: (sheetContext) {
          return _CleanSheet(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_navigation.routeState == RouteLoadState.failed)
                  _CleanRow(
                    key: const ValueKey<String>('retry-route-option'),
                    title: 'Retry route',
                    subtitle: 'Route unavailable. Your trip remains active.',
                    onTap: () { if (popOwned(sheetContext)) unawaited(_navigation.retryRoute()); },
                  ),
                _CleanRow(
                  key: const ValueKey<String>('current-trip-waybill-option'),
                  title: 'Current waybill',
                  subtitle:
                      '${widget.pickupAddress} → ${widget.dropoffAddress}',
                  onTap: () {
                    if (!popOwned(sheetContext)) return;
                    final record = _waybills.current;
                    if (record != null) {
                      showMoveraWaybillSheet(
                        context,
                        record,
                        title: 'Current trip waybill',
                      );
                    }
                  },
                ),
                if (showNext)
                  _CleanRow(
                    key: const ValueKey<String>('next-trip-waybill-option'),
                    title: 'Next trip waybill',
                    subtitle: _waybills.next!.dropoff,
                    onTap: () {
                      if (!popOwned(sheetContext)) return;
                      showMoveraWaybillSheet(
                        context,
                        _waybills.next!,
                        title: 'Next trip waybill',
                      );
                    },
                  ),
                _CleanRow(
                  title: 'Safety toolkit',
                  subtitle: 'Share trip, record audio, get help',
                  onTap: () {
                    if (!popOwned(sheetContext)) return;
                    showSafetyToolKitSheet(context);
                  },
                ),
                _CleanRow(
                  key: const ValueKey<String>('active-ride-cancel-option'),
                  title: onTrip ? 'End trip early' : 'Cancel trip',
                  subtitle:
                      onTrip ? 'Stop safely first · reason required' : null,
                  danger: true,
                  last: true,
                  onTap: () {
                    if (!popOwned(sheetContext)) return;
                    _showCancellationReasons();
                  },
                ),
              ],
            ),
          );
        },
      );
    }
    Future<void> _showCancellationReasons() async {
      final isOnTrip = _stage == ActiveRideStage.onTrip;
      final reasons = isOnTrip
          ? _AcceptRideState._onTripCancellationReasons
          : _stage == ActiveRideStage.waitingForRider &&
                  !_paidStopWait &&
                  _waitSeconds >= _noShowWaitSeconds
              ? <_TripCancellationReason>[_AcceptRideState._noShowReason, ..._AcceptRideState._preTripCancellationReasons]
              : _AcceptRideState._preTripCancellationReasons;

      final reason = await showMoveraModalSheet<_TripCancellationReason>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.32),
        heightFactor: 0.86,
        fitContent: true,
        builder: (sheetContext) {
          return _CleanSheet(
            key: const ValueKey<String>('trip-cancellation-reasons-sheet'),
            child: Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                children: [
                  Text(
                    isOnTrip
                        ? 'Why are you ending the trip?'
                        : 'Why are you cancelling?',
                    style: _CleanSheet.title,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isOnTrip
                        ? 'Stop in a safe place first.'
                        : 'Pick the reason that fits best.',
                    style: _CleanSheet.note,
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < reasons.length; i++)
                    _CleanRow(
                      key: ValueKey<String>(
                        'trip-cancel-reason-${reasons[i].code}',
                      ),
                      title: reasons[i].title,
                      subtitle: reasons[i].detail,
                      last: i == reasons.length - 1,
                      onTap: () => popOwned(sheetContext, reasons[i]),
                    ),
                ],
              ),
            ),
          );
        },
      );

      if (!mounted || reason == null) { return; }
      await _AcceptRideTrip(this)._confirmCancellationReason(reason);
    }
}

class _CleanSheet extends StatelessWidget {
  const _CleanSheet({super.key, required this.child});

  final Widget child;

  static const TextStyle title = TextStyle(
    color: Color(0xFF111614),
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );
  static const TextStyle note = TextStyle(
    color: Color(0xFF8A9390),
    fontSize: 14,
    height: 1.35,
  );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9DDDB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// One row of a clean sheet: title, optional short line, chevron, and a
/// thin line under it. No icons.
class _CleanRow extends StatelessWidget {
  const _CleanRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.danger = false,
    this.last = false,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: Color(0xFFECEEEF))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: danger
                          ? const Color(0xFFC2453A)
                          : const Color(0xFF111614),
                      fontSize: 16.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF8A9390),
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFB4BBB8),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

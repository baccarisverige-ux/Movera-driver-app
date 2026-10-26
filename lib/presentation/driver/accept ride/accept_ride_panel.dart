part of 'accept_ride.dart';

// Sheet, panel, and rider-contact presentation for AcceptRide.
// Trip lifecycle stays in the trip extension. This file does not change geometry.

extension _AcceptRidePanel on _AcceptRideState {
  void _setMapGesturesBlocked(bool value) {
    if (!mounted || _blockMapGestures == value) {
      return;
    }
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

  TripSheetMotion _newTripMotion() => TripSheetMotion(
    sheet: _snapSheet,
    position: _ridePanelPosition,
    snap: () => _rideSnapPoint(context),
    canDrag: () => !_incomingOfferOpen,
    scrollArea: () => _fullScrollKey.currentContext?.findRenderObject(),
    onRelease: _onRideSheetRelease,
  );
  void _onRideSheetPointerDown(PointerDownEvent event) {
    _sheetTrace.down();
    _ridePointerActive = true;
    _rideSheetPositionGuardTimer?.cancel();
    _tripMotion.drag.down(event);
    _setMapGesturesBlocked(true);
  }

  void _onRideSheetPointerMove(PointerMoveEvent event) =>
      _tripMotion.drag.move(event);
  void _onRideSheetPointerEnd(PointerEvent event) {
    _ridePointerActive = false;
    _tripMotion.drag.end(event);
  }

  /// A drag settles at once, toward where the finger went and with its
  /// speed; a tap is left to the buttons it hit.
  void _onRideSheetRelease(double velocity, double start) {
    _sheetTrace.up(velocity);
    unawaited(_snapRideSheet(velocity: velocity, start: start));
  }

  void _scheduleRideSheetPositionGuard({
    Duration delay = const Duration(milliseconds: 180),
  }) {
    _rideSheetPositionGuardTimer?.cancel();
    _rideSheetPositionGuardTimer = Timer(delay, () {
      if (!mounted ||
          _ridePointerActive ||
          _snapSheet.isSpringing ||
          !_ridePanelController.isAttached) {
        return;
      }

      final snap = _rideSnapPoint(context);
      final position = _ridePanelController.panelPosition.clamp(0.0, 1.0);
      final nearestDistance = math.min(
        position.abs(),
        math.min((position - snap).abs(), (1 - position).abs()),
      );
      if (nearestDistance <= 0.025) {
        return;
      }
      unawaited(_snapRideSheet(velocity: 0));
    });
  }

  double _rideExpandedHeight(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context).height;
    final collapsed = MoveraSheetMetrics.activeCollapsedTotal(
      MediaQuery.paddingOf(context).bottom,
    );
    final bannerReserve = MediaQuery.paddingOf(context).top + 210;
    return _AcceptRideSheet(this)._fitRideExpanded(
      math.min(
        MoveraSheetMetrics.expandedHeight(viewport),
        math.max(collapsed + 160, viewport - bannerReserve),
      ),
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
      MoveraSheetMetrics.activeMiddleTotal(
        MediaQuery.paddingOf(context).bottom,
      );
  void _measureRideMiddle() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final action = _middleActionKey.currentContext?.findRenderObject();
      final panel = _ridePanelKey.currentContext?.findRenderObject();
      if (action is! RenderBox ||
          panel is! RenderBox ||
          !action.attached ||
          !panel.attached) {
        return;
      }
      final bottom =
          action.localToGlobal(Offset(0, action.size.height)).dy -
          panel.localToGlobal(Offset.zero).dy;
      final safeBottom = MediaQuery.paddingOf(context).bottom;
      final measured =
          bottom + _tripMotion.gripMissing() + 14 + math.max(safeBottom, 10);
      final old = _middleMeasured;
      if (old != null && (old - measured).abs() < 2) {
        return;
      }
      final wasAtMiddle =
          _ridePanelController.isAttached &&
          (_ridePanelController.panelPosition - _rideSnapPoint(context)).abs() <
              0.02;
      _rebuild(() => _middleMeasured = measured);
      // Resting on the middle: glide to its new height.
      if (wasAtMiddle && _ridePanelController.isAttached) {
        unawaited(
          _snapSheet.springTo(_rideSnapPoint(context), noOvershoot: true),
        );
      }
    });
  }

  void _showRideMiddle() {
    if (!_ridePanelController.isAttached) {
      return;
    }
    // Same spring as a drag, so a tap and a slide feel the same.
    unawaited(_snapSheet.springTo(_rideSnapPoint(context), noOvershoot: true));
  }

  void _showRideFull() {
    if (!_ridePanelController.isAttached) {
      return;
    }
    _rideSheetPositionGuardTimer?.cancel();
    unawaited(_snapSheet.springTo(1, noOvershoot: true));
  }

  // The sheet's travel (rangePx) is kept by TripSheetMotion.keep on
  // every layout, so a re-measured sheet never jumps.
  Future<void> _snapRideSheet({double velocity = 0, double? start}) async {
    if (!_ridePanelController.isAttached) {
      return;
    }
    final snap = _rideSnapPoint(context);
    final pos = _ridePanelController.panelPosition.clamp(0.0, 1.0);
    await _snapSheet.springTo(
      _rideTarget(start ?? pos, pos, velocity, snap),
      velocityPxPerSec: velocity,
      noOvershoot: true,
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
      ActiveRideStage.headingToPickup => tr.headingToPickup,
      ActiveRideStage.waitingForRider => tr.waitingForFirst(first),
      _ =>
        _stopCursor < widget.stopAddresses.length
            ? tr.toNextStop
            : tr.toDropOff,
    };
  }

  /// R13-18: a destination can be set during the trip too; next-trip
  /// offers then follow it. Admin's daily limit applies here as well.
  void _openDestinationPicker() {
    final refusal = OnTripDestination.refusalText();
    if (refusal != null) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(refusal)));
      return;
    }
    // UI-07: one picker per tap burst. UI-08: from the car, so a place
    // opens the confirm map (distance, time) as on Home.
    pushSingle<DriverDestinationResult>(
      context,
      MaterialPageRoute(
        builder: (_) => DriverDestinationPicker(
          origin: _driverPosition,
          routeRepository: _routeService,
        ),
      ),
    ).then((result) {
      if (!mounted || result == null) {
        return;
      }
      OnTripDestination.started(
        address: result.address,
        position: GeoPointMaps.fromLatLng(result.position),
      );
      _rebuild(() {
        _destinationActive = true;
        _destinationAddress = result.address;
        _destinationPosition = result.position;
      });
    });
  }

  Widget _buildIncomingRideCard() {
    final offer = _nextTripRadarOffer;
    if (offer == null) {
      return const SizedBox.shrink();
    }
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
          border: Border.all(
            color: alertCoral.withValues(alpha: 0.55),
            width: 1.2,
          ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _AcceptRideState._ink,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      tr.onYourWay,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: alertCoral.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      tr.afterThisDropOff,
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
                    offer.shownFare,
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
            PickupPayLine(quote: offer.pickupPay),
            const SizedBox(height: 5),
            Text(
              tr.availableAfterYourCurrentDropOff,
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
                    (remaining *
                            (_AcceptRideState
                                    ._onTripOfferLifetime
                                    .inMilliseconds /
                                1000))
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
                            tr.exclusiveSecondsS(seconds),
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
                        Flexible(
                          child: Text(
                            tr.onThisRide,
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
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          alertCoral,
                        ),
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
              title: tr.pickupMinutesMinAway(offer.pickupMinutes),
              subtitle: offer.pickup,
            ),
            const SizedBox(height: 9),
            _offerLocationRow(
              color: _AcceptRideState._ink,
              title: tr.tripMinutesMinTrip(offer.tripMinutes),
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
                    child: Text(
                      tr.deny,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
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
                    child: Text(
                      driverText(DriverTexts.offerAccept),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
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

  void _openWaitingTime() {
    if (!_countingWait) {
      return;
    }
    showWaitingTimeSheet(
      context,
      readSeconds: () => _waitSeconds,
      fullyPaid: _paidStopWait,
      terms: _waitTerms,
      onNoShow: _paidStopWait
          ? null
          : () {
              if (_waitSeconds < _noShowWaitSeconds || !mounted) {
                return;
              }
              _AcceptRideTrip(
                this,
              )._confirmCancellationReason(_AcceptRideState._noShowReason);
            },
    );
  }

  void _openRidePreferences() {
    pushSingle(
      context,
      MaterialPageRoute<void>(builder: (_) => const Preferences()),
    );
  }

  /// driver-u66: the label is bounded to the screen and lets touches
  /// through to the map; only the buttons are a map overlay.
  Widget _buildMapControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // The demo's own offers only: a live trip (a real rider, offers from
        // movera-server) is never labelled "Demo offers".
        if (!LiveDriverServices.active) ...[
          IgnorePointer(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: math.max(0, MediaQuery.sizeOf(context).width - 28),
              ),
              child: Text(
                _freshRadarLocation
                    ? tr.demoOffers
                    : tr.demoOffersLiveLocationUnavailableStale,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
        _mapOverlay(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              MapControlButton(
                key: const ValueKey<String>('active-ride-safety-button'),
                tooltip: tr.safetyToolkit,
                size: 50,
                onTap: () => showSafetyToolKitSheet(context),
                child: SvgPicture.asset(
                  AppAssets.mapSafety,
                  width: 26,
                  height: 26,
                ),
              ),
              if (!_browsing) ...[
                const SizedBox(height: 12),
                MapControlButton(
                  key: const ValueKey<String>('active-ride-google-maps-button'),
                  tooltip: tr.navigateWithGoogleMaps,
                  size: 56,
                  fill: MapControlButton.googleGrey,
                  onTap: _openGoogleMaps,
                  child: SvgPicture.asset(
                    AppAssets.mapGoogle,
                    width: 26,
                    height: 26,
                  ),
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
                            final t = Curves.easeOutCubic.transform(
                              _browsePulse.value,
                            );
                            const blue = Color(0xFF3B7DD8);
                            final size = 56 + 36 * t;
                            return Center(
                              key: const ValueKey<String>(
                                'active-ride-recenter-pulse',
                              ),
                              child: Container(
                                width: size,
                                height: size,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: blue.withValues(alpha: 0.16 * (1 - t)),
                                  border: Border.all(
                                    color: blue.withValues(
                                      alpha: 0.42 * (1 - t),
                                    ),
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
                    tooltip: tr.recenter,
                    size: 56,
                    fill: MapControlButton.recenterBlue,
                    // Follows the car again at the locate view and brings the
                    // sheet back; the same quiet window as leaving browse.
                    onTap: () =>
                        _AcceptRideTrip(this)._exitBrowse(locate: true),
                    child: SvgPicture.asset(
                      AppAssets.mapRecenter,
                      width: 24,
                      height: 24,
                    ),
                  ),
                ],
              ),
            ],
          ),
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
    final opened = await _externalMapAction.run(
      context,
      () =>
          widget.launchExternalMap?.call(uri) ??
          launchUrl(uri, mode: LaunchMode.externalApplication),
    );
    if (opened == false &&
        mounted &&
        ModalRoute.of(context)?.isCurrent == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr.googleMapsIsUnavailable)));
    }
  }

  Widget _buildRidePanel() {
    // Each frame only the sheet's shape follows the finger; its content
    // is built again when the face changes (or the trip does).
    // The empty vertical drag keeps a sheet drag in the gesture arena, as
    // the panel's own drag did, so a slide or a tap under it gives way;
    // TripSheetMotion moves the sheet itself, from the first pixel.
    return GestureDetector(
      onVerticalDragUpdate: (_) {},
      child: ValueListenableBuilder<double>(
        valueListenable: _ridePanelPosition,
        child: ValueListenableBuilder<TripSheetFace>(
          valueListenable: _tripMotion.face,
          builder: (context, face, _) => _buildRideFace(face),
        ),
        builder: (context, pos, content) {
          return Container(
            key: const ValueKey<String>('active-ride-panel'),
            decoration: BoxDecoration(
              color: _AcceptRideState._panel,
              // Flat and square like the bar; rounded only when full.
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(24 * _tripMotion.roundness(pos)),
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
            child: content,
          );
        },
      ),
    );
  }

  Widget _buildRideFace(TripSheetFace face) {
    // Three faces: the flat bar, the middle sheet with the rider and
    // the next action, and the clean full sheet with trip details.
    final compact = face == TripSheetFace.compact;
    final full = face == TripSheetFace.full;
    if (face == TripSheetFace.middle) {
      _measureRideMiddle();
      _AcceptRideSheet(this)._measureRideFull(ahead: true);
    }
    if (full) {
      _AcceptRideSheet(this)._measureRideFull();
    }
    return SafeArea(
      top: false,
      child: Column(
        children: [
          KeyedSubtree(
            key: ValueKey<String>('active-ride-panel-${_stage.name}'),
            child: const SizedBox.shrink(),
          ),
          // Grip line: the sheet can be pulled up for details.
          TripSheetGrip(
            key: _tripMotion.gripKey,
            shown: !compact,
            child: Padding(
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
            TripBottomBar(
              key: const ValueKey<String>('active-ride-expanded-header'),
              instruction: _tripBarInstruction,
              address: _tripBarAddress,
              onPreferences: _openRidePreferences,
              onTap: full ? _showRideMiddle : _showRideFull,
            ),
            if (!full) ...[
              _AcceptRideSheet(this)._buildFullAhead(),
              // Coming up from the bar the rider fades in; coming
              // down from the full sheet it is already there.
              if (_tripMotion.previousFace == TripSheetFace.compact)
                TripSheetFadeIn(child: _buildRiderRow())
              else
                _buildRiderRow(),
              TripSheetFadeIn(
                child: Padding(
                  key: _middleActionKey,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: _buildPrimaryAction(),
                ),
              ),
            ] else
              Expanded(
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(overscroll: false),
                  child: SingleChildScrollView(
                    key: _fullScrollKey,
                    controller: _tripMotion.fullScroll,
                    padding: const EdgeInsets.only(bottom: 16),
                    physics: const TopClampedBouncingScrollPhysics(),
                    child: Column(
                      key: _fullContentKey,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _fullDetails(),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// The full sheet's details: rider, trip cards, wait phase and radar.
  List<Widget> _fullDetails() => [
    _buildRiderRow(),
    const SizedBox(height: 8),
    TripSheetFadeIn(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            _AcceptRideSheet(this)._buildCurrentTripCard(),
            _AcceptRideSheet(this)._buildNextTripCard(),
          ],
        ),
      ),
    ),
    if (_countingWait) ...[
      const SizedBox(height: 12),
      Center(child: _waitPhaseChip()),
    ],
    _AcceptRideSheet(this)._buildRadarDock(),
  ];
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
      padding: const EdgeInsets.fromLTRB(12, 2, 16, 2),
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
          TripRoundButton(
            key: const ValueKey<String>('active-ride-call-rider'),
            tooltip: tr.callRider,
            onTap: _callRider,
            asset: AppAssets.solarPhoneCalling,
          ),
          const SizedBox(width: 12),
          _chatButton(),
        ],
      ),
    );
  }

  /// Chat with the rider; a live build counts their unread messages on it.
  Widget _chatButton() {
    final chat = LiveDriverServices.instance?.chat;
    TripRoundButton button(String tooltip) => TripRoundButton(
      key: const ValueKey<String>('active-ride-message-rider'),
      tooltip: tooltip,
      onTap: _messageRider,
      asset: AppAssets.solarChatRoundDots,
    );
    if (chat == null) {
      return button(tr.messageRider);
    }
    return ListenableBuilder(
      listenable: chat.thread(widget.tripId),
      builder: (_, __) {
        final unread = chat.unreadOf(widget.tripId);
        return Badge.count(
          key: const ValueKey<String>('active-ride-chat-unread'),
          count: unread,
          isLabelVisible: unread > 0,
          backgroundColor: const Color(0xFFE0474C),
          child: button(
            unread > 0 ? tr.chatNewMessages(unread) : tr.messageRider,
          ),
        );
      },
    );
  }

  void _callRider() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(RiderContactPolicy.unavailableMessage),
        backgroundColor: _AcceptRideState._ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void _messageRider() {
    pushSingle(
      context,
      BottomToTopTransition(
        Chat(riderDisplayName: widget.riderName, tripId: widget.tripId),
      ),
    );
  }

  Widget _buildPrimaryAction() {
    final accent = switch (_stage) {
      ActiveRideStage.headingToPickup => const Color(0xFF1C242C),
      ActiveRideStage.waitingForRider => const Color(0xFF146B45),
      ActiveRideStage.onTrip => const Color(0xFF1B3F6F),
    };

    // Arriving is a plain button; only trip steps after it slide.
    final arrival =
        _stage == ActiveRideStage.headingToPickup ||
        (_stage == ActiveRideStage.onTrip &&
            !_paidStopWait &&
            _stopCursor < widget.stopAddresses.length);
    if (arrival) {
      final near = _nearArrivalTarget;
      // driver-u67: still a live button when not near (it says why), so
      // its label stays readable, and a screen reader hears the reason.
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
            backgroundColor: near
                ? const Color(0xFF111614)
                : const Color(0xFFEEEFF1),
            foregroundColor: near ? Colors.white : const Color(0xFF5F6B72),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Semantics(
            hint: near
                ? null
                : _stage == ActiveRideStage.onTrip
                ? tr.moveWithin100MOfStop
                : tr.moveWithin100MOfPickup,
            child: Text(
              driverText(DriverTexts.tripArrived),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
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
          child: Text(
            driverText(DriverTexts.tripCollectCash),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
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
                    tr.ratingAndRides(
                      widget.riderRating?.toStringAsFixed(1) ?? tr.rrNew,
                      widget.riderTrips,
                    ),
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
                    child: Text(
                      tr.riderDetailsFromBookingWillAppear,
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
    final showNext =
        _onTripRadarState == _OnTripRadarState.secured &&
        _waybills.next != null;
    await showMoveraModalSheet<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      heightFactor: 0.78,
      fitContent: true,
      builder: (sheetContext) {
        return _CleanSheet(
          // Scrolls on short screens and large text, so "End trip early"
          // stays reachable.
          child: Flexible(
            child: SingleChildScrollView(
              key: const ValueKey<String>('trip-options-scroll'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_navigation.routeState == RouteLoadState.failed)
                    _CleanRow(
                      key: const ValueKey<String>('retry-route-option'),
                      title: tr.retryRoute,
                      subtitle: tr.routeUnavailableYourTripRemainsActive,
                      onTap: () {
                        if (popOwned(sheetContext)) {
                          unawaited(_navigation.retryRoute());
                        }
                      },
                    ),
                  _CleanRow(
                    key: const ValueKey<String>('current-trip-waybill-option'),
                    title: tr.currentWaybill,
                    subtitle: '$_pickupAddress → ${widget.dropoffAddress}',
                    onTap: () {
                      if (!popOwned(sheetContext)) return;
                      final record = _waybills.current;
                      if (record != null) {
                        showMoveraWaybillSheet(
                          context,
                          record,
                          title: tr.currentTripWaybill,
                        );
                      }
                    },
                  ),
                  if (showNext)
                    _CleanRow(
                      key: const ValueKey<String>('next-trip-waybill-option'),
                      title: tr.nextTripWaybill,
                      subtitle: _waybills.next!.dropoff,
                      onTap: () {
                        if (!popOwned(sheetContext)) return;
                        showMoveraWaybillSheet(
                          context,
                          _waybills.next!,
                          title: tr.nextTripWaybill,
                        );
                      },
                    ),
                  if (onTrip)
                    _CleanRow(
                      key: const ValueKey<String>('trip-destination-option'),
                      title: tr.destination,
                      subtitle: _destinationActive
                          ? (_destinationAddress ?? tr.onYourWay)
                          : tr.nextTripsOnYourWay,
                      onTap: () {
                        if (popOwned(sheetContext)) {
                          _openDestinationPicker();
                        }
                      },
                    ),
                  _CleanRow(
                    title: tr.safetyToolkit,
                    subtitle: SafetyAudioOption.toolkitSubtitle,
                    onTap: () {
                      if (!popOwned(sheetContext)) return;
                      showSafetyToolKitSheet(context);
                    },
                  ),
                  _CleanRow(
                    key: const ValueKey<String>('active-ride-cancel-option'),
                    title: onTrip ? tr.endTripEarly : tr.cancelTrip,
                    subtitle: onTrip ? tr.stopSafelyFirstReasonRequired : null,
                    danger: true,
                    last: true,
                    onTap: () {
                      if (!popOwned(sheetContext)) return;
                      _showCancellationReasons();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// The trip's cancel reasons; with [nextTrip], the same sheet cancels
  /// the secured next trip and the current one goes on.
  Future<void> _showCancellationReasons({bool nextTrip = false}) async {
    final isOnTrip = !nextTrip && _stage == ActiveRideStage.onTrip;
    final reasons = nextTrip
        ? _AcceptRideState._nextTripCancellationReasons
        : isOnTrip
        ? _AcceptRideState._onTripCancellationReasons
        : _stage == ActiveRideStage.waitingForRider &&
              !_paidStopWait &&
              _waitSeconds >= _noShowWaitSeconds
        ? <_TripCancellationReason>[
            _AcceptRideState._noShowReason,
            ..._AcceptRideState._preTripCancellationReasons,
          ]
        : _AcceptRideState._preTripCancellationReasons;

    final reason = await showMoveraModalSheet<_TripCancellationReason>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      heightFactor: 0.86,
      fitContent: true,
      builder: (sheetContext) {
        return _CleanSheet(
          key: ValueKey<String>(
            nextTrip
                ? 'next-trip-cancellation-reasons-sheet'
                : 'trip-cancellation-reasons-sheet',
          ),
          child: Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const BouncingScrollPhysics(),
              children: [
                Text(
                  nextTrip
                      ? tr.whyAreYouCancellingNextTripQuestion
                      : isOnTrip
                      ? tr.whyAreYouEndingTripQuestion
                      : tr.whyAreYouCancellingQuestion,
                  style: _CleanSheet.title,
                ),
                const SizedBox(height: 4),
                Text(
                  nextTrip
                      ? tr.yourCurrentTripContinues
                      : isOnTrip
                      ? tr.stopInSafePlaceFirst
                      : tr.pickReasonThatFitsBest,
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

    if (!mounted || reason == null) {
      return;
    }
    await _AcceptRideTrip(
      this,
    )._confirmCancellationReason(reason, nextTrip: nextTrip);
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

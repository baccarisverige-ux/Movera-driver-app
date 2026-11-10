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
    final first = _riderName.split(' ').first;
    return switch (_stage) {
      ActiveRideStage.headingToPickup => tr.headingToPickup,
      ActiveRideStage.waitingForRider => tr.waitingForFirst(first),
      _ => _stopCursor < _stopAddresses.length ? tr.toNextStop : tr.toDropOff,
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

  void _openWaitingTime() {
    if (!_countingWait) {
      return;
    }
    showWaitingTimeSheet(
      context,
      readSeconds: () => _waitSeconds,
      fullyPaid: _paidStopWait,
      terms: _waitTerms,
      // Q5: the rider's waiting cost so far as the server counts it.
      chargedSoFar: _paidStopWait ? null : _live?.waiting?.chargedSoFar,
      // Q2: the zone's rule, from the trip's terms.
      cancelAfterArrivedIsNoShow:
          !_paidStopWait && (_live?.terms?.cancelAfterArrivedIsNoShow ?? false),
      noShowAt: _paidStopWait ? null : _live?.waiting?.noShowAt,
      noShowDriverShare: _paidStopWait ? null : _noShowDriverShare,
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

  /// G5 re-check 2026-10-30: the trip sheet's "Trip settings" button
  /// opened the car types; it opens the driver's trip settings (the
  /// navigation app, status item 3), which lead to the car types.
  void _openTripSettings() {
    pushSingle(
      context,
      MaterialPageRoute<void>(builder: (_) => const TripSettings()),
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
                onTap: () => showSafetyToolKitSheet(context, duringTrip: true),
                child: SvgPicture.asset(
                  AppAssets.mapSafety,
                  width: 26,
                  height: 26,
                ),
              ),
              if (!_browsing) ...[
                const SizedBox(height: 12),
                // G5 status item 3: the app the driver chose in Trip
                // settings (Google Maps by default), shown as its logo (owner G5-3).
                ValueListenableBuilder<NavigationApp>(
                  valueListenable: NavigationAppSetting.current,
                  builder: (context, app, _) => MapControlButton(
                    key: const ValueKey<String>(
                      'active-ride-navigation-button',
                    ),
                    tooltip: app == NavigationApp.waze
                        ? tr.navigateWithWaze
                        : tr.navigateWithGoogleMaps,
                    size: 56,
                    fill: MapControlButton.googleGrey,
                    onTap: _openNavigationApp,
                    // Owner G5-3: the original look — the chosen app's logo
                    // (Google Maps keeps its logo; Waze its logo), no text.
                    child: SvgPicture.asset(
                      app == NavigationApp.waze
                          ? AppAssets.mapWaze
                          : AppAssets.mapGoogle,
                      key: ValueKey<String>(
                        app == NavigationApp.waze
                            ? 'active-ride-navigation-waze-logo'
                            : 'active-ride-navigation-google-logo',
                      ),
                      width: 26,
                      height: 26,
                    ),
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

  Future<void> _openNavigationApp() async {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    final target = _approachTarget ?? _dropoffPosition;
    final app = NavigationAppSetting.current.value;
    final uri = app.directionsTo(target.latitude, target.longitude);
    final opened = await _externalMapAction.run(
      context,
      () =>
          widget.launchExternalMap?.call(uri) ??
          launchUrl(uri, mode: LaunchMode.externalApplication),
    );
    if (opened == false &&
        mounted &&
        ModalRoute.of(context)?.isCurrent == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            app == NavigationApp.waze
                ? tr.wazeIsUnavailable
                : tr.googleMapsIsUnavailable,
          ),
        ),
      );
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
              onPreferences: _openTripSettings,
              onTap: _showRideMiddle,
              bookedTime:
                  widget.bookedTime ?? widget.restoredSnapshot?.badgeTime,
            )
          else ...[
            TripBottomBar(
              key: const ValueKey<String>('active-ride-expanded-header'),
              instruction: _tripBarInstruction,
              address: _tripBarAddress,
              onPreferences: _openTripSettings,
              onTap: full ? _showRideMiddle : _showRideFull,
              bookedTime:
                  widget.bookedTime ?? widget.restoredSnapshot?.badgeTime,
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // G7 live fix: the stop wait and its price show on
                      // the middle sheet from minute 1, not only in the
                      // full sheet.
                      if (_paidStopWait) ...[
                        _waitPhaseChip(
                          key: const ValueKey<String>(
                            'active-ride-stop-wait-line',
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      _buildPrimaryAction(),
                    ],
                  ),
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
  Widget _waitPhaseChip({Key key = const ValueKey('active-ride-wait-phase')}) {
    final color = _waitBarColor;
    return InkWell(
      key: key,
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
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        _riderName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _AcceptRideState._ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    // Q1 (contract v0.18.7 `riderSummary`): the rider's
                    // rating in the G4 offer card's chip, one decimal and a
                    // star, only while the zone shows it and the server
                    // sent one.
                    if (_riderRating case final rating?
                        when DriverOfferRules.current.card.riderRating) ...[
                      const SizedBox(width: 8),
                      Semantics(
                        label:
                            '${tr.riderRatingLabel} ${rating.toStringAsFixed(1)}',
                        excludeSemantics: true,
                        child: OfferBadge.riderRating(
                          rating.toStringAsFixed(1),
                          key: const ValueKey<String>(
                            'active-ride-rider-rating',
                          ),
                        ),
                      ),
                    ],
                  ],
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
            _stopCursor < _stopAddresses.length);
    if (arrival) {
      // G7 live fix: an aged fix is no reason to look disabled; the tap
      // asks for a fresh one and only then decides near or far.
      final near = _nearArrivalTarget || _AcceptRideTrip(this)._arrivalFixAged;
      // driver-u67: still a live button when not near (it says why), so
      // its label stays readable, and a screen reader hears the reason.
      return SizedBox(
        width: double.infinity,
        height: 58,
        child: FilledButton(
          key: const ValueKey<String>('active-ride-arrived-button'),
          onPressed: _stepBusy
              ? null
              : () {
                  _setMapGesturesBlocked(false);
                  unawaited(_AcceptRideTrip(this)._onArrivedTap());
                },
          style: tripStepStyle(
            FilledButton.styleFrom(
              elevation: 0,
              backgroundColor: near
                  ? const Color(0xFF111614)
                  : const Color(0xFFEEEFF1),
              foregroundColor: near ? Colors.white : const Color(0xFF5F6B72),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          child: tripStepLabel(
            busy: _stepBusy,
            child: Semantics(
              hint: near
                  ? null
                  : _stage == ActiveRideStage.onTrip
                  ? tr.moveWithin100MOfStop
                  : tr.moveWithin100MOfPickup,
              // Contract v0.7.1 §3.8: at a middle stop the tap is the server's
              // arrived-at-stop, from which the stop wait is paid.
              child: Text(
                driverText(
                  _stage == ActiveRideStage.onTrip
                      ? DriverTexts.tripArriveAtStop
                      : DriverTexts.tripArrived,
                ),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
          onPressed: _stepBusy
              ? null
              : () {
                  _setMapGesturesBlocked(false);
                  unawaited(_AcceptRideTrip(this)._collectCash());
                },
          style: tripStepStyle(
            FilledButton.styleFrom(
              elevation: 0,
              backgroundColor: const Color(0xFF7A5200),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          child: tripStepLabel(
            busy: _stepBusy,
            child: Text(
              driverText(DriverTexts.tripCollectCash),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
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
}

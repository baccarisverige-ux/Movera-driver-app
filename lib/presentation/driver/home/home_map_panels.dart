part of 'home.dart';

extension _HomeMapPanels on _DriverHomeState {
  void _onRadarSheetDragUpdate(DragUpdateDetails details) {
    if (!_panelController.isAttached || _outsideRadarOffer != null) {
      return;
    }
    _snapSheet.stopSpring();
    final range =
        _homeExpandedHeight(context) - MoveraSheetMetrics.collapsedHeight;
    if (range <= 0) {
      return;
    }
    final next = (_panelController.panelPosition - details.delta.dy / range)
        .clamp(0.0, 1.0);
    _panelController.panelPosition = next;
  }

  void _onRadarSheetDragEnd(DragEndDetails details) {
    _settleHomeSheet(velocity: details.primaryVelocity ?? 0);
  }

  Widget _radarDragToSheet({required Widget child}) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: _onRadarSheetDragStart,
      onVerticalDragUpdate: _onRadarSheetDragUpdate,
      onVerticalDragEnd: _onRadarSheetDragEnd,
      child: child,
    );
  }

  bool _isVersionNewer(String candidate, String current) {
    List<int> parse(String value) {
      return value
          .split('.')
          .map((part) => int.tryParse(part) ?? 0)
          .toList(growable: true);
    }

    final a = parse(candidate);
    final b = parse(current);
    final length = math.max(a.length, b.length);

    while (a.length < length) {
      a.add(0);
    }
    while (b.length < length) {
      b.add(0);
    }

    for (var index = 0; index < length; index++) {
      if (a[index] > b[index]) {
        return true;
      }
      if (a[index] < b[index]) {
        return false;
      }
    }

    return false;
  }

  /// One quiet row of the Home sheet list: line icon, label, and a value
  /// or a chevron when the row opens something.
  Widget _todayRow({
    Key? key,
    required MoveraMark mark,
    required String label,
    String? value,
    Color valueColor = const Color(0xFF111614),
    bool dot = false,
    VoidCallback? onTap,
    bool last = false,
  }) {
    const ink = Color(0xFF111614);
    return InkWell(
      key: key,
      onTap: onTap,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: Color(0xFFEDEFF0))),
        ),
        child: Row(
          children: [
            MoveraLineIcon(mark: mark, size: 20, color: ink),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ink,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (dot) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: valueColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (value != null)
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFB4BBB8),
                  size: 22,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _todayGroup(List<Widget Function(bool last)> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7E9EA)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) rows[i](i == rows.length - 1),
        ],
      ),
    );
  }

  Widget _sheetPointer(Widget child) {
    return PointerInterceptor(
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onSheetPointerDown,
        onPointerMove: _onSheetPointerMove,
        onPointerUp: _onSheetPointerEnd,
        onPointerCancel: _onSheetPointerEnd,
        child: child,
      ),
    );
  }

  /// Q19: holding the Radar asks "Go offline?" first; only Go offline
  /// takes the driver offline.
  Future<void> _confirmGoOffline() async {
    if (!mounted || !_isOnline || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    // A Match or Accept already sent is answered first: won, its trip
    // opens; the driver can go offline after that (driver-u131: the
    // island's long press reaches here with an Exclusive Accept out).
    if (_HomeOfferRules(this)._claimInFlight) {
      IslandMessages.show(HomeIslandNotices.matching);
      return;
    }
    if (!await showGoOfflineConfirm(context)) {
      return;
    }
    if (mounted && _isOnline) {
      await _goOffline();
    }
  }

  /// The radar button with the sheet closed: a long press asks to go
  /// offline (Q19); a tap does what the face says.
  Widget _radarLongPressOff(Widget radar) => GestureDetector(
    key: const ValueKey<String>('home-radar-long-press'),
    onLongPress: () {
      HapticFeedback.mediumImpact();
      unawaited(_confirmGoOffline());
    },
    child: radar,
  );

  /// The online radar with the sheet open: same look, "Hold · OFF ·
  /// Go offline"; a one-second hold vibrates and asks "Go offline?".
  Widget _holdOffRadar() {
    return RadarHoldOff(
      onConfirmed: () => unawaited(_confirmGoOffline()),
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _goOnlinePulseController,
          _radarSweepController,
        ]),
        builder: (context, child) => _buildRadarOrb(
          title: tr.hold,
          status: tr.orbOff,
          subtitle: tr.goOffline,
          active: true,
          offer:
              _hasRideOffers ||
              _radarHomeOffers.isNotEmpty ||
              _pendingRadarHomeOffers.isNotEmpty,
          pulse: _goOnlinePulseController.value,
          sweep: _radarSweepController.value,
        ),
      ),
    );
  }

  /// While offers show, the radar reads "Accept · MATCH" and tapping it
  /// matches the deck's front trip, same as its Match button.
  Widget _acceptRadar(_HomeDirectOffer front) {
    final busy = _homeRadarMatchingOfferId != null;
    return KeyedSubtree(
      key: const ValueKey<String>('home-radar-accept'),
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _goOnlinePulseController,
          _radarSweepController,
          _radarMotionController,
        ]),
        builder: (context, child) => _buildRadarOrb(
          title: busy ? tr.matching : tr.accept,
          status: tr.orbMatch,
          subtitle: busy ? tr.pleaseWait : tr.tapToAccept,
          active: true,
          offer: true,
          pulse: _goOnlinePulseController.value,
          sweep: _radarSweepController.value,
          wedge: _radarWedge(found: true),
          statusPulse: _matchPulse,
          onTap: busy
              ? null
              : () => _HomeOfferRadar(this)._startHomeRadarMatch(front),
        ),
      ),
    );
  }

  Widget _sheetRow({
    required Key key,
    required Widget icon,
    required String label,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      child: SizedBox(
        height: 72,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              SizedBox(width: 32, child: Center(child: icon)),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _HomeMapSheet._sheetText,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (trailing != null) Flexible(child: trailing),
            ],
          ),
        ),
      ),
    );
  }

  Widget _solarIcon(String asset) => SvgPicture.asset(
    asset,
    width: 26,
    height: 26,
    colorFilter: const ColorFilter.mode(
      _HomeMapSheet._sheetInk,
      BlendMode.srcIn,
    ),
  );

  /// Home sheet, open: "Today", then one card with driving time,
  /// Performance and the latest waybill. Each row opens its details.
  List<Widget> _todayList() {
    final performance = DriverPerformanceConfig.current;
    final showPerformance =
        performance.showRating ||
        performance.showAcceptanceRate ||
        performance.showCancellationRate;
    return [
      // Contract v0.17.0 (owner group 2 items 2, 3 and 9): "Important
      // reminders (N)" first (live builds; the demo has none).
      _HomeAccount(this)._remindersBox(),
      // Contract v0.10.0 §19: the Content page's driver-home and
      // driver-event texts (live builds; the demo has none).
      for (final item in DriverContentStore.instance.home)
        DriverContentCard(item: item),
      Padding(
        padding: EdgeInsets.only(bottom: 14),
        child: Text(
          tr.rightNow,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _HomeMapSheet._sheetSub,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _HomeMapSheet._sheetLine),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0811181C),
              blurRadius: 6,
              offset: Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            DrivingTimeRow(
              clock: DrivingTimeClock.instance,
              running: _isOnline,
              onTap: _openDrivingTime,
            ),
            // Q23: cash rides on or off. Off: no cash offers. One node,
            // so the switch is read with its label (UI-12).
            MergeSemantics(
              child: _sheetRow(
                key: const ValueKey<String>('home-sheet-cash'),
                icon: _solarIcon(AppAssets.solarWadOfMoney),
                label: tr.cashRides,
                trailing: Switch.adaptive(
                  key: const ValueKey<String>('home-sheet-cash-switch'),
                  value: DriverOfferPreferences.acceptsCash.value,
                  activeTrackColor: const Color(0xFF1C6B45),
                  onChanged: _HomeOfferRules(this)._setAcceptsCash,
                ),
                onTap: () => _HomeOfferRules(
                  this,
                )._setAcceptsCash(!DriverOfferPreferences.acceptsCash.value),
              ),
            ),
            if (showPerformance)
              _sheetRow(
                key: const ValueKey<String>('home-sheet-performance'),
                icon: _solarIcon(AppAssets.solarMedalRibbonStar),
                label: tr.performance,
                onTap: _openPerformance,
              ),
            ValueListenableBuilder<WaybillRecord?>(
              valueListenable: _waybills.lastListenable,
              builder: (context, lastWaybill, _) => _sheetRow(
                key: const ValueKey<String>('home-sheet-last-waybill'),
                icon: _solarIcon(AppAssets.solarBillList),
                label: tr.latestWaybill,
                trailing: lastWaybill == null
                    ? Text(
                        tr.noneYet,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _HomeMapSheet._sheetSub,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
                onTap: lastWaybill == null
                    ? null
                    : () => showMoveraWaybillSheet(
                        context,
                        lastWaybill,
                        title: tr.latestWaybill,
                      ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Future<void> _openDetailsSheet({
    required String title,
    required List<Widget Function(bool last)> rows,
    String? note,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _HomeMapSheet._sheetInk,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _todayGroup(rows),
              if (note != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                  child: Text(
                    note,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _HomeMapSheet._sheetSub,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPerformance() {
    final performance = DriverPerformanceConfig.current;
    unawaited(
      _openDetailsSheet(
        title: tr.performance,
        rows: [
          if (performance.showRating)
            (last) => _todayRow(
              mark: MoveraMark.star,
              label: tr.rating,
              value: performance.ratingLabel,
              last: last,
            ),
          if (performance.showAcceptanceRate)
            (last) => _todayRow(
              mark: MoveraMark.check,
              label: tr.acceptance,
              value: performance.acceptanceLabel,
              last: last,
            ),
          if (performance.showCancellationRate)
            (last) => _todayRow(
              mark: MoveraMark.close,
              label: tr.cancellation,
              value: performance.cancellationLabel,
              last: last,
            ),
        ],
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:movera/presentation/driver/accept%20ride/trip_island.dart';
import 'package:movera/presentation/driver/home/components/digital_island.dart';
import 'package:movera/widgets/route_mark_pins.dart';

/// Top of the Active Ride map: the navigation card, which the driver can
/// pull down to reveal the island (menu, money, search) above it, and push
/// back up to hide it. Once revealed, a touch anywhere but the island's
/// middle puts the card back; the touched button still does its job.
class TripTopReveal extends StatefulWidget {
  const TripTopReveal({
    super.key,
    required this.child,
    this.onMenu,
    this.onSearch,
    this.onHistory,
    this.status,
    this.lastTripLabel = DigitalIslandParts.noAmount,
    this.initiallyOpen = false,
  });

  /// The navigation card.
  final Widget child;
  final VoidCallback? onMenu;
  final VoidCallback? onSearch;
  final VoidCallback? onHistory;

  /// The trip's step for the island, e.g. "To pickup".
  final String? status;
  final String lastTripLabel;
  final bool initiallyOpen;

  @override
  State<TripTopReveal> createState() => _TripTopRevealState();
}

class _TripTopRevealState extends State<TripTopReveal> {
  late bool _open = widget.initiallyOpen;
  double _drag = 0;
  final GlobalKey _middleKey = GlobalKey();
  bool _routed = false;

  @override
  void initState() {
    super.initState();
    _syncRoute();
  }

  @override
  void dispose() {
    _unroute();
    super.dispose();
  }

  void _setOpen(bool open) {
    if (_open == open) { return; }
    setState(() => _open = open);
    _syncRoute();
  }

  void _syncRoute() => _open ? _route() : _unroute();

  void _route() {
    if (_routed) { return; }
    _routed = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onAnyPointer);
  }

  void _unroute() {
    if (!_routed) { return; }
    _routed = false;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onAnyPointer);
  }

  /// Any touch while revealed closes it, except on the island's middle
  /// (its money and messages); buttons still get their tap.
  void _onAnyPointer(PointerEvent event) {
    if (event is! PointerDownEvent || !_open || !mounted) { return; }
    final box = _middleKey.currentContext?.findRenderObject();
    if (box is RenderBox && box.attached) {
      final local = box.globalToLocal(event.position);
      if (box.paintBounds.contains(local) && !_onIslandSides(box, local)) {
        return;
      }
    }
    _setOpen(false);
  }

  // The menu and search ends of the island act, then close it.
  bool _onIslandSides(RenderBox box, Offset local) {
    const side = 54 * 0.8;
    final islandWidth = DigitalIslandParts.width * 0.8;
    final left = (box.size.width - islandWidth) / 2;
    return local.dx < left + side || local.dx > left + islandWidth - side;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _drag += details.delta.dy;
    if (!_open && _drag > 14) {
      _setOpen(true);
      _drag = 0;
    } else if (_open && _drag < -14) {
      _setOpen(false);
      _drag = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: _open
                ? Padding(
                    key: const ValueKey<String>('trip-island-open'),
                    padding: EdgeInsets.only(top: math.max(pad.top - 4, 10)),
                    child: KeyedSubtree(
                      key: _middleKey,
                      child: TripIsland(
                        status: widget.status,
                        onMenu: widget.onMenu,
                        onSearch: widget.onSearch,
                        onHistory: widget.onHistory,
                        lastTripLabel: widget.lastTripLabel,
                      ),
                    ),
                  )
                : const SizedBox(
                    key: ValueKey<String>('trip-island-closed'),
                    width: double.infinity,
                  ),
          ),
        ),
        GestureDetector(
          key: const ValueKey<String>('trip-top-reveal'),
          behavior: HitTestBehavior.translucent,
          onVerticalDragStart: (_) => _drag = 0,
          onVerticalDragUpdate: _onDragUpdate,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // With the island shown, the card sits right under it.
              MediaQuery.removePadding(
                context: context,
                removeTop: _open,
                child: widget.child,
              ),
              // Small handle: the card can be pulled down.
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF111614).withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Small top card shown while the trip sheet is lifted: only where the
/// driver is heading, street on the first line and area on the second.
class TripDestinationCard extends StatelessWidget {
  const TripDestinationCard({
    super.key,
    required this.address,
    this.kind = RouteMarkKind.pickup,
    this.fallbackArea,
  });

  /// Full address, e.g. "Porslinsvägen 3, Södertälje".
  final String address;

  /// Which route mark leads the card, as on the map.
  final RouteMarkKind kind;

  /// Second line when [address] has no area part.
  final String? fallbackArea;

  @override
  Widget build(BuildContext context) {
    final comma = address.indexOf(',');
    final street = (comma < 0 ? address : address.substring(0, comma)).trim();
    final rest = comma < 0 ? '' : address.substring(comma + 1).trim();
    final area = rest.isNotEmpty ? rest : (fallbackArea ?? '').trim();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        8,
        MediaQuery.paddingOf(context).top + 6,
        8,
        0,
      ),
      child: Container(
        key: const ValueKey<String>('active-ride-destination-card'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            RouteMarkIcon(kind, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    street,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (area.isNotEmpty)
                    Text(
                      area,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
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

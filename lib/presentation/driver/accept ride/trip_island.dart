import 'package:movera/core/l10n/driver_l10n.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:movera/presentation/driver/home/components/digital_island.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/components/island_side_hit_slop.dart';

/// Shared dimensions of the default island as displayed on the driver map.
abstract final class TripIslandGeometry {
  static const scale = .8;
  static const width = DigitalIslandParts.width * scale;
  static const height = DigitalIslandParts.height * scale;
  static const maximumWidth = width * 1.15;
}

/// The Home island on the trip screen: menu, the money screen and search,
/// the same black island as on Home. It opens on the trip's step, e.g.
/// "To pickup"; a tap closes that message and the island works as usual.
class TripIsland extends StatefulWidget {
  const TripIsland({
    super.key,
    this.status,
    this.onMenu,
    this.onSearch,
    this.onHistory,
    required this.lastTripLabel,
  });

  /// The trip's step, e.g. "Waiting for Angelica". A new step shows again
  /// after an earlier one was closed.
  final String? status;
  final VoidCallback? onMenu;
  final VoidCallback? onSearch;
  final VoidCallback? onHistory;
  final String lastTripLabel;

  @override
  State<TripIsland> createState() => _TripIslandState();
}

enum _Face { hidden, lastTrip, today, history }

class _TripIslandState extends State<TripIsland> {
  _Face _face = _Face.hidden;
  String? _closed;
  Timer? _idle;
  int _seq = 0;

  String? get _message {
    final status = widget.status;
    return status == null || status == _closed ? null : status;
  }

  @override
  void didUpdateWidget(TripIsland oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _closed = null;
      _seq++;
    }
  }

  @override
  void dispose() {
    _idle?.cancel();
    super.dispose();
  }

  void _onTap() {
    HapticFeedback.selectionClick();
    final message = _message;
    if (message != null) {
      setState(() => _closed = message);
      return;
    }
    setState(
      () => _face = _Face.values[(_face.index + 1) % _Face.values.length],
    );
    if (_face == _Face.today) {
      unawaited(DigitalIslandParts.refreshToday());
    }
    _idle?.cancel();
    if (_face != _Face.hidden) {
      // Left alone for 5 s, the money hides again.
      _idle = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() => _face = _Face.hidden);
        }
      });
    }
  }

  Widget _faceView() => switch (_face) {
    _Face.hidden => DigitalIslandParts.hiddenFace(),
    _Face.lastTrip => DigitalIslandParts.amountFace(
      'island-last-trip',
      tr.lastTrip,
      widget.lastTripLabel,
    ),
    _Face.today => DigitalIslandParts.todayFace(),
    _Face.history => DigitalIslandParts.historyFace(),
  };

  @override
  Widget build(BuildContext context) {
    const height = DigitalIslandParts.height;
    const scale = TripIslandGeometry.scale;
    final message = _message;
    final maxWidth = MediaQuery.sizeOf(context).width / scale - 32;
    final width = message != null
        ? (DigitalMessageFace.widthFor(context, message) + 14 + 14 + 2 + 36)
              .clamp(math.min(DigitalIslandParts.width, maxWidth), maxWidth)
              .toDouble()
        : math.min(maxWidth, DigitalIslandParts.width);
    Widget side(Widget button) => AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      width: message == null ? 54 : 14,
      child: ClipRect(
        child: OverflowBox(
          minWidth: 54,
          maxWidth: 54,
          child: IgnorePointer(
            ignoring: message != null,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: message == null ? 1 : 0,
              child: button,
            ),
          ),
        ),
      ),
    );
    final (color, icon) = DigitalIslandParts.toneLook(IslandTone.info);
    final island = DigitalIslandShell(
      width: width,
      height: height,
      // On a trip the driver is driving: no light passing over it.
      calm: true,
      duration: const Duration(milliseconds: 680),
      curve: Curves.easeOutBack,
      child: Row(
        children: [
          side(
            Tooltip(
              message: tr.menu,
              child: IslandSideButton(
                outward: AxisDirection.left,
                child: InkWell(
                  onTap: widget.onMenu,
                  child: SizedBox(
                    width: 54,
                    height: height,
                    child: DigitalIslandParts.menuIcon(),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (details) {
                if (_face == _Face.history &&
                    (details.primaryVelocity ?? 0).abs() > 80) {
                  widget.onHistory?.call();
                }
              },
              child: InkWell(
                key: const ValueKey<String>('trip-island-middle'),
                onTap: _onTap,
                onLongPress: message != null || widget.onHistory == null
                    ? null
                    : () {
                        HapticFeedback.mediumImpact();
                        widget.onHistory!();
                      },
                child: SizedBox(
                  height: height,
                  child: DigitalFaceSwitcher(
                    child: message != null
                        ? DigitalMessageFace(
                            key: ValueKey<String>('trip-island-message-$_seq'),
                            title: message,
                            color: color,
                            icon: icon,
                            pulse: true,
                          )
                        : _faceView(),
                  ),
                ),
              ),
            ),
          ),
          side(
            Tooltip(
              message: tr.searchDestination,
              child: IslandSideButton(
                outward: AxisDirection.right,
                child: InkWell(
                  key: const ValueKey<String>('trip-island-search'),
                  onTap: widget.onSearch,
                  child: const SizedBox(
                    width: 54,
                    height: height,
                    child: DigitalIslandParts.searchIcon,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    // Drawn at 80 %, like on Home; the box keeps the scaled height.
    return SizedBox(
      key: const ValueKey<String>('trip-top-island'),
      width: double.infinity,
      height: height * scale,
      child: OverflowBox(
        alignment: Alignment.topCenter,
        maxHeight: height,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topCenter,
          child: Align(alignment: Alignment.topCenter, child: island),
        ),
      ),
    );
  }
}

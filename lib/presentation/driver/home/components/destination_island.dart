import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

const TextStyle _placeStyle = TextStyle(
  color: Colors.white,
  fontSize: 15,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.1,
);
const TextStyle _etaStyle = TextStyle(
  color: Color(0xFFA9B0B8),
  fontSize: 14,
  fontWeight: FontWeight.w600,
);

/// Destination mode on the island: map pin, "Centralplan 15 · 35 min".
class DigitalDestinationFace extends StatelessWidget {
  const DigitalDestinationFace({
    super.key,
    required this.place,
    required this.eta,
  });

  final String place;

  /// "35 min", or null while unknown.
  final String? eta;

  static const double _icon = 20;
  static const double _gap = 8;

  /// Width the face needs: icon, gap and words.
  static double widthFor(BuildContext context, String place, String? eta) {
    final painter = TextPainter(
      text: TextSpan(children: [
        TextSpan(text: place, style: _placeStyle),
        if (eta != null) TextSpan(text: ' · $eta', style: _etaStyle),
      ]),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return _icon + _gap + painter.width + 4;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            AppAssets.solarMapPoint,
            width: _icon,
            height: _icon,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
          const SizedBox(width: _gap),
          Flexible(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: place, style: _placeStyle),
                if (eta != null) TextSpan(text: ' · $eta', style: _etaStyle),
              ]),
              key: const ValueKey<String>('island-destination'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// White bar over the dock once a destination is confirmed:
/// "35 min · 35 km" over "Destination mode until 02:40", which turns into
/// "Finding trips…" after a few seconds while [finding].
class DestinationModeBar extends StatefulWidget {
  const DestinationModeBar({
    super.key,
    required this.summary,
    required this.until,
    required this.finding,
    this.onTap,
  });

  final String summary;
  final String until;
  final bool finding;
  final VoidCallback? onTap;

  @override
  State<DestinationModeBar> createState() => _DestinationModeBarState();
}

class _DestinationModeBarState extends State<DestinationModeBar> {
  Timer? _timer;
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 4), () {
      if (mounted) { setState(() => _settled = true); }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final line = _settled && widget.finding
        ? 'Finding trips…'
        : 'Destination mode until ${widget.until}';
    return PointerInterceptor(
      child: Material(
        color: Colors.white,
        elevation: 4,
        shadowColor: const Color(0x3311181C),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: const ValueKey<String>('destination-mode-bar'),
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.summary,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Color(0xFF111315),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: Text(
                    line,
                    key: ValueKey<String>(line),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF5D646C),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tapping the destination island: where to, how long, and
/// "Turn off destination".
Future<void> showDestinationDetailsSheet(
  BuildContext context, {
  required String place,
  required String address,
  required String? summary,
  required String? until,
  required VoidCallback onShowRoute,
  required VoidCallback onTurnOff,
}) {
  const ink = Color(0xFF111315);
  const muted = Color(0xFF5D646C);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => PointerInterceptor(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            key: const ValueKey<String>('destination-details'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F3F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SvgPicture.asset(AppAssets.solarMapPoint,
                        width: 22, height: 22,
                        colorFilter:
                            const ColorFilter.mode(ink, BlendMode.srcIn)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(place,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: ink,
                                fontSize: 19,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(color: muted, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              if (summary != null || until != null) ...[
                const SizedBox(height: 14),
                Text(
                  [
                    if (summary != null) summary,
                    if (until != null) 'Destination mode until $until',
                  ].join(' · '),
                  style: const TextStyle(
                      color: ink, fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  key: const ValueKey<String>('destination-details-route'),
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    onShowRoute();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ink,
                    side: const BorderSide(color: Color(0xFFDADEE1)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Show route',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  key: const ValueKey<String>('destination-mode-end'),
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    onTurnOff();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: ink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Turn off destination',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

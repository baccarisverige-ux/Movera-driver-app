import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';

/// The trip sheet's header: what to do next and where, plus Ride
/// preferences. Waiting clocks belong exclusively to the island.
class TripBottomBar extends StatelessWidget {
  const TripBottomBar({
    super.key,
    required this.instruction,
    required this.address,
    required this.onPreferences,
    required this.onTap,
  });

  /// The next step, e.g. "Pick up Angelica".
  final String instruction;

  /// Where that step happens.
  final String address;
  final VoidCallback onPreferences;

  /// Lifts the sheet (or lowers it from full details).
  final VoidCallback onTap;

  static const _ink = Color(0xFF303A3F);
  static const _muted = Color(0xFF7D898F);

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 76,
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: tr.tripDetails,
            child: InkWell(
              key: const ValueKey('trip-bar-details'),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      instruction,
                      key: const ValueKey('trip-bar-instruction'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      address,
                      key: const ValueKey('trip-bar-next-address'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Tooltip(
          // G5: the driver's trip settings (navigation app, car types).
          message: tr.tripSettings,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPreferences,
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: SvgPicture.asset(
                    AppAssets.navMenuBranch,
                    width: 22,
                    height: 22,
                    colorFilter: const ColorFilter.mode(_ink, BlendMode.srcIn),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    ),
  );
}

import 'package:flutter/material.dart';

/// Full-width, SafeArea-aware top status/navigation chrome.
class TripStatusBanner extends StatelessWidget {
  const TripStatusBanner({
    super.key,
    required this.title,
    required this.subtitle,
    this.leading,
    this.trailing,
    this.accent = const Color(0xFF19865C),
    this.busy = false,
  });

  final String title;
  final String subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Color accent;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF252E3A);
    const muted = Color(0xFF7D898F);
    final pad = MediaQuery.paddingOf(context);

    return Material(
      color: const Color(0xFFFCFDFC),
      elevation: 10,
      shadowColor: const Color(0x33172027),
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16 + pad.left,
          10 + pad.top,
          16 + pad.right,
          12,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: busy
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: accent,
                        ),
                      )
                    : leading ??
                          Icon(Icons.check_rounded, color: accent, size: 22),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.25,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

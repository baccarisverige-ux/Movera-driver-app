import 'package:flutter/material.dart';

enum LedCountTone { mint, grey }

/// A small seven-segment counter ("01 NEW"). Unlit "88" segments sit behind
/// the digits like on a real display.
class LedCountBadge extends StatelessWidget {
  const LedCountBadge({
    super.key,
    required this.count,
    this.label = 'NEW',
    this.tone = LedCountTone.mint,
    this.trailing,
  });

  final int count;
  final String label;
  final LedCountTone tone;

  /// Small mark after the label, e.g. a chevron when the badge opens a list.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final mint = tone == LedCountTone.mint;
    final digitColor = mint ? const Color(0xFF58E5A6) : const Color(0xFF3A444B);
    final digits = count.clamp(0, 99).toString().padLeft(2, '0');
    final digitStyle = TextStyle(
      fontFamily: 'DSEG7',
      fontSize: 14,
      height: 1,
      fontWeight: FontWeight.w700,
      color: digitColor,
      shadows: mint
          ? [
              Shadow(
                color: digitColor.withValues(alpha: 0.55),
                blurRadius: 6,
              ),
            ]
          : null,
    );
    return Semantics(
      label: '$count ${label.toLowerCase()}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: mint ? const Color(0xFF0F1416) : const Color(0xFFF4F5F6),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: mint ? const Color(0xFF26302F) : const Color(0xFFDCE0E3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Text(
                  '88',
                  style: digitStyle.copyWith(
                    color: digitColor.withValues(alpha: mint ? 0.09 : 0.08),
                    shadows: const [],
                  ),
                ),
                Text(digits, style: digitStyle),
              ],
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: mint ? const Color(0xFF7E8C88) : const Color(0xFF6B757C),
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:movera/core/l10n/driver_l10n.dart';

/// Audit 2026-11-01: what a live build shows on a page that has no server
/// data yet, in place of the demo's example figures. Plain and honest:
/// "Coming soon" and one line saying what will appear.
class LiveSoonNotice extends StatelessWidget {
  const LiveSoonNotice({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('live-soon-notice'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6E8EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr.acctComingSoon,
            style: const TextStyle(
              color: Color(0xFF252E3A),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFF5F6B72),
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

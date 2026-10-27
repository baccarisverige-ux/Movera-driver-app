import 'dart:async';

import 'package:flutter/material.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/l10n/driver_l10n.dart';

/// Contract v0.7.1 (`contract.json#surgeNotice`, owner 2026-10-27): when a
/// surge starts in the driver's zone, or an admin presses "Tell drivers
/// now", the server sends a `surge_started` notice. Home shows the newest
/// unread one at the top, in the words the server sent in the driver's
/// language, until the driver closes it (it is then read on the server).
/// While Home is open the notices are read again every [pollEvery].
class SurgeNoticeBanner extends StatefulWidget {
  const SurgeNoticeBanner({
    super.key,
    required this.session,
    this.pollEvery = const Duration(seconds: 60),
  });

  final DriverAccountSession session;
  final Duration pollEvery;

  @override
  State<SurgeNoticeBanner> createState() => _SurgeNoticeBannerState();
}

class _SurgeNoticeBannerState extends State<SurgeNoticeBanner> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(
      widget.pollEvery,
      (_) => unawaited(widget.session.refreshUnread()),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ServerNotification?>(
      valueListenable: widget.session.surgeNotice,
      builder: (context, notice, _) {
        if (notice == null) return const SizedBox.shrink();
        final multiplier = notice.surgeMultiplier;
        return Semantics(
          container: true,
          liveRegion: true,
          child: Material(
            key: const ValueKey<String>('surge-notice-banner'),
            color: const Color(0xFF7A1F2B),
            elevation: 6,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      multiplier == null
                          ? '↑'
                          : '×${multiplier.toStringAsFixed(1)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          notice.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          notice.body,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const ValueKey<String>('surge-notice-close'),
                    tooltip: tr.close,
                    onPressed: () => unawaited(widget.session.dismissSurge()),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

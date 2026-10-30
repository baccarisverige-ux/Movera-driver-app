import 'package:flutter/material.dart';
import 'package:movera/core/l10n/driver_l10n.dart';

/// Driver group 3 ("Already decided": a permanent Home reason card with
/// tap-to-fix instead of a 6 s snackbar). Why the driver is not online, or
/// what he should know before he goes: the server's refusal, "Turn on
/// location to go online" with Open Settings, "You were set offline – tap
/// to go online again", the one-time battery saver warning. It sits above
/// the radar, so it never covers Go online, and stays until it is fixed,
/// tapped or closed.
class HomeReasonCard extends StatelessWidget {
  const HomeReasonCard({
    super.key,
    required this.text,
    this.actionLabel,
    this.onAction,
    this.onTap,
    this.onClose,
    this.tone = HomeReasonTone.problem,
  });

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onTap;
  final VoidCallback? onClose;
  final HomeReasonTone tone;

  static const red = Color(0xFFD03A2B);
  static const orange = Color(0xFFE08A00);
  static const blue = Color(0xFF237F9B);

  @override
  Widget build(BuildContext context) {
    final accent = switch (tone) {
      HomeReasonTone.problem => red,
      HomeReasonTone.warning => orange,
      HomeReasonTone.info => blue,
    };
    return Semantics(
      liveRegion: true,
      button: onTap != null,
      child: Material(
        color: Colors.white,
        elevation: 6,
        shadowColor: const Color(0x33000000),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: accent, width: 4)),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                Icon(
                  tone == HomeReasonTone.info
                      ? Icons.power_settings_new_rounded
                      : Icons.info_outline_rounded,
                  color: accent,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: Color(0xFF1D2427),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
                if (actionLabel != null)
                  TextButton(
                    key: const ValueKey<String>('home-reason-action'),
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      foregroundColor: accent,
                      minimumSize: const Size(48, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(
                      actionLabel!,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                if (onClose != null)
                  IconButton(
                    key: const ValueKey<String>('home-reason-close'),
                    tooltip: tr.close,
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: const Color(0xFF7D898F),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum HomeReasonTone { problem, warning, info }

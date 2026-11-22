import 'package:flutter/material.dart';
import 'package:movera/core/app_update/min_app_version.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:url_launcher/url_launcher.dart';

/// Contract v0.18.154 P16c (`contract.json#appUpdate.apps`): this build is
/// below the zone's minimum version. One full screen over every screen,
/// "Update Movera to continue", with Update (the zone's store link for
/// this platform, else [fallbackStore]) and SOS. It goes away only when a
/// newer driver document says the version is OK.
class MinVersionScreen extends StatefulWidget {
  const MinVersionScreen({
    super.key,
    required this.onSos,
    required this.fallbackStore,
    this.openStore,
  });

  final VoidCallback onSos;
  final String fallbackStore;
  final Future<bool> Function(Uri store)? openStore;

  @override
  State<MinVersionScreen> createState() => _MinVersionScreenState();
}

class _MinVersionScreenState extends State<MinVersionScreen> {
  bool _failed = false;

  Future<void> _open() async {
    final uri = MinAppVersion.storeUri(widget.fallbackStore);
    var opened = false;
    try {
      opened =
          await (widget.openStore ??
              (uri) =>
                  launchUrl(uri, mode: LaunchMode.externalApplication))(uri);
    } catch (_) {
      opened = false;
    }
    if (mounted) setState(() => _failed = !opened);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        key: const ValueKey<String>('min-version-required'),
        color: const Color(0xFFF9FBFA),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const Icon(
                  Icons.system_update_rounded,
                  size: 56,
                  color: Color(0xFF111614),
                ),
                const SizedBox(height: 18),
                Text(
                  tr.minVersionTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF111614),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  tr.minVersionBody,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF5D6A70),
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
                const Spacer(),
                if (_failed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      tr.contentUpdateStoreFailed,
                      key: const ValueKey<String>('min-version-store-failed'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFCB424B)),
                    ),
                  ),
                FilledButton(
                  key: const ValueKey<String>('min-version-update'),
                  onPressed: _open,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF111614),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    tr.minVersionUpdate,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  key: const ValueKey<String>('min-version-sos'),
                  onPressed: widget.onSos,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFCB424B),
                    minimumSize: const Size.fromHeight(50),
                    side: const BorderSide(color: Color(0xFFCB424B)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.sos_rounded),
                  label: Text(tr.safetySos),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

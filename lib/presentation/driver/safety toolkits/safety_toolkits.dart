import 'package:movera/widgets/owned_route_exit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/safety/emergency_dial.dart';
import 'package:url_launcher/url_launcher.dart';

Future<T?> showSafetyToolKitSheet<T>(BuildContext context) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xFF172027).withValues(alpha: 0.30),
    builder: (_) => const SafetyToolKits(),
  );
}

class SafetyToolKits extends StatefulWidget {
  const SafetyToolKits({super.key, this.launchEmergencyDial});

  final Future<bool> Function()? launchEmergencyDial;

  @override
  State<SafetyToolKits> createState() => _SafetyToolKitsState();
}

class _SafetyToolKitsState extends State<SafetyToolKits> {
  static const Color _ink = Color(0xFF252E3A);
  static const Color _muted = Color(0xFF7D898F);
  static const Color _green = Color(0xFF19865C);
  static const Color _line = Color(0xFFE5E9EB);
  static const Color _canvas = Color(0xFFF4F6F7);

  String? _status;
  bool _emergencyInFlight = false;

  bool get _ownsRoute => mounted && ModalRoute.of(context)?.isCurrent == true;

  void _showMessage(String message) {
    if (!_ownsRoute) return;
    setState(() => _status = message);
  }

  Future<void> _confirmEmergencyCall() async {
    if (!_ownsRoute || _emergencyInFlight) return;
    _emergencyInFlight = true;
    try {
      final call = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text(
              'Contact emergency services?',
              style: TextStyle(
                color: _ink,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: const Text(
              'Use 112 only when you or someone else needs immediate help.',
              style: TextStyle(color: _muted, fontSize: 13, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => popOwned(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => popOwned(dialogContext, true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFCB424B),
                ),
                child: const Text('Call 112'),
              ),
            ],
          );
        },
      );

      if (call == true && _ownsRoute) {
        final result = await handoffEmergencyDial(
          widget.launchEmergencyDial ?? () => launchUrl(Uri.parse('tel:112')),
        );
        if (!_ownsRoute) {
          return;
        }
        _showMessage(
          result == EmergencyDialResult.opened
              ? 'Emergency dialer opened — confirm the call on your device.'
              : 'Could not open the dialer. Dial 112 manually.',
        );
      }
    } finally {
      _emergencyInFlight = false;
    }
  }

  void _toggleRecording() {
    _showMessage('Audio recording is unavailable in this demo.');
  }

  void _shareTrip() {
    _showMessage('Trip sharing is unavailable in this demo.');
  }

  Future<void> _openPreferences() {
    if (!_ownsRoute) return Future<void>.value();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, _) {
            return SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
                decoration: const BoxDecoration(
                  color: _canvas,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD6DDE0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Safety preferences',
                                style: TextStyle(
                                  color: _ink,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Ride check is on. The others are preview only.',
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => popOwned(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                          color: _muted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _preferenceTile(
                      icon: Icons.pin_outlined,
                      title: 'PIN verification',
                      subtitle: 'Unavailable without account verification',
                      value: false,
                      onChanged: null,
                    ),
                    const SizedBox(height: 10),
                    _preferenceTile(
                      icon: Icons.ios_share_outlined,
                      title: 'Automatic trip sharing',
                      subtitle: 'Unavailable without a sharing service',
                      value: false,
                      onChanged: null,
                    ),
                    const SizedBox(height: 10),
                    _preferenceTile(
                      key: const ValueKey('ride-check-preference'),
                      icon: Icons.shield_outlined,
                      leading: _rideCheckIcon(),
                      title: 'Ride check',
                      subtitle: 'On · set by Movera for every trip',
                      value: true,
                      onChanged: null,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Widget _rideCheckIcon({double size = 21}) => SvgPicture.asset(
    AppAssets.solarShieldWarning,
    width: size,
    height: size,
    colorFilter: const ColorFilter.mode(Color(0xFF4D5A61), BlendMode.srcIn),
  );

  /// Ride check is live: what it checks, in short.
  Widget _rideCheckInfo() => Container(
    key: const ValueKey('ride-check-info'),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      border: Border.all(color: _line),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _rideCheckIcon(size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Ride check',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F4EE),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'On',
                      style: TextStyle(
                        color: _green,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'On for every trip. Asks "Is everything OK?" after a long '
                'stop, a drop-off far from the destination, a big detour or '
                'a very hard stop.',
                style: TextStyle(
                  color: _muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _preferenceTile({
    Key? key,
    required IconData icon,
    Widget? leading,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          leading ?? Icon(icon, color: const Color(0xFF4D5A61), size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: _green,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottomInset),
          decoration: const BoxDecoration(
            color: _canvas,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6DDE0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  IconButton(
                    onPressed: () => popOwned(context),
                    icon: const Icon(Icons.close_rounded),
                    color: _ink,
                    tooltip: 'Close',
                  ),
                  const Expanded(
                    child: Text(
                      'Safety',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'Safety tools',
                style: TextStyle(
                  color: _ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Quick tools designed to protect you during every ride.',
                style: TextStyle(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _SafetyToolButton(
                      icon: Icons.call_outlined,
                      label: 'Contact 112',
                      onTap: _confirmEmergencyCall,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _SafetyToolButton(
                      icon: Icons.mic_outlined,
                      label: 'Record audio',
                      onTap: _toggleRecording,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _SafetyToolButton(
                      icon: Icons.ios_share_outlined,
                      label: 'Share trip',
                      onTap: _shareTrip,
                    ),
                  ),
                ],
              ),
              if (_status != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F4EE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: _green,
                        size: 17,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _status!,
                          style: const TextStyle(
                            color: Color(0xFF496158),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _rideCheckInfo(),
              const SizedBox(height: 10),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(19),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _openPreferences,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(color: _line),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 22,
                          color: Color(0xFF4D5A61),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Safety preferences',
                                style: TextStyle(
                                  color: _ink,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Ride check on · the others are preview only',
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF98A3A8),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SafetyToolButton extends StatelessWidget {
  const _SafetyToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active = false;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF19865C);
    const ink = Color(0xFF252E3A);

    return Material(
      color: active ? const Color(0xFFE5F4ED) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 94),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active ? const Color(0xFFB9DDCD) : const Color(0xFFE5E9EB),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: active ? green : const Color(0xFF45525A),
                size: 23,
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: active ? green : ink,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

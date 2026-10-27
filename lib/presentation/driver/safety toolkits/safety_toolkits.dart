import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/safety/driver_sos.dart';
import 'package:movera/core/safety/emergency_dial.dart';
import 'package:movera/core/safety/safety_audio_option.dart';
import 'package:movera/presentation/driver/accept%20ride/ride_check_card.dart';
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
  const SafetyToolKits({
    super.key,
    this.launchEmergencyDial,
    this.sendSos,
    this.web = kIsWeb,
  });

  final Future<bool> Function()? launchEmergencyDial;

  /// Contract v0.7.0: the SOS to Movera ([DriverSos.fromApp] by default).
  final Future<DriverSosOutcome> Function()? sendSos;

  /// A browser build: its tel: launch reports success whether or not a
  /// dialer opened (url_launcher_web), so the sheet never says it did.
  final bool web;

  @override
  State<SafetyToolKits> createState() => _SafetyToolKitsState();
}

class _SafetyToolKitsState extends State<SafetyToolKits> {
  static const Color _ink = Color(0xFF252E3A);
  static const Color _muted = Color(0xFF7D898F);
  static const Color _green = Color(0xFF19865C);
  static const Color _line = Color(0xFFE5E9EB);
  static const Color _canvas = Color(0xFFF4F6F7);
  static const Color _red = Color(0xFFCB424B);

  String? _status;

  /// The status reports something that worked (green check); otherwise it
  /// is a failure or a feature that is not there (driver-93).
  bool _statusOk = false;
  bool _emergencyInFlight = false;

  bool get _ownsRoute => mounted && ModalRoute.of(context)?.isCurrent == true;

  void _showMessage(String message, {bool ok = false}) {
    if (!_ownsRoute) return;
    setState(() {
      _status = message;
      _statusOk = ok;
    });
  }

  /// Owner safety part 1 (2026-10-27): SOS opens the 112 call on the phone
  /// AND alerts Movera with the phone's position; afterwards the sheet says
  /// only "SOS sent".
  Future<void> _confirmSos() async {
    if (!_ownsRoute || _emergencyInFlight) return;
    _emergencyInFlight = true;
    try {
      final send = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            tr.safetySosQ,
            style: const TextStyle(
              color: _ink,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            tr.safetySosBody,
            style: const TextStyle(color: _muted, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => popOwned(dialogContext, false),
              child: Text(tr.cancel),
            ),
            FilledButton(
              key: const ValueKey('safety-sos-send'),
              onPressed: () => popOwned(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: _red),
              child: Text(tr.safetySosSend),
            ),
          ],
        ),
      );
      if (send != true || !_ownsRoute) return;
      // Both at once: the dialer does not wait for the network.
      final alert = (widget.sendSos ?? DriverSos.fromApp)();
      final dial = await handoffEmergencyDial(
        widget.launchEmergencyDial ?? () => launchUrl(Uri.parse('tel:112')),
      );
      final outcome = await alert;
      if (!_ownsRoute) return;
      final dialed = dial == EmergencyDialResult.opened;
      _showMessage(switch (outcome) {
        // A browser reports a tel: launch as opened whether or not a dialer
        // opened (url_launcher_web), so it never says it did.
        DriverSosOutcome.sent =>
          !dialed
              ? tr.safetySosSentNoDialer
              : widget.web
              ? '${tr.safetySosSent}. ${tr.safetyDialerAskedBrowser}'
              : tr.safetySosSent,
        DriverSosOutcome.noTrip => tr.safetySosNoTrip,
        DriverSosOutcome.failed => tr.safetySosNotSent,
      }, ok: outcome == DriverSosOutcome.sent && dialed && !widget.web);
    } finally {
      _emergencyInFlight = false;
    }
  }

  static Widget _iconCircle(String asset, Color fill, Color color) => Container(
    width: 46,
    height: 46,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
    child: RideCheckStyle.icon(asset, color: color, size: 24),
  );

  Widget _statusBanner() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
    decoration: BoxDecoration(
      color: _statusOk ? const Color(0xFFE7F4EE) : const Color(0xFFFCEEEE),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(
          _statusOk
              ? Icons.check_circle_outline_rounded
              : Icons.info_outline_rounded,
          color: _statusOk ? _green : const Color(0xFFB3261E),
          size: 17,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _status!,
            style: TextStyle(
              color: _statusOk
                  ? const Color(0xFF496158)
                  : const Color(0xFF7A2E2A),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _onPill() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFFE7F4EE),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      tr.safetyOn,
      style: const TextStyle(
        color: _green,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  static Widget _sheetHandle() => Center(
    child: Container(
      width: 38,
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFFD6DDE0),
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );

  Widget _header(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          tr.safetyTools,
          style: const TextStyle(
            color: _ink,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      IconButton(
        onPressed: () => popOwned(context),
        icon: const Icon(Icons.close_rounded),
        color: _muted,
        tooltip: tr.close,
      ),
    ],
  );

  void _toggleRecording() {
    _showMessage(tr.safetyAudioUnavailable);
  }

  void _shareTrip() {
    _showMessage(tr.safetyTripSharingUnavailable);
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr.safetyPreferences,
                                style: TextStyle(
                                  color: _ink,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                tr.safetyRideCheckOnOthersPreview,
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
                          tooltip: tr.close,
                          onPressed: () => popOwned(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                          color: _muted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _preferenceTile(
                      icon: Icons.pin_outlined,
                      title: tr.pinVerification,
                      subtitle: tr.safetyUnavailableWithoutVerification,
                      value: false,
                      onChanged: null,
                    ),
                    const SizedBox(height: 10),
                    _preferenceTile(
                      icon: Icons.ios_share_outlined,
                      title: tr.safetyAutoTripSharing,
                      subtitle: tr.safetyUnavailableWithoutSharing,
                      value: false,
                      onChanged: null,
                    ),
                    const SizedBox(height: 10),
                    _preferenceTile(
                      key: const ValueKey('ride-check-preference'),
                      icon: Icons.shield_outlined,
                      leading: _rideCheckIcon(),
                      title: tr.rideCheck,
                      subtitle: tr.safetyOnSetByMovera,
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

  /// The big SOS card (option B).
  Widget _sosCard() => Material(
    key: const ValueKey('safety-sos'),
    color: RideCheckStyle.red,
    borderRadius: BorderRadius.circular(24),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: _confirmSos,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            _iconCircle(
              AppAssets.solarDangerTriangle,
              RideCheckStyle.white(.18),
              Colors.white,
            ),
            const SizedBox(height: 12),
            Text(
              tr.safetySos,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr.safetySosHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: RideCheckStyle.white(.92),
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  static const _cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(19)),
    side: BorderSide(color: _line),
  );

  Widget _tile(String icon, String label, VoidCallback onTap) => Material(
    color: Colors.white,
    shape: _cardShape,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 96),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RideCheckStyle.icon(icon, color: const Color(0xFF4D5A61)),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _rideCheckCard() => Container(
    key: const ValueKey('ride-check-info'),
    padding: const EdgeInsets.all(16),
    decoration: ShapeDecoration(color: Colors.white, shape: _cardShape),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RideCheckStyle.icon(
          AppAssets.solarShieldWarning,
          color: const Color(0xFF4D5A61),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tr.rideCheck,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _onPill(),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                tr.safetyRideCheckExplained,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final tiles = <Widget>[
      // Owner decision 10: hidden while the option is off.
      if (SafetyAudioOption.enabled)
        _tile(AppAssets.solarMicrophone, tr.recordAudio, _toggleRecording),
      _tile(AppAssets.solarUploadMinimalistic, tr.safetyShareTrip, _shareTrip),
      _tile(AppAssets.solarTuning2, tr.safetyPreferences, _openPreferences),
    ];

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 10, 20, 24 + bottomInset),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sheetHandle(),
              const SizedBox(height: 12),
              _header(context),
              const SizedBox(height: 12),
              _sosCard(),
              if (_status != null) ...[
                const SizedBox(height: 10),
                _statusBanner(),
              ],
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < tiles.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(child: tiles[i]),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _rideCheckCard(),
            ],
          ),
        ),
      ),
    );
  }
}

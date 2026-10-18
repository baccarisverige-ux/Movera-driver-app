import 'package:movera/widgets/owned_route_exit.dart';
import 'package:movera/widgets/single_route_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/settings/map_traffic_setting.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/presentation/driver/pin%20verification/pin_verification.dart';
import 'package:movera/presentation/driver/safety%20toolkits/safety_toolkits.dart';
import 'package:movera/presentation/driver/settings/accessibility/accessibility.dart';
import 'package:movera/presentation/driver/settings/emergency_contacts.dart';
import 'package:movera/presentation/driver/settings/sound%20&%20voice/sound_voice.dart';
import 'package:movera/widgets/navigation_transition.dart';

class Settings extends StatefulWidget {
  const Settings({super.key, this.repository});
  final SettingsRepository? repository;

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  static const Color _ink = Color(0xFF252E3A);
  static const Color _muted = Color(0xFF7D898F);
  static const Color _line = Color(0xFFE6E8EA);

  late final _settings = widget.repository ?? SettingsRepository();

  @override
  void initState() {
    super.initState();
    MapTrafficSetting.restore(_settings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F7),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(tooltip: 'Back', 
          onPressed: () => maybePopOwned(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
        ),
        titleSpacing: 0,
        title: const Text(
          'App settings',
          style: TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _group([
            _row(
              icon: Icons.volume_up_outlined,
              title: 'Sound & voice',
              onTap: () => pushSingle(
                context,
                RightToLeftTransition(const SoundAndVoice()),
              ),
            ),
            _row(
              icon: Icons.dark_mode_outlined,
              title: 'Dark mode',
              detail: 'Unavailable in demo',
            ),
            _row(
              icon: Icons.language_rounded,
              title: 'Language',
              detail: 'English (US) only',
            ),
          ]),
          const SizedBox(height: 12),
          _group([_trafficRow()]),
          const SizedBox(height: 12),
          _group([
            _row(
              icon: Icons.accessibility_new_rounded,
              title: 'Accessibility',
              onTap: () => pushSingle(
                context,
                RightToLeftTransition(const Accessibility()),
              ),
            ),
            _row(
              icon: Icons.pin_outlined,
              title: 'Pin verification',
              onTap: () => pushSingle(
                context,
                RightToLeftTransition(const PinVerification()),
              ),
            ),
            _row(
              icon: Icons.contact_phone_outlined,
              title: 'Emergency contacts',
              onTap: () => pushSingle(
                context,
                RightToLeftTransition(const EmergencyContactsScreen()),
              ),
            ),
            _row(
              icon: Icons.shield_outlined,
              title: 'Safety',
              onTap: () => showSafetyToolKitSheet(context),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _group(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Column(children: children),
    );
  }

  Widget _row({
    required IconData icon,
    required String title,
    String? detail,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F5F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: _ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (detail != null)
              Flexible(child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  detail,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )),
            trailing ??
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFB0B8BC),
                  size: 20,
                ),
          ],
        ),
      ),
    );
  }

  /// "Show traffic on map": trip map only, ON by default (R13-17).
  Widget _trafficRow() {
    return ValueListenableBuilder<bool>(
      valueListenable: MapTrafficSetting.enabled,
      builder: (context, on, _) {
        void toggle(bool value) => MapTrafficSetting.set(value, _settings);
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F5F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SvgPicture.asset(
                  AppAssets.solarMapArrowSquare,
                  width: 18,
                  height: 18,
                  colorFilter: const ColorFilter.mode(_ink, BlendMode.srcIn),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Show traffic on map',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Traffic colours on the trip map',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Semantics(
                label: 'Show traffic on map',
                toggled: on,
                onTap: () => toggle(!on),
                child: ExcludeSemantics(
                  child: Switch.adaptive(
                    key: const ValueKey<String>('settings-show-traffic'),
                    value: on,
                    activeTrackColor: _ink,
                    onChanged: toggle,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

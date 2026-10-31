import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:movera/widgets/single_route_entry.dart';
import 'package:flutter/material.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/presentation/driver/pin%20verification/pin_verification.dart';
import 'package:movera/presentation/driver/safety%20toolkits/safety_toolkits.dart';
import 'package:movera/presentation/driver/settings/accessibility/accessibility.dart';
import 'package:movera/presentation/driver/settings/emergency_contacts.dart';
import 'package:movera/presentation/driver/settings/sound%20&%20voice/sound_voice.dart';
import 'package:movera/presentation/driver/settings/trip_settings.dart';
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
        leading: IconButton(
          tooltip: tr.back,
          onPressed: () => maybePopOwned(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
        ),
        titleSpacing: 0,
        title: Text(
          tr.appSettings,
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
              title: tr.soundVoice,
              onTap: () => pushSingle(
                context,
                RightToLeftTransition(const SoundAndVoice()),
              ),
            ),
            // G5 status item 3: the navigation app (Google Maps / Waze).
            _row(
              key: const ValueKey<String>('settings-trip-settings'),
              icon: Icons.navigation_outlined,
              title: tr.tripSettings,
              onTap: () => pushSingle(
                context,
                RightToLeftTransition(const TripSettings()),
              ),
            ),
            _row(
              icon: Icons.dark_mode_outlined,
              title: tr.darkMode,
              detail: tr.unavailableInDemo,
            ),
            _languageRow(),
          ]),
          const SizedBox(height: 12),
          _group([
            _row(
              icon: Icons.accessibility_new_rounded,
              title: tr.accessibility,
              onTap: () => pushSingle(
                context,
                RightToLeftTransition(const Accessibility()),
              ),
            ),
            _row(
              icon: Icons.pin_outlined,
              title: tr.pinVerification,
              onTap: () => pushSingle(
                context,
                RightToLeftTransition(const PinVerification()),
              ),
            ),
            _row(
              icon: Icons.contact_phone_outlined,
              title: tr.emergencyContacts,
              onTap: () => pushSingle(
                context,
                RightToLeftTransition(const EmergencyContactsScreen()),
              ),
            ),
            _row(
              icon: Icons.shield_outlined,
              title: tr.safety,
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
    Key? key,
    required IconData icon,
    required String title,
    String? detail,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      key: key,
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
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    detail,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
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

  /// Round 4 (Q48/Q49): the app's language, "SV · Svenska". The zone sets
  /// the default; the driver's pick is saved and wins.
  Widget _languageRow() {
    return ValueListenableBuilder<String>(
      valueListenable: DriverLanguage.current,
      builder: (context, code, _) => KeyedSubtree(
        key: const ValueKey<String>('settings-language'),
        child: _row(
          icon: Icons.language_rounded,
          title: tr.language,
          detail: DriverLanguage.label(code),
          onTap: _pickLanguage,
        ),
      ),
    );
  }

  Future<void> _pickLanguage() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                tr.languageTitle,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (final code in DriverLanguage.available)
              ListTile(
                key: ValueKey<String>('settings-language-$code'),
                title: Text(
                  DriverLanguage.label(code),
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: code == DriverLanguage.zoneDefault
                    ? Text(
                        tr.languageZoneDefault,
                        style: const TextStyle(color: _muted, fontSize: 12),
                      )
                    : null,
                trailing: code == DriverLanguage.current.value
                    ? const Icon(Icons.check_rounded, color: _ink)
                    : null,
                selected: code == DriverLanguage.current.value,
                onTap: () => Navigator.of(sheet).pop(code),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    try {
      await DriverLanguage.choose(picked, _settings);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr.languageSaveFailed)));
    }
  }
}

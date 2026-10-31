import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/settings/navigation_app.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/presentation/driver/preferences/preferences.dart';
import 'package:movera/widgets/navigation_transition.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:movera/widgets/single_route_entry.dart';

/// Driver group 5, status item 3: the driver's trip settings. Today one
/// choice, the navigation app the trip's map button opens (Google Maps,
/// the default, or Waze), and the way to the ride preferences (car types),
/// which the trip sheet's button opened by mistake before (G5 re-check
/// 2026-10-30 "Reseinställningar in trip sheet opens car types").
class TripSettings extends StatefulWidget {
  const TripSettings({super.key, this.repository});
  final SettingsRepository? repository;

  @override
  State<TripSettings> createState() => _TripSettingsState();
}

class _TripSettingsState extends State<TripSettings> {
  static const Color _ink = Color(0xFF252E3A);
  static const Color _muted = Color(0xFF7D898F);
  static const Color _line = Color(0xFFE6E8EA);

  late final _settings = widget.repository ?? SettingsRepository();

  @override
  void initState() {
    super.initState();
    NavigationAppSetting.load(_settings);
  }

  Future<void> _choose(NavigationApp app) async {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    final saved = await NavigationAppSetting.save(app, _settings);
    if (!saved && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr.navigationAppSaveFailed)));
    }
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
          tr.tripSettings,
          style: const TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: ListView(
        key: const ValueKey<String>('trip-settings'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr.navigationApp,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tr.navigationAppHint,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<NavigationApp>(
            valueListenable: NavigationAppSetting.current,
            builder: (context, chosen, _) => _group([
              _choice(
                key: const ValueKey<String>('trip-settings-google-maps'),
                app: NavigationApp.googleMaps,
                chosen: chosen,
                title: 'Google Maps',
                mark: AppAssets.mapGoogle,
              ),
              const Divider(height: 1, color: _line),
              _choice(
                key: const ValueKey<String>('trip-settings-waze'),
                app: NavigationApp.waze,
                chosen: chosen,
                title: 'Waze',
                mark: AppAssets.mapWaze,
              ),
            ]),
          ),
          const SizedBox(height: 12),
          _group([
            InkWell(
              key: const ValueKey<String>('trip-settings-ride-preferences'),
              onTap: () => pushSingle(
                context,
                RightToLeftTransition(const Preferences()),
              ),
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
                      child: const Icon(
                        Icons.directions_car_outlined,
                        size: 18,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tr.ridePreferences,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFFB0B8BC),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _group(List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _line),
    ),
    child: Column(children: children),
  );

  Widget _choice({
    required Key key,
    required NavigationApp app,
    required NavigationApp chosen,
    required String title,
    required String mark,
  }) {
    final selected = app == chosen;
    return Semantics(
      key: key,
      button: true,
      selected: selected,
      label: title,
      child: InkWell(
        onTap: () => _choose(app),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F5F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SvgPicture.asset(mark, width: 22, height: 22),
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
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? _ink : const Color(0xFFB0B8BC),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

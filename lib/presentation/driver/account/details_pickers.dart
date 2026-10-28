import 'package:flutter/material.dart';
import 'package:movera/core/admin/trip_rules_admin_config.dart';
import 'package:movera/core/contracts/driver_onboarding_rules.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_style.dart';
import 'package:movera/widgets/movera_modal_sheet.dart';

/// Round 4b: the details step's three pickers, each a white sheet from
/// the bottom with a title, a line under it and tall rows. Country rows
/// carry the flag (a country not open yet is shown with "Coming soon" and
/// cannot be picked); city and language rows carry none.

/// The flag emoji of an ISO country code.
String countryFlag(String iso) => String.fromCharCodes([
  for (final unit in iso.toUpperCase().codeUnits) 0x1F1E6 + unit - 0x41,
]);

String countryName(String code) => switch (code) {
  'SE' => tr.acctCountrySweden,
  'FR' => tr.acctCountryFrance,
  'TN' => tr.acctCountryTunisia,
  _ => code,
};

/// A line under a city's name (the contract names the whole county).
String? cityHint(String? cityId) => switch (cityId) {
  'stockholm_lan' => tr.acctCityStockholmHint,
  'paris' => tr.acctCityParisHint,
  _ => null,
};

Future<String?> showDetailsCountryPicker(
  BuildContext context, {
  required String selected,
}) {
  return showDetailsPicker<String>(
    context,
    title: tr.acctChooseCountry,
    subtitle: tr.acctChooseCountryBody,
    rows: [
      for (final code in DriverOnboardingRules.countries.keys)
        PickerRow(
          value: code,
          key: 'pick-country-$code',
          leading: Text(
            countryFlag(code),
            style: const TextStyle(fontSize: 30, height: 1),
          ),
          title: countryName(code),
          enabled: DriverOnboardingRules.isOpen(code),
          tag: DriverOnboardingRules.isOpen(code) ? null : tr.acctComingSoon,
        ),
    ],
    selected: selected,
  );
}

Future<String?> showDetailsCityPicker(
  BuildContext context, {
  required String country,
  required String? selected,
}) {
  final cities = DriverOnboardingRules.citiesOf(country);
  return showDetailsPicker<String>(
    context,
    title: tr.acctChooseCity,
    subtitle: countryName(country),
    rows: [
      for (final city in cities)
        PickerRow(
          value: city.cityId,
          key: 'pick-city-${city.cityId}',
          title: city.name,
          // v0.11.0 §21: the zone's name from the server, in the app
          // language; the built-in hint without it.
          subtitle:
              DriverZones.nameOf(city.zoneId, DriverAppTexts.language) ??
              cityHint(city.cityId),
        ),
    ],
    selected: selected,
  );
}

Future<String?> showDetailsLanguagePicker(
  BuildContext context, {
  required String selected,
}) {
  return showDetailsPicker<String>(
    context,
    title: tr.acctChooseLanguage,
    subtitle: tr.acctChooseLanguageBody,
    rows: [
      for (final code in DriverLanguage.supported)
        PickerRow(
          value: code,
          key: 'pick-language-$code',
          title: DriverLanguage.names[code] ?? code,
        ),
    ],
    selected: selected,
  );
}

class PickerRow<T> {
  const PickerRow({
    required this.value,
    required this.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.enabled = true,
    this.tag,
  });

  final T value;
  final String key;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool enabled;

  /// "Coming soon" on a row that cannot be picked.
  final String? tag;
}

Future<T?> showDetailsPicker<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<PickerRow<T>> rows,
  T? selected,
}) {
  return showMoveraModalSheet<T>(
    context: context,
    fitContent: true,
    builder: (sheet) => Material(
      color: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDE3DE),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: AuthText.urbanist(size: 20, weight: FontWeight.w800),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle, style: AuthText.cardSub()),
              ],
              const SizedBox(height: 6),
              for (final row in rows)
                _PickerTile(
                  row: row,
                  selected: row.value == selected,
                  onTap: row.enabled
                      ? () => Navigator.of(sheet).pop(row.value)
                      : null,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PickerTile<T> extends StatelessWidget {
  const _PickerTile({
    required this.row,
    required this.selected,
    required this.onTap,
  });

  final PickerRow<T> row;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: [
        row.title,
        if (row.subtitle != null) row.subtitle!,
        if (row.tag != null) row.tag!,
      ].join(', '),
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey(row.key),
        onTap: onTap,
        child: Opacity(
          opacity: enabled ? 1 : 0.55,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFEEF1EC))),
            ),
            child: Row(
              children: [
                if (row.leading != null) ...[
                  SizedBox(width: 40, child: Center(child: row.leading)),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.title,
                        style: AuthText.urbanist(
                          size: 17,
                          weight: FontWeight.w600,
                        ),
                      ),
                      if (row.subtitle != null)
                        Text(
                          row.subtitle!,
                          style: AuthText.urbanist(
                            size: 12.5,
                            color: AuthColors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                if (row.tag != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBF1DD),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      row.tag!.toUpperCase(),
                      style: AuthText.urbanist(
                        size: 11,
                        weight: FontWeight.w800,
                        color: const Color(0xFFB07A1A),
                      ),
                    ),
                  )
                else if (selected)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AuthColors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

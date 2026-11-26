# Dependency hygiene

Checked against the Driver source without a bulk upgrade.

`flutter_sliding_up_panel` was a direct dependency and had no import in `lib/`
or `test/`. The sheet uses `sliding_up_panel`. The unused package is removed.

Other direct dependencies were left on their current constraints. Map, picker,
animation, and UI packages were not upgraded together. Run `flutter pub outdated`
in a later maintenance change and upgrade one compatible group at a time.

## R08 (deep re-audit, N15/N16)

Removed direct dependencies with no import in `lib/`: `animator`, `flip_card`, `animated_segmented_tab_control`, `syncfusion_flutter_datepicker` (commercial/community licence), `readmore`, `flutter_colorpicker`, `carousel_slider`, `flutter_animate`, `fl_chart`, `riff_switch`, `lottie`. `test/audit/dependency_hygiene_test.dart` now fails on any unused direct dependency.

Removed the `driver-part-*.zip` upload snapshots (September source), `UPLOAD_MANIFEST.txt` and the superseded `docs/Movera-Driver-Audit-2026-09-29.pdf`. The repository tree is the single source of truth, and git history keeps the old files. `*.zip` is ignored.

Still open: `google_fonts` fetches fonts at runtime (bundle the font files as assets), and an injectable clock (N24).

## Sign-up v2 (contract v0.18.166, 2026-11-26)

- `cunning_document_scanner` 3.1.0 (MIT): "Scanner" in the documents' Ajouter sheet; iOS VisionKit, Android ML Kit document scanner (Google Play services module, downloaded by the system). Not used on the web.
- `image` 4.x (MIT, pure Dart): joins a recto and a verso into one JPEG before the upload.
- Solar icon set, Linear style, by 480 Design (https://www.figma.com/community/file/1166831539721848736), licence CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/), owner 2026-11-26 "Make solar icons": the sign-up v2 screens only, as SVG strings in `lib/presentation/driver/signup/solar_icons.dart` (from npm `@iconify-json/solar` 1.2.17, paths unchanged). Credit: "Solar icons by 480 Design, CC BY 4.0". Drawn with the existing `flutter_svg`.

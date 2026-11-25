#!/usr/bin/env bash
# v0.18.155 My profile texts live in their own small localization class
# (ProfileLocalizations, lib/l10n/profile_arb/*.arb) that only the My
# profile screen imports, so they load with Profile (deferred) and stay
# out of the always-loaded web bundle. Regenerate after editing the ARBs:
#   bash tool/gen_profile_l10n.sh
# (flutter gen-l10n ignores its flags while l10n.yaml exists, so the file
# is set aside for the run and put back.)
set -euo pipefail
cd "$(dirname "$0")/.."
mv l10n.yaml l10n.yaml.off
trap 'mv l10n.yaml.off l10n.yaml' EXIT
flutter gen-l10n --arb-dir lib/l10n/profile_arb \
  --template-arb-file profile_en.arb --output-dir lib/l10n \
  --output-localization-file app_localizations_profile.dart \
  --output-class ProfileLocalizations --no-nullable-getter
dart format lib/l10n/app_localizations_profile*.dart

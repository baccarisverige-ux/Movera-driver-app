# Movera Driver

Driver frontend for pickup, navigation, and delivery (Flutter; bundle id `se.movera.driver`,
unchanged). Contract copy in `contracts/` (version **0.18.64**).

Two builds come from this repository. The **live** build
(`--dart-define=MOVERA_AUTH_REQUIRED=true --dart-define=MOVERA_API_BASE_URL=<server>`) signs in
against movera-server and uses its dispatch, locations and trip steps. Without those defines the
app is the local **demo**: payments, rider phone contact, and dispatch are not connected
services, and the in-app banner says demo mode so a test build is not mistaken for production.

## Build and test

Flutter 3.47.6 (stable) on CI; `pubspec.yaml` asks for Flutter >= 3.41 and Dart ^3.8.1.

```sh
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed .
python3 tool/l10n_parts.py --check          # ARBs match lib/l10n/parts
flutter analyze --fatal-infos
flutter test --coverage
python3 tool/check_coverage.py coverage/lcov.info lib/core/ 91.5
python3 -m unittest discover -s tool/tests -p 'test_*.py' -v
python3 tool/check_frontend_release.py docs/frontend-completion/09-release-candidate.json
node tool/verify_driver_map_web.cjs
flutter test integration_test/driver_lifecycle_test.dart -d flutter-tester
flutter build web --release
python3 tool/check_web_budget.py build/web --main-raw 6200000 --main-gzip 1760000
```

These are the steps of the `verify` job in `.github/workflows/drider-ci.yml` ("Drider CI", on
every PR and push to `main`). Its other jobs: `changes` (docs-only detection), `secret-scan`,
`live-web` (the live web build), `android-release` (release fails closed without signing
secrets and a maps key), and `gate`, the one job a branch rule requires: green only when every
job passed or was skipped on purpose (docs-only PR or draft). `drider-ios.yml` is the iOS
preflight (PRs and nightly); `android-test-apk.yml` builds a staging APK by hand.
`test/audit/release_metadata_test.dart` checks this README and the release metadata.

## Translations

Rule 25 split: new texts go in their area file, `lib/l10n/parts/<area>.<lang>.arb` (en, fr,
sv), never in `lib/l10n/app_<lang>.arb`, which `python3 tool/l10n_parts.py` writes from the
area files; then `flutter gen-l10n`. See `lib/l10n/parts/README.md`.

## Contract copy

Never edit `contracts/` by hand (Rule 43(4)). After a contract merge run
`tool/sync_contract.sh v<version>` and commit `contracts/` exactly as it comes out.
`.github/workflows/contract-copy.yml` runs `tool/check_contract_copy.sh` on every PR and
push and once a day opens or closes the issue "Contract copy behind movera-contracts main".

## Web deployment

`.github/workflows/deploy-pages.yml` publishes the live build after "Drider CI" succeeded on
a push to `main`, to `https://baccarisverige-ux.github.io/Movera-driver-app/live/` (the site
root redirects there; the demo is no longer published). It reads the `MOVERA_LIVE_API_URL`
repository variable. The server is movera-server on Render.

## Working rules

- The owner's memory for the project is the Rules repository (`Movera-team/Rules`:
  `RULES.md`, `decisions/`, `plan/`). Read it first; `docs/DECISIONS.md` here is checked by
  the docs-truth tests in `test/audit/`.
- Rule 25: a hand-written file over 1,500 lines is split before it is changed (`.arb` files
  included; generated l10n outputs are exempt). Rule 21: never delete anything without
  asking the owner.
- Pull requests use `.github/pull_request_template.md`; security problems go through
  `SECURITY.md` (private reporting), never a public issue.

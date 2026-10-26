# Phase 2 — CI hardening (driver app)

Branch `audit/phase-2`, from `main` @ 436bfb54. Plan: `movera-contracts` `docs/audit/AUDIT_PLAN.md` (Phase 2); baseline: `docs/audit/baseline-2026-10.md` (branch `audit/phase-1`), sections 3, 4, 10.

## Status

| # | Item | Status |
|---|---|---|
| 1 | `drider-ci.yml` as the required gate | Done (CI result: see the PR) |
| 2 | `dart format .` in its own commit + format check | Done |
| 3 | Two wall-clock-flaky tests made deterministic | Done |
| 4 | Contract copy synced to movera-contracts main (v0.5.5) | Done; product follow-ups listed for Phase 3 |
| 5 | CupertinoIcons font warning | Not done (see below) |

## 1. CI gate (`.github/workflows/drider-ci.yml`)

- Lockfile: `flutter pub get --enforce-lockfile` in every job (was already there).
- Pinned Flutter: one `FLUTTER_VERSION: 3.47.6` env used by every job (deploy-pages.yml also pins 3.47.6).
- Format: `dart format --output=none --set-exit-if-changed .` before analyze.
- Coverage: `flutter test --coverage`; `tool/check_coverage.py coverage/lcov.info lib/core/ 91.5` fails below 91.5 % of lib/core lines (baseline 91.8 %; local run on this branch: see Evidence); `coverage/lcov.info` uploaded as artifact `driver-coverage-<sha>`.
- Secret scan: job `Secret scan`, gitleaks v8.28.0 (Docker image) on the checked-out tree. History is not scanned: the Maps key in old commits (baseline finding 4) would fail every run; rotating/restricting it is Phase 4.
- Live web: job `Build live web (MOVERA_AUTH_REQUIRED=true)` builds with the deploy workflow's live flags on every push and PR (API URL from `vars.MOVERA_LIVE_API_URL`, fallback the Render URL).
- Timeouts on every job (verify raised 30 → 40 min for coverage; new jobs 10 / 30). deploy-pages.yml jobs also got timeouts (30 / 10), they had none.
- Concurrency: one group per PR / pushed ref, `cancel-in-progress: true`; push and pull_request runs are separate groups.
- Pub cache: `actions/cache` on `~/.pub-cache`, keyed on OS + Flutter version + `pubspec.lock`.

### Required check names (for branch protection, owner decision D1 — not changed here)
- `Analyze, test and build web`
- `Secret scan`
- `Build live web (MOVERA_AUTH_REQUIRED=true)`
- `Android release signing and preview`
- `iOS release compile preflight`

## 2. Formatting

- Commit `eb98d603`: only `dart format .` (451 of 696 files; Flutter 3.47.7 locally).
- Fallout, separate commits:
  - `755371f5`: two line-limit audit tests measure formatted files: `home.dart` 1198 → 1407 lines and `accept_ride.dart` 1798 → 2146 with the same code; limits scaled 1200 → 1410 and 1800 → 2150 (test/audit/home_map_sheet_split_test.dart, test/audit/accept_ride_panel_split_test.dart). No code moved. `docs_truth_d54_test` driver-6 now matches `accept_ride.dart` whitespace-insensitively (the formatter wrapped the ternary).
  - `6598dbd4`: six `if` statements the formatter split over two lines broke `curly_braces_in_flow_control_structures` under `--fatal-infos`; fixed with `dart fix --apply --code=curly_braces_in_flow_control_structures`.

## 3. Flaky tests

- `test/audit/r5_lows_test.dart` driver-r5-3: the app's Radar pick window compared the server's `expiresAt` with `DateTime.now()` while its deadline used `ScheduledClock.realNow()` (same in the app; different in tests). It now uses the same `now` (home_offer_radar.dart, one line). The test sets `ScheduledClock.realNow` to a manual clock that stands still while the card comes up and moves 250 ms per pumped frame. Assertions unchanged. Mutation check: with the server-expiry clamp removed the test fails ("before: Match stayed on for the app's full 15 s").
- `test/core/locate_view_test.dart` smooth flight: the camera port gets `clock: () => tester.binding.clock.now()` (existing parameter), so each frame is 16 ms of fake time. Assertions unchanged.
- Both files passed 5 consecutive runs while a full `flutter test --coverage` ran in parallel.
- Seen once, not fixed: `driver-r5-2` failed in one of those parallel runs and passed in 4 whole-file runs and 4 single runs afterwards; not reproduced.

## 4. Contract sync

- `tool/sync_contract.sh 9c0acb659e3ee1c0f1a651f7e5616be603699fe4` (movera-contracts main, v0.5.5): CHECKSUMS, CONTRACT.md, contract.json, openapi.yaml, tools/gen_openapi.py.
- Fallout fixed: version pins (`TripTransitions.contractVersion`, contract_copy_test, driver_app_config_test, docs/DECISIONS.md) and the transition mirror's new row `raise_price` (rider, `searching|offered` → `searching`). `test/contract`: 63 passed.

### For Phase 3 (product logic, not changed here)
- v0.5.5 raise-price: open offers are withdrawn and drivers who declined are asked again at the new fare, with a `rider_raise` fare line and `driverEarnings` += increase. The driver app has no handling or test of a re-offer of a trip it declined, nor of the `rider_raise` line on the waybill/earnings (no `rider_raise` in lib/). NOT VERIFIED against the server.
- v0.5.4 `rider_on_the_way`: the event kind is parsed (lib/core/realtime/driver_realtime.dart:18); what the driver sees for it was not checked.

## 5. CupertinoIcons font warning — not done

`flutter build web` warns "Expected to find fonts for (MaterialIcons, packages/cupertino_icons/CupertinoIcons)". lib/ uses no `CupertinoIcons` and pubspec has no `cupertino_icons`; the reference comes from a dependency or the framework (not found). The fix is adding the `cupertino_icons` package (a new dependency and font asset in every build), so it is not a trivial change for this phase.

## Evidence
(filled in below as runs finish)

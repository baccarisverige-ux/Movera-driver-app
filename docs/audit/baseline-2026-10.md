# Driver app — Phase 1 baseline audit (2026-10)

Repo: `Movera-driver-app` (package `movera`). Audited commit: `main` @ `436bfb54`.
Documentation only; no source, test or workflow changes.
Toolchain used locally: Flutter 3.47.7 / Dart 3.13.5 (CI pins 3.47.6).

> **Important correction to the brief:** PR #380 (`driver-live-fixes-1`) is **already merged**:
> GitHub API shows `merged: true`, `merged_at: 2026-10-26T11:47:46Z`, merge commit `436bfb54` = current `main`.
> Drider CI run 40317722373 on that commit was green (all three jobs) and Pages deployed (run 40319129190).
> So "main" in this audit already contains N1, N5, N9, N11 and the camera reports.

## Progress

- [x] 1. Structure and architecture
- [ ] 2. Dependencies
- [x] 3. CI
- [ ] 4. Baseline run
- [ ] 5. Coverage of critical logic
- [ ] 6. Screen inventory
- [ ] 7. Code quality
- [ ] 8. Known issues (N1, N5, N6, N8, N9, N11)
- [ ] 9. Untested features and risks
- [ ] 10. Summary

## 1. Structure and architecture

### Size
- `lib/`: 335 Dart files, ~87.6k lines in total including ~27k generated l10n lines (`lib/l10n/app_localizations*.dart`).
- `test/`: 358 Dart files, 356 `*_test.dart`: `test/audit` 151, `test/widget` 102, `test/core` 73, `test/contract` 9, `test/l10n` 6, `test/round2` 4, `test/round3` 4, `test/widgets` 4, `test/live` 1, `test/presentation` 1, plus `test/widget_test.dart`. One integration test `integration_test/driver_lifecycle_test.dart` (run by CI).
- Folder names under `lib/presentation/driver/` contain **spaces** (`accept ride`, `ride history`, `my wallet`, ...), so imports read `scheduled%20rides/...` (lib/main.dart:52). Shell tooling must quote paths.
- Biggest presentation folders: `home/` 36 files / 14.1k lines, `accept ride/` 24 files / 13.0k lines, `auth/` 20 files / 4.7k lines.

| Area | Folder | Files / lines |
|---|---|---|
| Dispatch (offers, claim, destination mode) | lib/core/dispatch | 12 / 2689 |
| Navigation + camera | lib/core/navigation | 14 / 2361 |
| Active ride | lib/core/ride | 7 / 2355 |
| Safety / ride check | lib/core/safety | 15 / 1975 |
| Routing (OSRM, instructions) | lib/core/routing | 5 / 1434 |
| Live services (server) | lib/core/live | 6 / 1354 |
| Auth | lib/core/auth | 13 / 1339 |
| Account | lib/core/account | 7 / 1231 |
| Realtime model | lib/core/realtime | 1 / 504 |
| Waybill | lib/core/waybill | 1 / 478 |
| Money / earnings | lib/core/money, earnings | 4 / 474 |
| Shared widgets (maps, radar, buttons) | lib/widgets | 39 / 6114 |

### Composition root and state
- No state-management package: plain `ChangeNotifier` / `ValueNotifier` + constructor injection from `MoveraApp` (lib/main.dart:72-385) and an `InheritedWidget`-style `DriverRuntimeScope` (lib/core/session/driver_runtime_scope.dart).
- **Build switches** in `DriverRuntimeConfig` (lib/core/session/driver_runtime_config.dart): `MOVERA_AUTH_REQUIRED` (live build), `MOVERA_API_BASE_URL`, `MOVERA_DEMO_ARRIVAL`, `MOVERA_EXTERNAL_ROUTING`, `MOVERA_SKIP_ACTIVATION`. `MOVERA_PRODUCTION=true` deliberately throws at start (lib/core/session/driver_composition_guard.dart:6-11): "Production Driver composition is unavailable" — i.e. the live test build is a *non-production* composition.
- `DriverSessionController` (lib/core/session/driver_session_controller.dart, 278 lines, ChangeNotifier) holds online/offline/on-trip; its repository is **always** `MemoryDriverSessionRepository` (lib/main.dart:143), also in the live build.
- `DriverAccountSession` (lib/core/account/driver_account_session.dart, 81 lines) holds the server account; injected into the scope only when `authRequired` (lib/main.dart:259-261).
- Dispatch: `DispatchRepository` interface (lib/core/dispatch/dispatch_repository.dart:351). Live: `ApiDispatchRepository` (599 lines, offer stream with reconnect backoff min(30 s, 2^n) at :231/:416, 10 s request timeout :227). Demo: `DemoDispatchRepository` (795 lines). Choice at lib/main.dart:152-164.
- `LiveDriverServices` (lib/core/live/live_driver_services.dart): static singleton `instance` (:56) set by the root; bundles location reporter (periodic 10 s, :310/:343), trip commands, trip chat, reverse-geocode, dispatch and presence. Screens check `LiveDriverServices.active` / `DriverRuntimeScope.maybeOf(context)?.account` (29 occurrences of live/auth gating in lib).
- Components that stay **demo/in-memory even in the live build** (lib/main.dart): `MemoryDriverSessionRepository` (:143), `InMemoryWaybillRepository.instance` (:145), `DemoSafetyAlertRepository` for ride-check alerts (:169, comment "demo outbox until a backend exists"), `LocalDriverHomeConfigRepository` (:166), `PrefsActiveRideRepository` (device storage, :167). See section 7.
- Several screens fall back to a demo when no repository is injected: `DriverHome` (`widget.dispatchRepository ?? DemoDispatchRepository()`, lib/presentation/driver/home/home.dart:479), `RideRequests` (lib/presentation/driver/ride requests/ride_requests.dart:230).

### Navigation and gates
- Navigator 1.0 (`MaterialApp(home:)` + 41 `Navigator.push`/`MaterialPageRoute`-style calls; no router package). Root: `DriverSessionGate` when `authRequired`, else `DriverHome` directly (lib/main.dart:301-308).
- `DriverSessionGate` (lib/presentation/driver/auth/session_gate.dart, 132 lines) → sign-in (3 steps) or Home; on refresh refusal `_sessionExpired` pushes Sign in (lib/main.dart:217-222).
- Account hold: `accountPending: !authRequired || _account.onHold` (lib/main.dart:377).
- `driverRouteObserver` (lib/core/session/driver_route_observer.dart) is the only navigator observer. `PopScope`/`WillPopScope` appear in 13 lib files.

### Realtime
- Offers: `ApiDispatchRepository` stream with exponential reconnect.
- Trip events: `ApiDriverRealtime` (lib/core/live/api_driver_realtime.dart) = SSE `GET /trips/{id}/events`, resumes with `?after=<seq>`, backoff min(30 s, 2^n) (:58-61, :259). Sequence ordering by `DriverRealtimeSequenceGate` (lib/core/realtime/driver_realtime.dart:278). Demo: `MemoryDriverRealtime` (:344).

### Maps / camera layer
- `lib/widgets/custom_google_map.dart` (510 lines) wraps `google_maps_flutter`; `lib/widgets/google_driver_camera_port.dart` (623) is the camera port; web uses `web/driver_map_camera.js` (666 lines, loaded from web/index.html:43, cache-busted with the commit SHA by deploy-pages).
- `lib/core/navigation/`: `driver_camera_controller.dart` (828), `navigation_controller.dart` (691), `route_camera_fit.dart`, `route_camera_geometry.dart`, `driver_map_zoom_change_detector.dart`, `map_double_tap_policy.dart`, `map_camera_report.dart` (camera reports added by #380), `live_vehicle_animator.dart` (33 ms ticker, see `liveMapTicker`).
- Web Maps key: placeholder `GOOGLE_MAPS_API_KEY` in web/index.html:42, replaced at deploy from secret `newmap131189`.

### l10n
- `l10n.yaml`, template `app_en.arb`; en/fr/sv each have **1621 keys** (identical counts). Runtime language switch via `DriverLanguage` + a full element rebuild (lib/main.dart:180-189).

### Audit tests (test/audit, 151 files)
Named after earlier audit rounds (e.g. `acceptance_session_races_test.dart`, `active_ride_restore_races_test.dart`, `authoritative_terminal_test.dart`, `exclusive_claim_resolution_test.dart`, `dependency_hygiene_test.dart`, `docs_truth_d54_test.dart`, `evidence_matrix_test.dart`). Many are source-text/structure guards rather than behaviour tests (e.g. split tests for `accept_ride_panel`/`accept_ride_trip`); they constrain refactors (see section 7).

## 3. CI

Workflows: `.github/workflows/drider-ci.yml`, `.github/workflows/deploy-pages.yml` (no others).

**Drider CI** — triggers: push to `main`, `chore/drider-phase0-1-baseline`, `audit/phase-*`; PR to `main`, `audit/phase-*`. Flutter pinned 3.47.6, `cache: true`. Timings from run 40317722373 (main @ 436bfb54, green):

| Job | Steps | Time |
|---|---|---|
| Analyze, test and build web (timeout 30 min) | pub get --enforce-lockfile (1 s), `flutter analyze --fatal-infos` (25 s), `flutter test` (8 m 55 s), tool/tests unittest + check_frontend_release (<1 s), verify_driver_map_web.cjs (<1 s), integration_test/driver_lifecycle_test.dart on flutter-tester (42 s), `flutter build web --release` (67 s), upload evidence | **11 m 37 s** |
| Android release signing and preview (40 min) | APK release must fail without signing (3 m), must fail without maps key (3 s), debug-signed preview APK (2 m 48 s) | 6 m 33 s |
| iOS release compile preflight (macos-14, 45 min) | `build ios --release --no-codesign` (3 m 35 s), must fail without maps key (33 s) | 4 m 57 s |

**Deploy Drider to GitHub Pages** — `workflow_run` after Drider CI succeeds on a push to `main` (or manual). Builds the live build first (`MOVERA_AUTH_REQUIRED=true`, `MOVERA_API_BASE_URL=$MOVERA_LIVE_API_URL`, base-href `/Movera-driver-app/live/`) then the demo build (`MOVERA_DEMO_ARRIVAL=true`), injects the Maps key from secret `newmap131189` and `DRIVER_MAP_ID` var. Build 2 m 39 s + deploy 59 s (run 40319129190). Permissions split correctly (only `deploy` has `pages: write`).

### Gaps vs the plan's Phase 2 table
| Check | Status |
|---|---|
| Lockfile install | present |
| `dart format --set-exit-if-changed` | **missing** (see section 4 for the count of unformatted files) |
| `flutter analyze --fatal-infos` | present |
| `flutter test` | present |
| Coverage report | **missing** (no `--coverage`, no lcov upload) |
| Build web / APK / iOS no-codesign | present (APK only as debug-signed preview) |
| E2E web probes | `verify_driver_map_web.cjs` is a static source check (<1 s); no browser probe in CI |
| Security: `pub outdated`/advisories, secret scan | **missing** |
| Caching | Flutter SDK cache only (`cache: true`); no pub-cache key |
| Timeouts | present on every CI job; **none** on the deploy workflow jobs |
| Branch protection | NOT VERIFIED (needs admin API; owner decision D1) |
| The live build (`MOVERA_AUTH_REQUIRED=true`) is **only built in deploy-pages after merge**, never in CI on a PR — a live-only compile break would surface after merge. |

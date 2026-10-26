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
- [x] 2. Dependencies
- [x] 3. CI
- [ ] 4. Baseline run
- [ ] 5. Coverage of critical logic
- [x] 6. Screen inventory
- [x] 7. Code quality
- [x] 8. Known issues (N1, N5, N6, N8, N9, N11)
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

## 2. Dependencies

Constraints: Dart `^3.8.1`, Flutter `>=3.41.0` (pubspec.yaml:22-23). `pubspec.lock` holds 161 packages. `flutter pub get --enforce-lockfile`: OK in 21 s locally, "70 packages have newer versions incompatible with dependency constraints"; no advisory / discontinued / retracted notice printed.

Direct dependencies (31 incl. SDK ones) and where they are imported (`package:<name>/` in lib / test files):

| Package | Locked | Latest | lib files | Note |
|---|---|---|---|---|
| google_maps_flutter | 2.13.1 | 2.19.0 | 22 | maps core |
| google_maps_flutter_platform_interface | 2.14.0 (pinned exact) | 2.17.0 | 2 | pinned for D-08 marker updates |
| geolocator | 14.0.2 | 14.1.2 | 2 | |
| http / http_parser | 1.5.0 / – | 1.6.0 | 8 / 1 | API |
| flutter_secure_storage | 10.3.4 | 11.2.0 (major) | 1 | tokens |
| shared_preferences | 2.5.3 | 2.5.6 | 10 | active ride, settings, vehicles (base64 photos) |
| sign_in_with_apple / google_sign_in | 8.2.0 / 7.2.0 | – | 1 / 1 | buttons show "Coming soon" until keys exist |
| file_picker | 10.3.2 | 13.3.0 (major) | 4 | |
| image_picker | 1.2.0 | 1.2.4 | 5 | |
| share_plus | 12.0.2 | 13.3.1 (major) | 1 | |
| pinput | 5.0.1 | 7.0.0 (major) | 1 | code entry |
| google_fonts | 8.2.1 | 9.0.0 (major) | 6 | fetches fonts at runtime unless bundled (NOT VERIFIED) |
| flutter_screenutil, sliding_up_panel, flutter_svg, pointer_interceptor, url_launcher, record, audioplayers, path_provider, web, intl, circle_progress_bar, country_pickers, dotted_line, flutter_rating_bar, mobkit_dashed_border | – | – | 1–30 each | all imported at least once |
| dev: crypto, shared_preferences_platform_interface, flutter_lints 5.0.0 (latest 6.0.0) | | | test only | |

- **Unused direct dependencies: none found** (every direct dependency is imported from lib/ or, for dev deps, test/). `sliding_up_panel 2.0.0+1` is an old, unmaintained package (last release years ago, NOT VERIFIED on pub.dev from here) used in 5 lib files.
- `flutter pub outdated --no-transitive`: **15 direct + 3 dev** outdated; 12 upgradable within constraints, 9 need a constraint change (majors: file_picker 13, flutter_secure_storage 11, google_fonts 9, pinput 7, share_plus 13, flutter_lints 6). Whole graph: 54 locked older than upgradable, 20 constrained below resolvable.
- Security advisories: `pub` printed none; a dedicated advisory scan (osv-scanner) was **NOT VERIFIED** (tool not installed here).
- Local Flutter is 3.47.7; CI and deploy pin 3.47.6 (drider-ci.yml, deploy-pages.yml).

## 6. Screen inventory

Method: every lib file with a `Scaffold(` (plus sheets opened as screens), its callers (`grep -rlE "\bClass\("` in lib), the number of test files naming the class, and whether the file itself has `PopScope`/`WillPopScope`. "Back" = custom Back handling in that file; screens without it use the default Navigator pop (no custom guard). Live column: whether the screen reads the server (L), only device/demo data (D), or both by mode (L/D).

| Screen (class) | File (lib/presentation/driver/…) | Entry points | Test files | PopScope | Data |
|---|---|---|---|---|---|
| DriverSessionGate | auth/session_gate.dart | main.dart (live root) | 1 | no | L |
| DriverSignIn (3 steps) | auth/sign_in.dart | main.dart, session expiry | 5 | no | L |
| DriverPhoneVerification | auth/phone_verify.dart | sign_in.dart | 4 | yes | L |
| DriverDetailsScreen (step 3 / Your details) | account/driver_details_screen.dart | session_gate, auth_navigation, profile | 1 | yes | L |
| DriverHome | home/home.dart (+ 35 part/component files) | main.dart, ride_completed | 51 | no (sheet-level) | L/D |
| RideRequests | ride requests/ride_requests.dart | home.dart | 17 | no | L/D (falls back to `DemoDispatchRepository()` :230) |
| AcceptRide (trip) | accept ride/accept_ride.dart | home_offer_radar, ride_requests, accept_ride_trip (next trip) | 72 | yes | L/D |
| Chat | common/chat/chat.dart | accept_ride_panel, accept_ride_sheet | 15 | no | L/D |
| Waybill sheet | waybill/waybill_sheet.dart (`showMoveraWaybillSheet`) | accept_ride_panel:1100/1115, accept_ride_sheet:110 | yes (waybill tests) | n/a (sheet) | in-memory record |
| DriverRideCompleted | ride completed/ride_completed.dart | accept_ride_trip | 18 | yes | L/D |
| DriverRideHistory / Detail | ride history/… | side menu, home sheet, accept_ride | 8 / 7 | yes / no | **device only** (PrefsTripHistoryRepository) |
| ScheduledRidesScreen | scheduled rides/scheduled_rides.dart | side menu, notifications, home | 16 | no | **D: seeded demo reservations** (see §7) |
| ReservationRouteMapPage | home/components/reservation_route_map.dart | same file :82 | 2 | no | D |
| DriverDestinationPicker / DestinationConfirmScreen | destination mode/… | home sheet, accept_ride_panel | 8 / 2 | no | L/D |
| MyQueuePosition sheet (+ InAirportQueue card) | my queue position/… | home_map_sheet:1028 (destination panel) | 2 | no | **D: sample ranks, not live-gated** |
| DriverProfile | profile/profile.dart | side menu | 6 | yes | L/D |
| DriverVehicles → LiveVehiclesScreen | vehicles/… | profile:257 | 5 / **0** | no | D / L |
| AddVehicle / VehicleDocuments | add vehicle/add_vehicle.dart | vehicles.dart (demo branch) | 5 / 9 | no | D (LocalVehicleStore) |
| AddCarScreen | account/add_car_screen.dart | my_fleet, live_vehicles | **0** | no | L |
| JoinFleetScreen | account/join_fleet_screen.dart | live_vehicles | **0** | no | L |
| MyFleetScreen | account/my_fleet_screen.dart | profile, server notifications, home | 1 | no | L |
| DriverDocuments / LiveDocumentsScreen / DocumentPreview | documents/… | profile, home | 8 / 1 / 2 | no | D / L / D |
| DriverNotificationsScreen | notifications/driver_notifications_screen.dart | side menu, home_account | 4 | no | D (in-memory feed) |
| ServerNotificationsScreen | notifications/server_notifications_screen.dart | home_account | **0** | no | L |
| Analytics / AcceptanceRate / CancelationRate | analytics/… | profile | 6 / 5 / 6 | no | **D: labelled sample numbers** |
| EarningStatsScreen | earning stats/earning_stats.dart | analytics | 2 | no | **D: sample** |
| WalletScreen / MyBank / AddNewAccount | my wallet, my bank | side menu, sheet nav, profile | 6 / 4 / 5 | no | D |
| Promotions | promotions/promotions.dart | side menu | 5 | no | D |
| DrivingLogs | driving logs/driving_logs.dart | side menu | 4 | no | D |
| Preferences | preferences/preferences.dart | side menu, sheet nav, accept_ride_panel | 12 | no | device |
| Settings / Accessibility / SoundAndVoice / EmergencyContacts / PinVerification | settings/… | profile, side menu | 6 / 5 / 6 / 7 / 4 | EmergencyContacts yes | device |
| SafetyToolKits sheet | safety toolkits/safety_toolkits.dart | home, accept_ride, settings | yes | no | D alerts (DemoSafetyAlertRepository) |
| SupportInboxScreen | support/support_inbox.dart | profile, side menu, home | 15 | yes | D |
| LegalDocumentScreen | profile/legal_document.dart | sign_in:54/56, profile:302 | 3 | no | static |
| DriverSideMenu | side menu/side_menu.dart | home, accept_ride | 5 | n/a | – |
| **AdditionalInfoNavigation** (+ SelectDocumentType, TakeIdPhoto, vehicle_*) | auth/additional detail/… | **no caller in lib** (legacy onboarding) | 2 / 0 / 2 | yes | dead code kept alive by tests (e.g. test/widget/frontend_legacy_boundary_test.dart) |

Screens with **no test file naming them**: AddCarScreen, JoinFleetScreen, LiveVehiclesScreen, ServerNotificationsScreen, SelectDocumentType — all but the last are **live-only fleet/notification screens from round 4b**.
Back handling: only 13 lib files use `PopScope`/`WillPopScope`; Back behaviour on the rest is default pop and is **not** systematically tested (Phase 5).

## 7. Code quality

### Huge files (lines, `wc -l`)
| File | Lines |
|---|---|
| lib/presentation/driver/scheduled rides/scheduled_rides.dart | 2706 (contains a 600-line static `ScheduledRideStore` at :461-1066 — state in a screen file) |
| lib/presentation/driver/home/home_map_sheet.dart | 2396 (26 `Timer` mentions, 29 setState/_rebuild) |
| lib/presentation/driver/accept ride/accept_ride_trip.dart | 1846 (45 `Timer` mentions; builds waybills, money) |
| lib/presentation/driver/accept ride/accept_ride.dart | 1798 (`_AcceptRideState` ~200 private fields) |
| lib/presentation/driver/home/home_offer_radar.dart | 1482 |
| lib/presentation/driver/accept ride/accept_ride_panel.dart | 1354 |
| lib/presentation/driver/account/driver_details_screen.dart | 1320 |
| accept ride/navigation_instruction_banner.dart, ride_check_card.dart | 1272, 1260 |
| lib/presentation/driver/home/home.dart | 1198 (66 `Timer` mentions) |
`home.dart` and `accept_ride.dart` are split with `part`/extensions (18 `part` lines) — the state is still one object; extensions only spread it over files.

### Business logic in widgets
- Trip money and waybill building inside the trip widget: `_paidWaybill`, `_buildCurrentWaybill`, `_buildNextWaybill` (accept ride/accept_ride_trip.dart:116, :278, :370).
- Scheduled-ride store, seeding and claim logic inside the screen file (scheduled_rides.dart:461-1066).
- Ride-history period totals computed in the widget (ride history/ride_history.dart:126-132).

### Demo code paths reachable in the live build (`MOVERA_AUTH_REQUIRED=true`)
Verified from source on main (not clicked on the live site):
| Path | Evidence | Risk |
|---|---|---|
| Scheduled rides seeded with demo reservations (rider "Lars", Södermalm → Bromma, 184 kr, plus `DemoReservations.main/clashing/airport`) | scheduled_rides.dart:464-509; the file has no live/auth check; reachable from side menu, notifications, home | S2: a live driver sees and can act on fake reservations |
| Airport queue card + "10 drivers ahead" sample ranks | home_map_sheet.dart:1025-1028 (destination panel), my_queue_pos.dart:29-38 | S3 |
| Analytics / earning stats sample numbers (labelled "Sample") | analytics/analytics.dart:19-20, earning stats/earning_stats.dart:67-362 | S3 (labelled) |
| Ride-check alerts go to `DemoSafetyAlertRepository` (never reach Movera) | lib/main.dart:169; ride_check_controller.dart:401 shows "not reached Movera" only by type check | S2 safety: in live the driver's alert is not sent to a server |
| Driver session in memory only | lib/main.dart:143 `MemoryDriverSessionRepository` | S3 (server presence is the truth) |
| Waybills in memory only (`InMemoryWaybillRepository.instance`) | lib/main.dart:145, waybill.dart:207-211 | S3: waybill gone after reload |
| Trip history and **today's earnings** from device storage only | core/history/today_earnings.dart:20-30 (`PrefsTripHistoryRepository`) | S2: new device / cleared storage / logout shows 0 earnings; not the server's numbers |
| Local vehicle store default `MVR 418` demo car | core/vehicle/local_vehicle_store.dart:71-83 | mitigated on main: Profile (profile.dart:44), Vehicles (vehicles.dart:58-59) and waybill (accept_ride_trip.dart:301-312) use the account in live — fixed by #380 / round 4b |
| `RideRequests` / `DriverHome` fall back to `DemoDispatchRepository()` when not injected | ride_requests.dart:230, home.dart:479 | S4 (root injects the live one) |
| `adminDemoOffers: !driverProductionRequested` is **true in the live build** | driver_runtime_config.dart:94 | S4 — only read by the demo dispatch (NOT VERIFIED that nothing else reads it) |

### Client-side money vs server numbers
- **Currency assumed SEK when summing**: `TodayEarnings.totalOf` sums `minorUnits` of every record regardless of currency and formats with `Money.ore(total)` = SEK (core/history/today_earnings.dart:35-49; `Money.ore` defaults `currency='SEK'`, core/money/money.dart:6-8). Same in ride history totals (ride_history.dart:126-132) and `TripHistoryRecord.fareMoney` (trip_history.dart:126-129, `Money.parseSekLabel` / `Money.ore`). A Paris (EUR) driver's island would show "kr". **S2**, untested for EUR.
- `RideOffer.driverPay` falls back to a **client 25 % commission** (`WaybillPayment.serviceFeeRate = 0.25`, waybill.dart:362) when the server sent no `driverEarnings` (dispatch_repository.dart:154-159). Waybill fee lines computed locally: `_feeOre = ((rider - wait) * feeRate).round()` (waybill.dart:427-445); label parse fallback "in kronor" (waybill.dart:451-459).
- Pickup pay computed client-side (`PickupPayCalculator`, core/dispatch/pickup_pay.dart:85-112) when the offer has no `pickupPay`.
- On main the live trip end uses the server projection (`LiveTripMoney.tryParse`, core/live/live_trip_money.dart) — this is the N9 fix from #380.

### Timers / streams / listeners
- 12 `Timer.periodic` in lib. Heuristic (creates vs `.cancel()` per file) flagged only home_start_position.dart, whose `_startWait` is cancelled in home.dart:1145 — no leak found. Files with more `addListener` than `removeListener` were checked by hand for the big ones (accept_ride.dart:614-749, home.dart:470-1187, adaptive_trip_island.dart:170-191): the unmatched ones listen to objects the same State owns and disposes. No leak proven; **no automated leak test** exists.
- `LiveDriverServices.instance` is a mutable static singleton (live_driver_services.dart:56): tests must reset it; screens reach it globally.

### Duplication with the rider app (/home/user/movera-rider-app, origin/main c1063fb8)
Same-purpose files written twice, diverged (diff lines): `money.dart` driver 229 / rider 134 (287), `api_client.dart` 406 / 371 (407), `secure_token_store.dart` 161 / 187 (132), `trip_status.dart` 109 / 234 (275), `geo_point.dart` 88 / 12, `token_store.dart` 33 / 30 (5). No shared package. Contract copy: driver **0.5.3**, rider 0.5.0, contract repo 0.5.5 (contracts/contract.json:3).

### Secrets and keys
- Working tree: no key literal found (`git grep` for `AIza…`, private keys, tokens). Maps key injected at deploy (web/index.html:42 placeholder) and from env on Android/iOS (android/app/build.gradle.kts:29, ios/Runner/Info.plist:6).
- **History: a Google API key (`AIzaSyB2…`, redacted here) is in git history** in commits e6729267 / 039b3b7d (android/app/src/main/AndroidManifest.xml) and removed in f3c6cb69. **S2**: confirm it is restricted (Android package + SHA-1) or rotate it (NOT VERIFIED which restrictions apply — needs the owner's Google Cloud console).
- android/local.properties is not tracked; android/gradle.properties is tracked (JVM flags only).

### Personal data in logs
- `DriverLog` (core/logging/driver_log.dart) documents "no rider names, phone numbers" and scrubs `FormatException` sources; prints via `debugPrint` (also in release web console). 58 log/print call sites; the ones checked log trip ids, status codes and `error.detail` (live_trip_commands.dart:226 logs the server's `detail` text verbatim — content not controlled by the app, NOT VERIFIED free of PII). `sheets/sheet_trace.dart:11` prints sheet positions unconditionally when called.

## 8. Known issues (owner notes) — status on main

PR #380 is merged (main = 436bfb54), so "main" and "#380" are the same code. Its own "Still open" list: N6 device reproduction, N8 driver-side live run.

| Note | Status on main | Evidence | Remaining |
|---|---|---|---|
| N1 radar offers on the island | **Fixed** | test/audit/home_notices_radar_sheet_test.dart:423 group "owner N1"; the formerly red `accessibility_d53a_test` driver-u136 was updated in #380 (result of this run in §4) | screenshots only from the demo build |
| N5 traffic layer | **Fixed** | `trafficEnabled: false` lib/widgets/custom_google_map.dart:446 — every map in lib goes through `CustomGoogleMap` (6 call sites, no raw `GoogleMap(`); no `TrafficLayer` in web/driver_map_camera.js; test/widget/no_traffic_layer_test.dart | – |
| N6 pinch zoom on the trip map | **Partly** (defence only) | `CustomGoogleMap._onCameraMove` drops web reports with zoom 0 / centre 0,0; lib/core/navigation/map_camera_report.dart; test/core/map_camera_report_test.dart | crash/fight/snap not reproduced; needs iPhone Safari (D3) and a Maps key in CI (D2). NOT VERIFIED |
| N8 ride check from the driver side | **Open (driver side)** | driver card is local: `RideCheckDetector` (lib/core/safety/ride_check_detector.dart:119-121) fires when the drop is farther than `farDropMeters` = `defaultFinishFarFromDropoffKm = 3` km (lib/core/admin/ride_check_admin_config.dart:9) — **not 300 m** as in the owner's scenario; alerts go to `DemoSafetyAlertRepository` in every build (lib/main.dart:169) | verify the intended threshold with the owner/server; a live-rig run; Phase 3 scenario 7 |
| N9 server's final money after early finish | **Fixed** | `LiveTripMoney.tryParse` (lib/core/live/live_trip_money.dart); test/core/live_trip_money_test.dart, test/widget/live_trip_finish_money_test.dart | today's earnings/history still sum locally and assume SEK (§7) |
| N11 waybill identities | **Fixed except rider name** | live name/car from the account (accept_ride_trip.dart:301-312), reverse-geocoded pickup (`LiveAddressLookup`, live_driver_services.dart:109); test/audit/trip_waybill_fare_test.dart:131 | the rider's first name is not in the contract: "Passenger" stays until the server+contract change (Phase 0 item) |

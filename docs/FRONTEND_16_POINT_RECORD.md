# 16-point frontend record

Driver frontend only, on `baccarisverige-ux/Movera-drider-`. Rider, Admin, backend, payments, auth server, support transport, dispatch server, and database work were out of scope. This note was written from main `2b46a5711a9590da76b82d978f7103d045ad7f92` (F10d, pull request #90). It does not change product behavior.

The plan started from frozen main `7332577b4f41d53ccd57e8ab0adb352eaffccaca` (Phase 56, pull request #72). Phase 46 / pull request #62 is an older gate. It is not the current gate.

This file does not certify a device, browser, visual diff, accessibility pass, or performance run. It does not certify native Google Maps. `docs/certification/RELEASE_EVIDENCE_MATRIX.md` stays entirely PENDING. A row may say PASS only when `artifact` points at evidence for that same SHA. This commit cannot cite its own workflow run, because that run does not exist until after the commit is pushed.

## What CI actually ran

Workflow name: `Drider CI` (`.github/workflows/drider-ci.yml`).

- `web` below means the run's only product job was "Analyze, test and build web", and that job succeeded. Those runs do not include Android signing or iOS compile.
- `web+android+ios` means all three jobs succeeded: web (including the Critical lifecycle step when the workflow file at that SHA contains it), Android release signing and preview, and iOS release compile preflight.
- A pull-request run certifies that pull-request head SHA, not the later squash SHA.
- A main push run certifies the squash SHA in `head_sha`, not a descendant.
- Native jobs exist from F04. The lifecycle step exists from F05. Do not read them backward onto earlier runs.

| Finding | PR | Merge SHA | PR-head run | PR-head jobs | Main push run | Main jobs |
| --- | --- | --- | --- | --- | --- | --- |
| F01 camera usage | [#73](https://github.com/baccarisverige-ux/Movera-drider-/pull/73) | `8fea72572e037c337149489c893f8561e7d9be64` | [36843680136](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36843680136) | web | [36844143711](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36844143711) | web |
| F02 chat contact | [#74](https://github.com/baccarisverige-ux/Movera-drider-/pull/74) | `a4507b5eccff60bfa809d57dd059a20b1019a81d` | [36843681721](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36843681721) | web | [36844154702](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36844154702) | web |
| F03 bank truth | [#75](https://github.com/baccarisverige-ux/Movera-drider-/pull/75) | `d133ea74f380c2cf7f2569f35f07ed97c166eac8` | [36843684551](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36843684551) | web | [36844163742](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36844163742) | web |
| F04 release signing | [#76](https://github.com/baccarisverige-ux/Movera-drider-/pull/76) | `b5433f8da909a756e328dd4a08c51cff7e9d4168` | [36845168817](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36845168817) | web+android+ios | [36852119531](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36852119531) | web+android+ios |
| F12 storage permissions | [#77](https://github.com/baccarisverige-ux/Movera-drider-/pull/77) | `b1188e93a00a3f61cdc62400e1e797c52c9dd4d1` | [36843933945](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36843933945) | web | [36844599790](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36844599790) | web |
| F07 local data | [#78](https://github.com/baccarisverige-ux/Movera-drider-/pull/78) | `d26da2f07010e2d8b0c27245f9b544d1a12599be` | [36843936936](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36843936936) | web | [36844605945](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36844605945) | web |
| F09 route client | [#79](https://github.com/baccarisverige-ux/Movera-drider-/pull/79) | `3812a137988a5ba99924de45da473c34124dec3e` | [36843939933](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36843939933) | web | [36844610568](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36844610568) | web |
| F06 evidence matrix | [#80](https://github.com/baccarisverige-ux/Movera-drider-/pull/80) | `e6d3c691244ddd68239e40745a1e0f892e834cbb` | [36843942177](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36843942177) | web | [36844616948](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36844616948) | web |
| F11 dead withdrawal UI | [#81](https://github.com/baccarisverige-ux/Movera-drider-/pull/81) | `ca9c0089c532c3280d261c4ed13909145636cff7` | [36843945673](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36843945673) | web | [36844622628](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36844622628) | web |
| F08 chat dispose | [#82](https://github.com/baccarisverige-ux/Movera-drider-/pull/82) | `7a7ebd53f5beae4c8087c750e4b711cb3f1bf95d` | [36844683887](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36844683887) | web | [36845051086](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36845051086) | web |
| F16 location privacy | [#83](https://github.com/baccarisverige-ux/Movera-drider-/pull/83) | `971510d31c0e2e0e31d87a22cf98c3dbfa190cf9` | [36844366746](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36844366746) | web | [36845055880](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36845055880) | web |
| F14 unused dependency | [#84](https://github.com/baccarisverige-ux/Movera-drider-/pull/84) | `792b44ff986ed0c1fc5ded7db9d50c2b3a861636` | [36845708673](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36845708673) | web | [36852127874](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36852127874) | web+android+ios |
| F05 lifecycle test | [#85](https://github.com/baccarisverige-ux/Movera-drider-/pull/85) | `b1864bf94dd376b8a084b193d9927fd26b573fcf` | [36875058892](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36875058892) | web+android+ios | [36875953309](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36875953309) | web+android+ios |
| F15 display name | [#86](https://github.com/baccarisverige-ux/Movera-drider-/pull/86) | `b58d270061c93eb7b808e0e53500fccf0e46d619` | [36845236354](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36845236354) | web | [36845582009](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36845582009) | web |
| F10a Home offers | [#87](https://github.com/baccarisverige-ux/Movera-drider-/pull/87) | `60ef8293560c4a212c8ea106a799ef67e2bebaa9` | [36878106073](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36878106073) | web+android+ios | [36879180733](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36879180733) | web+android+ios |
| F10c AcceptRide trip | [#88](https://github.com/baccarisverige-ux/Movera-drider-/pull/88) | `419e051caa650627428066f7eea6267b32ae7c88` | [36878741763](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36878741763) | web+android+ios | [36879914306](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36879914306) | web+android+ios |
| F10b Home map/sheet | [#89](https://github.com/baccarisverige-ux/Movera-drider-/pull/89) | `4b983ab26a53bdcdae15d08ba64b3752222544e7` | [36880572226](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36880572226) | web+android+ios | [36881621759](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36881621759) | web+android+ios |
| F10d AcceptRide panel | [#90](https://github.com/baccarisverige-ux/Movera-drider-/pull/90) | `2b46a5711a9590da76b82d978f7103d045ad7f92` | [36881206360](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36881206360) | web+android+ios | [36882061165](https://github.com/baccarisverige-ux/Movera-drider-/actions/runs/36882061165) | web+android+ios |

F04 pull-request head was `b820a9c989fb06d045692115153d4b0afbdbe64b` (run 36845168817). That Android job succeeded on the fail-closed step, the missing-maps-key step, and the explicit preview build. F05 pull-request head was `e90596edef1101d1963966a46b61fc9034c4ad43`. Its web job's "Critical lifecycle" step succeeded. The newest SHA in the table, `2b46a57`, main run 36882061165, also has Critical lifecycle, Android, and iOS green. That still does not fill the evidence matrix.

F14's pull-request head did not run the native jobs. Its squash SHA did, because that main push already contained the F04 workflow.

## Finding intent that landed

- F01. `NSCameraUsageDescription` for the image-picker camera paths. No photo-library key was added. No always-location key.
  - Update 2026-10-21 (audit driver-u6, owner decision): `NSPhotoLibraryUsageDescription` and `NSAppleMusicUsageDescription` are now declared, because image_picker and file_picker reference those APIs and App Store processing rejects the upload without them (ITMS-90683). The app still never requests either; the strings say so.
- F02. Chat does not dial `tel:+46701234567` and does not show a hard-coded driver name. `Chat` takes `riderDisplayName`. With no rider phone connected, it does not dial; the message is `Rider phone contact is not connected in this demo.` Emergency `tel:112` and user-entered emergency contacts stay.
- F03. My Bank matches the disconnected wallet preview. No invented account holder, bank, or IBAN. Add Account stays a local draft. The wallet chip says `Not set`, not a weekly payout.
- F04. Android release does not silently use debug signing when `MOVERA_UPLOAD_STORE_FILE` is absent. Preview signing requires `MOVERA_ALLOW_DEBUG_SIGNED_PREVIEW=true`. `MOVERA_REQUIRE_MAPS_KEY=true` fails a native release when `GOOGLE_MAPS_API_KEY` is blank. Debug configuration itself does not throw. iOS preflight is `flutter build ios --release --no-codesign`. Application id stays `se.movera.driver`.
- F05. `integration_test/driver_lifecycle_test.dart` drives real `MoveraApp` with the existing demo services: launch, offline, online, offer, accept, arrive, start, in trip, complete, Home offline, plus dismiss driver cancel without ending the trip. The OFF control is tapped on `trip-radar-touch-target` above the collapsed sheet. `HeadlessMapPlatform` creates each platform view once. That stand-in does not certify native Google Maps. Linux CI cannot host `google_maps_flutter`.
- F06. The evidence matrix plus `tool/check_evidence_matrix.py` reject `| PASS |` with an empty artifact. Rows were left PENDING on purpose.
- F07. Logout `clearLocalUserData` removes only the inventoried `movera_driver_*` keys (active ride, terminal trips, completion journal, completed trips, support drafts, settings and `movera_driver_settings_section_`). Web `localStorage` under the Flutter prefix is demo state, not secure storage. Active-trip recovery stays until logout.
- F08. Chat disposes `_messageController` before `super.dispose()`.
- F09. `RoadRouteService` closes an `http.Client` only when it created it (`ownsClient`). Timeout and offline become `RoadRouteException` and must not tear down the trip. Default timeout is 8 seconds. `MoveraApp.dispose` calls `_routing.dispose()`.
- F10. Behavior-preserving `part` / `extension` split. No sheet-geometry or map-control redesign. Public widgets stay `DriverHome` and `AcceptRide`. Extensions call `_rebuild` because `setState` is protected. `addListener` / `removeListener` use stable State fields, not a new extension tear-off on each evaluation. Offer timers stay 2200, 11500, 14500, 17500, 50000, and 40000 ms after the 1400 ms go-online timer.
- F11. `tool/source_inventory.py` before delete. Removed proven-dead withdrawal UI only. Kept `lib/core/contracts/driver_trip_gateway.dart` and `lib/core/failures/failures.dart`.
- F12. Removed `READ_EXTERNAL_STORAGE` and `WRITE_EXTERNAL_STORAGE`. Kept `INTERNET`, `ACCESS_FINE_LOCATION`, and `ACCESS_COARSE_LOCATION`. See `docs/ANDROID_PERMISSIONS.md`.
- F14. Removed unused `flutter_sliding_up_panel` only. `sliding_up_panel` stays. No bulk upgrades. See `docs/DEPENDENCIES.md`.
- F15. User-visible titles say Movera Driver, not the Flutter template string or lowercase `movera`. Bundle id / application id were not changed.
- F16. Removed `NSLocationAlwaysUsageDescription`. When-in-use copy says location is used only while the app is open and background location is not used. No `UIBackgroundModes`. No `NSLocationAlwaysAndWhenInUseUsageDescription`. The F01 camera string stays.

## Source inventory at this code tip

Regenerated with `python3 tool/source_inventory.py` into `docs/SOURCE_INVENTORY.json` (import, export, and part graph; not proof that a retained seam is dead):

- `app_reachable`: 130
- `test_reachable`: 196
- `outside_app_graph`: `driver_trip_gateway.dart`, `driver_document.dart`, `driver_profile.dart`, `earnings.dart`, `failures.dart`, `vehicle.dart`
- `outside_app_and_tests`: `lib/core/contracts/driver_trip_gateway.dart` and `lib/core/failures/failures.dart` only

The previous committed snapshot (124 / 176) was stale after the F10 parts. Do not reuse it.

## Still not done

Do not mark the 16-point plan fully certified. Still pending, with no artifact on this SHA:

- physical iPhone and Android sheet, map, lock/resume
- Chrome, Safari, and Edge on a deployed build
- visual diffs at 390, 320, and 200% text
- VoiceOver and TalkBack
- cold-start and 30-minute soak traces
- PWA install, reload, and lock
- a native Google Map run (the headless platform is not that)

Demo mode remains on. There is no production dispatch, payment, support transport, or account backend in this repository.

## How to continue

Branch from latest main. One concern per pull request. Push with `git push origin HEAD:<branch>` so a worktree that tracks `origin/main` cannot update `main` by accident. Squash-merge only after that head's own `Drider CI` jobs are green. Look up run IDs with `gh api repos/baccarisverige-ux/Movera-drider-/actions/runs?head_sha=<sha>`. Never invent one.

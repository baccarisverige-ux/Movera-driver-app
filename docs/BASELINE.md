# Movera Drider — current protected baseline

## Scope

This repository is **Movera Drider**: `baccarisverige-ux/Movera-driver-app` (formerly `Movera-drider-`).
The separate Rider repository is out of scope.

The application remains a Flutter frontend/demo. Architecture and reliability work must preserve the current product design unless a later task explicitly authorizes redesign.

## Canonical bootstrap

The current app starts directly on the Driver surface:

`MoveraApp → LayoutViewport → ScreenUtilInit → GetMaterialApp → DriverHome`

The old Splash bootstrap is not part of the canonical app entry. Legacy authentication remains opt-in behind `MOVERA_ENABLE_LEGACY_AUTH`.

## Current runtime boundaries

- Driver session state is owned by `DriverSessionController`.
- Active trip state and recovery use `ActiveRideController` / `ActiveRideRepository`.
- Completed/cancelled terminal transitions use the replayable `CompletionJournal`.
- Terminal markers prevent completed/cancelled snapshots from resurrecting.
- Completed-trip History is a separate projection and does not invent missing tip/payment facts.
- Driver realtime remains an in-memory/backend-ready seam. Events are sequence-gated per trip; duplicate/reordered events are ignored and terminal events dominate later non-terminal events.
- Driver location, routing, dispatch, support and settings remain replaceable boundaries rather than production backend integrations.
- Canonical market/currency remains Stockholm / SEK.

## Post-audit protections now present

- Home/active-trip lifecycle ownership and explicit `DriverOnlineStatus.onTrip`.
- Cold start remains offline.
- Replayable completion/cancellation journal.
- Driver/rider cancellation metadata survives terminal cleanup.
- Active-trip stale recovery and exact-trip cleanup.
- Bounded terminal-marker retention with legacy-marker compatibility.
- History archive idempotency by `tripId`.
- Truthful local/demo labels for contact, chat, support, settings, analytics, earnings, queue, promotions and driving-log preview data.
- Support optimistic state rolls back when local persistence fails.
- Settings persistence is isolated per section so one corrupted section does not erase unrelated sections.
- Realtime sequence ordering, reconnect replay of the newest known event and terminal dominance.
- Conservative orphan cleanup only after analyzer proof.

## Sheet behavior

A real-device smoke test was reported by the product owner on 2026-09-30 with no sheet defect observed. Device model/platform and the full trace matrix were not captured. Because no reproducible issue exists, the current Home and Active Ride sheet behavior is protected from speculative Phase 36/37 rewrites.

## File split

F10 kept the public widgets `DriverHome` and `AcceptRide` and did not redesign the sheet or map controls. Same-library parts:

- `lib/presentation/driver/home/home.dart` with `home_offer_radar.dart` and `home_map_sheet.dart`
- `lib/presentation/driver/accept ride/accept_ride.dart` with `accept_ride_trip.dart` and `accept_ride_panel.dart`

Listener tear-offs that are added and removed stay as stable fields on the State. Extension code calls `_rebuild`, not `setState`.

## Product limits

This repository does **not** establish a live production backend for dispatch, payments, support, chat delivery, reservations, document review, OTP, safety recording/sharing or account verification. Local/demo state must not be described as a successful production action.

## Current verification gate

Written against code main `2b46a5711a9590da76b82d978f7103d045ad7f92`. This description does not certify a later commit.

Every implementation pull request must pass on its exact head. The workflow file at that head determines which jobs exist.

1. `flutter pub get`
2. `flutter analyze --no-fatal-infos`
3. `flutter test`
4. `flutter test integration_test/driver_lifecycle_test.dart -d flutter-tester` (since F05; flutter-tester with a headless map stand-in, not a native Google Map)
5. `flutter build web --release`
6. Android release job: fail closed without upload signing secrets; separate debug-signed preview only when `MOVERA_ALLOW_DEBUG_SIGNED_PREVIEW=true`; missing maps key fails when `MOVERA_REQUIRE_MAPS_KEY=true` (since F04)
7. `flutter build ios --release --no-codesign` (since F04)
8. verification artifact upload

No newer commit is covered by an older successful workflow run. A successful main push on a squash SHA covers that squash SHA only. Physical device, browser, visual, and performance checks stay PENDING in `docs/certification/RELEASE_EVIDENCE_MATRIX.md` until an artifact for that same SHA is recorded. Do not mark those rows PASS from CI alone.

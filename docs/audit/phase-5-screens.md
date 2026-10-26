# Driver app — Phase 5: every screen and every button

Branch `audit/phase-5-driver`. Rules: `AUDIT_PLAN.md` Phase 5. Status per screen:
**tested** (automated widget tests cover its controls, states and Back), **needs device** (the part that
matters needs a real phone, a Google Maps key or the live server: listed in the owner's device list),
**n.a.** (not a screen a driver reaches).

"Sweep" = `test/audit/phase5/screen_sweep_test.dart`: opens the screen, lays it out at 320×568 with text
×2 in sv, fr and en (and 390×844 ×1 in sv), fails on any overflow or exception, then the **system Back**
(Android button / browser back) must leave it with no crash. 21 screens × 4 = 84 tests.

## Screens

| # | Screen (file under `lib/presentation/`) | Reached from | Tests (files naming it, before → now) | Status |
|---|---|---|---|---|
| 1 | Sign in, 3 steps (`driver/auth/sign_in.dart`) | session gate | 5 | tested |
| 2 | Phone verification (`driver/auth/phone_verify.dart`) | sign in | 5 | tested |
| 3 | Session gate (`driver/auth/session_gate.dart`) | app root (live) | 1 | tested |
| 4 | Home: map, radar, offers, island, sheets (`driver/home/home.dart`) | root | 52 → 53 (+D-3 restore) | tested; map camera/pinch **needs device** (N6, D2/D3) |
| 5 | Trip screen (`driver/accept ride/accept_ride.dart`), with island, ride check card, cash, waiting, finish-soon, outcome sheets | Home | 73 → 74 | tested; real GPS/map **needs device** |
| 6 | Ride completed (`driver/ride completed/ride_completed.dart`) | trip end | 18 | tested (M6 label sv/fr/en) |
| 7 | Chat (`common/chat/chat.dart`) | trip | 15 | tested |
| 8 | Ride requests (`driver/ride requests/ride_requests.dart`) | Home | 17 | tested |
| 9 | Scheduled rides + details + cancel sheets (`driver/scheduled rides/…`) | side menu, Home | 17 → 19 (+live empty state) | tested |
| 10 | Reservation route map (`driver/home/components/reservation_route_map.dart`) | scheduled ride | 2 | tested; map **needs device** |
| 11 | Destination picker / confirm (`driver/destination mode/…`) | Home | 8 / 2 | tested; map **needs device** |
| 12 | Ride history + detail + cash balance sheet (`driver/ride history/…`) | side menu | 8 / 7 | tested (+sweep) |
| 13 | Profile (`driver/profile/profile.dart`) | side menu | 6 | tested |
| 14 | Legal document (`driver/profile/legal_document.dart`) | sign in, profile | 3 | tested |
| 15 | Driver details (`driver/account/driver_details_screen.dart`) | gate (live) | 1 | tested |
| 16 | My fleet (`driver/account/my_fleet_screen.dart`) | profile (live) | 1 (8 tests) → +1 (one pick at a time) | tested |
| 17 | Join fleet (`driver/account/join_fleet_screen.dart`) | vehicles, my fleet (live) | **0 → 1** | tested |
| 18 | Add car (`driver/account/add_car_screen.dart`) | vehicles, my fleet (live) | **0 → 1** | tested |
| 19 | Vehicles, live (`driver/vehicles/live_vehicles_screen.dart`) | profile (live) | **0 → 1** | tested |
| 20 | Notifications, server (`driver/notifications/server_notifications_screen.dart`) | Home bell (live) | **0 → 1** | tested |
| 21 | Notifications, demo feed (`driver/notifications/driver_notifications_screen.dart`) | Home bell (demo) | 4 (+sweep) | tested |
| 22 | Documents, live (`driver/documents/live_documents_screen.dart`) | profile (live) | 1 | tested; file picker upload **needs device** |
| 23 | Documents, demo (`driver/documents/documents.dart`) | profile (demo) | 8 (+sweep: fr overflow fixed) | tested |
| 24 | Document preview (`driver/documents/document_preview.dart`) | documents | 2 | tested |
| 25 | Vehicles, demo (`driver/vehicles/vehicles.dart`) | profile (demo) | 5 (+sweep) | tested |
| 26 | Add vehicle, demo (`driver/add vehicle/add_vehicle.dart`) | vehicles (demo) | 6 | tested |
| 27 | Analytics / Acceptance rate / Cancellation rate (`driver/analytics/…`) | profile | 6 / 5 / 6 (+sweep) | tested (labelled sample numbers, Phase 1 S3) |
| 28 | Earning stats (`driver/earning stats/earning_stats.dart`) | analytics | 2 (+sweep) | tested (sample, labelled) |
| 29 | Wallet / My bank / Add account (`driver/my wallet`, `driver/my bank`) | side menu | 6 / 4 / 5 (+sweep) | tested (demo) |
| 30 | Promotions (`driver/promotions/promotions.dart`) | side menu | 5 (+sweep) | tested (demo) |
| 31 | Driving logs (`driver/driving logs/driving_logs.dart`) | side menu | 4 (+sweep) | tested (demo) |
| 32 | My queue position / in airport queue (`driver/my queue position/…`) | destination panel | 3 | tested (sample ranks, Phase 1 S3) |
| 33 | Preferences (`driver/preferences/preferences.dart`) | side menu, trip | 142 (+sweep) | tested |
| 34 | Settings / Accessibility / Sound & voice (`driver/settings/…`) | profile | 14 / 5 / 6 (+sweep) | tested |
| 35 | Emergency contacts (`driver/settings/emergency_contacts.dart`) | settings | 7 (+sweep) | tested; the dialer **needs device** |
| 36 | PIN verification (`driver/pin verification/pin_verification.dart`) | trip | 4 (+sweep) | tested |
| 37 | Support inbox (`driver/support/support_inbox.dart`) | profile, side menu | 15 (+sweep) | tested |
| 38 | Safety toolkit sheet (`driver/safety toolkits/safety_toolkits.dart`) | Home, trip | 9 | tested; 112 call **needs device** |
| 39 | Side menu (`driver/side menu/side_menu.dart`) | Home | 5 | tested |
| 40 | Waybill sheet (`driver/waybill/waybill_sheet.dart`) | trip, history | 4 | tested (M6 row) |
| 41 | Legacy onboarding: additional detail, vehicle registration, insurance, upload/take ID photo, select doc type (`driver/auth/additional detail/…`) | not reachable (Phase 1 R13) | 0–2 | n.a. |
| 42 | `AuthScaffold` (`driver/auth/widgets/auth_scaffold.dart`) | layout wrapper of 1–2 | — | n.a. |

## What each new test checks

- **Controls do their action, once:** Notifications row (marked read once over three quick taps), Add car Save
  and Join fleet Ask (one POST over three taps while the first is in flight), choosing a car on Vehicles and on
  My fleet (one PATCH when a second car is tapped while the first pick runs: **was two**).
- **Loading / empty / error:** Notifications (spinner, "no notifications", error + Retry recovers), Vehicles
  (error + Retry, member with no cars), Scheduled rides in a live build (honest empty state).
- **Forms validate:** Add car keeps Save off until every field is filled and the year is 1950–2100; Join fleet
  keeps Ask off for a malformed e-mail.
- **Back never crashes:** every screen in the sweep, plus the four live screens (page back).
- **Small screens, large text, three languages:** the sweep (84) and the four live screens at 320×568 ×2 in
  sv/fr/en.

## Not covered here (needs device / owner list)

Map rendering, camera and pinch (N6), real GPS, the phone's dialer (112, emergency contacts), the file
picker and camera for documents, keyboard-open layout on a real iPhone, reopening the app on a device (the
restore logic itself is covered: D-3 test, restore suites).

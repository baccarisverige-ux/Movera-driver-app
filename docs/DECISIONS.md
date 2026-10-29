# Movera platform decisions (P1, P2, P4, D11)

Written 21 September 2026. These are the Week 0/1 product records from
*Movera Platform Audit & Work Plan*. They are not a backend and they do not
change Driver or Rider screens.

## P1 — Canonical vocabulary

| Concept | Canonical name | Notes |
|---|---|---|
| Trip identifier | `tripId` | Neutral to Rider `rideId` and Driver `offerId`/`tripId`. Rider rename is R4 (later). |
| Trip lifecycle | `TripStatus` | See enum below. Payment and rating are **not** trip states. |
| Currency code | `SEK` | ISO 4217. Minor units are öre integers. |
| Vehicle categories | `economy`, `comfort`, `premium`, `priority`, `xl`, `electric`, `pet` | Contract seed ids (`contracts/contract.json#categories`); ids come from the admin Pricing catalog, which may add more. `movera` is a read-only alias of `economy` for one release. The driver app still shows its display names ("Movera", "Movera XL") and maps them with `CategoryCatalog` (`lib/core/contracts/category_catalog.dart`); "Booster Seat" is an extra, not a category. |

### TripStatus

Happy path:

`draft → quoted → requested → searching → offered → accepted → driver_to_pickup → arrived → rider_onboard → in_trip → approaching_dropoff → completed`

Terminal:

`completed` · `cancelled_by_rider` · `cancelled_by_driver` · `cancelled_by_admin` · `cancelled_by_system` · `no_show` · `expired` · `failed`

The source of truth is now `contracts/contract.json` (v0.17.0, copied byte-for-byte from the `movera-contracts` repository; see "Contract v0.3" and "Contract v0.4" below).

Driver `ActiveRideStage` maps onto the live slice only:

| ActiveRideStage | TripStatus |
|---|---|
| `headingToPickup` | `driver_to_pickup` |
| `waitingForRider` | `arrived` |
| `onTrip` | `in_trip` |

### Separate machines (not TripStatus)

- **PaymentStatus:** `pending → authorized → captured`, plus `failed`, `refunded`
- **RatingStatus:** `pending → submitted → skipped`
- **DriverOnlineStatus:** `offline`, `going_online`, `online`, `on_trip`, `suspended`

## P2 — Market / currency

**SEK / Stockholm.** Rider and Driver already run this market. Admin's USD / New York sample data is placeholder and is replaced in A10. Named owner: Movera product (this record).

## P4 — State ownership

| State | Owner | Clients |
|---|---|---|
| Trip status | Backend | Rider, Driver, Admin receive projections |
| Driver availability | Backend | Driver sends intent; Admin may suspend |
| Fare | Backend | Clients display a quote; they do not invent totals |
| Payment status | Backend / PSP | Rider sees result; Driver sees payout implication |
| GPS | Driver device sends, backend stores | Rider/Admin receive a projection |
| Queued next trip | Backend (`GET /api/v1/drivers/:id/queue`) | Driver `WaybillRepository.next` is the local slot |

Until a backend exists, each app keeps its current mock, but **new code uses these names**.

## D11 — Online status after restart

A driver does **not** return online after a crash or cold start. Going online is an explicit action. `DriverSessionController.restore()` therefore stays offline even if the last in-memory write was online.

## Out of this record

P3 (`movera-contracts` OpenAPI) consumes this document. R3–R5 and D5 (full ActiveRideStage replacement) wait on this record and do not redesign screens.

D3 — `GeoPoint` is the domain type. `LatLng` conversion lives in `lib/core/geo/geo_point_maps.dart`. `RoadRoute.points` is `List<GeoPoint>`.

D4 — Driver, Vehicle, DriverDocument, and Earnings repositories exist under `lib/core/` as in-memory seams. Screens are not yet wired (no UX change).

D6 — `Money` stores öre integers and formats `104,80 kr`. Existing screen literals are unchanged until a later wiring pass.

D7 — History detail takes a `TripHistoryRecord`. Tapping a history card opens that trip, not dummy Pakistan/USD copy.

D8 / D9 — `DriverRealtime` is a sequence-numbered envelope. `riderCancelled` is a kind on that envelope. Screens do not subscribe yet.

P5 — ~~Same envelope shape as Rider's `RideRealtimeEvent`~~. This was not true: the Driver and Rider envelopes differed (fields, status type, kinds). Both apps now target the one envelope in `contracts/contract.json#realtime` (`eventId, tripId, sequence, version, kind, occurredAt, serverTime` + optional `projection, location, etaSeconds, cancelFee, message`).

## Active ride crash recovery (Safari / PWA)

Safari was killing the tab during an active trip (`A problem repeatedly occurred`) because `AcceptRide` rebuilt `CustomGoogleMap` (an `HtmlElementView`) on every `LiveVehicleAnimator` pose tick (~60fps) and every 2m GPS `setState`. After the reload, the ride lived only in the Navigator stack and in-memory repositories, so Home came back empty.

Fix (no UX change):

- The map keeps a stable `ValueKey('active-ride-map')` and is not rebuilt for the moving car (D-07/D-08). A 33 ms ticker (about 30 Hz) checks the car's pose and, only when it moved, hands the one car marker to `CustomGoogleMap`, which sends it once per frame with `GoogleMapsFlutterPlatform.updateMarkers`; lines and pins are not sent again.
- GPS `setState` is gone. There is no web GPS distance filter: the trip watches with `distanceFilterMeters: 0` on every platform, and a fix that changes nothing on screen outside the map rebuilds nothing (D-07), so each browser fix is cheap.
- `PrefsActiveRideRepository` stores `movera_driver_active_ride` (6h freshness). Home restores `AcceptRide.fromPersisted` after a crash, reload, or PWA resume.
- Lifecycle pause persists the snapshot and stops GPS; resume continues the same trip.
- D11 still holds: restoring a trip does **not** restore `online = true`.

## Active ride stage transitions (no remount)

Pickup → Waiting → On trip stays on the same `AcceptRide` route. The sheet used a stage-suffixed `ValueKey`, which remounted the panel (and felt like a reload) on every slide. Camera `fitRoute` / `focusPickup` on those transitions fought live follow.

Fix (no UX change, no lifecycle change):

- Stable `ValueKey('active-ride-panel')` and `ValueKey('active-ride-slide-action')`. Stage keys remain as zero-size markers for tests.
- Stage changes update copy, slide label and markers in place. GPS, map, overlays and sheet position stay mounted.
- Waiting and on-trip transitions do not re-fit the camera or flash `Routing…`. First map create and crash-restore may still fit.


## Contract v0.4 (October 2026)

`contracts/` now holds the shared Movera contract v0.17.0 (from the `movera-contracts` repository, `tool/sync_contract.sh <commit>`); `test/contract/contract_copy_test.dart` pins that version and `TripTransitions.contractVersion`. The 0.4 line is additive to v0.3 below; `contracts/CONTRACT.md` has the full notes:

- v0.4.0: per-zone config fields (languages, tips, payment methods, waiting by category, auto-offline, driver bonus limits), `TripProjection.acceptedAt`, whole-star ratings and admin dispatch (direct assign, radar group, lock after accept).
- v0.4.1: `DriverAppConfig.reservations` carries the reservation timings and the running-late ETA watch.
- v0.4.2: the `reservations.leaveNow` switch is gone (Leave now always opens the trip); reservations on/off for the zone and per driver.
- v0.4.3: route-change pricing counts a booked stop once and keeps offer raises.
- v0.4.4: the rider's after-cancel reason command (no driver change).
- v0.5.0 (23 Oct 2026, additive): pickup pay per category (`pickupPay.byCategory`: tiered km ranges, a maximum per ride, the rider's fixed fee; `Offer.pickupPay` is the server's number, the driver sees the total only), the stopped / driving signal (`GeoFix.moving`, `speedMps`) with the Radar limits per state in `offers.radarApp` / `exclusiveWhileDriving`, the surge schedule, sign-in / tokens / push devices (`/auth/*`, `/push/devices`, test numbers with a fixed code outside production) and the config document version. The app keeps its demo pickup-pay maths until the server sends `Offer.pickupPay`; the v0.4 `pickupPay` keys stay in the document until v0.6.
- v0.5.1–v0.5.3 (25 Oct 2026, additive): a live trip is accepted only from an offer (`accept` from `requested` is scheduled-only); §14 driver sign-up, fleets and documents (`driverOnboarding`: the details screen after the first sign-in, `driver` and `fleet` accounts, the fleet code with the owner's name and e-mail, cars owned by fleets and picked by drivers, documents per country uploaded to the server). The driver app's live mode (`MOVERA_AUTH_REQUIRED=true`) uses these; the demo keeps its local sample data.
- v0.5.4–v0.7.1 (26–27 Oct 2026, additive): the rider's raise and "I'm on the way"; 10 missed Exclusive offers in a row before offline (`ZoneDefaults.missedExclusiveBeforeOffline`); `child_seat` in the category seed (the driver app's "Booster Seat"); SOS (§15); middle-stop arrive/leave (`POST /driver/trips/{tripId}/stops/{i}/arrive|leave`, the "Framme vid stoppet" button, §3.8).
- v0.7.2 (28 Oct 2026, owner Pricing answers): no surge notice to drivers (`contract.json#surgeNoticeRemoved`; the v0.7.1 Home banner is removed); Home's map colours the surge zones from `GET /driver/surge-map` (`lib/core/surge/`: low `#FFC79E`, medium `#FF8A3D`, high `#E5482B`, ~40 % fill, 2 px edge, no text or number; asked on going online, every 60 s while online on Home and on coming back to the front, the last answer kept on a failure, nothing offline; the demo draws three zones around the driver). The waiting tip is only "Hög bonus i närheten", inside a zone or within 3 km of one.
- v0.8.0–v0.8.1 (27–28 Oct 2026): the settings flow (`contracts/fixtures/settings_flow.json`, live driver config, Exclusive deny/offline rules in §6.7); v0.8.1 carries v0.7.2 pricing on top.
- v0.9.0 (28 Oct 2026): real data part 3 (§18): payouts (`fixtures/payouts.json`; `PayoutLine` breakdown is admin only, the driver app shows only the payout total), support ticket messages, fixed rating tags, risk signals and KPIs. Additive; X-Api-Version stays `0.5`.
- v0.10.0 (28 Oct 2026): Content (§19): admin-published driver-home / driver-event / help / legal / app-versions items, `GET /driver/content?zoneId`, `POST /account/terms/accept`. Additive; X-Api-Version stays `0.5`.
- v0.10.4 (28 Oct 2026): one status word list (§20, `contract.json#statusWords`): the app shows the contract's sv/fr/en status words via `tool/gen_status_words.py` (ARB entries plus `lib/core/contracts/status_words.g.dart`); `test/contract/status_words_contract_test.dart` fails when a word differs. Swedish says "Resenär", never "Passagerare".
- v0.11.0 (28 Oct 2026): Zones from the server (§20): `GET /driver/zones` (open zones with names and outline), read on start and on `config_published` doc `zones`; onboarding cities whose zone is not open are hidden. Additive; X-Api-Version stays `0.5`.
- v0.12.0 (28 Oct 2026): Ride check answers (§22): `POST /driver/trips/{tripId}/ride-check` (shown, then ok | need_help). Additive; X-Api-Version stays `0.5`.
- v0.13.0 (28 Oct 2026): Trip chat (§23): the chat closes at drop-off; calls only through `POST /trips/{tripId}/call` (masked number, 503 `call_unavailable` without a provider); no real phone number of the rider in any driver payload. Additive except the chat window; X-Api-Version stays `0.5`.
- v0.14.0 (28 Oct 2026): Activation needs approved documents (`409 documents_not_approved`, `details` "<scope>:<type>"); a car whose required documents are not all approved can't be picked or driven (reason `vehicle_documents_not_approved`). The app names the missing documents and shows such a car as "Can't be driven – upload documents" without a pick button.
- v0.15.0 (29 Oct 2026): Sign-in group 1: the sign-in calls wait up to 60 s with "Starting the server…"; 429 waits shown in minutes; "Too many wrong tries" highlights Resend code; a restricted number can join the waiting list (`POST /auth/waitlist`); test builds list the test numbers (`GET /auth/test-accounts`, not in production).
- v0.16.0 (29 Oct 2026): Crashes & errors: optional crash report fields (server and admin only; no driver app change).
- v0.17.0 (29 Oct 2026): Past ride route: `GET /trips/{tripId}/path` (driven path from the trip trace, else the planned route); the past-ride screen keeps the map fixed on the top 40 %, fits the route with the pickup and drop-off pins, shows the category icon, date and time and status, and no person photo.

## Contract v0.3 (19 October 2026)

`contracts/` held the shared Movera contract v0.3 for Rider, Driver and Admin. It is copied byte-for-byte; `test/contract/contract_copy_test.dart` checks it against `contracts/CHECKSUMS`. Change it upstream and re-sync, never here. `docs/contracts/openapi.yaml` is now only a pointer to `contracts/openapi.yaml`.

- `TripStatus` has 19 values incl. `cancelled_by_system`; one terminal set. Local storage (journal, history, terminal markers) writes the wire name and still reads older camelCase saves (`TripStatusWire.parse`).
- `TripTransitions` (`lib/core/contracts/trip_transitions.dart`) mirrors `contract.json#transitions`; contract tests replay `fixtures/scenarios.json`. `ActiveRideController` checks every local stage change against it.
- Driver no-show is `no_show` (it was saved as `cancelled_by_driver` + `rider_no_show`).
- A driver cancel before the rider is on board does not end the trip: it goes back to dispatch (`searching`; a reservation goes back to `requested`). On this phone the trip is over all the same, so local records keep that status with the driver's cancel reason. After the rider is on board a driver cancel is `cancelled_by_driver`.
- `CancelReasonCode` (`lib/core/contracts/cancel_reason_code.dart`) is the contract's code registry; `DriverTripGateway` is typed with it, `expectedVersion` and an idempotency key (interface only; no network).
- `Money` JSON is `{amountMinor, currency}` with ISO exponents (SEK/EUR 2, TND 3); `Money.fromJson` is strict wire input, `Money.fromStoredJson` also reads the legacy `minorUnits` key from local storage only.
- `DriverRealtimeEvent` carries the v0.3 envelope (`eventId`, server `sequence`, `version`, `kind` incl. `driver_cancelled`, `payment_updated`, `rating_updated`, `message`, UTC `occurredAt`/`serverTime`, `location`, `cancelFee`). The gate drops a seen `eventId` or an old sequence, accepts gaps (resync) and, after a terminal status, lets only payment, rating and message events through. `MemoryDriverRealtime` still numbers events: it is the in-process stand-in for the server, not a client rule.
- `RideOffer.fare`, `fareBoost` and `cashToCollect` are `Money`; the app formats them locally (`fareLabel`, …). Other trip models still carry SEK labels (follow-up).

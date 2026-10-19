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

The source of truth is now `contracts/contract.json` (v0.3.0, copied byte-for-byte; see "Contract v0.3" below).

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

- Map markers update on a 5Hz throttle with a stable `ValueKey('active-ride-map')`. GPS `setState` is gone; web GPS filter is 20m.
- `PrefsActiveRideRepository` stores `movera_driver_active_ride` (6h freshness). Home restores `AcceptRide.fromPersisted` after a crash, reload, or PWA resume.
- Lifecycle pause persists the snapshot and stops GPS; resume continues the same trip.
- D11 still holds: restoring a trip does **not** restore `online = true`.

## Active ride stage transitions (no remount)

Pickup → Waiting → On trip stays on the same `AcceptRide` route. The sheet used a stage-suffixed `ValueKey`, which remounted the panel (and felt like a reload) on every slide. Camera `fitRoute` / `focusPickup` on those transitions fought live follow.

Fix (no UX change, no lifecycle change):

- Stable `ValueKey('active-ride-panel')` and `ValueKey('active-ride-slide-action')`. Stage keys remain as zero-size markers for tests.
- Stage changes update copy, slide label and markers in place. GPS, map, overlays and sheet position stay mounted.
- Waiting and on-trip transitions do not re-fit the camera or flash `Routing…`. First map create and crash-restore may still fit.


## Contract v0.3 (19 October 2026)

`contracts/` holds the shared Movera contract v0.3.0 for Rider, Driver and Admin. It is copied byte-for-byte; `test/contract/contract_copy_test.dart` checks it against `contracts/CHECKSUMS`. Change it upstream and re-sync, never here. `docs/contracts/openapi.yaml` is now only a pointer to `contracts/openapi.yaml`.

- `TripStatus` has 19 values incl. `cancelled_by_system`; one terminal set. Local storage (journal, history, terminal markers) writes the wire name and still reads older camelCase saves (`TripStatusWire.parse`).
- `TripTransitions` (`lib/core/contracts/trip_transitions.dart`) mirrors `contract.json#transitions`; contract tests replay `fixtures/scenarios.json`. `ActiveRideController` checks every local stage change against it.
- Driver no-show is `no_show` (it was saved as `cancelled_by_driver` + `rider_no_show`).
- A driver cancel before the rider is on board does not end the trip: it goes back to dispatch (`searching`; a reservation goes back to `requested`). On this phone the trip is over all the same, so local records keep that status with the driver's cancel reason. After the rider is on board a driver cancel is `cancelled_by_driver`.
- `CancelReasonCode` (`lib/core/contracts/cancel_reason_code.dart`) is the contract's code registry; `DriverTripGateway` is typed with it, `expectedVersion` and an idempotency key (interface only; no network).

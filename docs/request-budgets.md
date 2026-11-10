# Driver app request budgets (global plan step 62, T3)

Measured by `test/perf/request_budget/request_budget_test.dart` (harness:
`request_budget_harness.dart`). Each state runs the app's real request owners
(`LiveDriverServices` with its location sender, offer feed, settings stream and
trip commands; `ApiDriverRealtime`; `AirportQueue`; `SurgeMapController`;
`NavigationController` + `RoadRouteService`; `DriverAccountSession`) over one
real `ApiClient` / `http.Client` that counts every request; the clock is fake
(`fake_async`). Where the timer lives in a screen's `State` (Home's 60 s badges,
the trip screen's 10 s follow poll, the GPS fixes that drive the route) the
harness runs the same period and the same calls. Steady rate = requests in
minutes 1-11 after entering the state, divided by 10. "On entry" = requests in
the first second (each state starts from a fresh sign-in, so the entry burst
includes the sign-in reads). SSE streams answer a heartbeat every 15 s, so an
open stream costs one request on entry and nothing after.

The test fails when a state sends more than its budget + max(10 %, 0.5/min) on
any endpoint (an endpoint not listed has budget 0). **A PR that raises a number
changes this file and `budgets` in the test, and says why.**

What runs in each state (the code the harness drives):

| State | Request owners |
|---|---|
| offline | settings stream (`lib/core/live/live_driver_config.dart`), airport queue (`lib/core/airport/airport_queue.dart`, 20 s, only while online and in a queue or within ~2 km of an airport zone, `AirportQueueCard.wantedFor`; owner 2026-11-10: not read in any state measured here, the phone is far from any airport), Home badges (`home_account.dart:83`, 60 s, profile + unread notifications + reminders + onboarding settings, `:512-534`) |
| onlineIdle | offline + location sender (`live_driver_services.dart:667/747`, 10 s) + offer feed (`api_dispatch_repository.dart`, SSE + one offer list) + surge zones (`surge_map.dart:284`, 60 s, online and Home in front) |
| offerShown | onlineIdle + the offer's road on the map, once (`home_offer_route.dart:103`) |
| toPickup / onTrip | Home under the trip: airport queue only near an airport (badges and surge stop, Home not visible); location sender; offer feed stays open; trip screen (`accept_ride.dart:697-716`): trip read + trip stream (`api_driver_realtime.dart`), follow poll only while the stream is down (`accept_ride_pickup.dart:76`, `accept_ride_live.dart:20`), road route refresh on GPS fixes (`navigation_controller.dart:194`, 90 s) |
| atPickup | toPickup without the route: no route while waiting (`accept_ride_trip_drive.dart:184`, `navigation_controller.dart:374`) |
| tripFinished | receipt over Home, driver still online: airport queue (near an airport), location sender, offer feed (trip screen gone) |
| background | online, app in the background: location sender (decision 1), airport queue (near an airport), offer feed, settings stream; badges and surge stop (`home.dart:205` `_liveVisible`) |
| offlineConfigStreamDown | offline with `/driver/config/stream` answering 503 (owner 2026-11-10: backoff 5 → 10 → 20 → 40 → 60 s with ±10 % jitter, reset after a successful connect; each retry also reads `/driver/config`: `LiveDriverConfig.nextRetryWait`) |
| onlineOffersStreamDown | onlineIdle with `/driver/offers/stream` answering 503 (backoff 1 s doubling to 30 s: `api_dispatch_repository.dart:331`) |
| toPickupTripStreamDown | toPickup with the trip stream answering 503 (backoff to 30 s, `api_driver_realtime.dart:79`; follow poll every 10 s) |

## Table (state × endpoint × per minute)

| State | Endpoint | Budget /min | Measured /min | On entry |
|---|---|---|---|---|
| offline | `GET /api/v1/driver/config` | 0 | 0.00 | 1 |
| offline | `GET /api/v1/driver/config/stream (SSE open)` | 0 | 0.00 | 1 |
| offline | `GET /api/v1/driver/content` | 0 | 0.00 | 1 |
| offline | `GET /api/v1/driver/events` | 0 | 0.00 | 1 |
| offline | `GET /api/v1/driver/onboarding/settings` | 1.0 | 1.00 | 1 |
| offline | `GET /api/v1/driver/profile` | 1.0 | 1.00 | 1 |
| offline | `GET /api/v1/driver/reminders` | 1.0 | 1.00 | 1 |
| offline | `GET /api/v1/driver/zones` | 0 | 0.00 | 1 |
| offline | `GET /api/v1/notifications` | 1.0 | 1.00 | 1 |
| onlineIdle | `GET /api/v1/driver/config` | 0 | 0.00 | 1 |
| onlineIdle | `GET /api/v1/driver/config/stream (SSE open)` | 0 | 0.00 | 1 |
| onlineIdle | `GET /api/v1/driver/content` | 0 | 0.00 | 1 |
| onlineIdle | `GET /api/v1/driver/events` | 0 | 0.00 | 1 |
| onlineIdle | `GET /api/v1/driver/offers` | 0 | 0.00 | 1 |
| onlineIdle | `GET /api/v1/driver/offers/stream (SSE open)` | 0 | 0.00 | 1 |
| onlineIdle | `GET /api/v1/driver/onboarding/settings` | 1.0 | 1.00 | 1 |
| onlineIdle | `GET /api/v1/driver/profile` | 1.0 | 1.00 | 2 |
| onlineIdle | `GET /api/v1/driver/reminders` | 1.0 | 1.00 | 1 |
| onlineIdle | `GET /api/v1/driver/surge-map` | 1.0 | 1.00 | 1 |
| onlineIdle | `GET /api/v1/driver/zones` | 0 | 0.00 | 1 |
| onlineIdle | `GET /api/v1/notifications` | 1.0 | 1.00 | 1 |
| onlineIdle | `POST /api/v1/driver/location` | 6.0 | 6.00 | 1 |
| offerShown | `GET /api/v1/driver/config` | 0 | 0.00 | 1 |
| offerShown | `GET /api/v1/driver/config/stream (SSE open)` | 0 | 0.00 | 1 |
| offerShown | `GET /api/v1/driver/content` | 0 | 0.00 | 1 |
| offerShown | `GET /api/v1/driver/events` | 0 | 0.00 | 1 |
| offerShown | `GET /api/v1/driver/offers` | 0 | 0.00 | 1 |
| offerShown | `GET /api/v1/driver/offers/stream (SSE open)` | 0 | 0.00 | 1 |
| offerShown | `GET /api/v1/driver/onboarding/settings` | 1.0 | 1.00 | 1 |
| offerShown | `GET /api/v1/driver/profile` | 1.0 | 1.00 | 2 |
| offerShown | `GET /api/v1/driver/reminders` | 1.0 | 1.00 | 1 |
| offerShown | `GET /api/v1/driver/surge-map` | 1.0 | 1.00 | 1 |
| offerShown | `GET /api/v1/driver/zones` | 0 | 0.00 | 1 |
| offerShown | `GET /api/v1/notifications` | 1.0 | 1.00 | 1 |
| offerShown | `GET /api/v1/routes/driving/{coords}` | 0 | 0.00 | 1 |
| offerShown | `POST /api/v1/driver/location` | 6.0 | 6.00 | 1 |
| toPickup | `GET /api/v1/driver/config` | 0 | 0.00 | 1 |
| toPickup | `GET /api/v1/driver/config/stream (SSE open)` | 0 | 0.00 | 1 |
| toPickup | `GET /api/v1/driver/content` | 0 | 0.00 | 1 |
| toPickup | `GET /api/v1/driver/events` | 0 | 0.00 | 1 |
| toPickup | `GET /api/v1/driver/offers` | 0 | 0.00 | 1 |
| toPickup | `GET /api/v1/driver/offers/stream (SSE open)` | 0 | 0.00 | 1 |
| toPickup | `GET /api/v1/driver/profile` | 0 | 0.00 | 1 |
| toPickup | `GET /api/v1/driver/zones` | 0 | 0.00 | 1 |
| toPickup | `GET /api/v1/routes/driving/{coords}` | 0.7 | 0.70 | 1 |
| toPickup | `GET /api/v1/trips/{tripId}` | 0 | 0.00 | 2 |
| toPickup | `GET /api/v1/trips/{tripId}/events (SSE open)` | 0 | 0.00 | 1 |
| toPickup | `POST /api/v1/driver/location` | 6.0 | 6.00 | 1 |
| atPickup | `GET /api/v1/driver/config` | 0 | 0.00 | 1 |
| atPickup | `GET /api/v1/driver/config/stream (SSE open)` | 0 | 0.00 | 1 |
| atPickup | `GET /api/v1/driver/content` | 0 | 0.00 | 1 |
| atPickup | `GET /api/v1/driver/events` | 0 | 0.00 | 1 |
| atPickup | `GET /api/v1/driver/offers` | 0 | 0.00 | 1 |
| atPickup | `GET /api/v1/driver/offers/stream (SSE open)` | 0 | 0.00 | 1 |
| atPickup | `GET /api/v1/driver/profile` | 0 | 0.00 | 1 |
| atPickup | `GET /api/v1/driver/zones` | 0 | 0.00 | 1 |
| atPickup | `GET /api/v1/trips/{tripId}` | 0 | 0.00 | 2 |
| atPickup | `GET /api/v1/trips/{tripId}/events (SSE open)` | 0 | 0.00 | 1 |
| atPickup | `POST /api/v1/driver/location` | 6.0 | 6.00 | 1 |
| onTrip | `GET /api/v1/driver/config` | 0 | 0.00 | 1 |
| onTrip | `GET /api/v1/driver/config/stream (SSE open)` | 0 | 0.00 | 1 |
| onTrip | `GET /api/v1/driver/content` | 0 | 0.00 | 1 |
| onTrip | `GET /api/v1/driver/events` | 0 | 0.00 | 1 |
| onTrip | `GET /api/v1/driver/offers` | 0 | 0.00 | 1 |
| onTrip | `GET /api/v1/driver/offers/stream (SSE open)` | 0 | 0.00 | 1 |
| onTrip | `GET /api/v1/driver/profile` | 0 | 0.00 | 1 |
| onTrip | `GET /api/v1/driver/zones` | 0 | 0.00 | 1 |
| onTrip | `GET /api/v1/routes/driving/{coords}` | 0.7 | 0.70 | 1 |
| onTrip | `GET /api/v1/trips/{tripId}` | 0 | 0.00 | 2 |
| onTrip | `GET /api/v1/trips/{tripId}/events (SSE open)` | 0 | 0.00 | 1 |
| onTrip | `POST /api/v1/driver/location` | 6.0 | 6.00 | 1 |
| tripFinished | `GET /api/v1/driver/config` | 0 | 0.00 | 1 |
| tripFinished | `GET /api/v1/driver/config/stream (SSE open)` | 0 | 0.00 | 1 |
| tripFinished | `GET /api/v1/driver/content` | 0 | 0.00 | 1 |
| tripFinished | `GET /api/v1/driver/events` | 0 | 0.00 | 1 |
| tripFinished | `GET /api/v1/driver/offers` | 0 | 0.00 | 1 |
| tripFinished | `GET /api/v1/driver/offers/stream (SSE open)` | 0 | 0.00 | 1 |
| tripFinished | `GET /api/v1/driver/profile` | 0 | 0.00 | 1 |
| tripFinished | `GET /api/v1/driver/zones` | 0 | 0.00 | 1 |
| tripFinished | `POST /api/v1/driver/location` | 6.0 | 6.00 | 1 |
| background | `GET /api/v1/driver/config` | 0 | 0.00 | 1 |
| background | `GET /api/v1/driver/config/stream (SSE open)` | 0 | 0.00 | 1 |
| background | `GET /api/v1/driver/content` | 0 | 0.00 | 1 |
| background | `GET /api/v1/driver/events` | 0 | 0.00 | 1 |
| background | `GET /api/v1/driver/offers` | 0 | 0.00 | 1 |
| background | `GET /api/v1/driver/offers/stream (SSE open)` | 0 | 0.00 | 1 |
| background | `GET /api/v1/driver/profile` | 0 | 0.00 | 1 |
| background | `GET /api/v1/driver/zones` | 0 | 0.00 | 1 |
| background | `POST /api/v1/driver/location` | 6.0 | 6.00 | 1 |
| offlineConfigStreamDown | `GET /api/v1/driver/config` | 1.1 | 1.10 | 1 |
| offlineConfigStreamDown | `GET /api/v1/driver/config/stream (SSE open)` | 1.1 | 1.10 | 1 |
| offlineConfigStreamDown | `GET /api/v1/driver/content` | 0 | 0.00 | 1 |
| offlineConfigStreamDown | `GET /api/v1/driver/events` | 0 | 0.00 | 1 |
| offlineConfigStreamDown | `GET /api/v1/driver/onboarding/settings` | 1.0 | 1.00 | 1 |
| offlineConfigStreamDown | `GET /api/v1/driver/profile` | 1.0 | 1.00 | 1 |
| offlineConfigStreamDown | `GET /api/v1/driver/reminders` | 1.0 | 1.00 | 1 |
| offlineConfigStreamDown | `GET /api/v1/driver/zones` | 0 | 0.00 | 1 |
| offlineConfigStreamDown | `GET /api/v1/notifications` | 1.0 | 1.00 | 1 |
| onlineOffersStreamDown | `GET /api/v1/driver/config` | 0 | 0.00 | 1 |
| onlineOffersStreamDown | `GET /api/v1/driver/config/stream (SSE open)` | 0 | 0.00 | 1 |
| onlineOffersStreamDown | `GET /api/v1/driver/content` | 0 | 0.00 | 1 |
| onlineOffersStreamDown | `GET /api/v1/driver/events` | 0 | 0.00 | 1 |
| onlineOffersStreamDown | `GET /api/v1/driver/offers` | 0 | 0.00 | 1 |
| onlineOffersStreamDown | `GET /api/v1/driver/offers/stream (SSE open)` | 2.0 | 2.00 | 1 |
| onlineOffersStreamDown | `GET /api/v1/driver/onboarding/settings` | 1.0 | 1.00 | 1 |
| onlineOffersStreamDown | `GET /api/v1/driver/profile` | 1.0 | 1.00 | 2 |
| onlineOffersStreamDown | `GET /api/v1/driver/reminders` | 1.0 | 1.00 | 1 |
| onlineOffersStreamDown | `GET /api/v1/driver/surge-map` | 1.0 | 1.00 | 1 |
| onlineOffersStreamDown | `GET /api/v1/driver/zones` | 0 | 0.00 | 1 |
| onlineOffersStreamDown | `GET /api/v1/notifications` | 1.0 | 1.00 | 1 |
| onlineOffersStreamDown | `POST /api/v1/driver/location` | 6.0 | 6.00 | 1 |
| toPickupTripStreamDown | `GET /api/v1/driver/config` | 0 | 0.00 | 1 |
| toPickupTripStreamDown | `GET /api/v1/driver/config/stream (SSE open)` | 0 | 0.00 | 1 |
| toPickupTripStreamDown | `GET /api/v1/driver/content` | 0 | 0.00 | 1 |
| toPickupTripStreamDown | `GET /api/v1/driver/events` | 0 | 0.00 | 1 |
| toPickupTripStreamDown | `GET /api/v1/driver/offers` | 0 | 0.00 | 1 |
| toPickupTripStreamDown | `GET /api/v1/driver/offers/stream (SSE open)` | 0 | 0.00 | 1 |
| toPickupTripStreamDown | `GET /api/v1/driver/profile` | 0 | 0.00 | 1 |
| toPickupTripStreamDown | `GET /api/v1/driver/zones` | 0 | 0.00 | 1 |
| toPickupTripStreamDown | `GET /api/v1/routes/driving/{coords}` | 0.7 | 0.70 | 1 |
| toPickupTripStreamDown | `GET /api/v1/trips/{tripId}` | 6.0 | 6.00 | 2 |
| toPickupTripStreamDown | `GET /api/v1/trips/{tripId}/events (SSE open)` | 2.0 | 2.00 | 1 |
| toPickupTripStreamDown | `POST /api/v1/driver/location` | 6.0 | 6.00 | 1 |

## Totals per state (steady, per minute)

| State | Requests /min |
|---|---|
| offline | 4.00 |
| onlineIdle | 11.00 |
| offerShown | 11.00 |
| toPickup | 6.70 |
| atPickup | 6.00 |
| onTrip | 6.70 |
| tripFinished | 6.00 |
| background | 6.00 |
| offlineConfigStreamDown | 6.20 |
| onlineOffersStreamDown | 13.00 |
| toPickupTripStreamDown | 14.70 |

## Compared with step 60 (server load tool, `tools/loadtest/cadences.mjs`)

| State | Step 60 | Measured | Why |
|---|---|---|---|
| offline | 7 | 4.00 | 4 badges; the airport queue (3) is read only near an airport (owner 2026-11-10) |
| online idle | 14 | 11.00 | GPS 6 + badges 4 + surge 1; airport 3 only near an airport (owner 2026-11-10) |
| to pickup | 9.67 | 9.70 | same; the route refresh is 0.70 here: GPS fixes every 1 s, so the 90 s refresh goes out on the first fix after 90 s (~91 s) |
| at pickup | 9.67 | 9.00 | the app asks no route while waiting for the rider (`navigation_controller.dart:374`); step 60 keeps the to-pickup route timer (0.67 too high) |
| on trip | 9.67 | 9.70 | same as to pickup |
| offer shown, trip finished, background, stream-down | not modelled | see table | new here |

## Notes

- **Airport queue** (owner 2026-11-10): read every 20 s only while the driver
  is online (the location sender runs) and in a queue or within ~2 km of an
  airport zone (`AirportQueue.wanted`); elsewhere it costs nothing (it was
  3/min in every state before). Near an airport add 3/min.
- `/driver/config/stream` refused (owner 2026-11-10): reconnect after 5, 10,
  20, 40 s, then every 60 s (±10 % jitter), back to 5 s after a successful
  connect; each retry also reads `/driver/config`. Steady: about 2 requests a
  minute per driver while the server is down (was 24 with a fixed 5 s).
- Opening a trip reads `GET /trips/{id}` twice at once: `trips.begin`
  (`accept_ride.dart:710`, `live_trip_commands.dart:252`) and the trip
  stream's `ensureKnown` (`api_driver_realtime.dart:157`) both ask before
  either answer is cached.
- Each `driver_reservations_changed` event, and every settings-stream (re)open
  (`live_driver_config.dart:247`), costs 2 requests (reservations open +
  accepted), as in step 60; not counted in the steady rates.
- A trip that ends with the driver offline stops the location sender (§74,
  `live_driver_services.dart:397`): tripFinished offline is the offline row
  without the badges (3/min; not measured here).
- Not in this table (one-off or not timed): going online / offline
  (profile + availability), trip steps, chat and calls, resume bursts
  (`LiveDriverServices.resumed`), Documents screen 60 s refresh
  (`live_documents_screen.dart:61`, only while that screen is open).

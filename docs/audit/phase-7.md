# Audit Phase 7 (driver): performance, measured

Date: 2026-10-27. Branch `audit/phase-7`. Plan: `movera-contracts/docs/audit/AUDIT_PLAN.md`, Phase 7.

Method: `flutter build web --release` (the CI build) and a live build (`MOVERA_AUTH_REQUIRED=true`, `MOVERA_API_BASE_URL` pointing at a local https origin that forwards `/api` to the server's e2e harness on Postgres), headless Chromium (Playwright 1.56, SwiftShader WebGL, 390x844 touch viewport), audit container with 4 cores, no GPU and no Google Maps key. Times are the container's, not a phone's. Device numbers are on the owner's list (`movera-server/docs/audit/device-checklist.md`).

## Measured

### Start (5 cold loads, median)

| | first Flutter frame | main thread quiet (no long task for 500 ms) | requests | JS heap after GC |
|---|---:|---:|---:|---:|
| `flutter build web --release` | 2,032 ms (1,800–2,731) | 22.5 s | 22 | 27.8 MB |

"Quiet" is late because Home never stops drawing (P7-D1); long tasks still came at 21.4 s and 22.3 s. `main.dart.js`: 5,631,828 bytes, 1,595,503 bytes after gzip -9.

### Frames and main-thread time (live build, signed in as +46 70 174 06 05)

Frame callbacks timed in the page (`requestAnimationFrame` wrapper) over each window:

| Screen | window | frame callbacks | p50 | p95 | max | over 32 ms | main thread busy |
|---|---:|---:|---:|---:|---:|---:|---:|
| Home, offline, untouched | 60 s | 2,025 | 5.0 ms | 8.4 ms | 17.8 ms | 0 | 11.1 s |
| Home, online, radar scanning | 60 s | 1,717 | 5.8 ms | 9.3 ms | 19.0 ms | 0 | 10.8 s |
| Offer card shown | 20 s | 433 | 6.7 ms | 12.0 ms | 42.8 ms | 2 | 3.3 s |
| Trip screen, driving to pickup, GPS 1 Hz | 60 s | 3,119 | 1.1 ms | 2.9 ms | 18.3 ms | 0 | 4.8 s |

Rebuild counts: not measured on the web build (no build timeline in a release build); the widget tests from Phase 6 pin the navigation update budget (`gps` budget test, 62 navigation updates a minute of driving).

### API calls per minute (live build, counted on the server)

| Screen | requests a minute (besides the open offer stream) |
|---|---:|
| Home offline | 0 |
| Home online, no offers | 0 |
| Offer card shown | 0 |
| Trip screen | 0 |

Going online sent `POST /driver/availability` once and opened `GET /driver/offers/stream`; accept sent `POST /offers/{id}/accept` and `POST /trips/{id}/head-to-pickup` and opened `GET /trips/{id}/events`. **No `POST /driver/location` was sent in the lab**, but that is the lab, not the app: in this Chromium even a bare `navigator.geolocation.getCurrentPosition` on the lab's origin timed out (error 3), so the app's 10 s location report had no fix to send (its log: "Current GPS failed … TimeoutException"). The report rate on a phone is on the device list.

## Findings

| Id | Sev | Finding | Fix | Evidence |
|---|---|---|---|---|
| P7-D1 | S3 (battery) | Home draws a new frame on every vsync while the driver only looks at it, also offline and when the account is not active: the Radar orb's pulse (`_goOnlinePulseController`, 2.6 s, repeat) and the radar sweep/motion controllers run for as long as Home is visible. Measured 2,025 frames and 11.1 s of main-thread time a minute in the sandbox (about 18 % of a core); on a 60–120 Hz phone it is every frame. | Not changed: the pulse is a design choice. A `RepaintBoundary` around the orb was tried and measured: no change (5.7 vs 5.5–5.9 ms per frame, the cost is CanvasKit drawing the frame, not repainting widgets). Options for the owner: pulse only while online, or stop after a few cycles. | Frame table above; rAF caller census: all from Flutter's frame scheduler. |
| P7-D2 | — | No location report in the lab run. | None: lab artifact (see above). On the device list. | Lab log. |

## Budgets added (CI)

- `tool/check_web_budget.py`, after "Build web" in `drider-ci.yml`: `main.dart.js` at most 6,200,000 bytes raw and 1,760,000 bytes gzip (baseline 5,631,828 / 1,595,503, plus about 10 %).

# Audit Phase 6 (driver): maps, GPS, routing

Date: 2026-10-27. Branch `audit/phase-6`. Plan: `movera-contracts/docs/audit/AUDIT_PLAN.md`, Phase 6. Owner notes N2, N6 (`MOVERA_HANDOFF.md`, `driver_round4_notes.md`).

No Google Maps key exists for CI or this container, so nothing here was checked on a real Google map, in Safari or on a phone. The findings come from the code, the node harness for the web gesture layer (`tool/verify_driver_map_web.cjs`) and Flutter tests.

## Already fixed in #380 (checked again)
- N6 "route line very thin": the web plugin's zoom 0 / (0, 0) report is no longer taken as a camera frame (`MapCameraReport`). Before, it put the route line at its thinnest step.
- N5: no traffic layer on any map.
- The trip camera never moves under a finger that Flutter can see (`_camera.touching`). A hand gesture switches the camera to browse mode, and it goes back to the car 12 s after the last map movement.

## Finding fixed on this branch

| Id | Sev | Finding | Fix | Test |
|---|---|---|---|---|
| P6-D1 (N6) | S3 | Web: the camera fights the finger. Flutter's pointer events do not reach the Google map element, so `_camera.touching` never turns on on the web. The gesture layer tells Dart about a gesture only once per touch. When the app took the camera back during a touch (the 12 s return to the car under a resting thumb), the rest of that touch moved the map without telling Dart, and every follow frame pulled it back. | An app claim during a touch re-arms the release. The finger's next move hands the camera back to the driver. | `tool/verify_driver_map_web.cjs` (fails before, passes after) |

Steps (before): on the web trip map, pinch, keep one finger resting on the map for more than 12 s until the camera returns to the car, then drag. The map jumps between the finger and the car.

## N2 (verified, not changed)
The driver app does not use the server's route. `RoadRouteService` asks an OSRM host directly: `MOVERA_ROUTING_HOST`, which defaults to the public demo `router.project-osrm.org`. The live build sets no host, so the driver's position goes to the public demo router (already open as N07 in `docs/ROUTING_PROVIDER.md`). When routing fails, the trip stays active and the island says "Route updating" / "Route unavailable — retry". The contract has `GET /routes/driving/{coordinates}` (server OSRM proxy). Switching to it is a product decision for the owner: without `OSRM_URL` it answers 503 `routing_unavailable`.

## GPS budget (new test `test/performance/gps_update_budget_test.dart`)
One minute of driving: one fix a second at 12 m/s along the route, with the route asked for on every fix (worst case). Measured: **1 route request** (network) and **62 navigation notifications** (rebuilds). Budgets: 2 requests and 64 notifications per minute.

## Not checked / needs a device
Pinch while following on an iPhone (Safari and the PWA), and the "crash" on pinch (losing the WebGL context is suspected; not reproduced). Native Android/iOS gestures go through the plugin's own touch path, and the Flutter `Listener` does see them there.

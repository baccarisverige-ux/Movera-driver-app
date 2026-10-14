# Phase 3 — Real Google Maps contract

Status: execution pending. This PR defines the real-SDK verification work; it does not provision a map ID or claim screenshots exist.

Dependencies: deployed Driver candidate; access to the Google Maps project/cloud style; GPU-capable and GPU-disabled browser sessions; physical iPhone and Android.

## Configuration and scenarios

- [ ] Confirm `DRIVER_MAP_ID` is a JavaScript vector map ID linked to a published cloud style.
- [ ] Compare that style to `lib/styles/reference_map_style.dart`; record city and street screenshots on Home, route preview and active trip.
- [ ] Record actual SDK rendering type. Confirm the map announces unavailable 3D when raster is used.
- [ ] Run pan, pinch, rotate, tilt and combined two-finger gestures; cover pointer cancellation and marker taps.
- [ ] Verify gesture takeover stops camera follow immediately and recenter restores it once.
- [ ] Verify route bends, sharp turns, interior-vertex reroutes, destination/leg changes and whole-route overview.
- [ ] Exercise stale GPS, inaccurate fixes, permission failure, offline routing, timeout and retry.
- [ ] Check stationary, background and resume traces for timer/request growth.
- [ ] Repeat gestures with raster fallback and unavailable WebGL; routes and recenter remain usable without unsupported axes.

## Evidence record

For each case record candidate commit, deployed URL, OS/browser/GPU, viewport, rendering type, map ID identifier (no API credentials), scenario, expected/actual outcome, console errors and screenshot/video/trace artifact. Keep failures open.

## Exit gate

Vector appearance and renderer fallback are verified on the actual SDK, all gesture/camera transitions preserve ownership, resources settle, and errors expose working recovery. `node tool/verify_driver_map_web.cjs` remains required but is mock-contract evidence only.

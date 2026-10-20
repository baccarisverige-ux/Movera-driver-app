# R04 - Explicit runtime policies instead of test-binding detection

Source: deep re-audit of 2 October 2026 (N05, N06, N09, N27; residuals of F12, F36).

## Problem

- Four production sites changed behaviour when `WidgetsBinding.runtimeType` contained `Test`: account activation, GPS arrival, external routing and the map pose ticker. Tests therefore never ran the production code paths.
- The only arrival bypass existed in tests. On a real phone or browser, the public demo could arrive only within 100 m of the hard-coded Stockholm pickups.
- The Radar list accepted trips under the static template ID (`nearby-1`), so a repeated demo ride was hidden by its old terminal marker.
- The lifecycle integration test used the real GPS plugin, which fails on Linux hosts without D-Bus/GeoClue.

## Change

- `DriverRuntimeConfig` holds explicit switches (`simulatedArrival`, `externalRouting`, `skipAccountActivation`, `liveMapTicker`) compiled from `--dart-define`. Release builds enforce the 100 m arrival check by default (D-12); only the GitHub Pages demo passes `--dart-define=MOVERA_DEMO_ARRIVAL=true`, and `MOVERA_PRODUCTION=true` always enforces it. `DriverRuntimeConfig.production` documents the fully gated policy.
- `test/flutter_test_config.dart` sets the test policy explicitly; the integration test sets its own.
- All accept paths use `tripOccurrenceId()`.
- `MoveraApp(locationRepository:)` lets the integration test inject scripted fixes, so it no longer touches host location services.

## Validation

- `test/audit/runtime_config_test.dart`: the production policy keeps arrival closed far from the pickup; the demo policy arrives; occurrence IDs are unique and used by every accept path; a source gate forbids binding-type checks in `lib/`.
- `integration_test/driver_lifecycle_test.dart` passes on a container without D-Bus.

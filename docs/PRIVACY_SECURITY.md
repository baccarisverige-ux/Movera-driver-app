# Privacy and security record

Source: deep re-audit of 2 October 2026 (N07, N08, N20, N21, N15). Frontend demo only; no backend, accounts or payments exist in this repository.

## Personal data on the device

| Data | Where | Protection |
| --- | --- | --- |
| Active trip, terminal markers, journal, history (rider names, addresses) | SharedPreferences / web localStorage | Cleared on logout; quarantine keys too (see `lib/core/privacy/local_data.dart`) |
| Trusted contacts, vehicle drafts | Settings sections | Cleared on logout |
| Vehicle document photos | Vehicle settings section (base64) | Max 700 KB per new photo and 2 MB total; cleared on logout |

- Android: `allowBackup="false"`, plus `backup_rules.xml` and `data_extraction_rules.xml` exclude app data from cloud backup and device-to-device transfer.
- Web localStorage is not encrypted and is readable by any script on the origin. Do not put production identity documents there. A production document flow must upload to the backend and keep no local copy.

## Third parties receiving data

| Party | Data | Status |
| --- | --- | --- |
| Google Maps JavaScript / SDK | map tiles, device IP; on web the browser key | Key must be restricted (below) |
| Routing host (`MOVERA_ROUTING_HOST`, default public OSRM demo) | driver origin and destination coordinates | Demo only; contracted provider + DPA required, see `ROUTING_PROVIDER.md` |
| Google Fonts (`google_fonts` runtime fetch) | device IP | Follow-up: bundle the fonts as assets and disable runtime fetching |

## Web key restriction (manual, owner action)

In Google Cloud Console, the key stored in the `newmap131189` secret must have:
1. Application restriction: HTTP referrers, limited to `https://baccarisverige-ux.github.io/Movera-driver-app/*` (the deploy workflow builds with `--base-href "/Movera-driver-app/"`), plus any production domain.
2. API restriction: Maps JavaScript API only.
3. A budget alert.

This repository cannot verify console settings. Record a screenshot in the release evidence matrix.

## Not changed here (and why)

- **Content-Security-Policy.** Flutter web loads CanvasKit from `gstatic`, and Google Maps loads scripts and tiles from several Google domains. A CSP that is not tested against the deployed site could break the map. Add it as a hosting header after a browser test on the Pages deployment.
- **Maps `loading=async`.** The Maps script tag is `async` (driver-r4-24): the app starts without waiting for it, and no map is built until `google.maps` and the camera adapter are in (`web/driver_map_camera.js` `ready()`). The `loading=async` URL parameter (libraries loaded on demand) is not used: `google_maps_flutter_web` needs `google.maps.Map` once the script has run, which must be verified in a browser first.
- **Background location (N20).** There is a product decision to make. Today, GPS stops while the app is in the background, by design (the iOS copy says so). A production driver app usually needs location during an active trip only: an Android foreground service with a persistent notification, and iOS `UIBackgroundModes: location` with the "When In Use" upgrade flow. That needs product, legal (privacy notice) and store-review sign-off and is not enabled here.

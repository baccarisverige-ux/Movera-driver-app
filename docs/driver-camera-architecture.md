# Driver camera architecture

Driver only. Rider, palette and trip business lifecycle are unchanged.

## Ownership

- `DriverCameraPose`: target, zoom, bearing, tilt and animation duration.
- `DriverCameraPolicy`: GPS course hold, speed zoom, route snapping,
  look-ahead bearing, maneuver framing and arrival flattening. No SDK/UI imports.
- `DriverCameraController`: Explore/Preview/Following/Free state, usable-fix
  validation, lifecycle and serialized/coalesced output. Route updates and car
  progress continue in Free but do not move its camera.
- `GoogleDriverCameraPort`: one damped follow loop. GPS retargets it in
  place instead of finishing a stale 450 ms ease-in-out and braking. Position,
  bearing and zoom use separate time constants; 900 ms entry/recenter still
  flies without dragging the car. On-route coast (max 1.1 s / 22 m) bridges
  gaps between fixes. Reduced motion is instant. Physical input cancels the loop.
- `CustomGoogleMap`: physical input release, native gesture-arena ownership,
  SDK callbacks and conditional web bridge. Camera callbacks never imply input.
  The port ignores SDK echoes while it owns follow, so the anchor shift cannot
  become the next frame's origin.
- `RouteCameraGeometry`: reusable along-route sampling for car, look-ahead and
  split route stroke. Remaining stroke starts at the car (5 dp, round caps);
  traveled stroke is thin/faded (3 dp, 18% alpha), never thick behind the car.

## Modes

| State | Framing | Car |
| --- | --- | --- |
| Explore | Driver-centered, north-up, flat, area zoom 11.7 (about 10 km across a phone) | Real course |
| Preview | Entire destination route fitted, north-up/flat; no GPS follow | Real course |
| Following | Heading-up, tilt from the zoom curve (up to 67.5 degrees), speed zoom; vehicle at 75% of screen, above overlays | Real course, on-route snapped |
| Free | Driver owns pan/zoom/bearing/tilt until Recenter | Continues real course and snapping |

The driving anchor is **75% of screen height**, clamped above the collapsed
sheet and below the top banner with 24 dp vehicle clearance. Horizontal is 50%.
Native SDK padding realizes the anchor; web uses OverlayView projection because
the pinned Flutter web plugin does not implement camera padding. During guidance
the native padding stays anchored in Free too (only Preview drops it): the SDK
keeps the camera target in the middle of the padded region, so changing the
padding at the first pan or at Recenter would jump the map.

Course is accepted only with valid speed >=1 m/s; otherwise retain the last good
course (unknown speed is not evidence of movement). Look-ahead is 3 seconds of
travel, clamped 40–250 m. Its shortest-angle delta from GPS course is clamped
to +/-30 degrees and blended at 70%. While already following, a single sample
cannot rotate the camera more than 55 degrees, and only 65% of that step is
applied, so a bad heading does not spin the map. Entry/recenter aims directly
down the route. Refreshing the same polyline does not reset along-track progress.
Auto Zoom defaults on and is smooth (no steps): 15 at a standstill, 14.5
urban, 14 fast urban and 13.625 on the highway (from 108 km/h). Tilt follows
zoom (`tiltForZoom`): flat at zoom 12 and below, rising linearly to 67.5
degrees at zoom 15.5, never above what the SDK allows. Inside 180 m of
significant maneuvers, zoom tightens toward 15.4 (at most 0.4 above the cruise
zoom), its tilt from the same curve, recovering after passing. Last 140 m
before a stop eases the zoom in toward 15.5 (never out) and the tilt
to 60 degrees; it never goes flat. Waiting/paid stops use flat 17.2 framing.

Home destination selection remains Preview, not guidance. Entering the active
pickup/dropoff screen begins guidance. Reroute does not reset manual mode,
vehicle course or camera bearing. Recenter without a trip is flat/north-up.

## Web adapter

Pinned `google_maps_flutter_web` 0.5.14+2 does not expose vector rendering,
touch heading/tilt, camera padding or bitmap-marker rotation. A small Driver-only
bootstrap adapter initializes **only Flutter Maps elements** using Google's
public `RenderingType.VECTOR` constructor option. It preserves inline styles,
API-key loading, traffic and the original SDK instances. No cloud map ID is
created/required. The constructor interception is isolated in
`web/driver_map_camera.js`; upgrading the plugin requires rechecking this adapter
against its element-ID and marker-option contracts.

Flutter web 0.5.14+2 applies `newCameraPosition` with `panTo`, which animates
and stacked a second glide on every follow frame. A claimed follow pan is
instant (`moveCamera`) and the 75% anchor is applied in the same turn, after
tilt is set and before paint. Unclaimed pans (mouse, overview) stay with the
SDK. The anchor must not be applied again from Dart after `moveCamera`.

That adapter owns touch pan, simultaneous pinch/twist, two-finger vertical tilt
(0–60), double tap and two-finger tap, and reports first touch/wheel to Dart.
Mouse/keyboard interaction remains with Google Maps. A projected image overlay
rotates the existing vehicle asset by real course minus map heading; only the
explicitly titled vehicle marker is replaced. Flutter listeners and overlays are
released when their map is disposed. Google may clamp tilt based on zoom and
hardware; WebGL capability must be verified on the target device.

## Verification

- `tool/verify_driver_camera.dart` (also Flutter test): speed thresholds,
  shortest angles, bounded bend lead, stationary course, snapping, split stroke,
  maneuver recovery, arrival, preview/start, recenter, reroute in Free, stale
  location rejection, lifecycle and obsolete command completion.
- `tool/verify_driver_map_web.cjs` (CI): constructor/palette, first-touch release,
  pan, simultaneous pinch/twist, tilt limits, tap gestures, projection anchor,
  vehicle overlay and listener removal. Uses SDK doubles, not real map tiles.
- Repository CI: analyzer, Flutter tests, lifecycle integration, web build,
  Android release preview and iOS compile preflight.

Acceptance still requires real browser/device testing: explore gestures; choose
a destination; begin guidance; drive a gentle right bend; pan and recenter;
approach a sharp turn/roundabout; arrive; reroute while Free. Unit tests, native
compile and deployment success are **not** proof of this driving experience.

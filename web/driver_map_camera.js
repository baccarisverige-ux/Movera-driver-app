/* Driver-only Google Maps adapter for google_maps_flutter_web 0.5.14+2.
 * That version does not expose vector rendering, padding, touch rotation/tilt
 * or bitmap marker rotation. Keep these SDK gaps out of the Dart policy.
 * Uses public Maps JS APIs. Styled vector maps require a configured cloud map ID.
 */
(() => {
  'use strict';
  // Maps JavaScript may arrive after this file (async/defer or slow network).
  // Install once it is there; until then ready() is false, so Flutter keeps
  // its map widgets unbuilt instead of throwing over Home's overlays.
  let sdk = null;
  const states = new Map();
  const byMap = new WeakMap();
  const clamp = (v, min, max) => Math.max(min, Math.min(max, v));
  const delta = (a, b) => ((b - a + 540) % 360) - 180;
  const touchPose = touches => {
    const a = touches[0], b = touches[1] || a;
    return {x: (a.clientX + b.clientX) / 2,
      y: (a.clientY + b.clientY) / 2, ay: a.clientY, by: b.clientY,
      span: Math.hypot(a.clientX - b.clientX, a.clientY - b.clientY),
      angle: Math.atan2(b.clientY - a.clientY, b.clientX - a.clientX) * 180 / Math.PI};
  };
  // Where the car goes on screen: the middle of the map left free by the
  // island and the sheet, or (driving) behind that middle so the road
  // ahead shows. `lead` is the camera's heading: with a heading-up map it
  // equals the map heading and the car sits low (75%); on a flat north-up
  // map the car moves away from the side it drives to, so the road ahead
  // is on screen whichever way the car goes.
  function anchorPixel(state) {
    const height = state.div.clientHeight, width = state.div.clientWidth || 0;
    if (!height) return null;
    const available = Math.max(0, height - state.top - state.bottom);
    if (!available) return null;
    const margin = Math.min(24, available / 2);
    const middle = state.top + available / 2;
    const y = state.anchor === .5 ? middle :
      clamp(height * state.anchor, state.top + margin,
        height - state.bottom - margin);
    if (state.lead == null || !width) return {x: width / 2, y};
    const behind = y - middle;
    const turn = (state.lead - (state.map.getHeading() || 0)) * Math.PI / 180;
    const side = Math.min(48, width / 4);
    return {
      x: clamp(width / 2 - Math.sin(turn) * behind, side, width - side),
      y: clamp(middle + Math.cos(turn) * behind, state.top + margin,
        height - state.bottom - margin),
    };
  }
  function shiftToAnchor(state, nativeMove) {
    const projection = state.overlay.getProjection();
    const height = state.div.clientHeight;
    if (!projection || !height) return;
    const desired = anchorPixel(state);
    if (!desired) return;
    const center = projection.fromLatLngToContainerPixel(state.map.getCenter());
    if (!center) return;
    const dx = state.div.clientWidth ? desired.x - state.div.clientWidth / 2 : 0;
    const dy = desired.y - height / 2;
    if (Math.abs(dx) < 0.5 && Math.abs(dy) < 0.5) return;
    const target = projection.fromContainerPixelToLatLng(
      new sdk.Point(center.x - dx, center.y - dy));
    if (!target) return;
    // Re-assert zoom/heading/tilt so a property write cannot keep animating.
    nativeMove({
      center: target,
      zoom: state.map.getZoom(),
      heading: state.map.getHeading() || 0,
      tilt: state.map.getTilt() || 0,
    });
  }
  function pan(state, dx, dy) {
    const projection = state.overlay.getProjection();
    if (!projection) return;
    const center = projection.fromLatLngToContainerPixel(state.map.getCenter());
    const target = projection.fromContainerPixelToLatLng(
      new sdk.Point(center.x - dx, center.y - dy));
    if (target) state.map.moveCamera({center: target});
  }
  // Tilt follows zoom on every driver map (DriverCameraPolicy.tiltForZoom
  // in Dart; keep both in step): 0 deg at zoom 12, then proportional to
  // zoom up to 67.5 deg at zoom 15.5, under the SDKs' own per-zoom limit.
  const MAX_TILT = 67.5, FLAT_ZOOM = 12, FULL_TILT_ZOOM = 15.5;
  const sdkMaxTilt = zoom => zoom <= 10 ? 30 : zoom <= 14 ?
    30 + (zoom - 10) / 4 * 15 : zoom < 15.5 ?
    45 + (zoom - 14) / 1.5 * (MAX_TILT - 45) : MAX_TILT;
  const tiltForZoom = zoom => Number.isFinite(zoom) ?
    Math.min(MAX_TILT * clamp((zoom - FLAT_ZOOM) /
      (FULL_TILT_ZOOM - FLAT_ZOOM), 0, 1), sdkMaxTilt(zoom)) : 0;
  // A zoom step carries the tilt along the curve in the same camera move,
  // so the horizon rises as the driver zooms in and flattens as they zoom
  // out, frame by frame. A tilt the driver set by hand is kept as an offset.
  // Rounding residue (1e-16) would keep a zoomed-out map a hair tilted.
  const tiltWithZoom = (tilt, from, to) => {
    const next = clamp(tilt + tiltForZoom(to) - tiltForZoom(from), 0, sdkMaxTilt(to));
    return next < 1e-9 ? 0 : next;
  };
  // The own vehicle is an upright arrow (lib MoveraVehicleMarker): turned
  // to its heading as seen from the camera, foreshortened like the tilted
  // ground (MoveraVehicleMarker.screenRotation; keep both in step).
  const HALO = 60;
  // The arrow and its halo grow a little zoomed in and shrink zoomed out
  // (MoveraVehicleMarker.scaleStops / nextScale; keep both in step):
  // interpolated between these stops, clamped, in 0.05 buckets that change
  // only once the zoom's scale is 0.7 of a bucket away.
  const SCALE_STOPS = [[11.5, .6], [13.5, .75], [15, 1], [17, 1.1]];
  const SCALE_STEP = .05;
  const scaleForZoom = zoom => {
    if (!Number.isFinite(zoom)) return 1;
    if (zoom <= SCALE_STOPS[0][0]) return SCALE_STOPS[0][1];
    for (let i = 1; i < SCALE_STOPS.length; i++) {
      const [z1, s1] = SCALE_STOPS[i];
      if (zoom <= z1) {
        const [z0, s0] = SCALE_STOPS[i - 1];
        return s0 + (s1 - s0) * (zoom - z0) / (z1 - z0);
      }
    }
    return SCALE_STOPS[SCALE_STOPS.length - 1][1];
  };
  const bucket = scale => Math.round(Math.round(scale / SCALE_STEP) * SCALE_STEP * 100) / 100;
  const nextScale = (shown, zoom) => {
    const wanted = scaleForZoom(zoom);
    if (shown != null && Math.abs(wanted - shown) < SCALE_STEP * .7) return shown;
    return bucket(wanted);
  };
  const screenRotation = (heading, bearing, tilt) => {
    const turn = (heading - bearing) * Math.PI / 180;
    const lean = Math.cos(clamp(tilt, 0, 89) * Math.PI / 180);
    const degrees = Math.atan2(Math.sin(turn), Math.cos(turn) * lean) * 180 / Math.PI;
    return Math.round(((degrees % 360) + 360) % 360 * 100) / 100;
  };
  // Raster tiles stop at about z18; closer, Google upscales them into giant
  // blurry street names. A vector map draws crisp at any zoom: no cap there.
  const RASTER_MAX_ZOOM = 18;
  function install(map, div, id, cloud) {
    const state = {map, div, top: 0, bottom: 0, anchor: .5,
      callbacks: new Set(), rendererCallbacks: new Set(), heading: 0, car: null, claim: false, anchorToken: 0,
      gesturesEnabled: true, lead: null, anchored: false, tiltFollowsZoom: true};
    const rendererListener = map.addListener?.('renderingtype_changed', () => {
      applyZoomCap();
      state.rendererCallbacks.forEach(callback => callback());
    });
    const supports3D = () => map.getRenderingType?.() === sdk.RenderingType.VECTOR;
    // Flutter re-sends every map option on widget updates. With a Map ID the
    // cloud style draws the map: drop inline styles (Google ignores them and
    // warns) and the plugin's empty mapId. Keep the raster zoom cap in force.
    const nativeSetOptions = typeof map.setOptions === 'function'
      ? map.setOptions.bind(map) : null;
    let requestedMaxZoom = null;
    const zoomCap = () => supports3D() ? requestedMaxZoom
      : Math.min(requestedMaxZoom ?? RASTER_MAX_ZOOM, RASTER_MAX_ZOOM);
    if (nativeSetOptions) {
      map.setOptions = (options = {}) => {
        let next = options || {};
        if (cloud) { const {styles, mapId, ...rest} = next; next = rest; }
        if ('maxZoom' in next) requestedMaxZoom = next.maxZoom ?? null;
        nativeSetOptions({...next, maxZoom: zoomCap()});
      };
    }
    const applyZoomCap = () => nativeSetOptions?.({maxZoom: zoomCap()});
    // Until Google settles on a renderer, keep the raster cap.
    if (cloud) applyZoomCap();
    const overlay = new sdk.OverlayView();
    overlay.onAdd = () => {};
    overlay.draw = () => {};
    overlay.onRemove = () => {};
    overlay.setMap(map);
    state.overlay = overlay;
    states.set(id, state);
    byMap.set(map, state);
    const nativeMove = map.moveCamera.bind(map);
    const nativePanTo = typeof map.panTo === 'function'
      ? map.panTo.bind(map)
      : latLng => nativeMove({center: latLng});
    // Flutter web applies a camera update with panTo, which animates. A follow
    // frame claims the next pan so it is instant and anchored before paint;
    // a claimed preview frame is instant and exact.
    map.panTo = latLng => {
      const claim = state.claim;
      if (!claim) {
        state.anchored = false;
        nativePanTo(latLng);
        return;
      }
      state.claim = false;
      nativeMove({center: latLng});
      const token = ++state.anchorToken;
      state.anchored = claim !== 'free';
      if (!state.anchored) return;
      queueMicrotask(() => {
        if (token !== state.anchorToken) return;
        shiftToAnchor(state, nativeMove);
      });
    };
    // A bounds fit is not a follow frame: sheet changes must not shift it.
    if (typeof map.fitBounds === 'function') {
      const nativeFit = map.fitBounds.bind(map);
      map.fitBounds = (...args) => { state.anchored = false; return nativeFit(...args); };
    }
    let previous, travel = 0, startedAt = 0, maxTouches = 0, lastTap = -Infinity;
    let lastTapPoint = null, lastTwoFingerPoint = null;
    let touchReleased = false;
    // A short but real pinch is not a two-finger tap. Its fractional zoom
    // must not be followed by an accidental full-level zoom-out on release.
    let multiTouchMoved = false;
    // A cancelled multi-touch stream must not be completed by a later
    // touchend as a stationary two-finger tap (which zooms out one level).
    let cancelledTouchSequence = false;
    let touchOnControl = false;
    let pointerOrigin = null;
    let pointerReleased = false;
    let controlPointerReleased = false;
    // Google Maps' own +/- camera buttons produce SDK zoom events, not a
    // drag/wheel. Their native control clicks must still switch Movera from
    // GPS-follow to manually owned zoom, or the next fix undoes the change.
    const nativeCameraControl = target => {
      if (!target?.closest) return false;
      if (target.closest('.gm-bundled-control, .gm-control-active')) return true;
      const button = target.closest('button[aria-label], button[title], [role="button"][aria-label]');
      if (!button) return false;
      const name = (button.getAttribute?.('aria-label') ||
          button.getAttribute?.('title') || '').toLowerCase();
      return /zoom|zoom[a-z]*|förstora|förminska|agrandir|dézoomer/.test(name);
    };
    state.setGesturesEnabled = enabled => {
      state.gesturesEnabled = !!enabled;
      if (!enabled) {
        state.stopWheel?.();
        previous = null; pointerOrigin = null;
        touchReleased = false; pointerReleased = false;
        multiTouchMoved = false;
        cancelledTouchSequence = false;
        touchOnControl = false; controlPointerReleased = false;
        lastTap = -Infinity; lastTapPoint = null;
      }
    };
    const release = () => {
      if (!state.gesturesEnabled) return;
      state.claim = false;
      state.anchored = false;
      state.anchorToken++;
      state.callbacks.forEach(callback => callback());
    };
    const releaseTouch = () => {
      if (!touchReleased) { touchReleased = true; release(); }
    };
    // moveCamera({zoom}) scales about the map center. Real pinch/double-tap
    // gestures instead scale about the point between the user's fingers.
    // Compensate in screen pixels so the tapped road stays under the fingers.
    // Client coordinates must be converted to this map's local rectangle.
    const zoomAt = (amount, x, y, camera = {}, gestureX = 0, gestureY = 0) => {
      const current = Number(map.getZoom());
      if (!Number.isFinite(current)) return;
      const next = clamp(current + amount, 3, 21);
      if (supports3D() && state.tiltFollowsZoom && !('tilt' in camera)) {
        camera = {...camera, tilt: tiltWithZoom(map.getTilt() || 0, current, next)};
      }
      map.moveCamera({...camera, zoom: next});
      let panX = gestureX, panY = gestureY;
      const width = div.clientWidth, height = div.clientHeight;
      if (width > 0 && height > 0 && Number.isFinite(x) &&
          Number.isFinite(y) && next !== current) {
        const rect = div.getBoundingClientRect?.() || {left: 0, top: 0};
        const scale = 2 ** (next - current);
        const localX = clamp(x - rect.left, 0, width);
        const localY = clamp(y - rect.top, 0, height);
        panX += (1 - scale) * (localX - width / 2);
        panY += (1 - scale) * (localY - height / 2);
      }
      if (panX || panY) pan(state, panX, panY);
    };
    div.style.touchAction = 'none';
    // A tap (including marker selection) is not a map pan. Ignore pointer
    // events from touch here; the custom touch path below owns their geometry.
    div.addEventListener('pointerdown', event => {
      controlPointerReleased = false;
      if (!state.gesturesEnabled) return;
      if (nativeCameraControl(event.target)) {
        release();
        controlPointerReleased = true;
        pointerOrigin = null;
        return;
      }
      if (event.pointerType === 'touch') return;
      pointerOrigin = {x: event.clientX, y: event.clientY};
      pointerReleased = false;
    }, {capture: true});
    // Keyboard activation has no pointerdown. Do not double-report pointer
    // clicks and do not treat ordinary marker/map taps as camera zoom.
    div.addEventListener('click', event => {
      if (state.gesturesEnabled && nativeCameraControl(event.target) &&
          !controlPointerReleased) release();
      controlPointerReleased = false;
    }, {capture: true});
    div.addEventListener('pointermove', event => {
      if (!state.gesturesEnabled || !pointerOrigin || pointerReleased) return;
      if (Math.hypot(event.clientX - pointerOrigin.x,
          event.clientY - pointerOrigin.y) >= 6) {
        pointerReleased = true;
        release();
      }
    }, {capture: true});
    const clearPointer = () => { pointerOrigin = null; pointerReleased = false; };
    div.addEventListener('pointerup', clearPointer, {capture: true});
    div.addEventListener('pointercancel', clearPointer, {capture: true});
    div.addEventListener('dblclick', release, {capture: true});
    // Wheel / trackpad zoom. A flat (raster) map keeps Google's own wheel
    // zoom. On a vector map Google's wheel animation would zoom with a
    // fixed tilt (and reset a tilt set meanwhile), so this layer zooms
    // instead: a short glide toward the wheel's goal, about the cursor,
    // with the tilt bound to the zoom on every frame.
    let wheelGoal = null, wheelPoint = null, wheelFrame = 0, wheelSet = null;
    const stopWheel = () => {
      if (wheelFrame) globalThis.cancelAnimationFrame?.(wheelFrame);
      wheelFrame = 0; wheelGoal = null; wheelSet = null;
    };
    state.stopWheel = stopWheel;
    const wheelTick = () => {
      wheelFrame = 0;
      const current = Number(map.getZoom());
      // Someone else moved the camera (recenter), or Maps capped the zoom.
      if (wheelGoal == null || !Number.isFinite(current) ||
          (wheelSet != null && Math.abs(current - wheelSet) > .001)) {
        stopWheel();
        return;
      }
      const left = wheelGoal - current;
      const step = Math.abs(left) < .01 ? left : left * .35;
      zoomAt(step, wheelPoint.x, wheelPoint.y);
      wheelSet = Number(map.getZoom());
      if (Math.abs(left) < .01) { stopWheel(); return; }
      wheelFrame = globalThis.requestAnimationFrame(wheelTick);
    };
    div.addEventListener('wheel', event => {
      release();
      if (!state.gesturesEnabled || !supports3D() ||
          typeof globalThis.requestAnimationFrame !== 'function') return;
      event.preventDefault(); event.stopImmediatePropagation();
      const unit = event.deltaMode === 1 ? 33 : event.deltaMode === 2 ? 800 : 1;
      const current = Number(map.getZoom());
      if (!Number.isFinite(current)) return;
      const step = clamp(-(event.deltaY || 0) * unit / 150, -1, 1);
      wheelGoal = clamp((wheelGoal ?? current) + step, 3, 21);
      wheelPoint = {x: event.clientX, y: event.clientY};
      if (!wheelFrame) {
        wheelSet = null;
        wheelFrame = globalThis.requestAnimationFrame(wheelTick);
      }
    }, {capture: true, passive: false});
    // Own touch geometry so zoom + rotate can happen in the same gesture.
    // Mouse/keyboard gestures stay with Google Maps.
    div.addEventListener('touchstart', event => {
      if (!state.gesturesEnabled || cancelledTouchSequence) return;
      // Let browser synthesize click for Maps' native +/- controls.
      // Capturing/preventing their touchstart can make zoom unresponsive.
      if (nativeCameraControl(event.target)) {
        touchOnControl = true;
        previous = null;
        return;
      }
      if (touchOnControl) return;
      event.preventDefault(); event.stopImmediatePropagation();
      state.stopWheel?.();
      if (!previous) {
        startedAt = performance.now(); maxTouches = 0;
        travel = 0; touchReleased = false; multiTouchMoved = false;
        lastTwoFingerPoint = null;
      }
      maxTouches = Math.max(maxTouches, event.touches.length);
      if (event.touches.length > 1) releaseTouch();
      previous = {...touchPose(event.touches), count: event.touches.length};
      if (previous.count > 1) {
        lastTwoFingerPoint = {x: previous.x, y: previous.y};
      }
    }, {capture: true, passive: false});
    div.addEventListener('touchmove', event => {
      if (!state.gesturesEnabled || touchOnControl ||
          cancelledTouchSequence) return;
      event.preventDefault(); event.stopImmediatePropagation();
      const next = {...touchPose(event.touches), count: event.touches.length};
      if (next.count > 1) lastTwoFingerPoint = {x: next.x, y: next.y};
      if (!previous || previous.count !== next.count) { previous = next; return; }
      const travelStep = Math.hypot(next.x - previous.x, next.y - previous.y) +
          Math.abs(next.span - previous.span);
      travel += travelStep;
      if (next.count > 1 && (travel > 2 ||
          Math.abs(delta(previous.angle, next.angle)) > 1.5)) {
        multiTouchMoved = true;
      }
      if (next.count > 1 || travel >= 6) releaseTouch();
      if (!touchReleased) { previous = next; return; }
      if (next.count > 1) {
        const twist = delta(previous.angle, next.angle);
        // Overlapping touch coordinates can briefly report a zero span,
        // making log2(0) infinite and snapping the entire map to minimum
        // zoom. Bound the zoom delta per event so sparse touch frames cannot
        // leap several levels either.
        const ratio = previous.span >= 5 && next.span >= 5
          ? next.span / previous.span : 1;
        const zoomDelta = clamp(Math.log2(ratio), -0.4, 0.4);
        const vertical = next.y - previous.y;
        // Tilt follows zoom by itself; a hand tilt is only a deliberate
        // two-finger drag: both fingers up (or both down) together, mostly
        // vertical, with no pinch or twist in the frame. A pinch whose
        // fingers drift vertically stays a zoom: hand tilt never takes a
        // frame's zoom, and every other frame binds the tilt to the zoom.
        const dyA = next.ay - previous.ay, dyB = next.by - previous.by;
        const tilting = Math.sign(dyA) === Math.sign(dyB) &&
          Math.min(Math.abs(dyA), Math.abs(dyB)) > 1 &&
          Math.abs(vertical) > 2 * Math.abs(next.x - previous.x) &&
          Math.abs(twist) < 2 && Math.abs(zoomDelta) < .01;
        // Zoom about the *previous* focal point; the midpoint translation
        // below then carries that road point to the fingers' new position.
        // A vertical two-finger drag tilts by hand; any other two-finger
        // move zooms with the tilt bound to the zoom (see zoomAt).
        zoomAt(zoomDelta, previous.x, previous.y,
          supports3D() ? {
            heading: ((map.getHeading() || 0) - twist + 360) % 360,
            ...(tilting ? {tilt: clamp((map.getTilt() || 0) - vertical * .3, 0, 67.5)} : {})
          } : {},
          tilting ? 0 : next.x - previous.x,
          tilting ? 0 : next.y - previous.y);
      } else pan(state, next.x - previous.x, next.y - previous.y);
      previous = next;
    }, {capture: true, passive: false});
    const end = event => {
      if (event.type === 'touchcancel') {
        // Browser/OS gesture interruption can leave one finger on the map.
        // Discard *all* tap and pinch history until the final touch lifts.
        cancelledTouchSequence = event.touches.length > 0;
        previous = null;
        touchReleased = false;
        multiTouchMoved = false;
        lastTwoFingerPoint = null;
        maxTouches = 0;
        travel = 0;
        lastTap = -Infinity;
        lastTapPoint = null;
        touchOnControl = false;
        return;
      }
      if (cancelledTouchSequence) {
        if (!event.touches.length) cancelledTouchSequence = false;
        return;
      }
      if (touchOnControl) {
        if (!event.touches.length) touchOnControl = false;
        return;
      }
      if (!state.gesturesEnabled) { previous = null; return; }
      event.preventDefault(); event.stopImmediatePropagation();
      if (event.touches.length) {
        // A two-finger tap ends one finger at a time. Preserve its midpoint;
        // the final remaining finger is NOT the zoom-out focal point.
        if (previous?.count > 1) {
          lastTwoFingerPoint = {x: previous.x, y: previous.y};
        }
        previous = {...touchPose(event.touches), count: event.touches.length};
        return;
      }
      if (event.type !== 'touchcancel' && previous &&
          performance.now() - startedAt < 300 &&
          travel < 8) {
        if (maxTouches > 1) {
          // Two stationary fingers are an intentional zoom-out tap. A subtle
          // pinch or two-finger pan already moved the camera fractionally;
          // do not undo it with another full zoom step on finger release.
          if (!multiTouchMoved) {
            releaseTouch();
            const focus = lastTwoFingerPoint || previous;
            zoomAt(-1, focus.x, focus.y);
          }
          lastTap = -Infinity; lastTapPoint = null;
        } else {
          const now = performance.now();
          // Two independent taps anywhere on the map are not a double-tap
          // zoom. Require both a short interval and nearby touch positions.
          const nearby = lastTapPoint != null &&
            Math.hypot(previous.x - lastTapPoint.x,
              previous.y - lastTapPoint.y) <= 32;
          if (now - lastTap < 300 && nearby) {
            releaseTouch();
            zoomAt(1, previous.x, previous.y);
            lastTap = -Infinity; lastTapPoint = null;
          } else {
            lastTap = now;
            lastTapPoint = {x: previous.x, y: previous.y};
          }
        }
      } else {
        // A long press, drag, or cancelled touch cannot become the first half
        // of a subsequent double-tap.
        lastTap = -Infinity; lastTapPoint = null;
      }
      previous = null;
      touchReleased = false;
      multiTouchMoved = false;
      lastTwoFingerPoint = null;
    };
    div.addEventListener('touchend', end, {capture: true, passive: false});
    div.addEventListener('touchcancel', end, {capture: true, passive: false});
    // Mounted Flutter platform views are removed at dispose. Release JS state.
    let wasConnected = div.isConnected;
    const observer = new MutationObserver(() => {
      wasConnected ||= div.isConnected;
      if (wasConnected && !div.isConnected) {
        state.car?.setMap(null); overlay.setMap(null);
        state.callbacks.clear(); state.rendererCallbacks.clear(); rendererListener?.remove(); states.delete(id); observer.disconnect();
      }
    });
    observer.observe(document.body, {childList: true, subtree: true});
  }
  function installSdk() {
    sdk = globalThis.google.maps;
    const NativeMap = sdk.Map;
    sdk.Map = new Proxy(NativeMap, {
      construct(target, args) {
        const [div, options = {}] = args;
        const match = /^plugins\.flutter\.io\/google_maps_(\d+)$/.exec(div.id);
        const configuredId = globalThis.document?.querySelector?.('meta[name="movera-google-map-id"]')?.content?.trim();
        let driverOptions = options;
        const cloud = !!configuredId && configuredId !== 'DRIVER_GOOGLE_MAP_ID';
        if (match) {
          if (cloud) {
            // The cloud style linked to this Map ID draws the map. If WebGL
            // is missing Google falls back to raster tiles but keeps the Map
            // ID, so inline styles still cannot apply; that fallback shows
            // the cloud style's raster rendering (only the zoom cap is ours).
            const {styles, ...cloudOptions} = options;
            driverOptions = {...cloudOptions, mapId: configuredId,
              renderingType: sdk.RenderingType.VECTOR,
              isFractionalZoomEnabled: true,
              headingInteractionEnabled: true, tiltInteractionEnabled: true};
          } else {
            // Explicit 2D preview preserves the approved inline palette. Styled
            // vector navigation stays gated until its cloud style is configured.
            // Google Maps raster tiles default to integer-only zoom. The
            // custom pinch handler issues fractional steps, so enable smooth
            // fractional zoom even without the configured vector Map ID.
            driverOptions = {...options, renderingType: sdk.RenderingType.RASTER,
              isFractionalZoomEnabled: true,
              maxZoom: Math.min(options.maxZoom ?? RASTER_MAX_ZOOM, RASTER_MAX_ZOOM)};
          }
        }
        const map = Reflect.construct(target, [div, driverOptions]);
        if (match) install(map, div, Number(match[1]), cloud);
        return map;
      }
    });
    const NativeMarker = sdk.Marker;
    sdk.Marker = class extends NativeMarker {
      constructor(options) {
        super(options);
        if (options.title !== 'Driver camera vehicle' || !options.icon?.url) return;
        const marker = this;
        let state;
        const car = new sdk.OverlayView();
        // The own vehicle stands up (a billboard): never rotateX'd into the
        // ground, only turned to its heading as the camera sees it. Its
        // halo lies on the ground and flattens with the tilt.
        const halo = document.createElement('div');
        halo.style.cssText = `position:absolute;pointer-events:none;width:${HALO}px;height:${HALO}px;` +
          'border-radius:50%;background:radial-gradient(circle,rgba(125,140,153,.32) 0,rgba(125,140,153,.26) 82%,rgba(125,140,153,0) 100%);';
        const image = document.createElement('img');
        image.style.cssText = 'position:absolute;pointer-events:none;';
        let anchor = {x: .5, y: .5};
        // Size bucket for the camera's zoom; the overlay redraws on every
        // camera frame, the transform changes only on a new bucket.
        let scale = null;
        const setIcon = icon => {
          if (!icon?.url) return;
          // The same picture again (each marker update sends the icon): no
          // reload (driver-u174).
          if (image.src !== icon.url) image.src = icon.url;
          const size = icon.scaledSize || icon.size;
          if (!size) return;
          image.style.width = `${size.width}px`; image.style.height = `${size.height}px`;
          anchor = icon.anchor && size.width && size.height
            ? {x: icon.anchor.x / size.width, y: icon.anchor.y / size.height}
            : {x: .5, y: .5};
          image.style.transformOrigin = `${anchor.x * 100}% ${anchor.y * 100}%`;
        };
        setIcon(options.icon);
        car.onAdd = () => {
          const pane = car.getPanes().overlayLayer;
          pane.appendChild(halo); pane.appendChild(image);
        };
        car.draw = () => {
          const pixel = car.getProjection()?.fromLatLngToDivPixel(marker.getPosition());
          if (!pixel) return;
          const tilt = state.map.getTilt() || 0;
          scale = nextScale(scale, Number(state.map.getZoom()));
          image.style.left = `${pixel.x}px`; image.style.top = `${pixel.y}px`;
          image.style.transform = `translate(${-anchor.x * 100}%,${-anchor.y * 100}%) ` +
            `rotate(${screenRotation(state.heading, state.map.getHeading() || 0, tilt)}deg) scale(${scale})`;
          halo.style.left = `${pixel.x}px`; halo.style.top = `${pixel.y}px`;
          halo.style.transform = `translate(-50%,-50%) scale(${scale}) scaleY(${Math.cos(tilt * Math.PI / 180)})`;
        };
        car.onRemove = () => { image.remove(); halo.remove(); };
        this.addListener('position_changed', () => car.draw());
        this.addListener('icon_changed', () => { setIcon(this.getIcon()); car.draw(); });
        const attach = () => {
          car.setMap(null);
          state = byMap.get(this.getMap());
          if (!state) return;
          state.car?.setMap(null); state.car = car;
          car.setMap(this.getMap());
        };
        this.addListener('map_changed', attach);
        this.addListener('visible_changed', () => {
          if (this.getVisible()) this.setVisible(false);
        });
        attach();
        this.setVisible(false);
      }
    };
  }
  const sdkLoaded = () => typeof globalThis.google?.maps?.Map === 'function' &&
    typeof globalThis.google.maps.OverlayView === 'function';
  if (sdkLoaded()) installSdk();
  else {
    const poll = setInterval(() => {
      if (!sdkLoaded()) return;
      clearInterval(poll);
      installSdk();
    }, 25);
  }
  globalThis.driverMapCamera = {
    ready() { return sdk !== null; },
    supports3D(id) {
      const state = states.get(id);
      return !!state && state.map.getRenderingType?.() === sdk.RenderingType.VECTOR;
    },
    listenRenderer(id, callback) {
      const state = states.get(id); state?.rendererCallbacks.add(callback);
      return () => state?.rendererCallbacks.delete(callback);
    },
    // New island/sheet insets. While the camera follows the car, glide
    // the car to its new place (Maps animates a short panBy) instead of
    // jumping on the next GPS frame or staying under a raised sheet.
    configure(id, top, bottom, anchor) {
      const state = states.get(id); if (!state) return;
      if (state.top === top && state.bottom === bottom &&
          state.anchor === anchor) return;
      const before = state.anchored ? anchorPixel(state) : null;
      Object.assign(state, {top, bottom, anchor});
      const after = before && anchorPixel(state);
      if (!after || typeof state.map.panBy !== 'function') return;
      const dx = after.x - before.x, dy = after.y - before.y;
      if (Math.abs(dx) >= .5 || Math.abs(dy) >= .5) state.map.panBy(-dx, -dy);
    },
    gestures(id, enabled) {
      states.get(id)?.setGesturesEnabled(enabled);
    },
    // Waiting at a stop the map stays flat while the driver zooms it.
    tiltFollowsZoom(id, enabled) {
      const state = states.get(id); if (state) state.tiltFollowsZoom = !!enabled;
    },
    listen(id, callback) {
      const state = states.get(id); state?.callbacks.add(callback);
      return () => state?.callbacks.delete(callback);
    },
    // The own vehicle's size bucket at a zoom (for checks; see nextScale).
    vehicleScale(zoom, shown) { return nextScale(shown ?? null, zoom); },
    vehicle(id, heading) {
      const state = states.get(id); if (!state) return;
      state.heading = heading; state.car?.draw();
    },
    anchor(id) {
      const state = states.get(id); if (!state) return;
      const nativeMove = state.map.moveCamera.bind(state.map);
      shiftToAnchor(state, nativeMove);
    },
    claim(id, anchored, lead) {
      const state = states.get(id); if (!state) return;
      state.claim = anchored === false ? 'free' : 'anchor';
      if (anchored !== false) state.lead = Number.isFinite(lead) ? lead : null;
    },
  };
})();

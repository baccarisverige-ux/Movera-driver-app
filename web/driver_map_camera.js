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
  // The own position arrow (lib MoveraVehicleMarker; keep the numbers in
  // step; owner 2026-10-31, Rules plan/driver-pin/SPEC.md): a teal rounded
  // navigation arrowhead with a notch at its back, a darker teal inner
  // edge, a thin white outline and a soft shadow, about 18 x 21 pt seen
  // from above, the same size at every zoom. On a tilted map it lies on
  // the road in perspective with a pale mint-grey thickness. It is the
  // plugin's own native marker (Maps places it on every frame, so it never
  // lags a pinch) drawn as Symbols, which Maps paints at once (no image to
  // load, so no blink as it turns): the face on the car's marker, the
  // outline, wall and shadow on native markers under it. Their paths are
  // worked out here for the heading less the map heading and the tilt.
  const ARROW_RAW = [[0, -12], [8.9, 10], [0, 7.4], [-8.9, 10]];
  const ARROW_CONVEX = [true, true, false, true];
  const ARROW_CORNER = 1.8, ARROW_NOTCH = 2.5, ARROW_OUTLINE = 1.5, ARROW_EDGE = 1;
  const ARROW_FLAT_TILT = 1, ARROW_THICKNESS = 3.8;
  const ARROW = {fill: '#00A8C0', edge: '#0090A8', outline: '#F0FAFA',
    wallTop: '#C8E0E0', wallBottom: '#B0CCCC', shadow: '#000000'};
  // Owner 2026-10-31 ("same in all zoom steps"): the halo is 60 pt on
  // screen at every zoom, and the arrow keeps one size at every zoom and tilt.
  const HALO = {color: '#7797A8', opacity: .35, radiusPx: 60};
  // The halo is a screen-facing picture (a native marker), so it stays a
  // 60 pt circle on a tilted map and never changes with the zoom.
  const HALO_URL = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(
    `<svg xmlns="http://www.w3.org/2000/svg" width="${HALO.radiusPx * 2}" height="${HALO.radiusPx * 2}">` +
    `<circle cx="${HALO.radiusPx}" cy="${HALO.radiusPx}" r="${HALO.radiusPx}" ` +
    `fill="${HALO.color}" fill-opacity="${HALO.opacity}"/></svg>`);
  const area2 = pts => pts.reduce((sum, a, i) => {
    const b = pts[(i + 1) % pts.length]; return sum + a[0] * b[1] - b[0] * a[1];
  }, 0);
  const offsetPolygon = (pts, d) => {
    const sign = area2(pts) > 0 ? 1 : -1, n = pts.length;
    const lines = pts.map((a, i) => {
      const b = pts[(i + 1) % n], dx = b[0] - a[0], dy = b[1] - a[1], l = Math.hypot(dx, dy);
      return [[a[0] + sign * dy / l * d, a[1] - sign * dx / l * d], [dx, dy]];
    });
    return lines.map((_, i) => {
      const [p1, d1] = lines[(i - 1 + n) % n], [p2, d2] = lines[i];
      const t = ((p2[0] - p1[0]) * d2[1] - (p2[1] - p1[1]) * d2[0]) / (d1[0] * d2[1] - d1[1] * d2[0]);
      return [p1[0] + d1[0] * t, p1[1] + d1[1] * t];
    });
  };
  const fillet = (p, v, q, r, steps) => {
    const unit = (x, y) => { const l = Math.hypot(x, y); return [x / l, y / l]; };
    const a = unit(p[0] - v[0], p[1] - v[1]), b = unit(q[0] - v[0], q[1] - v[1]);
    const half = Math.acos(clamp(a[0] * b[0] + a[1] * b[1], -1, 1)) / 2;
    const along = r / Math.tan(half), m = unit(a[0] + b[0], a[1] + b[1]);
    const c = [v[0] + m[0] * r / Math.sin(half), v[1] + m[1] * r / Math.sin(half)];
    const a1 = Math.atan2(v[1] + a[1] * along - c[1], v[0] + a[0] * along - c[0]);
    const a2 = Math.atan2(v[1] + b[1] * along - c[1], v[0] + b[0] * along - c[0]);
    const sweep = ((a2 - a1 + Math.PI) % (2 * Math.PI) + 2 * Math.PI) % (2 * Math.PI) - Math.PI;
    const out = [];
    for (let k = 0; k <= steps; k++) {
      const angle = a1 + sweep * k / steps;
      out.push([c[0] + Math.cos(angle) * r, c[1] + Math.sin(angle) * r]);
    }
    return out;
  };
  const outlineCache = new Map();
  const arrowOutline = offset => {
    if (outlineCache.has(offset)) return outlineCache.get(offset);
    const grown = offsetPolygon(ARROW_RAW, offset), n = grown.length, out = [];
    grown.forEach((v, i) => {
      const r = ARROW_CONVEX[i] ? ARROW_CORNER + offset : Math.max(ARROW_NOTCH - offset, .05);
      out.push(...fillet(grown[(i - 1 + n) % n], v, grown[(i + 1) % n], Math.max(r, .05), 6));
    });
    outlineCache.set(offset, out);
    return out;
  };
  const arrowProject = (p, rotation, tilt, height, s = 1) => {
    const r = rotation * Math.PI / 180, t = clamp(tilt, 0, 89) * Math.PI / 180;
    const x = p[0] * s, y = p[1] * s;
    const sy = x * Math.sin(r) + y * Math.cos(r);
    return [x * Math.cos(r) - y * Math.sin(r), sy * Math.cos(t) - height * Math.sin(t)];
  };
  const diameter = pts => {
    let most = 0;
    for (let i = 0; i < pts.length; i++) for (let j = i + 1; j < pts.length; j++) {
      most = Math.max(most, Math.hypot(pts[i][0] - pts[j][0], pts[i][1] - pts[j][1]));
    }
    return most;
  };
  let longSide = null;
  // The arrow's scale on the road so that its longest extent on screen is
  // the flat arrow's (lib MoveraVehicleMarker.footprintScale).
  const footprintScale = (rotation, tilt) => {
    if (tilt < ARROW_FLAT_TILT) return 1;
    longSide ??= diameter(arrowOutline(ARROW_OUTLINE));
    const seen = diameter(arrowOutline(ARROW_OUTLINE).map(p => arrowProject(p, rotation, tilt, 0)));
    return seen > 0 ? longSide / seen : 1;
  };
  const svgPath = pts => 'M' + pts.map(p => p[0].toFixed(2) + ' ' + p[1].toFixed(2)).join('L') + 'Z';
  // The arrow's layers (Symbol paths around the anchor) for its rotation on
  // screen and the map's tilt, bottom to top.
  const arrowLayers = (rotation, tilt) => {
    const tilted = tilt >= ARROW_FLAT_TILT;
    const h = tilted ? ARROW_THICKNESS : 0, scale = footprintScale(rotation, tilt);
    const at = (offset, height, dy = 0) => arrowOutline(offset).map(p => {
      const q = arrowProject(p, rotation, tilt, height, scale); return [q[0], q[1] + dy];
    });
    const rim = at(ARROW_OUTLINE, h);
    let wall = null;
    if (tilted) {
      const road = at(ARROW_OUTLINE, 0), turn = Math.sign(area2(road));
      const parts = [svgPath(road)];
      road.forEach((_, i) => {
        const j = (i + 1) % road.length;
        const quad = [rim[i], rim[j], road[j], road[i]];
        parts.push(svgPath(Math.sign(area2(quad)) === turn ? quad : quad.reverse()));
      });
      wall = parts.join('');
      // The wall's lighter upper half (#C8E0E0 over #B0CCCC).
      const mid = at(ARROW_OUTLINE, h / 2), upper = [svgPath(mid)];
      mid.forEach((_, i) => {
        const j = (i + 1) % mid.length;
        const quad = [rim[i], rim[j], mid[j], mid[i]];
        upper.push(svgPath(Math.sign(area2(quad)) === turn ? quad : quad.reverse()));
      });
      wall = {bottom: wall, top: upper.join('')};
    }
    const dy = tilted ? 1 : 0;
    return {
      // A soft shadow in three steps (a Symbol cannot blur).
      shadowOuter: svgPath(at(ARROW_OUTLINE + 3, 0, dy)),
      shadowMid: svgPath(at(ARROW_OUTLINE + 1.8, 0, dy)),
      shadowInner: svgPath(at(ARROW_OUTLINE + .7, 0, dy)),
      wallBottom: wall?.bottom ?? null,
      wallTop: wall?.top ?? null,
      outline: svgPath(rim),
      face: svgPath(at(-ARROW_EDGE / 2, h)),
    };
  };
  const symbol = (path, fillColor, fillOpacity, extra = {}) => ({path, fillColor, fillOpacity,
    strokeWeight: 0, strokeOpacity: 0, scale: 1, anchor: new sdk.Point(0, 0), ...extra});
  // The arrow's rotation on screen: its compass heading less the map's
  // heading, to a hundredth of a degree.
  const vehicleRotation = (heading, mapHeading) =>
    Math.round((((heading - mapHeading) % 360) + 360) % 360 * 100) / 100;
  // The face (the car's own marker): teal with the darker inner edge as
  // its 1 pt stroke.
  const faceSymbol = layers => symbol(layers.face, ARROW.fill, 1,
    {strokeColor: ARROW.edge, strokeOpacity: 1, strokeWeight: ARROW_EDGE});
  // The arrow's layers by "rotation/tilt" (whole degrees), the most
  // recently used kept.
  const layerCache = new Map();
  const cachedLayers = (rotation, tilt) => {
    const key = rotation + '/' + tilt;
    let layers = layerCache.get(key);
    if (layers) { layerCache.delete(key); layerCache.set(key, layers); return layers; }
    layers = arrowLayers(rotation, tilt);
    layerCache.set(key, layers);
    if (layerCache.size > 128) layerCache.delete(layerCache.keys().next().value);
    return layers;
  };
  // Raster tiles stop at about z18; closer, Google upscales them into giant
  // blurry street names. A vector map draws crisp at any zoom: no cap there.
  const RASTER_MAX_ZOOM = 18;
  function install(map, div, id, cloud) {
    const state = {map, div, top: 0, bottom: 0, anchor: .5,
      callbacks: new Set(), rendererCallbacks: new Set(), car: null, claim: false, anchorToken: 0,
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
    // Owner N6: Flutter's pointer events do not reach the trip map on the
    // web, so Dart cannot see a finger that stays on the map. When the app
    // takes the camera back during a touch (the 12 s return to the car
    // under a resting thumb), the gesture that follows must hand it back
    // again; released once per touch, it fought the app frame by frame.
    state.appClaimDuringTouch = () => { if (previous) touchReleased = false; };
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
      // Maps caps the zoom at maxZoom (raster 18): compensate for the zoom
      // it applied, or a tap at the cap pans the map instead of zooming.
      const shown = Number(map.getZoom());
      const applied = Number.isFinite(shown) ? shown : next;
      let panX = gestureX, panY = gestureY;
      const width = div.clientWidth, height = div.clientHeight;
      if (width > 0 && height > 0 && Number.isFinite(x) &&
          Number.isFinite(y) && applied !== current) {
        const rect = div.getBoundingClientRect?.() || {left: 0, top: 0};
        const scale = 2 ** (applied - current);
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
        state.car?.release(); overlay.setMap(null);
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
    const ownVehicles = new WeakSet();
    // The plugin's own-vehicle marker (the face) with its layers under it
    // and its halo. Returns the car's handle for driverMapCamera.vehicle().
    const LAYERS = ['shadowOuter', 'shadowMid', 'shadowInner', 'wallBottom', 'wallTop', 'outline'];
    const LAYER_STYLE = {shadowOuter: [ARROW.shadow, .04], shadowMid: [ARROW.shadow, .06],
      shadowInner: [ARROW.shadow, .1],
      wallBottom: [ARROW.wallBottom, 1], wallTop: [ARROW.wallTop, 1], outline: [ARROW.outline, 1]};
    const ownVehicle = (marker, zIndex) => {
      // Made bottom first (the halo, then the layers): at one z-index, Maps
      // paints the later one on top.
      const halo = new NativeMarker({
        icon: {url: HALO_URL, scaledSize: new sdk.Size(HALO.radiusPx * 2, HALO.radiusPx * 2),
          anchor: new sdk.Point(HALO.radiusPx, HALO.radiusPx)},
        // zIndex 0: under every trip pin (pickup/drop-off 8, destination 6),
        // so the grey disc never covers them.
        clickable: false, zIndex: 0, position: marker.getPosition(),
      });
      const under = Object.fromEntries(LAYERS.map(name => [name, new NativeMarker({
        clickable: false, zIndex: (zIndex ?? 0) - 1, position: marker.getPosition(),
      })]));
      let heading = 0, state = null, listeners = [], drawn = '';
      const draw = () => {
        const map = marker.getMap();
        // Whole degrees: finer turns are not visible.
        const rotation = Math.round(vehicleRotation(heading, map?.getHeading?.() || 0)) % 360;
        const rawTilt = Number(map?.getTilt?.()) || 0;
        const tilt = rawTilt < ARROW_FLAT_TILT ? 0 : Math.round(rawTilt);
        const key = rotation + '/' + tilt;
        if (key === drawn) return;
        drawn = key;
        const layers = cachedLayers(rotation, tilt);
        marker.setIcon(faceSymbol(layers));
        for (const name of LAYERS) {
          const [color, opacity] = LAYER_STYLE[name];
          under[name].setIcon(layers[name] ? symbol(layers[name], color, opacity) : null);
          under[name].setVisible(!!layers[name] && marker.getVisible() !== false);
        }
      };
      const car = {
        turn(next) { heading = next; draw(); },
        release() {
          listeners.forEach(l => l?.remove()); listeners = [];
          for (const name of LAYERS) under[name].setMap(null);
          halo.setMap(null);
        },
        // Checks: the layers' markers and the halo.
        parts: () => ({under, halo}),
      };
      const attach = () => {
        listeners.forEach(l => l?.remove()); listeners = [];
        if (state?.car === car) state.car = null;
        const map = marker.getMap() ?? null;
        for (const name of LAYERS) under[name].setMap(map);
        halo.setMap(map);
        halo.setPosition(marker.getPosition());
        state = map ? byMap.get(map) ?? null : null;
        if (state) state.car = car;
        // Every camera frame that turns or tilts the map redraws the arrow.
        if (map?.addListener) {
          listeners = [map.addListener('heading_changed', draw),
            map.addListener('tilt_changed', draw)];
        }
        drawn = '';
        draw();
      };
      marker.addListener('position_changed', () => {
        const at = marker.getPosition();
        for (const name of LAYERS) under[name].setPosition(at);
        halo.setPosition(at);
      });
      marker.addListener('visible_changed', () => {
        const visible = marker.getVisible() !== false;
        drawn = '';
        draw();
        for (const name of LAYERS) if (!visible) under[name].setVisible(false);
        halo.setVisible(visible);
      });
      marker.addListener('zindex_changed', () => {
        // The halo stays at 0, under the trip pins.
        for (const name of LAYERS) under[name].setZIndex((marker.getZIndex() ?? 0) - 1);
      });
      marker.addListener('map_changed', attach);
      attach();
      return car;
    };
    // The plugin sends the car's raster icon (drawn in Dart) and its title
    // with every update; a raster icon cannot turn or tilt, and a title made
    // the map show it in a broken image box (driver group 3), so only a
    // Symbol gets through and the car gets no tooltip or click.
    const ownOptions = options => {
      const {icon, title, clickable, ...rest} = options;
      return icon && !icon.url ? {...rest, icon, clickable: false} : {...rest, clickable: false};
    };
    sdk.Marker = class extends NativeMarker {
      constructor(options) {
        const own = options?.title === 'Driver camera vehicle';
        super(own ? ownOptions(options) : options);
        if (!own) return;
        ownVehicles.add(this);
        this.setIcon(faceSymbol(arrowLayers(0, 0)));
        ownVehicle(this, options.zIndex);
      }
      setOptions(options) {
        super.setOptions(ownVehicles.has(this) ? ownOptions(options) : options);
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
    // The arrow's rotation on screen (for checks; see vehicleRotation).
    vehicleRotation(heading, mapHeading) { return vehicleRotation(heading, mapHeading); },
    // The own vehicle's compass heading (degrees, 0 north, clockwise).
    vehicle(id, heading) {
      states.get(id)?.car?.turn(heading);
    },
    // Checks: the arrow's layer paths for a rotation on screen and a tilt,
    // and the halo's picture.
    arrowLayers(rotation, tilt) { return arrowLayers(rotation, tilt); },
    haloIcon() { return {url: HALO_URL, radiusPx: HALO.radiusPx}; },
    // Checks: the own vehicle's layer markers and halo on a map.
    vehicleParts(id) { return states.get(id)?.car?.parts() ?? null; },
    anchor(id) {
      const state = states.get(id); if (!state) return;
      const nativeMove = state.map.moveCamera.bind(state.map);
      shiftToAnchor(state, nativeMove);
    },
    claim(id, anchored, lead) {
      const state = states.get(id); if (!state) return;
      state.appClaimDuringTouch?.();
      state.claim = anchored === false ? 'free' : 'anchor';
      if (anchored !== false) state.lead = Number.isFinite(lead) ? lead : null;
    },
  };
})();

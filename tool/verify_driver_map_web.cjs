// Contract tests for our JS adapter, not a replacement for real Maps/device QA.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
let clock = 1000;
class Element {
  constructor(id = '') { this.id = id; this.style = {}; this.handlers = {}; this.clientHeight = 800; this.clientWidth = 400; this.left = 0; this.top = 0; this.isConnected = true; }
  getBoundingClientRect() { return {left: this.left, top: this.top}; }
  addEventListener(name, callback) { this.handlers[name] = callback; }
  fire(name, touches = [], props = {}) {
    const event = {type: name, touches, ...props,
      defaultPrevented: false, propagationStopped: false,
      preventDefault() { this.defaultPrevented = true; },
      stopImmediatePropagation() { this.propagationStopped = true; }};
    this.handlers[name]?.(event);
    return event;
  }
  appendChild() {} remove() {}
}
class MapMock {
  constructor(div, options) { this.div = div; this.options = options;
    this.camera = {center: {x: 0, y: 0}, zoom: 16, heading: 0, tilt: 0}; }
  moveCamera(camera) {
    // Match the Maps raster default: integer-only zoom unless fractional
    // zoom is explicitly enabled. This makes the pinch test fail when the
    // adapter accidentally drops that required map option.
    const next = {...camera};
    if (next.zoom != null && this.options.renderingType === 'RASTER' &&
        !this.options.isFractionalZoomEnabled) {
      next.zoom = Math.round(next.zoom);
    }
    Object.assign(this.camera, next);
  }
  addListener(event, callback) { this.listeners ??= {}; this.listeners[event] = callback; return {remove: () => delete this.listeners[event]}; }
  getRenderingType() { return this.renderer ?? this.options.renderingType; }
  getCenter() { return this.camera.center; } getZoom() { return this.camera.zoom; }
  getHeading() { return this.camera.heading; } getTilt() { return this.camera.tilt; }
}
class OverlayMock {
  setMap(map) { if (this.map) this.onRemove(); this.map = map;
    if (map) { this.onAdd(); this.draw(); } }
  getPanes() { return {overlayLayer: new Element()}; }
  getProjection() { if (!this.map) return null; return {
    fromLatLngToContainerPixel: p => p,
    fromContainerPixelToLatLng: p => p,
    fromLatLngToDivPixel: p => p,
  }; }
}
class MarkerMock {
  constructor(options) { this.options = options; this.handlers = {}; }
  addListener(event, callback) { this.handlers[event] = callback; }
  setMap(map) { this.options.map = map; this.handlers.map_changed?.(); }
  getMap() { return this.options.map; } getPosition() { return this.options.position; }
  getIcon() { return this.options.icon; } getVisible() { return this.options.visible; }
  setVisible(visible) { this.options.visible = visible; this.handlers.visible_changed?.(); }
}
const maps = {Map: MapMock, Marker: MarkerMock, OverlayView: OverlayMock,
  Point: class {constructor(x,y) {this.x=x;this.y=y;}}, RenderingType: {VECTOR: 'VECTOR', RASTER: 'RASTER'}};
const images = [];
const context = {google: {maps}, performance: {now: () => clock},
  queueMicrotask,
  document: {querySelector: () => ({content: 'configured-vector-style'}), body: new Element(), createElement: () => {
    const image = new Element(); images.push(image); return image;
  }},
  MutationObserver: class {observe() {} disconnect() {}}};
// Maps JavaScript loaded after the adapter (async/defer, slow network): the
// adapter must not throw, must report not ready, and must install itself
// once the SDK arrives. Flutter builds no map until ready().
{
  const ticks = [];
  const late = {performance: context.performance, queueMicrotask,
    document: context.document, MutationObserver: context.MutationObserver,
    setInterval: callback => ticks.push(callback), clearInterval: () => ticks.length = 0};
  vm.runInNewContext(fs.readFileSync('web/driver_map_camera.js', 'utf8'), late);
  assert.equal(late.driverMapCamera.ready(), false, 'No SDK yet: adapter waits');
  assert.equal(late.driverMapCamera.supports3D(1), false);
  late.driverMapCamera.configure(1, 0, 0, .5);
  late.google = {maps: {...maps}};
  ticks[0]();
  assert.equal(late.driverMapCamera.ready(), true, 'Adapter installs when SDK lands');
  assert.notEqual(late.google.maps.Map, MapMock, 'Late SDK Map is wrapped');
  assert.equal(ticks.length, 0, 'Polling stops after install');
}
vm.runInNewContext(fs.readFileSync('web/driver_map_camera.js', 'utf8'), context);
assert.equal(context.driverMapCamera.ready(), true);
const div = new Element('plugins.flutter.io/google_maps_7');
const style = [{featureType: 'water'}];
const map = new maps.Map(div, {styles: style});
assert.equal(map.options.renderingType, 'VECTOR');
assert.equal(map.options.isFractionalZoomEnabled, true,
  'Vector Maps keeps fractional following and pinch zoom');
assert.equal(map.options.styles, undefined, 'Cloud style and inline styles cannot coexist');
assert.equal(map.options.mapId, 'configured-vector-style');
assert.equal(map.options.headingInteractionEnabled, true);
const api = context.driverMapCamera;
assert.equal(api.supports3D(7), true);
context.document.querySelector = () => ({content: ''});
const rasterDiv = new Element('plugins.flutter.io/google_maps_8');
const raster = new maps.Map(rasterDiv, {styles: style});
assert.equal(raster.options.renderingType, 'RASTER');
assert.equal(raster.options.isFractionalZoomEnabled, true,
  'Raster fallback must allow fractional pinch steps');
assert.equal(raster.options.styles, style, 'Explicit 2D preview retains approved palette');
assert.equal(api.supports3D(8), false);
rasterDiv.fire('touchstart', [{clientX:100,clientY:100},{clientX:200,clientY:100}]);
rasterDiv.fire('touchmove', [{clientX:80,clientY:80},{clientX:220,clientY:120}]);
assert.ok(raster.getZoom() > 16 && raster.getZoom() < 17,
  'A single raster pinch frame should zoom smoothly, not snap or get ignored');
assert.equal(raster.getHeading(), 0, 'Raster gestures do not request rotation');
assert.equal(raster.getTilt(), 0, 'Raster gestures do not request tilt');
let changed = 0;
const removeRenderer = api.listenRenderer(7, () => changed++);
map.renderer = 'RASTER'; map.listeners.renderingtype_changed();
assert.equal(changed, 1); assert.equal(api.supports3D(7), false);
removeRenderer(); map.renderer = 'VECTOR'; map.listeners.renderingtype_changed();
assert.equal(changed, 1, 'Renderer listener is released');
let gestures = 0;
const remove = api.listen(7, () => gestures++);
const mouse = (x, y) => ({pointerType: 'mouse', clientX: x, clientY: y});
div.fire('pointerdown', [], mouse(100,100));
assert.equal(gestures, 0, 'Mouse tap must not release follow');
div.fire('pointermove', [], mouse(103,100));
assert.equal(gestures, 0, 'Mouse jitter must not release follow');
div.fire('pointermove', [], mouse(113,100));
assert.equal(gestures, 1, 'Real mouse drag releases follow');
div.fire('pointermove', [], mouse(130,100));
assert.equal(gestures, 1, 'One drag releases once');
div.fire('pointerup', [], mouse(130,100));
// Clicking Google's +/- control must release follow exactly once, unlike a
// map/marker tap. Keyboard activation has no pointerdown, but must still work.
const cameraControl = {
  closest: selector => selector.includes('.gm-bundled-control') ? {} : null,
};
const mapSurface = {closest: () => null};
div.fire('pointerdown', [], {...mouse(100,100), target: mapSurface});
div.fire('click', [], {target: mapSurface});
assert.equal(gestures, 1, 'Ordinary tap preserves GPS follow');
div.fire('pointerdown', [], {...mouse(100,100), target: cameraControl});
assert.equal(gestures, 2, 'Native zoom-in control immediately releases GPS follow');
div.fire('click', [], {target: cameraControl});
assert.equal(gestures, 2, 'Pointer click cannot double-release camera');
div.fire('click', [], {target: cameraControl});
assert.equal(gestures, 3, 'Keyboard zoom-out click also releases follow');
// Some SDK versions render the control as a labelled button rather than
// .gm-bundled-control. Confirm the generic native button fallback.
const labelledButton = {getAttribute: field =>
  field === 'aria-label' ? 'Zoom out' : null};
const labelledTarget = {closest: selector =>
  selector.includes('button[aria-label]') ? labelledButton : null};
div.fire('click', [], {target: labelledTarget});
assert.equal(gestures, 4, 'ARIA-labelled map zoom button releases follow');
const touch = (x, y) => ({clientX: x, clientY: y});
div.fire('touchstart', [touch(100,100)]);
div.fire('touchend');
assert.equal(gestures, 4, 'Single finger tap preserves follow');
clock += 350;
div.fire('touchstart', [touch(100,100)]);
div.fire('touchmove', [touch(103,102)]);
assert.equal(gestures, 4, 'Touch jitter preserves follow');
div.fire('touchmove', [touch(130,120)]);
assert.equal(gestures, 5, 'Touch pan releases follow');
assert.equal(map.camera.center.x, -27, 'One-finger pan after jitter threshold');
div.fire('touchend');
div.fire('touchstart', [touch(100,100),touch(200,100)]);
div.fire('touchmove', [touch(80,80),touch(220,120)]);
assert.ok(map.getZoom() > 16 && map.getHeading() !== 0, 'Combined pinch + twist');
div.fire('touchend');
map.moveCamera({tilt: 0});
div.fire('touchstart', [touch(100,100),touch(200,100)]);
div.fire('touchmove', [touch(100,50),touch(200,50)]);
assert.equal(map.getTilt(), 15, 'Two-finger up tilts');
div.fire('touchmove', [touch(100,-300),touch(200,-300)]);
assert.equal(map.getTilt(), 60, 'Tilt clamps to 60');
div.fire('touchmove', [touch(100,400),touch(200,400)]);
assert.equal(map.getTilt(), 0, 'Two-finger down flattens');
div.fire('touchend');
const beforeTap = map.getZoom();
div.fire('touchstart', [touch(100,100),touch(200,100)]);
div.fire('touchend', [touch(100,100)]); div.fire('touchend');
assert.equal(map.getZoom(), beforeTap - 1, 'Two-finger tap zooms out');
// A small *actual* pinch must not also apply the unrelated two-finger-tap
// zoom-out step when the fingers lift. Before the fix a 3px pinch produced
// +0.04 zoom and then -1.00 zoom on release.
clock += 400;
const beforeMicroPinch = map.getZoom();
div.fire('touchstart', [touch(100,100), touch(200,100)]);
div.fire('touchmove', [touch(100,100), touch(203,100)]);
div.fire('touchend', [touch(100,100)]);
div.fire('touchend');
assert.ok(map.getZoom() > beforeMicroPinch &&
  map.getZoom() < beforeMicroPinch + 0.2,
  'Small pinch-in cannot reverse into full zoom-out on finger release');
clock += 400;
const beforeMicroShrink = map.getZoom();
div.fire('touchstart', [touch(100,100), touch(200,100)]);
div.fire('touchmove', [touch(100,100), touch(197,100)]);
div.fire('touchend', [touch(100,100)]);
div.fire('touchend');
assert.ok(map.getZoom() < beforeMicroShrink &&
  map.getZoom() > beforeMicroShrink - 0.2,
  'Small pinch-out remains fractional instead of doubling zoom-out');
// Pinch zoom must retain the geographic point below the fingers, even when
// the Maps div does not begin at the origin of the browser viewport.
map.moveCamera({zoom: 16, center: {x:0, y:0}});
div.left = 50; div.top = 75;
clock += 400;
div.fire('touchstart', [touch(170,325), touch(230,325)]);
div.fire('touchmove', [touch(140,325), touch(260,325)]);
const focalScale = 2 ** (map.getZoom() - 16);
assert.ok(Math.abs(map.camera.center.x + (focalScale - 1) * 50) < 0.001,
  'Pinch compensates X around the fingers, accounting for map screen offset');
assert.ok(Math.abs(map.camera.center.y + (focalScale - 1) * 150) < 0.001,
  'Pinch compensates Y around the fingers instead of jumping at map center');
div.fire('touchend');
// Ending fingers separately cannot shift two-finger zoom to the position of
// whichever finger happens to be lifted last. Keep the gesture midpoint.
map.moveCamera({zoom: 16, center: {x:0, y:0}});
clock += 400;
div.fire('touchstart', [touch(150,325), touch(250,325)]);
div.fire('touchend', [touch(150,325)]);
div.fire('touchend');
assert.equal(map.getZoom(), 15);
assert.ok(Math.abs(map.camera.center.x - 25) < 0.001,
  'Two-finger zoom-out uses original midpoint, not final left finger');
assert.ok(Math.abs(map.camera.center.y - 75) < 0.001,
  'Two-finger tap maintains midpoint even when the touches end separately');
div.left = 0; div.top = 0;
map.moveCamera({zoom: 16, center: {x:0, y:0}});
clock += 400;
div.fire('touchstart', [touch(100,200), touch(200,200)]);
div.fire('touchmove', [touch(100,200), touch(300,200)]);
const combinedScale = 2 ** (map.getZoom() - 16);
assert.ok(Math.abs(map.camera.center.x +
    (50 + (combinedScale - 1) * 50)) < 0.001,
  'Simultaneous pan plus zoom uses previous pinch center, then translates');
assert.ok(Math.abs(map.camera.center.y +
    (combinedScale - 1) * 200) < 0.001,
  'Combined pinch and pan retains Y anchor without drift');
div.fire('touchend');
map.moveCamera({center: {x:0, y:0}});
const beforeDoubleTap = map.getZoom();
div.fire('touchstart', [touch(100,100)]); div.fire('touchend');
clock += 150;
div.fire('touchstart', [touch(100,100)]); div.fire('touchend');
assert.equal(map.getZoom(), beforeDoubleTap + 1,
  'Double tap zooms in exactly one level from current fractional zoom');
assert.ok(map.camera.center.x < 0 && map.camera.center.y < 0,
  'Double-tap on upper-left map point zooms around tap, not screen center');
// Fast taps at different positions should select different map items, not zoom.
clock += 400;
const separateZoom = map.getZoom();
div.fire('touchstart', [touch(100,100)]); div.fire('touchend');
clock += 100;
div.fire('touchstart', [touch(550,550)]); div.fire('touchend');
assert.equal(map.getZoom(), separateZoom,
  'Distant taps inside 300ms must not zoom unexpectedly');
clock += 100;
div.fire('touchstart', [touch(552,551)]); div.fire('touchend');
assert.equal(map.getZoom(), separateZoom + 1,
  'A nearby second tap still zooms in');
clock += 400;
const canceledZoom = map.getZoom();
div.fire('touchstart', [touch(200,200)]); div.fire('touchcancel');
clock += 100;
div.fire('touchstart', [touch(200,200)]); div.fire('touchend');
assert.equal(map.getZoom(), canceledZoom,
  'Canceled touch must not become a double-tap first strike');
// OS/browser may cancel a two-finger gesture *while one finger remains*.
// The final release must not be mistaken for an intentional two-finger tap.
clock += 400;
const interruptedPinchZoom = map.getZoom();
div.fire('touchstart', [touch(100,100), touch(200,100)]);
div.fire('touchcancel', [touch(100,100)]);
div.fire('touchmove', [touch(110,100)]);
div.fire('touchstart', [touch(110,100), touch(210,100)]);
div.fire('touchend', [touch(110,100)]);
div.fire('touchend');
assert.equal(map.getZoom(), interruptedPinchZoom,
  'Cancelled pinch with surviving finger cannot zoom out on release');
clock += 100;
div.fire('touchstart', [touch(110,100)]); div.fire('touchend');
assert.equal(map.getZoom(), interruptedPinchZoom,
  'Cancelled pinch must not leave behind a false double-tap');
clock += 400;
const recoveredPinchZoom = map.getZoom();
div.fire('touchstart', [touch(100,100), touch(200,100)]);
div.fire('touchmove', [touch(100,100), touch(220,100)]);
div.fire('touchend');
assert.ok(map.getZoom() > recoveredPinchZoom,
  'Fresh two-finger pinch still zooms normally after cancellation');
// A locked active-trip sheet must prevent custom web pan, pinch and zoom,
// not merely disable native Google Maps gesture flags.
api.gestures(7, false);
const lockedZoom = map.getZoom();
const lockedHeading = map.getHeading();
const lockedCenter = JSON.stringify(map.getCenter());
const lockedCallbacks = gestures;
div.fire('pointerdown', [], mouse(100,100));
div.fire('pointermove', [], mouse(160,140));
div.fire('pointerup', [], mouse(160,140));
div.fire('touchstart', [touch(100,100),touch(200,100)]);
div.fire('touchmove', [touch(50,70),touch(260,160)]);
div.fire('touchend');
div.fire('wheel');
div.fire('pointerdown', [], {...mouse(100,100), target: cameraControl});
div.fire('click', [], {target: cameraControl});
assert.equal(map.getZoom(), lockedZoom, 'Locked map ignores two-finger zoom');
assert.equal(map.getHeading(), lockedHeading, 'Locked map ignores rotation');
assert.equal(JSON.stringify(map.getCenter()), lockedCenter,
  'Locked map ignores pointer and touch pan');
assert.equal(gestures, lockedCallbacks,
  'Locked map cannot steal follow-camera ownership');
api.gestures(7, true);
div.fire('touchstart', [touch(100,100),touch(200,100)]);
div.fire('touchmove', [touch(60,100),touch(240,100)]);
assert.ok(map.getZoom() > lockedZoom, 'Re-enabled zoom gesture works');
div.fire('touchend');
const beforeCollapsedPinch = map.getZoom();
div.fire('touchstart', [touch(100,100), touch(200,100)]);
div.fire('touchmove', [touch(100,100), touch(100,100)]);
assert.equal(map.getZoom(), beforeCollapsedPinch,
  'Overlapping touch positions must not snap zoom to minimum');
div.fire('touchend');
const beforeSparsePinch = map.getZoom();
div.fire('touchstart', [touch(100,100), touch(200,100)]);
div.fire('touchmove', [touch(100,100), touch(5000,100)]);
assert.ok(map.getZoom() - beforeSparsePinch <= 0.400001,
  'Sparse pinch events cannot jump multiple zoom levels');
div.fire('touchend');
// Native double-tap / two-finger tap must respect Maps zoom boundaries.
map.moveCamera({zoom: 3});
clock += 500;
div.fire('touchstart', [touch(100,100), touch(200,100)]);
div.fire('touchend');
assert.equal(map.getZoom(), 3, 'Two-finger zoom-out cannot go below level 3');
map.moveCamera({zoom: 21});
clock += 500;
div.fire('touchstart', [touch(100,100)]); div.fire('touchend');
clock += 150;
div.fire('touchstart', [touch(100,100)]); div.fire('touchend');
assert.equal(map.getZoom(), 21, 'Double-tap zoom-in cannot exceed level 21');
api.configure(7, 100, 200, .72);
map.moveCamera({center: {x:0,y:400}}); api.anchor(7);
assert.equal(map.camera.center.y, 224, '72% screen anchor above overlays');
const marker = new maps.Marker({title:'Driver camera vehicle', position:{x:1,y:2},
  icon:{url:'vehicle.png',scaledSize:{width:40,height:40}}, visible:true});
marker.setMap(map); api.vehicle(7,90);
assert.equal(marker.getVisible(), false, 'Rotatable vehicle overlay replaces bitmap');
map.moveCamera({heading:90}); api.vehicle(7,90);
assert.ok(images[0].style.transform.includes('rotate(0deg)'), 'Heading-up car points up');
map.moveCamera({heading:30}); api.vehicle(7,90);
assert.ok(images[0].style.transform.includes('rotate(60deg)'), 'Free rotation preserves real car course');
marker.setMap(null);
// Native Maps +/- touches must not be cancelled by the map-wide custom
// gesture interpreter. Mobile browsers need an intact touch-to-click chain.
const beforeNativeTouch = gestures;
div.fire('pointerdown', [], {...mouse(100,100),
  pointerType: 'touch', target: cameraControl});
const plusTouch = div.fire('touchstart', [touch(100,100)],
  {target: cameraControl});
const plusEnd = div.fire('touchend', [], {target: cameraControl});
assert.equal(plusTouch.defaultPrevented, false,
  'Native zoom-in touchstart must be uncancelled for browser click');
assert.equal(plusEnd.defaultPrevented, false,
  'Native zoom-in touchend must be uncancelled for browser click');
div.fire('click', [], {target: cameraControl});
assert.equal(gestures, beforeNativeTouch + 1,
  'Touch and click on native zoom-in release follow exactly once');
const minusTouch = div.fire('touchstart', [touch(110,100)],
  {target: labelledTarget});
const minusEnd = div.fire('touchend', [], {target: labelledTarget});
assert.equal(minusTouch.defaultPrevented, false,
  'Native zoom-out button must receive uncancelled touchstart');
assert.equal(minusEnd.defaultPrevented, false,
  'Native zoom-out button must receive uncancelled touchend');
div.fire('click', [], {target: labelledTarget});
assert.equal(gestures, beforeNativeTouch + 2,
  'Touch and click on native zoom-out release follow once');
const ordinaryTouch = div.fire('touchstart', [touch(200,200)],
  {target: mapSurface});
assert.equal(ordinaryTouch.defaultPrevented, true,
  'Pinch and pan remain owned by the custom map gesture adapter');
div.fire('touchend', [], {target: mapSurface});
remove(); const count = gestures; div.fire('pointerdown', [], mouse(100,100));
div.fire('pointermove', [], mouse(120,100));
assert.equal(gestures,count,'Disposed Flutter listener released');
map.moveCamera({center: {x:0,y:400}, zoom: 16, heading: 12, tilt: 30});
api.claim(7);
map.panTo({x:0,y:400});
queueMicrotask(() => {
  assert.equal(map.camera.center.y, 224, 'Claimed follow pan anchors before paint');
  assert.equal(map.getZoom(), 16);
  assert.equal(map.getHeading(), 12);
  assert.equal(map.getTilt(), 30);
  console.log('PASS: vector palette, tap-safe release, gesture lock, drag, pan, pinch/twist, tilt, taps, anchor and vehicle overlay');
});

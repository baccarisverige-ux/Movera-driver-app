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
    // Maps never shows a zoom above the map's maxZoom (raster cap 18).
    if (next.zoom != null && this.options.maxZoom != null) {
      next.zoom = Math.min(next.zoom, this.options.maxZoom);
    }
    const turned = next.heading != null && next.heading !== this.camera.heading;
    Object.assign(this.camera, next);
    if (turned) this.listeners?.heading_changed?.();
  }
  setOptions(options) { this.options = {...this.options, ...options}; }
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
  static all = [];
  constructor(options) { this.options = {...options}; this.handlers = {}; MarkerMock.all.push(this); }
  addListener(event, callback) { (this.handlers[event] ??= new Set()).add(callback);
    return {remove: () => this.handlers[event].delete(callback)}; }
  fire(event) { for (const callback of [...this.handlers[event] ?? []]) callback(); }
  setMap(map) { this.options.map = map; this.fire('map_changed'); }
  // Like MVCObject: each changed property fires its lower-case _changed
  // event (zIndex: zindex_changed).
  setOptions(options) { for (const [key, value] of Object.entries(options)) {
    if (this.options[key] === value) continue;
    this.options[key] = value; this.fire(`${key.toLowerCase()}_changed`); } }
  getMap() { return this.options.map; } getPosition() { return this.options.position; }
  getIcon() { return this.options.icon; } getVisible() { return this.options.visible; }
  setVisible(visible) { this.setOptions({visible}); }
  setIcon(icon) { this.setOptions({icon}); }
  setPosition(position) { this.setOptions({position}); }
  getZIndex() { return this.options.zIndex; } setZIndex(zIndex) { this.setOptions({zIndex}); }
}
const maps = {Map: MapMock, Marker: MarkerMock, OverlayView: OverlayMock,
  Point: class {constructor(x,y) {this.x=x;this.y=y;}},
  Size: class {constructor(width,height) {this.width=width;this.height=height;}},
  RenderingType: {VECTOR: 'VECTOR', RASTER: 'RASTER'}};
const images = [], halos = [];
const frames = [];
const flushFrames = (max = 200) => {
  for (let i = 0; i < max && frames.length; i++) frames.shift()?.();
};
const context = {google: {maps}, performance: {now: () => clock},
  queueMicrotask,
  requestAnimationFrame: callback => { frames.push(callback); return frames.length; },
  cancelAnimationFrame: () => { frames.length = 0; },
  document: {querySelector: () => ({content: 'configured-vector-style'}), body: new Element(), createElement: tag => {
    const element = new Element(); (tag === 'img' ? images : halos).push(element); return element;
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
// driver-r4-24: that late arrival is what index.html must allow. A plain
// <script> for Maps blocks the parser, so a stalled maps.googleapis.com
// kept Flutter from starting at all (blank page).
{
  const html = fs.readFileSync('web/index.html', 'utf8');
  const tag = /<script\b[^>]*maps\.googleapis\.com[^>]*>/.exec(html)?.[0];
  assert.ok(tag, 'index.html loads Maps JavaScript');
  assert.match(tag, /\s(async|defer)[\s>=]/, 'Maps JavaScript never blocks the Flutter bootstrap');
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
assert.equal(raster.options.maxZoom, 18, 'Raster tiles stop before they upscale');
raster.setOptions({maxZoom: 21, styles: style});
assert.equal(raster.options.maxZoom, 18, 'Flutter option updates keep the raster cap');
assert.equal(raster.options.styles, style, 'Raster updates keep the in-app style');
// Flutter re-sends options on widget updates: never inline styles (or the
// plugin's empty mapId) on top of the cloud-styled Map ID.
map.setOptions({styles: style, mapId: undefined, zoomControl: false});
assert.equal(map.options.styles, undefined, 'Option updates keep the cloud style');
assert.equal(map.options.mapId, 'configured-vector-style');
assert.equal(map.options.zoomControl, false);
assert.equal(map.options.maxZoom, null, 'Vector map zooms without a cap');
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
assert.equal(map.options.maxZoom, 18, 'Vector fell back to raster: cap applies');
removeRenderer(); map.renderer = 'VECTOR'; map.listeners.renderingtype_changed();
assert.equal(changed, 1, 'Renderer listener is released');
assert.equal(map.options.maxZoom, null, 'Back on vector: cap lifted');
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
assert.equal(map.getTilt(), 67.5, 'Tilt clamps to 67.5');
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
// driver-u192: at the raster cap (18) Maps keeps the zoom. The finger
// compensation must use the zoom applied, or a double tap pans the map.
{
  rasterDiv.fire('touchend'); // the earlier raster pinch never lifted
  raster.moveCamera({zoom: 18, center: {x: 0, y: 0}});
  clock += 500;
  const right = {clientX: 320, clientY: 400}; // 120 px right of centre
  rasterDiv.fire('touchstart', [right]); rasterDiv.fire('touchend');
  clock += 150;
  rasterDiv.fire('touchstart', [right]); rasterDiv.fire('touchend');
  assert.equal(raster.getZoom(), 18, 'Raster double tap at the cap keeps zoom 18');
  assert.deepEqual(raster.camera.center, {x: 0, y: 0},
    'Raster double tap at the cap does not pan the map sideways');
  clock += 500;
}
api.configure(7, 100, 200, .75);
map.moveCamera({center: {x:0,y:400}}); api.anchor(7);
assert.equal(map.camera.center.y, 224, '75% screen anchor above overlays');
// uat-d3: the own vehicle is a native marker (Maps places it on every
// frame: no overlay that lags the map under a pinch and snaps after; no
// size that steps with the zoom; nothing that leans or squashes with the
// tilt) with a rotatable Symbol arrow (lib MoveraVehicleMarker; keep in
// step), over a second native marker holding the still soft ring.
const vehicleRotation = (heading, mapHeading) => (((heading - mapHeading) % 360) + 360) % 360;
assert.equal(api.vehicleRotation(90, 90), 0, 'Heading-up: the arrow points up');
assert.equal(api.vehicleRotation(90, 30), 60, 'Map turned 30: the arrow turns back by 30');
assert.equal(api.vehicleRotation(10, 30), 340);
assert.equal(api.vehicleRotation(-10, 0), 350);
assert.equal(api.vehicleRotation(45, 0, 60), 45, 'No tilt term');
const markersBefore = MarkerMock.all.length;
map.moveCamera({heading: 0, tilt: 0}); // the twist test left the map turned
const marker = new maps.Marker({title:'Driver camera vehicle', position:{x:1,y:2},
  icon:{url:'vehicle.png',scaledSize:{width:44,height:44}}, visible:true, zIndex: 12});
marker.setMap(map); api.vehicle(7,90);
assert.equal(marker.getVisible(), true, 'The own vehicle is the native marker itself');
assert.equal(images.length + halos.length, 0, 'No DOM overlay for the vehicle');
const arrow = () => marker.getIcon();
assert.equal(arrow().url, undefined, 'Not the raster icon (a raster icon cannot turn)');
assert.equal(arrow().path, 'M26 8L43 42L26 32.2L9 42Z', 'The arrow path of MoveraVehicleMarker.paintArrow');
assert.equal(arrow().scale, 38 / 52, 'Drawn at the 38 pt arrow size, whatever the zoom');
assert.deepEqual([arrow().anchor.x, arrow().anchor.y], [26, 32.2], 'Anchored at the arrow base notch');
assert.equal(arrow().fillColor, '#3FB6D3'); assert.equal(arrow().strokeColor, '#FFFFFF');
assert.equal(marker.options.title, undefined, 'No tooltip on the car');
assert.equal(marker.options.clickable, false, 'No info window on the car');
assert.equal(arrow().rotation, 90, 'North-up: the compass heading itself');
map.moveCamera({heading:90});
assert.equal(arrow().rotation, 0, 'The map turning heading-up turns the arrow up on that frame');
map.moveCamera({heading:30, tilt:0}); api.vehicle(7,90);
assert.equal(arrow().rotation, 60, 'Free rotation preserves the real car course');
map.moveCamera({heading:0, tilt:60}); api.vehicle(7,45);
assert.equal(arrow().rotation, 45, 'Tilted north-up: the course itself, not leaned by the tilt');
map.moveCamera({heading:45, tilt:60});
assert.equal(arrow().rotation, 0, 'Tilted heading-up: still straight up');
api.vehicle(7, 45.004);
const symbolAt45 = arrow();
api.vehicle(7, 45.001);
assert.equal(arrow(), symbolAt45, 'A hundredth of a degree is not a new icon');
for (const zoom of [5, 11.7, 15, 18, 21]) {
  map.moveCamera({zoom, heading: 0, tilt: zoom > 15 ? 67.5 : 0}); api.vehicle(7, 0);
  assert.equal(arrow().scale, 38 / 52, `Same size at zoom ${zoom}`);
}
// The ring: a native marker under the arrow, centred on the arrow's
// base, never squashed (a marker is a billboard), following the car.
const ring = MarkerMock.all.slice(markersBefore).find(m => m !== marker);
assert.ok(ring, 'One ring marker under the vehicle');
assert.equal(MarkerMock.all.length - markersBefore, 2, 'Arrow and ring, nothing else');
assert.match(ring.getIcon().url, /^data:image\/svg\+xml/, 'The ring is one still SVG');
assert.match(decodeURIComponent(ring.getIcon().url), /7D8C99/i, 'Grey ring');
assert.match(decodeURIComponent(ring.getIcon().url), /stop-opacity="\.28"/, 'At 28 %');
assert.match(decodeURIComponent(ring.getIcon().url), /stop-opacity="0"/, 'Fading at its edge');
assert.deepEqual([ring.getIcon().scaledSize.width, ring.getIcon().scaledSize.height], [32, 32], '32 pt ring: 1.3 x the arrow');
assert.deepEqual([ring.getIcon().anchor.x, ring.getIcon().anchor.y], [16, 16], 'Anchored at its centre');
assert.equal(ring.getMap(), map, 'The ring is on the car\'s map');
assert.deepEqual(ring.getPosition(), {x:1,y:2}, 'The ring is under the car');
assert.equal(ring.getZIndex(), 11, 'Under the arrow');
assert.equal(ring.options.clickable, false);
marker.setOptions({position: {x:3,y:4}, zIndex: 20, visible: true, title: 'Driver camera vehicle',
  icon:{url:'vehicle.png',scaledSize:{width:44,height:44}}});
assert.deepEqual(ring.getPosition(), {x:3,y:4}, 'A Flutter marker update moves the ring with the car');
assert.equal(ring.getZIndex(), 19);
assert.equal(arrow().path, 'M26 8L43 42L26 32.2L9 42Z', 'The update keeps the Symbol arrow, not the raster');
assert.equal(marker.options.title, undefined);
marker.setVisible(false);
assert.equal(ring.getVisible(), false, 'Hidden car: hidden ring');
marker.setVisible(true);
assert.equal(ring.getVisible(), true);
map.moveCamera({heading:0, tilt:0, zoom: 16});
marker.setMap(null);
assert.equal(ring.getMap(), null, 'The ring leaves with the car');
// driver-r4-36: the car is first built with the default icon (no URL;
// the arrow was still being drawn) and gets its icon by setOptions. The
// Symbol arrow is there from the start and the raster never replaces it.
{
  const late = new maps.Marker({title:'Driver camera vehicle', position:{x:1,y:2}, visible:true});
  late.setMap(map);
  assert.equal(late.getIcon().path, 'M26 8L43 42L26 32.2L9 42Z', 'Default icon: the Symbol arrow already');
  late.setOptions({icon:{url:'vehicle.png',scaledSize:{width:44,height:44}}});
  api.vehicle(7, 90);
  assert.equal(late.getIcon().rotation, 90, 'Late raster ignored; the arrow turns with the heading');
  late.setMap(null);
}
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
// Tilt follows zoom live: every pinch frame on a vector map moves zoom and
// tilt together in one camera move (lib DriverCameraPolicy.tiltForZoom:
// 0 deg at zoom 12, linear to 67.5 deg at zoom 15.5, under the SDK limit).
{
  const sdkMax = z => z <= 10 ? 30 : z <= 14 ? 30 + (z - 10) / 4 * 15 :
    z < 15.5 ? 45 + (z - 14) / 1.5 * 22.5 : 67.5;
  const curve = z => Math.min(67.5 * Math.min(1, Math.max(0, (z - 12) / 3.5)), sdkMax(z));
  // The line stays under the SDK limit (no clamp) and is at full tilt
  // from zoom 15.5, guidance standstill (15) already near 58 deg.
  for (let z = 12.05; z < 15.5; z += .05) assert.ok(curve(z) < sdkMax(z), `no SDK clamp at ${z}`);
  assert.equal(curve(15.5), 67.5);
  assert.ok(Math.abs(curve(15) - 67.5 * 3 / 3.5) < 1e-9);
  // The locate view (zoom 15) gets a strong tilt from the same curve.
  assert.ok(curve(15) > 55 && curve(15) < sdkMax(15), 'Locate view: strong tilt under the SDK limit');
  const liveDiv = new Element('plugins.flutter.io/google_maps_9');
  context.document.querySelector = () => ({content: 'configured-vector-style'});
  const live = new maps.Map(liveDiv, {});
  assert.equal(api.supports3D(9), true);
  live.moveCamera({center: {x: 0, y: 0}, zoom: 11.7, heading: 0, tilt: 0});
  const trace = [];
  const pinch = (from, to, steps) => {
    clock += 400;
    liveDiv.fire('touchstart', [touch(200 - from / 2, 400), touch(200 + from / 2, 400)]);
    for (let i = 1; i <= steps; i++) {
      const span = from + (to - from) * i / steps;
      liveDiv.fire('touchmove', [touch(200 - span / 2, 400), touch(200 + span / 2, 400)]);
      trace.push([live.getZoom(), live.getTilt()]);
    }
    liveDiv.fire('touchend');
  };
  pinch(60, 960, 60); // about 1 s of 16 ms frames, zooming in 4 levels
  const zoomIn = trace.length;
  pinch(960, 60, 60); // and back out
  for (let i = 0; i < trace.length; i++) {
    const [zoom, tilt] = trace[i];
    assert.ok(Math.abs(tilt - curve(zoom)) < 1e-9,
      `Pinch frame ${i}: tilt ${tilt} follows zoom ${zoom} live`);
    if (i && i !== zoomIn) {
      const [z0, t0] = trace[i - 1];
      assert.ok(Math.sign(zoom - z0) === Math.sign(tilt - t0) ||
        (zoom <= 12 && tilt === 0) || (zoom >= 15.5 && z0 >= 15.5 && tilt === 67.5) ||
        tilt === t0 && Math.abs(zoom - z0) < 1e-9,
        `Pinch frame ${i}: tilt moves with the zoom`);
    }
  }
  assert.ok(trace[zoomIn - 1][0] > 15.5 && trace[zoomIn - 1][1] > 59,
    'Pinching in raises the horizon');
  assert.ok(trace[trace.length - 1][0] < 12 && trace[trace.length - 1][1] === 0,
    'Pinching out flattens');
  // A tilt set by hand is kept as an offset while zooming.
  live.moveCamera({zoom: 14, tilt: 40});
  clock += 400;
  liveDiv.fire('touchstart', [touch(150, 400), touch(250, 400)]);
  liveDiv.fire('touchmove', [touch(140, 400), touch(260, 400)]);
  liveDiv.fire('touchend');
  assert.ok(Math.abs(live.getTilt() - (40 + curve(live.getZoom()) - curve(14))) < 1e-9,
    'A hand-set tilt rides along with the zoom');
  // Pinch while tilted, slowly, with both fingers drifting up the screen
  // (a real thumb + finger pinch): every frame zooms by the span ratio and
  // the tilt rides with the zoom. The hand-tilt mode cannot take it over.
  live.moveCamera({zoom: 14, tilt: 60});
  clock += 400;
  let span = 200, mid = 500;
  liveDiv.fire('touchstart', [touch(200 - span / 2, mid), touch(200 + span / 2, mid)]);
  for (let i = 0; i < 40; i++) {
    const zoom0 = live.getZoom(), tilt0 = live.getTilt();
    const next = span * 1.012, nextMid = mid - 3;
    liveDiv.fire('touchmove', [touch(200 - next / 2, nextMid), touch(200 + next / 2, nextMid)]);
    assert.ok(Math.abs(live.getZoom() - (zoom0 + Math.log2(next / span))) < 1e-9,
      `Slow tilted pinch frame ${i} zooms by the finger spread`);
    assert.ok(Math.abs(live.getTilt() -
      Math.min(Math.max(tilt0 + curve(live.getZoom()) - curve(zoom0), 0), sdkMax(live.getZoom()))) < 1e-9,
      `Slow tilted pinch frame ${i}: tilt follows the zoom, not the drift`);
    span = next; mid = nextMid;
  }
  liveDiv.fire('touchend');
  assert.ok(live.getZoom() > 14.6, 'A slow pinch while tilted zooms');
  // A deliberate two-finger drag (no pinch) still tilts by hand.
  live.moveCamera({zoom: 15, tilt: 50});
  clock += 400;
  liveDiv.fire('touchstart', [touch(150, 500), touch(250, 500)]);
  liveDiv.fire('touchmove', [touch(150, 480), touch(250, 480)]);
  liveDiv.fire('touchend');
  assert.equal(live.getTilt(), 56, 'Two-finger drag up tilts by hand');
  assert.equal(live.getZoom(), 15, 'and keeps the zoom');
  // Waiting at a stop: the map stays flat while the driver zooms.
  api.tiltFollowsZoom(9, false);
  live.moveCamera({zoom: 14, tilt: 0});
  clock += 400;
  liveDiv.fire('touchstart', [touch(150, 400), touch(250, 400)]);
  liveDiv.fire('touchmove', [touch(120, 400), touch(280, 400)]);
  liveDiv.fire('touchend');
  assert.ok(live.getZoom() > 14.3 && live.getTilt() === 0, 'Waiting map zooms flat');
  api.tiltFollowsZoom(9, true);
  // Wheel / trackpad zoom glides with the tilt bound to the zoom.
  let wheelGestures = 0;
  const removeWheel = api.listen(9, () => wheelGestures++);
  live.moveCamera({zoom: 12, tilt: 0});
  const wheel = liveDiv.fire('wheel', [], {deltaY: -300, deltaMode: 0, clientX: 200, clientY: 400});
  assert.equal(wheel.defaultPrevented, true, 'Vector wheel zoom is ours');
  assert.equal(wheel.propagationStopped, true);
  assert.equal(wheelGestures, 1, 'Wheel releases follow');
  let lastZoom = live.getZoom(), lastTilt = live.getTilt(), glideFrames = 0;
  while (frames.length && glideFrames < 200) {
    frames.shift()(); glideFrames++;
    assert.ok(live.getZoom() >= lastZoom && live.getTilt() >= lastTilt,
      'Wheel glide zooms in and tilts up together');
    assert.ok(Math.abs(live.getTilt() - curve(live.getZoom())) < 1e-9,
      'Wheel glide frame keeps tilt on the zoom curve');
    lastZoom = live.getZoom(); lastTilt = live.getTilt();
  }
  assert.ok(glideFrames > 3, 'Wheel zoom glides over several frames');
  assert.ok(Math.abs(live.getZoom() - 13) < 1e-9, 'Wheel reaches its goal (at most 1 level per event)');
  // Someone else moving the camera (recenter) ends the glide.
  liveDiv.fire('wheel', [], {deltaY: 150, deltaMode: 0, clientX: 200, clientY: 400});
  flushFrames(1);
  live.moveCamera({zoom: 17, tilt: 67.5});
  flushFrames();
  assert.equal(live.getZoom(), 17, 'A wheel glide never fights a camera move');
  removeWheel();
  const rasterWheel = rasterDiv.fire('wheel', [], {deltaY: -300, deltaMode: 0});
  assert.equal(rasterWheel.defaultPrevented, false, 'Raster keeps Google wheel zoom');
  assert.equal(frames.length, 0);
}
map.moveCamera({center: {x:0,y:400}, zoom: 16, heading: 12, tilt: 30});
api.claim(7);
map.panTo({x:0,y:400});
queueMicrotask(() => {
  assert.equal(map.camera.center.y, 224, 'Claimed follow pan anchors before paint');
  assert.equal(map.getZoom(), 16);
  assert.equal(map.getHeading(), 12);
  assert.equal(map.getTilt(), 30);
  // Flat north-up map driving south (lead 180): the road ahead is below
  // the car, so the car sits above the free middle (100 + 500 / 2 = 350).
  rasterDiv.clientWidth = 400;
  api.configure(8, 100, 200, .75);
  raster.moveCamera({center: {x: 0, y: 400}, heading: 0});
  api.claim(8, true, 180);
  raster.panTo({x: 0, y: 400});
  queueMicrotask(() => {
    // Car (y 400) drawn at 124 px, above the free middle at 350 px.
    assert.equal(raster.camera.center.y, 676, 'Lead south: car above the middle');
    // Driving east (lead 90): the car moves left of the middle instead.
    raster.moveCamera({center: {x: 0, y: 400}});
    api.claim(8, true, 90);
    raster.panTo({x: 0, y: 400});
    queueMicrotask(() => {
      assert.ok(raster.camera.center.x > 0, 'Lead east: road ahead to the right');
      assert.equal(raster.camera.center.y, 450, 'Lead east: car on the free middle row');
      // A preview frame is exact: no anchor shift.
      raster.moveCamera({center: {x: 5, y: 5}});
      api.claim(8, false);
      raster.panTo({x: 0, y: 400});
      queueMicrotask(() => {
        assert.deepEqual(raster.camera.center, {x: 0, y: 400}, 'Preview frame not shifted');
        let panned = null;
        raster.panBy = (x, y) => { panned = {x, y}; };
        api.configure(8, 100, 300, .75);
        assert.equal(panned, null, 'Insets after a preview do not move the map');
        api.claim(8, true, 0);
        raster.panTo({x: 0, y: 400});
        queueMicrotask(() => {
          api.configure(8, 100, 400, .75);
          assert.ok(panned && panned.y > 0, 'A raised sheet glides the followed car up');
          console.log('PASS: vector palette, tap-safe release, gesture lock, drag, pan, pinch/twist, tilt, live tilt-with-zoom, wheel glide, taps, anchor, look-ahead, sheet glide, native vehicle marker with ring and locate view');
        });
      });
    });
  });
});

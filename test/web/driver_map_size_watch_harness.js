// Runs web/driver_map_camera.js against a fake Google map that measures its
// element the way Maps JS 3.66 does (map.js): only when the hidden <iframe>
// it keeps in .gm-style fires 'load', or that frame's window fires
// 'resize'. The browser here never delivers those events after the first
// load (what leaves a grey band under the map on an iPhone), so only the
// driver layer's size watch can make Google measure again. Prints, as JSON,
// the sizes Google measured and the camera calls made along the way.
// Same fake as the rider's test/web/rider_map_size_watch_harness.js.
//
// node driver_map_size_watch_harness.js <driver_map_camera.js>
'use strict';
const fs = require('fs');
const vm = require('vm');

const [layerPath] = process.argv.slice(2);
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

class LatLng {
  constructor(lat, lng) { this._lat = lat; this._lng = lng; }
  lat() { return this._lat; }
  lng() { return this._lng; }
}
const handlers = new WeakMap();
const on = (target, name) => {
  let byName = handlers.get(target);
  if (!byName) handlers.set(target, byName = {});
  return (byName[name] ||= []);
};
const event = {
  addListener(target, name, fn) { on(target, name).push(fn); return {remove() {}}; },
  trigger(target, name, ...args) { [...on(target, name)].forEach(fn => fn(...args)); },
  clearInstanceListeners(target) { handlers.delete(target); },
};

// The ResizeObservers the layer makes; the test reports sizes through them.
const observers = [];
class FakeResizeObserver {
  constructor(callback) {
    this.callback = callback; this.targets = new Set(); this.disconnected = false;
    observers.push(this);
  }
  observe(target) { this.targets.add(target); }
  unobserve(target) { this.targets.delete(target); }
  disconnect() { this.disconnected = true; this.targets.clear(); }
}
const report = (container, width, height) => {
  for (const observer of observers) {
    if (!observer.targets.has(container)) continue;
    observer.callback([{target: container, contentRect: {width, height}}], observer);
  }
};
// The MutationObserver on document.body: the layer's dispose watch.
const mutationObservers = new Set();
class FakeMutationObserver {
  constructor(callback) { this.callback = callback; }
  observe() { mutationObservers.add(this); }
  disconnect() { mutationObservers.delete(this); }
}

const camera = {moves: 0, pans: 0, centers: 0, zooms: 0};
const measured = [];
class FakeMap {
  constructor(div, options = {}) {
    this.div = div; this.options = options; this.zoom = options.zoom ?? 15;
    this.heading = 0; this.tilt = 0;
    this.center = new LatLng(options.center?.lat ?? 0, options.center?.lng ?? 0);
    // Google's size frame: 'load' measures and starts listening to the
    // frame window's 'resize'; both read the element's current size.
    const frame = new EventTarget();
    frame.tagName = 'IFRAME';
    frame.getAttribute = name => (name === 'aria-hidden' ? 'true' : null);
    frame.contentWindow = new EventTarget();
    this.size = null;
    const measure = () => {
      const size = [div.clientWidth, div.clientHeight];
      measured.push(size[1]);
      this.size = size;
    };
    frame.addEventListener('load', () => {
      measure();
      frame.contentWindow.addEventListener('resize', measure);
    });
    this.frame = frame;
    const gm = {className: 'gm-style', children: [{tagName: 'DIV'}, frame]};
    div.querySelector = selector => (selector === '.gm-style' ? gm : null);
    // The browser loads the frame once, when the map is first shown.
    setTimeout(() => frame.dispatchEvent(new Event('load')), 1);
  }
  addListener(name, fn) { return event.addListener(this, name, fn); }
  setOptions(options) { this.options = {...this.options, ...options}; }
  setCenter(c) {
    camera.centers += 1;
    this.center = typeof c.lat === 'function'
      ? new LatLng(c.lat(), c.lng()) : new LatLng(c.lat, c.lng);
  }
  setZoom(z) { camera.zooms += 1; this.zoom = z; }
  setHeading(h) { this.heading = h; }
  setTilt(t) { this.tilt = t; }
  getCenter() { return this.center; }
  getZoom() { return this.zoom; }
  getHeading() { return this.heading; }
  getTilt() { return this.tilt; }
  getRenderingType() { return this.options.renderingType; }
  moveCamera(c) {
    camera.moves += 1;
    if (c.center) {
      this.center = typeof c.center.lat === 'function'
        ? new LatLng(c.center.lat(), c.center.lng()) : new LatLng(c.center.lat, c.center.lng);
    }
    if (c.zoom != null) this.zoom = c.zoom;
  }
  panTo(latLng) { camera.pans += 1; this.center = latLng; }
  panBy() { camera.pans += 1; }
}
class OverlayView { setMap() {} getProjection() { return null; } }
const element = id => ({
  id, style: {}, isConnected: true, clientWidth: 390, clientHeight: 555, children: [],
  addEventListener() {}, appendChild() {}, remove() {}, setAttribute() {},
  getBoundingClientRect: () => ({left: 0, top: 0}),
  querySelectorAll: () => [], replaceChildren() {},
});
const context = {
  google: {maps: {Map: FakeMap, OverlayView, Marker: class {}, Circle: class {},
    Point: class {}, Size: class {}, event,
    RenderingType: {VECTOR: 'VECTOR', RASTER: 'RASTER'}}},
  requestAnimationFrame: cb => setTimeout(() => cb(Date.now()), 16),
  cancelAnimationFrame: id => clearTimeout(id),
  performance: {now: () => Date.now()},
  MutationObserver: FakeMutationObserver,
  ResizeObserver: FakeResizeObserver,
  HTMLCanvasElement: class {},
  Event, EventTarget, queueMicrotask,
  document: {body: {}, querySelector: () => ({content: 'configured-vector-style'})},
  console,
  setTimeout, clearTimeout, setInterval, clearInterval,
};
context.globalThis = context;
vm.createContext(context);
vm.runInContext(fs.readFileSync(layerPath, 'utf8'), context);
const GMap = context.google.maps.Map;

(async () => {
  const out = {};
  const div = element('plugins.flutter.io/google_maps_3');
  const map = new GMap(div, {center: {lat: 59.33, lng: 18.06}, zoom: 15});
  await sleep(30);
  out.watched = observers.some(o => o.targets.has(div) && !o.disconnected);
  report(div, 390, 555); // the first observation, at the size Google has
  await sleep(40);
  out.firstSize = map.size && map.size[1];
  const cameraBefore = {...camera};
  const centerBefore = [map.getCenter().lat(), map.getCenter().lng(), map.getZoom()];
  const countBefore = measured.length;

  // The element grows (a driver screen whose sheet shrinks, or a box under
  // a collapsing Safari toolbar); the browser sends no frame event.
  div.clientHeight = 844;
  report(div, 390, 700);
  report(div, 390, 790);
  report(div, 390, 844); // three reports in one frame
  out.measuredSync = measured.length - countBefore; // nothing before the frame
  await sleep(40);
  out.grownSize = map.size && map.size[1];
  out.measuresForGrow = measured.length - countBefore;

  // Laid out at 0 x 0 for a moment (off stage): not a size to draw.
  const beforeHidden = measured.length;
  div.clientHeight = 0;
  report(div, 0, 0);
  await sleep(40);
  out.measuresWhenHidden = measured.length - beforeHidden;

  // Shown again with a new frame window whose 'load' the browser never
  // delivered: Google has no 'resize' listener on it yet.
  map.frame.contentWindow = new EventTarget();
  div.clientHeight = 621;
  report(div, 390, 621);
  await sleep(40);
  out.newWindowSize = map.size && map.size[1];

  out.cameraCalls = {moves: camera.moves - cameraBefore.moves,
    pans: camera.pans - cameraBefore.pans,
    centers: camera.centers - cameraBefore.centers, zooms: camera.zooms - cameraBefore.zooms};
  out.cameraKept = [map.getCenter().lat(), map.getCenter().lng(), map.getZoom()]
    .every((v, i) => v === centerBefore[i]);

  // Dispose: Flutter takes the map's <div> out of the page.
  div.isConnected = false;
  for (const observer of [...mutationObservers]) observer.callback([]);
  await sleep(400);
  out.disposedWatchDisconnected = observers.length > 0 &&
    observers.every(o => o.disconnected && !o.targets.has(div));
  process.stdout.write(JSON.stringify(out));
  process.exit(0);
})();

// Q3 (owner 2026-11-07, "Free each map, no reuse"): opens and closes the
// driver's web map [cycles] times in a fake page and prints, as JSON, what
// is still held afterwards: WebGL contexts not given back, map <div>s that
// still hold Google's DOM, and the Map objects whose listeners were cleared.
//
// node driver_map_release_harness.js <driver_map_camera.js> [cycles]
'use strict';
const fs = require('fs');
const vm = require('vm');

const [cameraPath, cyclesArg] = process.argv.slice(2);
const cycles = Number(cyclesArg || 6);

class Element {
  constructor(id = '') {
    this.id = id; this.style = {}; this.children = []; this.isConnected = true;
    this.clientHeight = 800; this.clientWidth = 400;
  }
  addEventListener() {}
  setAttribute(name, value) { (this.attributes ||= {})[name] = value; }
  getBoundingClientRect() { return {left: 0, top: 0}; }
  appendChild(child) { this.children.push(child); return child; }
  replaceChildren(...next) { this.children = next; }
  remove() {}
  querySelectorAll(selector) {
    const found = [];
    const walk = node => {
      for (const child of node.children || []) {
        if (selector === 'canvas' && child instanceof HTMLCanvasElement) found.push(child);
        walk(child);
      }
    };
    walk(this);
    return found;
  }
}
const contexts = [];
class HTMLCanvasElement extends Element {
  constructor() { super(); this.width = 300; this.height = 150; this.gl = {}; }
}
HTMLCanvasElement.prototype.getContext = function (kind) {
  const canvas = this;
  if (this.gl[kind]) return this.gl[kind];
  const gl = {kind, lost: false,
    isContextLost() { return this.lost; },
    getExtension(name) {
      return name === 'WEBGL_lose_context' ? {loseContext: () => {
        gl.lost = true;
        gl.markedReleased = 'data-movera-released' in (canvas.attributes || {});
      }} : null;
    }};
  this.gl[kind] = gl;
  contexts.push(gl);
  return gl;
};

let cleared = 0;
class MapMock {
  constructor(div, options) {
    this.div = div; this.options = options;
    // Google draws a vector map on a WebGL canvas inside the map's <div>.
    const inner = div.appendChild(new Element());
    const canvas = inner.appendChild(new HTMLCanvasElement());
    canvas.getContext('webgl2');
  }
  addListener() { return {remove() {}}; }
  setOptions(options) { this.options = {...this.options, ...options}; }
  getRenderingType() { return this.options.renderingType; }
  moveCamera() {}
}
class OverlayMock { setMap(map) { this.map = map; } }
const maps = {Map: MapMock, OverlayView: OverlayMock, Marker: class {}, Circle: class {},
  Point: class {}, Size: class {},
  RenderingType: {VECTOR: 'VECTOR', RASTER: 'RASTER'},
  event: {clearInstanceListeners: () => { cleared += 1; }}};
const observers = new Set();
const context = {
  google: {maps}, HTMLCanvasElement, queueMicrotask, setTimeout, clearTimeout,
  performance: {now: () => 0},
  document: {querySelector: () => ({content: 'configured-vector-style'}), body: new Element(),
    createElement: () => new Element()},
  MutationObserver: class {
    constructor(callback) { this.callback = callback; }
    observe() { observers.add(this); }
    disconnect() { observers.delete(this); }
  },
};
context.globalThis = context;
vm.runInNewContext(fs.readFileSync(cameraPath, 'utf8'), context);

const divs = [];
(async () => {
  for (let i = 0; i < cycles; i++) {
    // A screen with a map opens...
    const div = new Element(`plugins.flutter.io/google_maps_${i}`);
    divs.push(div);
    new maps.Map(div, {});
    // ...and closes: Flutter takes the map's <div> out of the page.
    div.isConnected = false;
    for (const observer of [...observers]) observer.callback([]);
    await new Promise(resolve => setTimeout(resolve, 20));
  }
  // Let any delayed release run.
  await new Promise(resolve => setTimeout(resolve, 600));
  process.stdout.write(JSON.stringify({
    cycles,
    contexts: contexts.length,
    liveContexts: contexts.filter(gl => !gl.lost).length,
    // Marked before loseContext, so the restart watch skips that event.
    releasedUnmarked: contexts.filter(gl => gl.lost && !gl.markedReleased).length,
    divsWithMapDom: divs.filter(div => div.children.length > 0).length,
    listenersCleared: cleared,
    jsStatesLeft: divs.filter((_, i) => context.driverMapCamera.supports3D(i)).length,
  }));
})();

// G4 decision 1 + E6 (contract v0.18.6 driverOffers.push): checks
// web/firebase-messaging-sw.js against a fake service-worker scope. Run by
// test/g4/g4_offer_push_web_test.dart (node), not a replacement for a real
// phone test.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '..', 'web', 'firebase-messaging-sw.js'), 'utf8');
const contract = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'contracts', 'contract.json'), 'utf8'));

function scope({ visible = false, prefs = null } = {}) {
  const shown = [];
  const handlers = {};
  const cacheStore = new Map();
  if (prefs) cacheStore.set('https://app.test/live/movera-push-prefs.json', JSON.stringify(prefs));
  const self = {
    registration: {
      scope: 'https://app.test/live/firebase-cloud-messaging-push-scope',
      showNotification: (title, options) => { shown.push({ title, options }); return Promise.resolve(); },
      getNotifications: () => Promise.resolve([]),
    },
    clients: {
      matchAll: () => Promise.resolve(visible ? [{ url: 'https://app.test/live/#/', visibilityState: 'visible' }] : [{ url: 'https://app.test/live/#/', visibilityState: 'hidden' }]),
      claim: () => Promise.resolve(),
    },
    addEventListener: (name, fn) => { handlers[name] = fn; },
    skipWaiting: () => {},
    caches: true,
  };
  const caches = {
    open: () => Promise.resolve({ match: (url) => Promise.resolve(cacheStore.has(url) ? { json: () => Promise.resolve(JSON.parse(cacheStore.get(url))) } : undefined) }),
  };
  const context = vm.createContext({ self, caches, URL, Date, Promise, setTimeout, console });
  vm.runInContext(source, context);
  return {
    shown,
    async push(data) {
      let done;
      handlers.push({ data: { json: () => ({ data }) }, waitUntil: (p) => { done = p; } });
      await done;
    },
  };
}

function offer(kind, extra = {}) {
  const loud = contract.driverOffers.push.sound[kind] === 'offer';
  return {
    notificationId: 'ntf_1', kind: 'new_offer', deepLink: 'movera-driver://offers/off_1', offerId: 'off_1', tripId: 'trp_1',
    offerKind: kind, sound: contract.driverOffers.push.sound[kind], vibrate: contract.driverOffers.push.vibrate[kind] ? 'true' : 'false',
    expiresAt: new Date(Date.now() + 120000).toISOString(), title: loud ? 'New trip for you' : 'New trip nearby', body: 'Tap to see the trip', ...extra,
  };
}

(async () => {
  // Exclusive, app closed, Vibrate on: sound + the contract's pattern.
  let sw = scope({ prefs: { vibrate: true } });
  await sw.push(offer('exclusive'));
  assert.equal(sw.shown.length, 1);
  assert.equal(sw.shown[0].options.silent, false);
  assert.deepEqual([...sw.shown[0].options.vibrate], contract.driverOffers.push.native.webVibratePattern);
  assert.equal(sw.shown[0].options.data.deepLink, 'movera-driver://offers/off_1');
  assert.equal(sw.shown[0].title, 'New trip for you');

  // Hand-sent (assigned) rings like Exclusive.
  sw = scope({ prefs: { vibrate: true } });
  await sw.push(offer('assigned'));
  assert.equal(sw.shown[0].options.silent, false);
  assert.ok(sw.shown[0].options.vibrate);

  // Exclusive with the driver's Vibrate setting off: sound, no vibration.
  sw = scope({ prefs: { vibrate: false } });
  await sw.push(offer('exclusive'));
  assert.equal(sw.shown[0].options.silent, false);
  assert.equal(sw.shown[0].options.vibrate, undefined);

  // No setting saved yet: the default is on (owner 2026-10-31).
  sw = scope();
  await sw.push(offer('exclusive'));
  assert.ok(sw.shown[0].options.vibrate);

  // Radar: quiet.
  sw = scope({ prefs: { vibrate: true } });
  await sw.push(offer('radar'));
  assert.equal(sw.shown[0].options.silent, true);
  assert.equal(sw.shown[0].options.vibrate, undefined);

  // App on screen: nothing (the offer stream shows it).
  sw = scope({ visible: true, prefs: { vibrate: true } });
  await sw.push(offer('exclusive'));
  assert.equal(sw.shown.length, 0);

  // Run out: nothing.
  sw = scope({ prefs: { vibrate: true } });
  await sw.push(offer('exclusive', { expiresAt: new Date(Date.now() - 1000).toISOString() }));
  assert.equal(sw.shown.length, 0);

  // Any other push is shown as before.
  sw = scope({ visible: true });
  await sw.push({ notificationId: 'ntf_2', kind: 'document_expiring', deepLink: 'movera-driver://documents', title: 'T', body: 'B' });
  assert.equal(sw.shown.length, 1);
  assert.equal(sw.shown[0].options.tag, 'ntf_2');

  console.log('offer push service worker: ok');
})().catch((error) => { console.error(error); process.exit(1); });

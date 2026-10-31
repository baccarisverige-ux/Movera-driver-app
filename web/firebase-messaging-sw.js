// Contract v0.18.3 (owner decision R7): the push service worker of the web
// build. The server sends web pushes as FCM data messages
// ({ notificationId, kind, deepLink, title, body }, already in the driver's
// language), so this worker needs no Firebase settings and no key: it shows
// the notice and, on a tap, opens the app on it.
//
// Contract v0.18.6 (driver group 4, decision 1 + E6, driverOffers.push): a
// new offer (kind "new_offer", data offerId, tripId, offerKind, sound,
// vibrate, expiresAt) is shown only while the app is not on screen (the
// open app already shows the offer) and never after expiresAt. Exclusive
// and hand-sent offers (sound "offer") make the phone's notification sound
// and vibrate [300, 150, 300] (webVibratePattern) when vibrate is "true" and
// the driver's own Vibrate setting is on; Radar (sound "none") is silent.
'use strict';

var OFFER_KIND = 'new_offer';
var VIBRATE_PATTERN = [300, 150, 300];
var PREFS_CACHE = 'movera-push-prefs';
var PREFS = 'movera-push-prefs.json';

self.addEventListener('install', function () { self.skipWaiting(); });
self.addEventListener('activate', function (event) { event.waitUntil(self.clients.claim()); });

function appRoot() {
  // The worker's scope is <app>/firebase-cloud-messaging-push-scope.
  return new URL('./', self.registration.scope).href;
}

// The driver's own settings the app left here (movera_push.js setOfferPrefs).
function offerPrefs() {
  if (!self.caches) return Promise.resolve({});
  return caches.open(PREFS_CACHE)
    .then(function (cache) { return cache.match(new URL(PREFS, appRoot()).href); })
    .then(function (res) { return res ? res.json() : {}; })
    .catch(function () { return {}; });
}

// True while a window of the app is on screen.
function appOnScreen() {
  var root = appRoot();
  return self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (list) {
    return list.some(function (client) {
      return client.url.indexOf(root) === 0 && client.visibilityState === 'visible';
    });
  }).catch(function () { return false; });
}

function showOffer(d, title, body) {
  var expires = Date.parse(d.expiresAt || '');
  if (!isNaN(expires) && expires <= Date.now()) return Promise.resolve();
  return Promise.all([appOnScreen(), offerPrefs()]).then(function (both) {
    if (both[0]) return undefined;
    var loud = d.sound === 'offer';
    var options = {
      body: body,
      tag: 'movera-offer-' + (d.offerId || d.notificationId || ''),
      renotify: true,
      silent: !loud,
      icon: appRoot() + 'icons/Icon-192.png',
      data: { notificationId: d.notificationId || '', deepLink: d.deepLink || '', kind: d.kind || '', offerId: d.offerId || '' }
    };
    if (loud && d.vibrate === 'true' && both[1].vibrate === true) options.vibrate = VIBRATE_PATTERN;
    return self.registration.showNotification(title, options).then(function () {
      return closeWhenGone(options.tag, expires);
    });
  });
}

// The offer's notice goes away when the offer runs out (best effort: only
// while the browser keeps the worker awake, at most a minute).
function closeWhenGone(tag, expires) {
  var wait = expires - Date.now();
  if (isNaN(wait) || wait <= 0 || wait > 60000) return undefined;
  return new Promise(function (resolve) { setTimeout(resolve, wait); }).then(function () {
    return self.registration.getNotifications({ tag: tag });
  }).then(function (list) {
    (list || []).forEach(function (n) { n.close(); });
  }).catch(function () {});
}

self.addEventListener('push', function (event) {
  var payload = {};
  try { payload = event.data ? event.data.json() : {}; } catch (e) { payload = {}; }
  var d = payload.data || payload;
  var title = d.title || (payload.notification && payload.notification.title) || 'Movera';
  var body = d.body || (payload.notification && payload.notification.body) || '';
  if (d.kind === OFFER_KIND) {
    event.waitUntil(showOffer(d, title, body));
    return;
  }
  event.waitUntil(self.registration.showNotification(title, {
    body: body,
    tag: d.notificationId || undefined,
    icon: appRoot() + 'icons/Icon-192.png',
    data: { notificationId: d.notificationId || '', deepLink: d.deepLink || '', kind: d.kind || '' }
  }));
});

self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  var d = event.notification.data || {};
  var root = appRoot();
  event.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (list) {
    for (var i = 0; i < list.length; i++) {
      var client = list[i];
      if (client.url.indexOf(root) === 0 && 'focus' in client) {
        client.postMessage({ type: 'movera-push-open', notificationId: d.notificationId, deepLink: d.deepLink });
        return client.focus();
      }
    }
    var url = root + '?movera_push=' + encodeURIComponent(d.notificationId || '') +
      '&movera_link=' + encodeURIComponent(d.deepLink || '');
    return self.clients.openWindow(url);
  }));
});

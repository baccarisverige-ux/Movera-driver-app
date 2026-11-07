// Contract v0.18.3 (owner decision R7): the push service worker of the web
// build. The server sends web pushes as FCM data messages
// ({ notificationId, kind, deepLink, title, body }, already in the driver's
// language), so this worker needs no Firebase settings and no key: it shows
// the notice and, on a tap, opens the app on it.
//
// Contract v0.18.6 (driver group 4, decision 1 + E6, driverOffers.push): a
// new offer (kind "new_offer", data offerId, tripId, offerKind, sound,
// vibrate, expiresAt) is shown as a notice. Exclusive and hand-sent offers
// (sound "offer") make the phone's notification sound and vibrate
// [300, 150, 300] (webVibratePattern) when vibrate is "true" and the
// driver's own Vibrate setting is on (the default); Radar (sound "none") is silent.
//
// Q1 (owner 2026-11-07, "Toujours afficher"): EVERY push shows a notice,
// also while the app is on screen and after the offer's expiresAt. iOS
// WebKit counts a push that shows no notice as "silent" and removes the push
// subscription after 3 of them (WebPushDaemonConstants.h maxSilentPushCount
// = 3), after which a locked phone hears no more offers. A run-out offer is
// shown quiet with its own text and closed at once (owner 2026-11-07: it
// counts as shown, no "New trip for you" is left); every offer notice uses the tag
// movera-offer-<offerId> with renotify, so a later push of the same offer
// replaces the earlier notice instead of adding one.
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

function showOffer(d, title, body) {
  var expires = Date.parse(d.expiresAt || '');
  var runOut = !isNaN(expires) && expires <= Date.now();
  return offerPrefs().then(function (prefs) {
    var loud = d.sound === 'offer' && !runOut;
    var options = {
      body: body,
      tag: 'movera-offer-' + (d.offerId || d.notificationId || ''),
      renotify: true,
      silent: !loud,
      icon: appRoot() + 'icons/Icon-192.png',
      data: { notificationId: d.notificationId || '', deepLink: d.deepLink || '', kind: d.kind || '', offerId: d.offerId || '' }
    };
    // The Vibrate setting is on unless the driver turned it off (owner 2026-10-31).
    if (loud && d.vibrate === 'true' && prefs.vibrate !== false) options.vibrate = VIBRATE_PATTERN;
    return self.registration.showNotification(title, options).then(function () {
      return runOut ? closeNow(options.tag) : closeWhenGone(options.tag, expires);
    });
  });
}

// A run-out offer's notice is closed right after it was shown.
function closeNow(tag) {
  return self.registration.getNotifications({ tag: tag }).then(function (list) {
    (list || []).forEach(function (n) { n.close(); });
  }).catch(function () {});
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
  // One notice per trip (Ride Check, trip messages…): the tag comes from
  // data.tripId first, then rideId, its legacy alias (contract
  // wire.ids.trip), so a newer push for the same trip replaces the older
  // one and alerts again. Without a trip, the notice's own id.
  var trip = d.tripId || d.rideId;
  var options = {
    body: body,
    tag: trip ? 'movera-ride-' + trip : (d.notificationId || undefined),
    icon: appRoot() + 'icons/Icon-192.png',
    data: { notificationId: d.notificationId || '', deepLink: d.deepLink || '', kind: d.kind || '' }
  };
  if (trip) options.renotify = true;
  event.waitUntil(self.registration.showNotification(title, options));
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

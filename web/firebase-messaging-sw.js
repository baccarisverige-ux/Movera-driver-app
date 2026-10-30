// Contract v0.18.3 (owner decision R7): the push service worker of the web
// build. The server sends web pushes as FCM data messages
// ({ notificationId, kind, deepLink, title, body }, already in the driver's
// language), so this worker needs no Firebase settings and no key: it shows
// the notice and, on a tap, opens the app on it.
'use strict';

self.addEventListener('install', function () { self.skipWaiting(); });
self.addEventListener('activate', function (event) { event.waitUntil(self.clients.claim()); });

function appRoot() {
  // The worker's scope is <app>/firebase-cloud-messaging-push-scope.
  return new URL('./', self.registration.scope).href;
}

self.addEventListener('push', function (event) {
  var payload = {};
  try { payload = event.data ? event.data.json() : {}; } catch (e) { payload = {}; }
  var d = payload.data || payload;
  var title = d.title || (payload.notification && payload.notification.title) || 'Movera';
  var body = d.body || (payload.notification && payload.notification.body) || '';
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

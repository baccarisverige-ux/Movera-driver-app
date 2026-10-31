// Contract v0.18.3 (owner decision R7): push to a closed phone through
// Firebase Cloud Messaging, for the web build. No key lives here: the app
// passes the public Firebase web settings it read from the server
// (GET /push/config) at run time. The Firebase SDK is loaded only then.
(function () {
  'use strict';
  var SDK = 'https://www.gstatic.com/firebasejs/10.14.1/';
  var SCOPE = './firebase-cloud-messaging-push-scope';
  var PREFS_CACHE = 'movera-push-prefs';
  var PREFS = 'movera-push-prefs.json';
  var handler = null;
  var waiting = [];

  function load(src) {
    return new Promise(function (resolve, reject) {
      if (document.querySelector('script[data-movera-push="' + src + '"]')) return resolve();
      var s = document.createElement('script');
      s.src = src;
      s.async = true;
      s.setAttribute('data-movera-push', src);
      s.onload = function () { resolve(); };
      s.onerror = function () { reject(new Error('could not load ' + src)); };
      document.head.appendChild(s);
    });
  }

  function deliver(id, link) {
    if (!id) return;
    if (handler) handler(String(id), String(link || ''));
    else waiting.push([id, link]);
  }

  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.addEventListener('message', function (event) {
      var d = event.data || {};
      if (d.type === 'movera-push-open') deliver(d.notificationId, d.deepLink);
    });
  }

  window.moveraPush = {
    supported: function () {
      return 'serviceWorker' in navigator && 'Notification' in window && 'PushManager' in window;
    },
    permission: function () {
      return 'Notification' in window ? Notification.permission : 'denied';
    },
    requestPermission: function () {
      return Promise.resolve(Notification.requestPermission());
    },
    getToken: function (configJson, serviceWorker) {
      var config = JSON.parse(configJson);
      return load(SDK + 'firebase-app-compat.js')
        .then(function () { return load(SDK + 'firebase-messaging-compat.js'); })
        .then(function () { return navigator.serviceWorker.register(serviceWorker, { scope: SCOPE }); })
        .then(function (registration) {
          var app = firebase.apps.filter(function (a) { return a.name === 'movera-push'; })[0] ||
            firebase.initializeApp(config, 'movera-push');
          return app.messaging().getToken({ serviceWorkerRegistration: registration });
        })
        .then(function (token) { return token || null; });
    },
    // G4-E6 (contract v0.18.6 driverOffers.push): the driver's own Vibrate
    // setting, kept where the service worker reads it when an offer push
    // comes (the app may be closed then). Same file name in the worker.
    setOfferPrefs: function (json) {
      if (!('caches' in window)) return Promise.resolve();
      var url = new URL(PREFS, document.baseURI).href;
      return caches.open(PREFS_CACHE).then(function (cache) {
        return cache.put(url, new Response(json, { headers: { 'content-type': 'application/json' } }));
      }).catch(function () {});
    },
    setOpenHandler: function (fn) {
      handler = fn;
      var queued = waiting;
      waiting = [];
      queued.forEach(function (q) { deliver(q[0], q[1]); });
    }
  };
})();

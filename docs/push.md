# Push notifications (contract v0.18.3, owner decision R7)

What is live: the **web build**. After sign-in the app explains why (sv / fr / en), the browser asks once, and the
FCM token goes to `POST /push/devices`; it is registered again when it changes and unregistered on sign-out. A tap on
a push opens the bell list on that notice, which follows its `deepLink`.

No Firebase key is in this repository. The app reads the public Firebase web settings from the server
(`GET /push/config?app=driver`) at run time; `web/movera_push.js` loads the Firebase JS SDK from gstatic only then.
`web/firebase-messaging-sw.js` shows the server's data messages (title and body already in the driver's language)
and needs no settings at all.

Android (BQ-V43, contract v0.18.105): `firebase_core` + `firebase_messaging` and `NativePushPlatform`
(`lib/core/push/native_push_platform.dart`, Firebase behind the `NativePushGateway` seam). After sign-in the app reads
`GET /push/config?app=driver&platform=android`; the server gives the Android Firebase app's public settings
(`androidConfig`, read from the Firebase project by the package name `se.movera.driver`), and Firebase is started with
them at run time. So there is **no `google-services.json`, no Google services Gradle plugin and no key** in this
repository or in CI. Without `androidConfig` (server without Firebase, or no Android app in the project) push stays off,
the log says `push off: the server has no android push settings`, and nothing is asked. Android 13+ asks for
`POST_NOTIFICATIONS` after the explanation (already in the manifest). The token is registered with platform `android`
and again when FCM changes it. `MainActivity.kt` makes the offer channels `movera_offers` (sound
`res/raw/movera_offer.mp3`, vibration, high importance) and `movera_offers_quiet` (Radar: no sound, no vibration),
named in sv / fr / en (`res/values*/strings.xml`). Gap: the in-app Vibrate setting cannot change a system notice; the
channel decides (the driver can change it in Android settings).

iOS: push is off (`UnsupportedPushPlatform`). It needs the Apple Developer account, an APNs auth key (.p8) uploaded to
Firebase (Project settings › Cloud Messaging), the Push Notifications and Background Modes (remote notifications)
capabilities, `movera_offer.caf`, and an iOS deployment target of at least 15 for the Firebase SDK (today 12.0). The
server answers `platform=ios` with `enabled: false` until then.

## New-offer push (contract v0.18.6, driver group 4 decision 1 + E6)

- The server sends a push for every new offer (`kind: new_offer`, data `offerId, tripId, offerKind, sound, vibrate,
  expiresAt`). It is not a bell notice: a tap opens Home (`lib/core/push/offer_push.dart`), where the offer card shows
  while it is still open; a driver on a trip keeps his screen.
- Web: `firebase-messaging-sw.js` shows a notice for EVERY push (Q1, owner 2026-11-07), also while the app is on
  screen and after `expiresAt` (then quiet, with its own text, and closed at once). iOS WebKit removes the push subscription after 3
  pushes that show no notice (`maxSilentPushCount = 3`). Offer notices use the tag `movera-offer-<offerId>` with
  `renotify`, so a repeat replaces the earlier one. Other trip pushes (Ride Check, trip messages) use the tag
  `movera-ride-<tripId>` (then the legacy `rideId`), one notice per trip.
  Exclusive and hand-sent (`sound: offer`) use the phone's notification sound and vibrate `[300, 150, 300]` when
  `vibrate` is `"true"` AND the driver's own Vibrate setting (Settings › Accessibility) is on; the app keeps that
  setting in the Cache Storage entry `movera-push-prefs.json` (`moveraPush.setOfferPrefs`). Radar is silent.
  `node tool/verify_offer_push_sw.cjs` checks the worker (run by `test/g4/g4_offers_test.dart`).
- In the open app, an Exclusive or hand-sent offer on Home plays the Movera offer sound (`assets/sounds/radar_offer.mp3`)
  until a tap, and vibrates once when the Vibrate setting is on; Radar offers are quiet.
- Store builds: the Android channels `movera_offers` and `movera_offers_quiet` are made (BQ-V43, above); later the
  iOS sound `movera_offer.caf` (the server already names it), and a native answer on the
  `movera/phone_sound` channel (method `state` → `{silent, volume}`) for the "Sound is off" notice (decision 2). Until
  then a native build shows no such notice; the web build shows it while the browser still blocks sound (no tap yet).

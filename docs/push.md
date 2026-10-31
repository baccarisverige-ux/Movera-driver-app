# Push notifications (contract v0.18.3, owner decision R7)

What is live: the **web build**. After sign-in the app explains why (sv / fr / en), the browser asks once, and the
FCM token goes to `POST /push/devices`; it is registered again when it changes and unregistered on sign-out. A tap on
a push opens the bell list on that notice, which follows its `deepLink`.

No Firebase key is in this repository. The app reads the public Firebase web settings from the server
(`GET /push/config?app=driver`) at run time; `web/movera_push.js` loads the Firebase JS SDK from gstatic only then.
`web/firebase-messaging-sw.js` shows the server's data messages (title and body already in the driver's language)
and needs no settings at all.

Android and iOS: push is off (`PushPlatform.supported` is false), so the native builds and CI need no Firebase files.
For store builds, later:

1. Add `firebase_core` and `firebase_messaging` and a native `PushPlatform` (lib/core/push/).
2. Android: `google-services.json` for `se.movera.driver` (Firebase console › project movera-200b2), the Google
   services Gradle plugin, and `POST_NOTIFICATIONS` (Android 13+). Keep the file out of git: write it from a CI secret.
3. iOS: `GoogleService-Info.plist`, the Push Notifications and Background Modes (remote notifications) capabilities,
   and an APNs auth key (.p8) uploaded to Firebase (Project settings › Cloud Messaging). Same secret handling.

## New-offer push (contract v0.18.6, driver group 4 decision 1 + E6)

- The server sends a push for every new offer (`kind: new_offer`, data `offerId, tripId, offerKind, sound, vibrate,
  expiresAt`). It is not a bell notice: a tap opens Home (`lib/core/push/offer_push.dart`), where the offer card shows
  while it is still open; a driver on a trip keeps his screen.
- Web: `firebase-messaging-sw.js` shows it only while no app window is on screen and never after `expiresAt`.
  Exclusive and hand-sent (`sound: offer`) use the phone's notification sound and vibrate `[300, 150, 300]` when
  `vibrate` is `"true"` AND the driver's own Vibrate setting (Settings › Accessibility) is on; the app keeps that
  setting in the Cache Storage entry `movera-push-prefs.json` (`moveraPush.setOfferPrefs`). Radar is silent.
  `node tool/verify_offer_push_sw.cjs` checks the worker (run by `test/g4/g4_offers_test.dart`).
- In the open app, an Exclusive or hand-sent offer on Home plays the Movera offer sound (`assets/sounds/radar_offer.mp3`)
  until a tap, and vibrates once when the Vibrate setting is on; Radar offers are quiet.
- Store builds, later: the Android channels `movera_offers` (sound `movera_offer`, vibration, high importance) and
  `movera_offers_quiet`, the iOS sound `movera_offer.caf` (the server already names them), and a native answer on the
  `movera/phone_sound` channel (method `state` → `{silent, volume}`) for the "Sound is off" notice (decision 2). Until
  then a native build shows no such notice; the web build shows it while the browser still blocks sound (no tap yet).

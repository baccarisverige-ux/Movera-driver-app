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

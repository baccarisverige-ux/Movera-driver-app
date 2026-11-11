# Android permissions

Every permission in `android/app/src/main/AndroidManifest.xml` (D14-19):

| Permission | Why it stays |
| --- | --- |
| `INTERNET` | The Movera API, the live streams, map tiles and road routing |
| `ACCESS_FINE_LOCATION` | The driver's position on Home and on trips, sent to the server while online |
| `ACCESS_COARSE_LOCATION` | Required next to FINE on Android 12+. A driver who grants only "Approximate" cannot drive: the app asks them to turn on precise location (driver-u24) |
| `FOREGROUND_SERVICE` | Owner decision 1 (driver group 3, contract v0.18.4): while online the position keeps going out with the phone locked, from geolocator's location foreground service |
| `FOREGROUND_SERVICE_LOCATION` | Android 14+ type of that foreground service (location) |
| `POST_NOTIFICATIONS` | Android 13+: shows the ongoing "Movera is online" notice of that service. Asked once at the first Go online (D14-7) |
| `RECORD_AUDIO` | Ride check "Record audio", only when the driver taps it, and in-app calls (WebRTC audio). A ride check file is saved only on this phone and never sent to Movera |
| `MODIFY_AUDIO_SETTINGS` | In-app calls (v0.18.38 §62): WebRTC audio and the speaker switch |

No background-location (`ACCESS_BACKGROUND_LOCATION`) permission: the
foreground service covers a locked phone while online.

The manifest also has a `<queries>` block (not a permission): text
processing (Flutter engine) and the `TTS_SERVICE` intent, so "Read rider
messages" (flutter_tts) can see the phone's text-to-speech engine on
Android 11+.

Camera and document photos use the image picker. That API does not need
`READ_EXTERNAL_STORAGE` or `WRITE_EXTERNAL_STORAGE` on current target SDKs.
Those legacy storage permissions are not requested.

Denial or cancel of camera, location, or the picker must leave the draft on
screen. It must not crash and must not invent a captured file.

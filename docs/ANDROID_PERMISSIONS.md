# Android permissions

Minimum set for the current Driver frontend:

| Permission | Why it stays |
| --- | --- |
| `INTERNET` | Demo road routing and map tiles |
| `ACCESS_FINE_LOCATION` | When-in-use driver location while the app is open |
| `ACCESS_COARSE_LOCATION` | Required next to FINE on Android 12+. A driver who grants only "Approximate" cannot drive: the app asks them to turn on precise location (driver-u24) |
| `RECORD_AUDIO` | Ride check "Record audio", only when the driver taps it. The file is saved only on this phone and never sent to Movera |

Camera and document photos use the image picker. That API does not need
`READ_EXTERNAL_STORAGE` or `WRITE_EXTERNAL_STORAGE` on current target SDKs.
Those legacy storage permissions are not requested.

Denial or cancel of camera, location, or the picker must leave the draft on
screen. It must not crash and must not invent a captured file.

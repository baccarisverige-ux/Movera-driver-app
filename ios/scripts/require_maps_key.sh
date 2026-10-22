#!/bin/sh
# driver-u5: a Release build with MOVERA_REQUIRE_MAPS_KEY=true and no
# GOOGLE_MAPS_API_KEY fails here, as the Android release does. Without the
# key AppDelegate skips GMSServices.provideAPIKey and the first Google map
# crashes the app on the phone.
if [ "${CONFIGURATION}" = "Release" ] &&
   [ "${MOVERA_REQUIRE_MAPS_KEY}" = "true" ] &&
   [ -z "$(printf '%s' "${GOOGLE_MAPS_API_KEY}" | tr -d '[:space:]')" ]; then
  echo "error: Native release requires GOOGLE_MAPS_API_KEY. Refusing to ship a maps build with an empty key."
  exit 1
fi
exit 0

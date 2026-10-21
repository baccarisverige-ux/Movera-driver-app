# Movera driver app: bug audit

Confirmed: 82 (high 5, medium 22, low 55). Rejected as false alarms: 35.

Runs finished: 10 of 38. Still running at this save: driver-w2a, driver-w2b, driver-w3a, driver-w3b, driver-w4a, driver-w4b, driver-w4c, driver-j1, driver-j3, driver-j4, driver-j5, driver-j6, driver-j7.

Each finding was checked by an independent code tracer and a reproducer (often with a throwaway flutter test), with a third reviewer on disagreements. Findings from read-only runs were verified by code reading only. Possible duplicates across runs are not yet merged.

## High (5)

### H1. Terminal exits call Navigator.pop() on whatever route is on top, so a rider cancel (or any authoritative outcome) while Chat/Preferences/a modal sheet is open leaves the dead trip screen mounted

`lib/presentation/driver/accept ride/accept_ride_trip.dart:452` (found by driver1)

**What happens:** Driver is waiting at pickup, opens Message rider (Chat page on top). The rider cancels; realtime delivers rider_cancelled. The Chat page closes, the trip screen stays with GPS stopped and the waybill discarded; nothing on it works any more and Back is blocked. The 'Rider cancelled' island notice is queued for Home, which is not reached.

**Why:** Every authoritative exit from the trip screen ends with a plain pop of the navigator: `_handleRiderCancelled` (lines 452-458 `final home = Navigator.of(context); if (next == null && home.canPop()) { IslandMessages.show(...); ... home.pop(); return; }` and 478-481), `_leaveAfterAuthoritativeOutcome` (388-389), `_leaveAfterRelease` (403-407) and `_submitTripCancellation` (1444-1446). `Navigator.pop()` removes the topmost route, not the AcceptRide route. The trip screen itself pushes other routes onto the same navigator while the trip is live: `_messageRider` pushes `Chat` (accept_ride_panel.dart:860-867), `_openRidePreferences` pushes `Preferences` (536-541), `_openDestinationPicker` pushes the picker, the island pushes `DriverRideHistory` (accept_ride.dart:1307-1308), plus modal sheets (trip options, rider profile, cash collect, waiting time, safety toolkit, the accessible-confirm AlertDialog). A realtime `rider_cancelled`/terminal/`searching` event arriving while any of those is on top therefore pops that page instead of the trip: `_handleRiderCancelled` has already journaled the cancel, set the lifecycle terminal, run `_pauseLiveUpdates()` (GPS off, wait timer off), `_waybills.discardCurrent()` and queued an island notice for a Home that is never shown. The driver is left on a terminal AcceptRide: the slide/arrive actions return silently (`_advanceRide` checks `_rideLifecycle.terminal`), cancel says it cannot be cancelled, `PopScope(canPop:false)` blocks Back. Reproduced with a throwaway widget test (Home -> AcceptRide waiting -> a page pushed on top -> `realtime.emit(riderCancelled)`): result `chatPopped=true tripStillMounted=true homeVisible=false island=Rider cancelled`. Rider cancelling while the driver is in the chat with that rider is a very plausible sequence.

**Suggested fix:** Pop to the trip's own route instead of the top route: capture `ModalRoute.of(context)` in the trip state and use `navigator.popUntil((r) => r != tripRoute && !r.isCurrent ...)` / `removeRoute`-style exit (e.g. `Navigator.of(context).popUntil((route) => route.isFirst)` when Home is the root, or `navigator.removeRoute(tripRoute)` after closing routes above it); for the `pushReplacement` branches first pop everything above the trip route.

### H2. After a driver cancel or no-show the session never ends the trip, so Home stays 'on trip': no offers and Go online does nothing

`lib/presentation/driver/accept ride/accept_ride_trip.dart:1384` (found by driver-j2)

**What happens:** The driver is online on Home and accepts a Radar trip. At pickup the wait passes the no-show time. The driver taps 'Rider didn't show' and confirms (or picks Cancel trip with any reason and confirms). The SnackBar 'Trip cancelled · …' appears and Home comes back, but the radar shows OFF and no offers ever arrive. Tapping OFF/Go online shows the 'online' island message, but the session stays onTrip and the driver never becomes available. The driving-time clock keeps running and can force a rest. Only an app restart recovers. Worked out by hand from the code; nothing was run.

**Why:** Every other way a trip can end releases the trip in the session controller: rider cancel (accept_ride_trip.dart:456/469), an authoritative outcome (:379), an admin release (:402) and completion (ride_completed.dart:71) all call `widget.sessionController?.stayOnlineAfterTrip()` (endTrip). `_submitTripCancellation`, which handles both a driver cancel and the driver no-show, never calls it. It journals the trip, calls `_rideLifecycle.cancel/noShow`, shows a SnackBar and then just `navigator.pop()`s (1439-1445). Nothing else ends the trip: Home's push of AcceptRide (home_offer_radar.dart:940, home.dart:567) has no `.then`, and AcceptRide.dispose does not touch the session. The DriverSessionController therefore keeps `_activeTripId = <cancelled trip>` and `_status = onTrip`. On Home, `_isOnline => _liveVisible && _recoveryResolved && _driverSession.availableForOffers` (home.dart:335) is false because `availableForOffers` needs `status == online`. Tapping Go online runs `_goOnline` (home.dart:884), which calls `beginGoingOnline()`. That returns at once when `_activeTripId != null` (driver_session_controller.dart:129). The 1.4 s timer's `completeGoingOnline()` then does nothing because the status is not goingOnline, yet the island still shows the 'online' notice. `setOnline` during a trip only flips `_offlineAfterTrip`. `DrivingTimeClock.sync(online: isOnline)` keeps counting driving time, because `isOnline` is true for onTrip. `didPopNext` skips restore because `activeTripId != null`. The same happens when the driver cancels with a secured next trip: the next AcceptRide's `beginTrip(next.id)` is ignored (driver_session_controller.dart:58-61), so the session keeps the cancelled trip's id until some later trip completes. No test confirms a driver cancel and then checks Home (integration_test/driver_lifecycle_test.dart:165 and test/widget_test.dart:2659 both tap 'Keep trip').

**Suggested fix:** In `_submitTripCancellation`, call `widget.sessionController?.stayOnlineAfterTrip()` after the lifecycle cancel/noShow succeeds and before `pushReplacement`/`pop`, as the rider-cancel and authoritative paths do. Add a widget test that confirms a driver cancel and a no-show from Home and expects LIVE/availableForOffers.

### H3. Closing (×) the Radar card whose Match claim is in flight leaves Home permanently in "Matching": no other trip can be matched and the won claim is dropped

`lib/presentation/driver/home/home_offer_radar.dart:895` (found by driver2)

**What happens:** Driver taps Match on a Radar card, then (within the claim's network latency) taps the small × on that card. Dispatch answers success: the trip is assigned to this driver on the server, but no trip opens; the remaining cards' Match buttons are disabled and the radar says "Matching / please wait" indefinitely. The driver cannot accept any trip until they go offline and online again; a scheduled "Leave now" in that state is handed to a backup driver.

**Why:** RadarOfferCard always shows the corner × on Home (onClose is always passed; radar_offer_card.dart:589-616 draws it regardless of `state`, including `matching`). _closeRadarHomeOffer (home_offer_radar.dart:890-896) calls _dismissRadarHomeOffer, which removes the offer from _radarHomeOffers and _homeRadarMatchStates (479-492) but never clears _homeRadarMatchingOfferId or _claimedHomeOffer. From then on: every other card's onMatch is null (`blocked != null && blocked != id ? null : ...`, 1127-1129), the radar orb is `busy` ("Matching · please wait", home_map_sheet.dart:1753-1774), _canStartScheduled is false so a scheduled "Leave now" goes to the backup driver (home_scheduled.dart:166-170, 177-178). When the dispatch claim resolves successfully, _claimHomeRadarOffer passes its guard (`_homeRadarMatchingOfferId == offer.id`), _resolveHomeRadarMatchWon sets _claimedHomeOffer and _openClaimedHomeOffer → 850 ms → _acceptRadarHomeOffer returns because the offer is no longer in _radarHomeOffers (925-928). _claimedHomeOffer stays set, so every later _scheduleVisibleOffers (resume) returns early at 1167-1170. The only exit is going offline (which runs _cancelAllOfferTimers without preserveClaim). The same path is reachable through _setAcceptsCash/_onCategoriesChanged, which dismiss listed offers regardless of claim state (home_offer_rules.dart:31-35, 52-56). Reproduced with a throwaway widget test (two offers on the deck, Match on `first`, tap `radar-offer-close`, then complete the claim with ClaimResult.success): AcceptRide never opened, `radar-match-second` onPressed stayed null and the orb read "Matching" 30 s later. Test result: `00:07 +2: All tests passed!`.

**Suggested fix:** Refuse × (and rule-driven dismissals) while `_homeRadarMatchingOfferId == offer.id` (pass onClose: null for a matching card), or make _dismissRadarHomeOffer clear _homeRadarMatchingOfferId/_claimedHomeOffer and cancel _homeRadarNoticeTimer when it removes the matching offer; and let _acceptRadarHomeOffer open the trip from _claimedHomeOffer even if the card was removed.

### H4. "Leave now" removes the accepted scheduled ride from the store before a push that silently does nothing when Home is not the current route

`lib/presentation/driver/home/home_scheduled.dart:220` (found by driver4)

**What happens:** Driver is online, has an accepted reservation for 07:40, and at 07:0x opens Scheduled rides (or any other screen/sheet) over Home to check it. The "leave now" moment arrives while that screen is on top: the ride disappears from Scheduled rides › Accepted, the island later flashes "Leave now for 07:40" and a notification "Leave now for 07:40 pickup" appears, but no trip screen ever opens; returning to Home shows no trip and the ride is gone for good (no backup hand-off either, since `_scheduled.ride` was set to null).

**Why:** `_planScheduled` arms `Timer(_clock.realUntil(start), () => _leaveNow(ride))` (line 161). These timers live in `_scheduled.timers`, which `_pauseHomeUpdates` (home.dart 192-203) never cancels, and `_leaveNow`/`_canStartScheduled` (lines 166-170, 175-189) only check `mounted`, `_recoveryResolved`, `_driverSession.availableForOffers`, `_claimedHomeOffer` and `_homeRadarMatchingOfferId`; neither `_routeVisible` nor `ModalRoute.isCurrent` is consulted. `availableForOffers` is `_status == online` (driver_session_controller.dart 34), which stays true while the driver is on any non-trip screen pushed over Home (Scheduled rides, Notifications, Settings, Support, Wallet, Ride history, a modal sheet such as the destination details sheet or the queue sheet). When the timer fires in that state, `_startScheduledTrip` (218-239) first calls `ScheduledRideStore.start(ride)` which is `_removeAccepted(ride) != null` (scheduled_rides.dart 638-660) and permanently drops the ride from Accepted, posts the "Leave now" island message and notification, and only then calls `_HomeOfferRadar(this)._openOfferTrip(...)` (home_offer_radar.dart 931-981) whose `pushSingle(context, ActiveRideTransition(AcceptRide(...)))` returns `Future.value()` without pushing because `ModalRoute.of(context)?.isCurrent == false` (single_route_entry.dart 11-13). `_planScheduled()` then re-plans for the *next* ride. Nothing re-opens or restores the removed ride; `didPopNext` only re-runs `_restoreActiveRideIfNeeded`, and no AcceptRide/persisted trip was ever created.

**Suggested fix:** Make `_canStartScheduled` require Home to be current/visible (e.g. `_routeVisible && ModalRoute.of(context)?.isCurrent == true`) and treat the not-current case like `_lateScheduled`/defer; or defer `_leaveNow` until `didPopNext` (store a pending ride and run it in `_resumeHomeUpdates`). Alternatively only call `ScheduledRideStore.start(ride)` after `pushSingle` has actually pushed (check its return/`navigator` state) and roll back on a no-op push.

### H5. Same defect as driver-74: "Leave now" removes the accepted ride from Accepted, then pushSingle silently does nothing while any route or sheet covers Home, so the trip never opens and the ride is lost

`lib/presentation/driver/home/home_scheduled.dart:234` (found by driver4)

**What happens:** Driver has accepted the 07:40 reservation, is online, and opens Scheduled rides (or any other screen) at 07:33. The smart-gap timer fires "Leave now": the ride leaves Accepted, the island (hidden) says "Leave now", no trip screen opens. Driver returns to Home: no active trip, the reservation is no longer in Accepted, nothing is persisted. The rider's ride is silently lost on this phone.

**Why:** _leaveNow() fires from a Timer planned in _planScheduled(). Its only guard is _canStartScheduled (home_scheduled.dart:166-170: _recoveryResolved, availableForOffers, no claim in flight); it never checks that Home is the current route. _startScheduledTrip() first calls ScheduledRideStore.start(ride) (line 220), which removes the ride from Accepted (scheduled_rides.dart:638-639 / 652-660), posts "Leave now" and then calls _HomeOfferRadar._openOfferTrip (line 234). _openOfferTrip cancels every offer timer and calls pushSingle(context, ActiveRideTransition(AcceptRide(...))) (home_offer_radar.dart:940). pushSingle returns Future.value() without pushing when `ModalRoute.of(context)?.isCurrent == false` or while another push's entry animation is running (single_route_entry.dart:11-15). The return value is ignored, the post-frame callback clears the offers, _planScheduled() moves on to the next ride. Nothing is persisted (AcceptRide is what writes the active-ride snapshot), so the ride is gone from the phone: not in Accepted, not an active trip. Home's didPopNext restore only re-opens persisted snapshots, so returning to Home does not recover it. Any pushed route over Home triggers this: Scheduled rides screen (where a driver is likely to be looking at exactly this ride), Wallet, Preferences, Support inbox, Ride history, Notifications, Documents, the Go-offline confirm dialog, the driving-time/performance/waybill/destination/safety modal sheets. Reproduced with a throwaway widget test (fast demo day, ride accepted, a MaterialPageRoute pushed over Home at ~07:33, then 12 s): `Leave now for 07:40 pickup` was posted, ScheduledRideStore.upcoming no longer contained the ride, find.byType(AcceptRide) was findsNothing before and after popping the covering route. Test result: `00:07 +2: All tests passed!`.

**Suggested fix:** In _leaveNow/_startScheduledTrip require Home to be visible and current (e.g. `_liveVisible && ModalRoute.of(context)?.isCurrent == true`), otherwise treat it like a pause: keep the ride in Accepted and retry from didPopNext/_resumeHomeUpdates (_onRadarLive already re-plans). Alternatively make _openOfferTrip check pushSingle's outcome and roll back (re-add the ride / not clear offers) when nothing was pushed.

## Medium (22)

### M1. Pickup pay is added to the fare shown on offer cards but is dropped on accept, so the trip, waybill earnings and history show less than the card promised

`lib/core/dispatch/pickup_pay.dart:38` (found by driver4)

**What happens:** While driving, the next-trip card says 132,20 kr (incl. 3,80 kr pickup) and the driver accepts. The secured-next banner, the next trip's screen, its waybill 'Your earnings' and the history row all say 128,40 kr; the 3,80 kr the card promised is gone. Same on Home radar/exclusive cards whenever pickup pay is non-zero.

**Why:** PickupPayQuote.totalOf(fare) returns fare + pickup pay and is what the cards display: the on-trip next-trip card shows `_NextTripRadarOffer.shownFare` (accept_ride.dart:333 `String get shownFare => pickupPay.totalOf(fare);`, rendered at accept_ride_panel.dart:309 and accept_ride_sheet.dart:132), the exclusive sheet shows `offer.shownFare(show)` and Home radar cards get a PickupPayQuote (home_offer_radar.dart:1069). PickupPayConfig.current defaults have every kind on with demo rates (pickup_pay_config.dart:188-209, demoRates), so for the default next-trip offer (Comfort, 1.6 km / 4 min: (1.6-1)*3 + (4-2)*1 = 3,80 kr) the card promises 132,20 kr. When the driver accepts, the trip is opened with the plain fare: _buildNextWaybill uses `offer.fare` (accept_ride_trip.dart:217), _snapshotForOffer uses `offer.fare` (:976), the next AcceptRide gets `fare: offer.fare` (:940, :1398), PersistedQueuedTrip.fare is the plain fare (:49), and Home's _openOfferTrip passes `fare: offer.fare` (home_offer_radar.dart:954). Nothing stores or adds the pickup pay afterwards, so the trip screen, completion journal, history and earnings all show the lower number the driver did not accept.

**Suggested fix:** Decide one truth: either carry the pickup pay into the trip (store it on the offer/snapshot/waybill and include it in earnings and the trip header), or show the card total as 'fare' plus a separate pickup-pay line that is clearly not part of the fare. At minimum pass `offer.shownFare` (or a stored PickupPayQuote) through _buildNextWaybill/_snapshotForOffer/_openOfferTrip so the accepted amount matches what was shown.

### M2. On web the 8 s GPS time limit is not enforced (geolocator_web 4.1.4 passes microseconds as ms, with no Dart timeout), so a browser that never answers blocks the one-shot fix and the GPS subscription on Home and the trip

`lib/core/location/driver_location_service.dart:29` (found by driver3)

**What happens:** Driver opens the PWA on a phone whose browser cannot obtain a fix right away: Home stays on the locating placeholder and the trip map shows no live car, no route and no status for as long as the browser withholds an answer (up to ~2.2 h) instead of falling back after 8 s as on native.

**Why:** `DriverLocationService.getCurrentPosition()` relies on `LocationSettings(timeLimit: 8 s)` to bound the one-shot fix. Both screens subscribe to `watchPosition()` only after that call resolves: `accept_ride_trip.dart:598-606` (`final position = await _locationService.getCurrentPosition(); ... _positionSubscription = _locationService.watchPosition(distanceFilterMeters: 0).listen(...)`) and `home_map_sheet.dart:38-45` (the catch path also subscribes, but only if the call completes). On native the platform-interface applies `.timeout(timeLimit)`, so after 8 s the service falls back to the last known fix or throws and the screens show `Location updating…` and keep working. On web the pinned geolocator_web 4.1.4 overrides `getCurrentPosition` with no Dart-side timeout and converts the limit with `timeout?.inMicroseconds` into the browser's millisecond `PositionOptions.timeout` (8 s becomes 8,000 s, about 2.2 h). The app's own guard therefore does not hold on its primary (web/PWA) deployment: when the browser's geolocation does not answer (device has location permission but no fix, e.g. indoors, or a slow provider), the one-shot neither resolves nor errors, no stream is ever subscribed, no `Location updating…` status is set, and on the trip no route request is made (`_refreshRoadRoute(force: true)` sits in the catch).

**Suggested fix:** Wrap `Geolocator.getCurrentPosition` in a Dart-side `.timeout(_settings.timeLimit!)` in `DriverLocationService.getCurrentPosition` (and `requestPermission` if it can block), and/or subscribe to `watchPosition` before awaiting the one-shot so a hung one-shot cannot block the stream.

### M3. Trip auto-resume timer that fires while suspended is dropped and never re-armed; resume() does not reschedule it

`lib/core/navigation/driver_camera_controller.dart:474` (found by driver4)

**What happens:** Driver on an active trip pans the map (camera enters Free), switches to another app for more than 12 s on Android, comes back: the trip map stays where it was panned indefinitely; the camera never returns to the car until the driver touches the map again or taps recenter.

**Why:** `_scheduleResume()` arms a one-shot Timer whose callback returns early when `_suspended` is true without rescheduling, and `resume()` (lines 693-696) only calls `_request(immediate: true)`, which is a no-op in browsing mode (`_canFollow` is false). The trip screen relies on this timer to bring the camera back to the car 12 s after the driver lets go of the map (`accept_ride.dart:488` sets `autoResumeAfter = tripAutoResume`, `accept_ride_trip.dart:794` sets `onAutoResume`). `suspend()` is called from `_pauseLiveUpdates` (`accept_ride_trip.dart:117`) on every lifecycle pause. On Android and on the web (PWA tab in background) Dart timers keep firing while the app is hidden, so the 12 s timer runs during the pause, hits the `_suspended` guard and dies. After `resume()` nothing re-arms it: `mapActivity()` only reschedules when `_resumeTimer != null`, and a later `update()` only calls `_scheduleResume()` on `enteringGuidance`, which is false mid-trip. Reproduced with a throwaway Flutter test (controller with `autoResumeAfter` 50 ms: userGesture, touching=false, suspend, wait 120 ms, resume, wait 300 ms): `Expected: <1> Actual: <0> after resume the camera should still auto-return`, mode stayed `browsing`.

**Suggested fix:** In the timer callback, when `_suspended` is true, leave `_resumeTimer` unset but have `resume()` call `_scheduleResume()` (it already checks mode/guidance/touching); alternatively cancel the timer in `suspend()` and re-arm it in `resume()`.

### M4. Corrupt local JSON records leak rider name, pickup/dropoff addresses (and trusted-contact phones) into DriverLog via FormatException source excerpts

`lib/core/ride/prefs_active_ride_repository.dart:81` (found by driver2)

**What happens:** localStorage/SharedPreferences holds a half-written movera_driver_active_ride (e.g. tab killed mid-write) -> next launch Home calls read() -> the rider's name, phone and pickup address are printed to the device/browser log in a release build and would be shipped to any future crash-reporting sink.

**Why:** DriverLog's own contract (lib/core/logging/driver_log.dart:5-6: 'Messages must not contain rider names, phone numbers or free text') is violated by every storage reader that logs a jsonDecode error. Dart's FormatException.toString() appends ~78 characters of the offending source around the error offset, and the stored records are JSON blobs holding rider names, phone numbers and addresses (active ride), trusted-contact phone numbers (settings sections) and completion journals. Paths: PrefsActiveRideRepository.read -> `DriverLog.error('Active-ride snapshot parse failed', error, stack)` (line 81) and again through `_enqueue`'s catchError (line 57); LocalQuarantine.store builds `reason: '$error'` from callers (prefs_active_ride_repository.dart:125, completion_journal.dart:157, settings_repository.dart:84) and then logs it: `DriverLog.warn('Quarantined $source record as $key: $reason')` (local_quarantine.dart:62). The default sink prints with debugPrint (driver_log.dart:42-43), which is not stripped in release builds, so this lands in logcat / the browser console; the file also says a crash-reporting adapter will be attached to this sink later. Reproduced with a throwaway flutter test: a truncated active-ride snapshot produced a log line containing `"riderPhone":"+46701234567","pickup":"Sveavägen 12, Stockholm"`, and a truncated contacts section produced `"phone":"+46709998877"` in the quarantine warning.

**Suggested fix:** Log only the exception type/message without the source excerpt (e.g. `error is FormatException ? error.message : error.runtimeType`), and pass a scrubbed `reason` to LocalQuarantine (the raw text is already stored in the quarantine payload, so the reason need not repeat it).

### M5. Scheduled-ride waiting rule is found by searching the localized 'Scheduled ride' label, so French and Swedish drivers get different wait and no-show terms

`lib/core/ride/waiting_rules.dart:250` (found by driver-j2)

**What happens:** Take a scheduled Movera XL reservation (category rule free 3 / no-show 3) and press Leave now. In English, termsFor applies XL, then scheduled sets free to 5, and the final guard lifts no-show to 5: 5 free minutes, no-show at 5 min. With the app in Swedish or French the same trip gets 3 free minutes and no-show at 3 min. Paid waiting therefore starts 2 minutes earlier (12,26 kr/min) and the driver can mark a no-show 2 minutes earlier, only because of the UI language. The waiting sheet also loses its 'Rule for this pickup: Scheduled ride' line. Worked out by hand from termsFor; nothing was run.

**Why:** AcceptRide builds `_waitTerms` from `WaitingRules.typeOf(matchedVia: widget.matchedVia, ...)` (accept_ride.dart:989-996). `typeOf` sees a scheduled ride only if `matchedVia.toLowerCase()` contains 'scheduled' or 'reservation'. 'Leave now' opens the trip with `matchedVia: tr.scheduledRide` (home_scheduled.dart:236). That is 'Scheduled ride' in English, 'Course planifiée' in French and 'Bokad resa' in Swedish, so in fr/sv the type falls back to `WaitingRideType.normal`. The scheduled rule is skipped: its free wait (`ScheduledRideRules.current.includedWaitingMinutes`), any admin perMin/noShowFee for `rideTypes.scheduled` (driver_app_config.dart reads them), and its 'Scheduled ride' rule label. The matchedVia string is also saved in the snapshot, so a restored trip keeps the wrong type.

**Suggested fix:** Pass a language-neutral source (for example a WaybillRecord constant like 'scheduled' or an explicit WaitingRideType/TripKind) to AcceptRide for reservations, and localize only the display label.

### M6. Ride-check audio that is still starting when the card closes keeps the microphone recording with no UI, and dispose() never stops it after a later check opens

`lib/core/safety/ride_check_controller.dart:260` (found by driver2)

**What happens:** Long-stop card opens, driver taps 'Record audio' and, while the OS mic permission sheet / recorder start is still in flight (hundreds of ms on a phone), taps 'I'm OK'. The card closes but the phone keeps recording the cabin to ride_check_audio/*.m4a with no indicator; after the next Ride check on the same trip and leaving the trip screen, the recorder is still running until the app process dies.

**Why:** `toggleRecording()` sets `_audio = starting`, awaits `recorder.requestPermission()` and then `recorder.start(...)` (lines 240-251). On native that start awaits `getApplicationDocumentsDirectory()`, `Directory.create` and the plugin. If the driver answers meanwhile (`imOk`/`done` → `_close()`), `_close()` calls `_stopRecording()` which returns immediately because `_audio != recording` (line 275), then marks the record answered and closes the card. When `start()` later completes, the only guard is `if (_disposed)` (line 260): `_audio` becomes `recording`, `_audioStartedAt` is set and a periodic 1 s ticker starts notifying listeners (lines 264-270) although the card is closed and `_answerable` is false, so nothing on screen shows a recording and no button can stop it. If a further Ride check opens later, `open()` resets `_audio = idle` (line 114) without touching the recorder or the ticker, after which `dispose()` skips the stop because `_audio != recording` (line 412) — the native recorder is never stopped for the rest of the process. Reproduced with a throwaway flutter test using a recorder whose `start()` awaits a Completer: after `imOk()` and completing start, `c.audio == RideCheckAudio.recording` and the fake recorder was still recording; after `open()` of a second event and `dispose()`, the recorder was still recording with `stops == 0` (test output: `after close: audio=RideCheckAudio.recording recorderRecording=true stops=0` / `after dispose: recorderRecording=true stops=0`). The test file was deleted afterwards.

**Suggested fix:** After `await recorder.start(...)` re-check `_disposed || _closing || !_answerable` and cancel/stop the recorder if the card is no longer open; in `open()` and `dispose()` stop any recorder that was started regardless of the `_audio` flag (track a `_recorderRunning` bool set around start/stop).

### M7. Saved Ride-preferences category choice is never restored at boot, so switched-off categories are offered again after every restart

`lib/core/vehicle/ride_categories.dart:53` (found by driver3)

**What happens:** Driver opens Ride preferences, switches off 'Movera Pet' (saved to settings), kills and relaunches the app, goes online. Home shows Radar/Exclusive/reservation offers in the Pet category (and scheduled Pet rides) because `DriverCategoryChoice.off` is empty; the filter only starts working again after the driver happens to open Ride preferences.

**Why:** `DriverCategoryChoice.off` (ride_categories.dart:56) is the in-memory set that every offer filter reads (`DriverCategoryChoice.takes` in home_offer_rules.dart:13/21/30, home_reservation.dart:107/132, scheduled_rides.dart:545). The only writer is the Ride preferences screen: `_publishChoice()` runs after `_restoreSettings()` or a toggle (preferences.dart:118/172), i.e. only once that screen has been opened. The choice is persisted to the `categories` settings section (preferences.dart:140), but nothing reads it back at app start: `main.dart:41-49` restores `MapTrafficSetting` and `DriverLanguage` and nothing else, and `DriverCategoryChoice` has no restore method. After a cold start `off` is the empty const set, so `takes()` returns true for every allowed category. The class comment (`ride_categories.dart:51`, 'kept for the session') documents the in-memory nature but the persisted setting and the Q27 promise ('offers follow that choice') make the restart behaviour wrong. The same global is also not reset on logout (`main.dart:180-195` calls `MapTrafficSetting.reset()` / `DriverLanguage.reset()` but not `DriverCategoryChoice.reset()`), so after logout the cleared storage and the stale in-memory set disagree until Preferences is opened again.

**Suggested fix:** Add `DriverCategoryChoice.restore([SettingsRepository])` that reads the `categories` section the same way `_restoreSettings` does and publishes the off-set; call it from `main()` beside `MapTrafficSetting.restore()`, and call `DriverCategoryChoice.reset()` in `_logout`.

### M8. WaybillPayment.fromFare reads only the first digit group of a thousands-grouped fare label, so earnings/fee are wrong for fares >= 1 000 kr

`lib/core/waybill/waybill.dart:296` (found by driver4)

**What happens:** A driver completes a 1 234,50 kr trip (any backend Offer.fare >= 100000 minor units, or a demo fare pushed over 1 000 kr by waiting fees). Opening the waybill shows "Your earnings 0.75 kr" and "Service fee 0.25 kr" instead of about 925,88 kr / 308,62 kr; with netFare on, the offer card shows a 0.75 kr net fare for a 1 234 kr trip.

**Why:** Money.formatted groups thousands with a space ("1 234,50 kr", lib/core/money/money.dart:187 via _group). RideOffer.fareLabel (dispatch_repository.dart:114) and WaitingTerms.addFee (waiting_rules.dart:77, used for _fareWithWaiting on completion) both produce this format, and it is what reaches WaybillRecord.fare. WaybillPayment.fromFare parses the label with `RegExp(r'\d+(?:[.,]\d{1,2})?').firstMatch(fare)` which matches only the leading "1" of "1 234,50 kr", so fareOre becomes 100 and _comma is false. Consumers: waybill_sheet.dart:70 (`WaybillPayment.fromFare(record.fare, bonus: record.driverBonus)` -> "Your earnings" row) and OfferCardDetails.fare (offer_rules.dart:157, the net-fare mode admin can switch on for offer cards). Money.parseSekLabel already accepts the grouped form (money.dart:73), so the producer and this consumer disagree. Reproduced with a throwaway flutter test: `Money(minorUnits:123450).formatted` = "1 234,50 kr"; `WaybillPayment.fromFare(that)` gave fare=1.00 kr, fee=0.25 kr, earnings=0.75 kr; `OfferCardDetails(netFare:true).fare(label)` = "0.75 kr".

**Suggested fix:** Parse the fare with Money.parseLabel/parseSekLabel (which understand grouped thousands and the currency suffix) instead of the ad-hoc regex, e.g. `final money = Money.parseLabel(fare); if (money == null) return null; fareOre = money.minorUnits;` and keep the comma flag from the label. Add a test for a >= 1 000 kr label.

### M9. An authoritative `completed` projection archives a cash trip without its payment method, cash collected or waiting fee

`lib/presentation/driver/accept ride/accept_ride_trip.dart:316` (found by driver1)

**What happens:** Cash trip in progress; admin force-completes it (`POST /admin/trips/{id}/complete`) -> `trip_projection` status completed arrives -> history row shows the trip as card-paid with no 'Cash collected' line; the period's cash balance sheet omits it.

**Why:** The driver's own Finish (`_completeCurrentTrip`, lines 912-917) journals `_paidWaybill()` (fare incl. the driver's waiting fee) with `paymentMethod: 'Cash'` and `cashCollected` for a cash trip; `TripHistoryRecord.cashBalance` and the history 'Other earnings' cash accounting depend on `paymentMethod == 'cash'`. The realtime terminal path in `_drainProjection` (contract rows `complete` by admin from rider_onboard/in_trip/approaching_dropoff, or a server echo of `completed`) journals `_waybills.current ?? _buildCurrentWaybill()` with only `status` and `authoritative: true`. The archived row then has no `paymentMethod`/`cashCollected` and no waiting fee, so the driver's cash balance for that trip (what they owe or are owed) silently disappears from history, and with `authoritative: true` it also overwrites a correct local row if one was written first.

**Suggested fix:** In the authoritative terminal branch pass the same `paymentMethod`/`cashCollected` (and `_paidWaybill()`) as the local completion when `status == TripStatus.completed`.

### M10. A repeated same-stage (onTrip) projection restarts the next-trip radar: an accepted (matching) or shown Exclusive offer is dropped, and the route and camera are re-fitted

`lib/presentation/driver/accept ride/accept_ride_trip.dart:341` (found by driver1)

**What happens:** Driver on trip accepts the Exclusive next-trip offer; within a second the app is resumed or a projection echo arrives with status in_trip. The match timer is cancelled, the state goes back to scanning, the accepted trip is lost and the same offer pops up again (or is gone if declined before); the long-stop ride-check timer also restarts from zero.

**Why:** `_drainProjection` treats a successful `applyProjection` as a stage change: `if (!await _rideLifecycle.applyProjection(status)) { return; } if (mounted) { _rebuild(() {}); _resumeStageSideEffects(); }` (lines 340-342). But `ActiveRideController.applyProjection` returns true without changing anything when `next == _stage` (active_ride_controller.dart: 'Realtime may repeat the same stage each poll ... if (next == _stage) { return true; }'). Same-stage projections are normal: `reconnectAndResync` (called on every app resume, accept_ride.dart:719, and on every sequence gap, accept_ride_trip.dart:248) re-emits the cached projection with a new sequence (driver_realtime.dart:468-482), and a poll/echo would do the same. For `onTrip`, `_resumeStageSideEffects` (100-115) then calls `_rideCheckDetector.startTrip(...)` (forgetting any long-stop/off-route progress), `_demoDrive?.startTrip()`, `_startOnTripRadar()` (995-1008) which cancels `_nextTripRadarMatchTimer` and sets `scanning` with `_nextTripRadarOffer = null` — so an offer the driver has just accepted (900 ms `matching` window, 1190-1208) is silently discarded after `ExclusiveAnswers.accepted()` was already counted, and an offer on screen disappears — and finally `_refreshOnTripRoute(fitCamera: true)` forces a route re-fetch and camera re-follow. Reproduced with a throwaway widget test: on-trip demo offer shown, tap 'match next', emit an `in_trip` projection: `securedCardPresent=false offerVisible=true` (the same offer is re-presented as a new one instead of being secured).

**Suggested fix:** Only run `_resumeStageSideEffects()` when the stage actually changed (compare `_stage` before/after `applyProjection`, or have `applyProjection` report 'unchanged' distinctly), and make `_startOnTripRadar` a no-op when state is `matching`/`offerAvailable`.

### M11. An authoritative `completed` projection discards the waybill instead of completing it and journals the trip without payment method, cash collected or waiting fee

`lib/presentation/driver/accept ride/accept_ride_trip.dart:376` (found by driver1)

**What happens:** Backend/admin marks the trip completed while the driver is on the last leg. The outcome sheet says 'Movera recorded this trip as completed', but the Home island still shows the previous trip as last trip and the history entry for this cash trip has no payment method or cash collected.

**Why:** `_drainProjection` handles every terminal status through `_leaveAfterAuthoritativeOutcome` (313-323 → 371-390). For `TripStatus.completed` that path writes the journal with the bare current waybill (`_waybills.current ?? _buildCurrentWaybill()`, no `paymentMethod`, no `cashCollected`, no `_paidWaybill()` waiting fee — unlike `_completeCurrentTrip` at 912-917) and then calls `_waybills.discardCurrent()` (376) rather than `completeCurrent()`. `discardCurrent` only nulls `current` (waybill.dart:195-197) so `_waybills.last` is never updated; Home's `lastListenable` listener (`_onLastTripChanged`, `_lastTripFareLabel`, `_lastTripSettling`) and the island 'Last trip' amount keep the previous trip, and a cash trip completed by the backend is archived without 'Cash'/cash collected, so the history detail cannot show what is owed to Movera (Q23).

**Suggested fix:** Branch on `status == TripStatus.completed`: journal with `_paidWaybill()`, `paymentMethod`/`cashCollected` as in `_completeCurrentTrip`, and call `_waybills.completeCurrent()` (or route to DriverRideCompleted).

### M12. Re-tapping Continue on Add vehicle after taking document photos silently deletes the saved photos

`lib/presentation/driver/add vehicle/add_vehicle.dart:76` (found by driver2)

**What happens:** Vehicles > + > fill make/model/year/plate > Continue > Registration certificate > Take photo (saved locally) > Back > Continue again: the photo row is overwritten; the documents page shows no saved photo and the base64 image is gone from preferences.

**Why:** `_save` always upserts the bare identity map `submitted` = {id, make, model, year, plate} (lines 76-85) using the fixed `_vehicleId`. `LocalVehicleStore._upsertSnapshot` replaces the whole row for that id (`rows.removeWhere((row) => row['id'] == vehicle['id']); rows.insert(..., Map.of(vehicle))`, local_vehicle_store.dart) and skips photo fields that are null (`if (value == null) continue;`). After the driver has taken a registration/insurance photo on VehicleDocuments (which upserts the row with `registrationPhoto`/`insurancePhoto`), pressing Back returns to the still-mounted AddVehicle whose `_ready` is still true; tapping Continue again writes the row without the photo keys and the photos are gone. The new VehicleDocuments then restores `_registrationDone = false` and shows 'Recommended next step' again with no message. Reproduced at store level with a throwaway test (upsert identity -> upsert with photo -> upsert identity -> list: `registrationPhoto` absent), test deleted afterwards.

**Suggested fix:** In `_save`, merge onto the existing row (`{...previousRow, ...submitted}`) or have the store preserve photo fields when the incoming map omits them; alternatively navigate with pushReplacement / disable re-save once the draft exists.

### M13. AppLifecycleState.inactive is treated as not foreground, so Home renders the driver as offline (radar "OFF · Tap to scan", offline dock, no "Finding trips") while the session is online

`lib/presentation/driver/home/home.dart:189` (found by driver3)

**What happens:** Driver is online on Home; a phone call comes in on iOS (app stays visible behind the call banner, state = inactive). Home immediately shows "Radar · OFF · Tap to scan" and the offline dock for the whole call; the driver believes they were taken offline. When the call ends, the online face returns. Offers arriving during the call were not listed.

**Why:** didChangeAppLifecycleState sets `_foreground = state == AppLifecycleState.resumed` (line 189); _isOnline (line 335) is `_liveVisible && _recoveryResolved && availableForOffers`, and the radar layer, dock, side menu and island all branch on _isOnline (home_map_sheet.dart:1654-1694, 1594, home.dart:713). `inactive` is a visible state: iOS during a phone call banner, Control Center/notification centre, Face ID prompt, app switcher; Android during a system dialog, the location-permission dialog, multi-window without focus. In all of these the app is on screen and after _pauseHomeUpdates() (line 190) it draws the offline face, cancels the dispatch subscription and offer timers, although DriverSessionController still says online and dispatch still sends offers. On return it snaps back. An incoming phone call while online is a routine driver situation.

**Suggested fix:** Treat `inactive` as foreground for rendering (only `paused`/`hidden`/`detached` pause updates), or keep rendering from the session state and use _liveVisible only to gate timers/subscriptions.

### M14. A Match claim that succeeds after the driver went offline is silently discarded although dispatch assigned the trip

`lib/presentation/driver/home/home_offer_radar.dart:546` (found by driver2)

**What happens:** Driver taps Match, then long-presses the radar and confirms "Go offline" before dispatch answers (slow network). Dispatch answers success → the trip is assigned to this driver server-side; the app shows nothing, stays offline, never opens the trip and never declines/cancels it.

**Why:** While a Radar claim is in flight the radar orb is still wrapped in _radarLongPressOff (home_map_sheet.dart:1689, 1716-1723) and the island long press also offers "Go offline?" (1110-1116). _goOffline() calls _HomeOfferRadar._cancelAllOfferTimers() without preserveClaim (home.dart:949), which sets _homeRadarMatchingOfferId = null (home_offer_radar.dart:796-800). When _dispatch.claimOffer later resolves with ClaimOutcome.success, _claimHomeRadarOffer returns at line 546 because `_homeRadarMatchingOfferId != offer.id`; nothing tells dispatch and nothing is shown. In the demo repository the offer was already removed from the feed by the claim (demo_dispatch_repository.dart:565-566), i.e. it is taken by this driver. The driver is offline, the rider is matched to a driver who is not coming.

**Suggested fix:** Either block going offline while a claim is in flight (disable the long press / show "please wait"), or keep the claim across _goOffline and, on a late success, open the trip or send dispatch a decline/cancel for that offer.

### M15. Two Radar offers lost within 2.8 s share one _homeRadarLostMatchTimer: only the last is dismissed, and the other stays in _radarHomeOffers (hidden by the deck), which keeps the deck slot and "trips found" up and holds back every Exclusive offer

`lib/presentation/driver/home/home_offer_radar.dart:692` (found by driver2)

**What happens:** Driver has two deck cards from destination mode and turns destination mode off. Both cards are marked taken; after 2.8 s only the second disappears, the first stays as a greyed "Taken by another driver" card and the radar keeps saying trips are found until the driver taps × or goes offline.

**Why:** _watchDispatchRadar's listener loops over every listed/pending offer missing from the new snapshot and calls _resolveHomeRadarMatchLost for each (604-611). _resolveHomeRadarMatchLost marks the offer claimedElsewhere and arms the single field _homeRadarLostMatchTimer after `_homeRadarLostMatchTimer?.cancel()` (691-702). The second call cancels the first offer's dismissal, so that offer keeps state claimedElsewhere, stays in _radarHomeOffers (shown blurred/"Taken"), keeps _hasRideOffers true (radar "trips found", island green ring) and is only removed by a manual ×, a pause/resume (_resumeOfferTimers) or going offline. _refreshRadarHomeOffers never drops claimedElsewhere offers. Concrete demo path: two destination-mode trips on the deck (home_map_sheet.dart:463-465), then "Turn off destination" → _clearDemoDestinationTrips → DemoDispatchRepository.clearDestinationTrips emits a snapshot without both (demo_dispatch_repository.dart:614-624) → both resolved lost in one loop. With a real feed any update that drops two listed offers at once does the same.

**Suggested fix:** Keep one dismissal timer per offer id (a Map<String, Timer> like _radarOfferTimeoutTimers), or have the timer dismiss every offer currently in claimedElsewhere state.

### M16. Won admin direct assign or Exclusive reservation is lost (shows 'Trip matched' or 'accepted', no trip opens) when a drawer route covers Home as the claim resolves

`lib/presentation/driver/home/home_reservation.dart:509` (found by driver4)

**What happens:** Exclusive reservation (or admin direct assign) is up, driver taps Accept, edge-swipes the drawer and opens Ride history while the claim is pending. Dispatch answers success: the reservation disappears from Scheduled rides and from Home, the island says "accepted", but no trip screen ever opens and nothing is persisted; on the server the trip is this driver's.

**Why:** _claimExclusiveReservation (home_reservation.dart:484-509) and _claimAdminAssign (home_offer_radar.dart:843-860) await dispatch, then on success call ScheduledRideStore.take(offer.id) / show "matched" and _openOfferTrip, which pushes via pushSingle (home_offer_radar.dart:940). pushSingle silently does nothing when Home is not the current route (single_route_entry.dart:11-13). During the claim the Exclusive sheet covers the dock, but the Scaffold drawer is still reachable by edge swipe (it is not a route) and its items push screens (Ride history, Wallet, …). The claim result then arrives while a route covers Home: the reservation has left Scheduled rides (take()), _reservation.wonId is set, _outsideRadarOffer is cleared in the post-frame callback, and no trip opens. Unlike the Radar deck path (_openClaimedHomeOffer waits for _liveVisible and is retried from _scheduleVisibleOffers), these two paths have no deferral/retry.

**Suggested fix:** Route won Exclusive claims through the same deferred handoff as the Radar deck (_claimedHomeOffer + _openClaimedHomeOffer, retried from _scheduleVisibleOffers/didPopNext), and have _openOfferTrip verify that pushSingle actually pushed before clearing state.

### M17. Native: the map padding switches between the 75% driving anchor and the plain top inset the instant a pan is reported or recenter starts, which the SDK realizes as an immediate content shift under the finger and a snap at the start of the 'no snap' recenter flight

`lib/presentation/driver/overlays/map_overlay_insets.dart:34` (found by driver2)

**What happens:** Driver in guidance on Android/iOS starts dragging the map: as soon as the drag registers (6 px) the whole map lurches ~130 px up under the finger; tapping recenter produces an equal downward jump before the smooth flight begins.

**Why:** On native the 75% vehicle anchor is realized through `GoogleMap.padding` (`drivingInsets(... following:)` returns a top inset of `2*desired - height + bottom`, roughly 520 px on an 800 px screen with a 260 px top and 120 px sheet, versus 260 px when not following). `accept_ride.dart:1227-1234` passes `following: _camera.isGuidance && _camera.mode == DriverCameraMode.following`. `onUserGesture` (`accept_ride.dart:1242`) runs `_rebuild(_camera.userGesture)`, so on the first 6 px of a drag the widget rebuilds with the smaller top padding; Android `setPadding` and iOS `GMSMapView.padding` keep the camera target lat/lng and re-centre it in the new padded region, i.e. the map content jumps by about (520-260)/2 = 130 px while the driver's finger is on it. On recenter the padding flips back before the eased 1 s flight (`google_driver_camera_port.dart:102-106` documents the flight as landing with no snap), so the flight starts with an instant jump. The web path is guarded (`drivingInsets` returns `edgeInsets` on web and the JS `configure` only pans when `state.anchored`, which `release()` has already cleared); the native path has no equivalent guard. Not executable here (needs a device), hence the modest confidence.

**Suggested fix:** Keep the native padding constant across follow/browse (the anchor is only needed for follow frames, which the port can realize by offsetting the camera target instead), or defer the padding change until the gesture ends and apply it together with the first camera move.

### M18. A ride-category choice saved in Ride preferences is not applied to offers after a cold start until the driver reopens Ride preferences

`lib/presentation/driver/preferences/preferences.dart:122` (found by driver4)

**What happens:** Driver switches off 'Priority' and 'Comfort' in Ride preferences (snackbar '4 ride categories saved'), kills and relaunches the app, goes online: Priority/Comfort offers appear on Home and in the Live list; reopening Ride preferences shows them correctly off and only then stops the offers.

**Why:** `DriverCategoryChoice.off` (the set offers are filtered by: home_offer_rules.dart `_offerAllowed`/`_rideAllowed` -> `DriverCategoryChoice.takes`) is only populated by `_publishChoice()` which runs from `_restoreSettings` (line 122) and `_toggle` (line 183) inside the Preferences screen. Nothing reads the `'categories'` settings section at startup: `main.dart` restores only `MapTrafficSetting.restore()` (line 41) and `DriverLanguage.restore()` (line 46); grep shows `read('categories')` exists only in preferences.dart. So the screen says '{n} ride categories saved' and persists the choice, but after a cold start `off` is `const {}` and the driver receives offers of every category they switched off, until they happen to open Ride preferences again.

**Suggested fix:** Move the restore/publish logic into a `DriverCategoryChoice.restore(SettingsRepository)` and call it from the app root at startup next to MapTrafficSetting/DriverLanguage; Preferences keeps using the same code.

### M19. Logout clears the saved category preferences but leaves the in-memory offer filter, so the next session filters offers by the previous driver's choice

`lib/presentation/driver/profile/profile.dart:394` (found by driver2)

**What happens:** Switch off 'Comfort' in Ride preferences, Profile > Log out > Return to demo, go online: Comfort offers are still filtered out although Ride preferences (storage) now shows every category enabled; opening Ride preferences once makes them reappear.

**Why:** Logout runs `runtime.logout` (main.dart:180-193) which calls `clearLocalUserData()` (removes every `movera_driver_settings_section_*` key incl. 'categories') and resets `MapTrafficSetting` and `DriverLanguage`, but never calls `DriverCategoryChoice.reset()`. `DriverCategoryChoice.off` therefore keeps the switched-off set after logout and 'Return to demo'. Home's `_startAccount` only listens to the notifier, so offers of those categories stay hidden while a reopened Preferences screen shows all categories on (storage was cleared) and only then republishes an empty set. LOCAL_DATA.md says logout removes settings; this derived state survives.

**Suggested fix:** Call `DriverCategoryChoice.reset()` (and reset the other derived demo singletons such as DocumentExpiryStore/DriverNotificationFeed if intended) in `_MoveraAppState._logout`.

### M20. System Back while a Radar claim is in flight unmounts Radar and drops a won trip (the on-screen Back is covered by the Matching banner)

`lib/presentation/driver/ride requests/ride_requests.dart:322` (found by driver3)

**What happens:** Driver taps Match, changes their mind and taps Back within a second, then reopens Radar: the trip is no longer listed (claim succeeded and removed it) and no active trip exists on this phone, while dispatch considers it accepted.

**Why:** `_claimTrip` awaits `claimOffer` and then returns if `!mounted` (line 322) without handling the result. The Back button (`_closeRides`, line 270-282) stays enabled during Matching, and Home unmounts `RideRequests` on close (`showRideRequests = false`, home.dart:759-765, the whole Stack is replaced). `DemoDispatchRepository.claimOffer` removes the offer from the feed on success (line 565-566) and there is no other path that opens the accepted trip. So a Back tap during the ~1.45 s claim delay loses the trip: it is assigned (server side) but the driver never sees AcceptRide, and the card is gone from Radar when reopened.

**Suggested fix:** Disable Back while `_matchingOfferId != null`, or hand a successful claim result to Home (callback/repository) so the active trip opens even when the Radar sheet has been closed.

### M21. A withdrawal of another offer cancels the won-match timer: the claimed trip never opens and Radar is stuck in Matching

`lib/presentation/driver/ride requests/ride_requests.dart:435` (found by driver3)

**What happens:** Driver taps Match on a Radar trip, dispatch answers success; within half a second another driver's accept withdraws a different card. The 'Matched' banner is replaced by 'Taken by another driver', no trip screen opens, the matched card spins forever, and no other trip can be matched until the driver closes and reopens Radar. The accepted trip is gone from the server feed.

**Why:** `_resolveMatchWon` (line 351-418) keeps the AcceptRide push on `_matchNoticeTimer` (500 ms). `_resolveMatchLost` (line 435) unconditionally does `_matchNoticeTimer?.cancel()` for any trip, and `_onWithdrawn` (line 181-189) calls it for every `claimedElsewhere` withdrawal whose trip is still `available`. If dispatch withdraws trip B while trip A's win timer is pending, the timer is cancelled: `navigator.push(ActiveRideTransition(ride))` never runs, `_matchingOfferId` stays A (line 437 only clears it when it equals B), `_offerStates[A]` stays `resolving`, so A's card shows the spinner forever and every other card's Match is disabled (`blockOtherOffers`, line 724-725). The server already removed A from the feed (`DemoDispatchRepository.claimOffer` line 565-566), so the trip is lost. Reproduced: match A, complete claim with success, pump 100 ms, emit `OfferWithdrawal(offerId: 'b', reason: claimedElsewhere)`, pump 2 s → `AcceptRide mounted: false; matching text: 1`. The demo fires `withdrawOffer(radarGroupTaken)` on its own timer (demo_dispatch_repository.dart:710-714), so the window is real, and a backend's `offer_withdrawn` can arrive at any moment.

**Suggested fix:** Use a separate timer for the won-match navigation (or push immediately and keep only the banner on a timer), and never let `_resolveMatchLost` for another offer touch the win timer; also ignore withdrawals while `_matchingOfferId` names a won trip.

### M22. Reservation claim that succeeds after the list unmounts is lost and later reported 'No longer available'

`lib/presentation/driver/scheduled rides/scheduled_rides.dart:278` (found by driver3)

**What happens:** Driver taps Accept on an open reservation and presses Back during the claim. Later they open Scheduled rides, see the reservation still under Requests, tap Accept, and get 'No longer available'. The reservation was assigned to them by dispatch and never reaches the Accepted tab, so no reminder, 'leave now' or waybill will come.

**Why:** `_claim` awaits `dispatch.claimOffer(ride.id)` (line 273) with the list screen's Back button active (`_buildHeader`, line 310-313). On success after unmount it returns false (line 278) and `_openRideDetails` stops before `_requests.remove`/`_accepted.insert` (line 222-224). The demo dispatch has already removed the reservation from `_reservations` and the Radar feed (demo_dispatch_repository.dart:537-544). The ride stays in the store's Requests; the next Accept calls `claimOffer` again, which now returns `unavailable` (line 559-560), so `_claim` runs `ScheduledRideStore.take(ride.id)` and shows 'No longer available' (line 286-291) to the driver who actually won it. The same path is hit when `_requests.remove(ride)` at line 223 fails because the request left the store while the claim was pending.

**Suggested fix:** Move the claim and the store mutation into `ScheduledRideStore` (not the widget) so a successful claim always moves the ride to Accepted regardless of the screen's lifetime; disable Back while `_claiming` is non-empty.

## Low (55)

### L1. DECISIONS.md still says contract v0.3.0 and has no record of the 0.4.0 bump that the code and tests pin

`docs/DECISIONS.md:26` (found by driver2)

**What happens:** A reviewer syncing the contract from upstream reads DECISIONS.md, re-syncs v0.3.0 and breaks contract_copy_test / the Rider-Driver realtime kinds added in 0.4.0.

**Why:** The decisions record says the source of truth is contracts/contract.json 'v0.3.0, copied byte-for-byte' (lines 26, 103) and refers to 'Contract v0.3'. contracts/contract.json line 3 is `"version": "0.4.0"` and test/contract/contract_copy_test.dart:39-43 asserts `"version": "0.4.0"` and `TripTransitions.contractVersion == '0.4.0'`. The documented intent and the enforced version disagree; per the audit rules, code that does not match the docs is a defect (here the docs are stale, which misleads reviewers about which shared contract the Driver app is pinned to).

**Suggested fix:** Update DECISIONS.md to v0.4.0 and add a doc/contract consistency check or a changelog entry for the 0.3 → 0.4 bump.

### L2. DECISIONS.md describes a 5 Hz marker throttle and a 20 m web GPS filter; the code instead pushes markers on a 33 ms ticker with distanceFilter 0 (D-07/D-08 design)

`docs/DECISIONS.md:85` (found by driver2)

**What happens:** An engineer reading DECISIONS.md believes web GPS is rate-limited to 20 m moves and markers to 5 Hz; on web every geolocation callback and up to 30 marker updates per second actually reach the map and the island (`NavigationController.setVehicle` → `notifyListeners`).

**Why:** The 'Active ride crash recovery (Safari / PWA)' decision says: `Map markers update on a 5Hz throttle ... GPS setState is gone; web GPS filter is 20m.` The trip subscribes with `watchPosition(distanceFilterMeters: 0)` for all platforms (`accept_ride_trip.dart:605`), and `DriverLocationService._streamSettings` forwards that 0 unchanged on web (`driver_location_service.dart:60-66`), so every browser callback reaches `_applyDriverPosition`; no 20 m filter exists anywhere in lib/ (grep for distanceFilter shows only 0 and 8). The marker path is `_ThrottledVehicleMap` with `Timer.periodic(33 ms)` (~30 Hz) feeding a `ValueNotifier<Marker?>` that `CustomGoogleMap._onLiveMarker` flushes once per frame via `GoogleMapsFlutterPlatform.instance.updateMarkers` (`custom_google_map.dart:216-243`), not 5 Hz. The later D-07/D-08 design (no widget rebuild per fix) is what prevents the Safari rebuild crash, so this is doc drift rather than a regression, but the decision record now describes guards that are not in the build.

**Suggested fix:** Either reinstate the documented web filter/throttle (e.g. `distanceFilterMeters: kIsWeb ? 20 : 0` and a 200 ms ticker) or update DECISIONS.md to describe the D-07/D-08 per-frame live-marker design.

### L3. Documented browser-key referrer restriction names a different Pages path than the one the deploy workflow actually serves

`docs/PRIVACY_SECURITY.md:33` (found by driver3)

**What happens:** Owner applies the documented referrer restriction `.../Movera-drider-/*` in Cloud Console -> the deployed site at `/Movera-driver-app/` loads the Maps script, Google rejects it, driverMapCamera.ready() never becomes true (see the blank-map finding) and the demo map is dead; alternatively the restriction is skipped and the public key stays usable from any site.

**Why:** PRIVACY_SECURITY.md instructs the owner to restrict the Maps browser key to HTTP referrer `https://baccarisverige-ux.github.io/Movera-drider-/*` (and BASELINE.md:5 names the repo `Movera-drider-`), but the git remote is `github.com/baccarisverige-ux/Movera-driver-app` and deploy-pages.yml builds with `--base-href "/Movera-driver-app/"`, so the live demo is served from `https://baccarisverige-ux.github.io/Movera-driver-app/`. The owner action the document prescribes is the only safeguard for a public key (the comment in web/index.html:37-39 relies on it); if followed literally it would block the real site with RefererNotAllowedMapError, and if the owner instead leaves the key unrestricted to keep the site working, the key is open to any origin. Either way the record does not describe the deployed artefact.

**Suggested fix:** Update PRIVACY_SECURITY.md (and BASELINE.md) to the current repository/Pages path, and record the applied restriction in the release evidence matrix.

### L4. Gate doc says verify runs `flutter analyze --no-fatal-infos`; workflow runs `--fatal-infos`

`docs/REVIEW_AND_MERGE_GATES.md:33` (found by driver1)

**What happens:** Developer runs the documented command locally, sees no errors, pushes; the verify job fails on an info-level lint.

**Why:** docs/REVIEW_AND_MERGE_GATES.md describes the verify job as running `flutter analyze --no-fatal-infos`, but .github/workflows/drider-ci.yml:47 runs `flutter analyze --fatal-infos`. The documented policy and the enforced policy differ: contributors following the doc locally will pass analysis with info-level diagnostics that then fail CI.

**Suggested fix:** Align the doc with the workflow (or vice versa).

### L5. docs/driver-camera-architecture.md is stale: it gives a 72% anchor, explore zoom 16.8, 45° following tilt, auto-zoom 17.5–14.75, 17.8/20° maneuver framing and a 35 m arrival flatten, but the code uses a 0.75 anchor, exploreZoom 11.7, tilt following zoom up to 67.5°, zoomForSpeed 15–13.625, turnZoom 15.4 and a 140 m ease to 60° tilt

`docs/driver-camera-architecture.md:35` (found by driver2)

**What happens:** Acceptance/device testers use the architecture doc as the spec (e.g. expect a 72% anchor or a flat arrival) and either pass wrong behaviour or fail correct behaviour; the CI web verifier gives no signal if the app's 0.75 anchor diverges from the doc.

**Why:** The document that the audit is told to treat as the record of intent no longer matches the shipped policy. Anchor: doc says `The driving anchor is 72% of screen height`; the trip passes `cameraAnchor: ... ? .75 : .5` (`accept_ride.dart:1234`), `MapOverlayInsets.drivingInsets` uses `height * .75` (`map_overlay_insets.dart:34`) and `CustomGoogleMap` documents `.75 drives` (`custom_google_map.dart:60`). `tool/verify_driver_map_web.cjs:362` and `:615` exercise `configure(..., .72)`, so the verifier checks the documented value, not the one the app sends. Zoom/tilt: doc lines 47-50 give Auto Zoom 17.5/16.5/15.5/14.75, maneuver zoom 17.8 with tilt easing to 20°, and `Last 35 m flattens for arrival`; the code has `zoomForSpeed` 15 → 13.625 (`driver_camera_controller.dart:198-209`), `turnZoom = 15.4` with tilt rising via `tiltForZoom` (189-191, 325), `arrivalMeters = 140`, `arrivalZoom = 15.5`, `arrivalTilt = 60` (194-196) and the comment `never flat`. Modes table: `Explore ... neighborhood zoom 16.8` vs `exploreZoom = 11.7` (line 92); `Following | Heading-up, 45 degrees` vs tilt from the zoom curve up to 67.5. The code comments make clear the newer numbers are the owner's intent, so the doc is stale.

**Suggested fix:** Update the Modes table, anchor percentage and zoom/tilt numbers in docs/driver-camera-architecture.md to the current constants, and have the verifier assert the anchor value the app actually passes (0.75).

### L6. ReservationRequestPreview.pickupAt is one hour off on daylight-saving switch days (adds minutes as absolute Duration to local midnight)

`lib/core/admin/driver_home_admin_content.dart:244` (found by driver4)

**What happens:** On Sunday 25 Oct 2026 (DST ends) a driver has a reservation 'Today 07:40'. The island says 'Leave now' and the reminder fires an hour early (06:40), and the countdown reads 1 h less than the clock; on 29 Mar it is an hour late, so 'leave now' appears after the pickup time.

**Why:** `pickupAt` builds the pickup instant as `DateTime(y, m, d + offset).add(Duration(minutes: minuteOfDay))`. `DateTime.add` adds absolute time, so when the 'Today'/'Tomorrow' date is a DST transition day in the zone (Sweden/France: last Sunday of March and October) the wall-clock result is shifted by an hour relative to the 'HH:mm' label. Reproduced with `TZ=Europe/Stockholm`: for 'Tomorrow 07:40' on 24 Oct 2026 the code yields 2026-10-25 06:40 (untilPickup 11h40 instead of 12h40); on 28 Mar 2026 it yields 08:40 (untilPickup 11h40 instead of 10h40). `untilPickup`, the 'leave now'/'go online for' island timers (home_scheduled.dart:94-131, 321-342), the Scheduled-rides sort (scheduled_rides.dart:630-632) and `SmartGap` clash detection (smart_gap.dart:67-68) all consume this value.

**Suggested fix:** Construct the wall-clock time directly: `DateTime(now.year, now.month, now.day + offset, minute ~/ 60, minute % 60)`.

### L7. _DemoReservationSet._at labels a next-day demo reservation 'Today' when the demo is booked on the spring-forward day itself (e.g. 29 Mar 2026), so its pickupAt is on the wrong day and untilPickup is null

`lib/core/admin/driver_home_admin_content.dart:492` (found by driver4)

**What happens:** Demo launched late on 28 March with a reservation lead that lands after midnight: Scheduled rides and the island show it as 'Today HH:mm' and its untilPickup is already negative, so it never becomes a 'Leave now' trip.

**Why:** Same pattern as scheduled_rides_notes.dart: `DateTime(at.y,m,d).difference(DateTime(anchor.y,m,d)).inDays` is 0 across the 23-hour spring-forward day, so `days == 0 ? 'Today' : 'Tomorrow'` yields 'Today' for a ride that is actually tomorrow. The resulting pickupDay feeds `pickupAt` (offset 0 instead of 1), so the demo reservation's countdown and clash logic are a full day off on that day. Demo seed data only (DemoReservations), hence low.

**Suggested fix:** Compare calendar dates (e.g. `DateTime.utc(at.year, at.month, at.day).difference(DateTime.utc(anchor.year, ...)).inDays`).

### L8. Demo document titles and demo notifications are localised once and cached, so they stay in the old language after the driver switches language

`lib/core/documents/document_expiry.dart:110` (found by driver1)

**What happens:** App starts in Swedish (zone default), the Home island already read the documents; the driver picks English in Settings. The island later says 'Försäkringsbrev expires in 7 days', the notification is 'Försäkringsbrev expires tomorrow' and the Documents screen keeps the Swedish names until the app is restarted. Conversely a Swedish driver always sees the three demo notifications in English.

**Why:** `DocumentExpiryStore.documents` lazily builds the demo list with `tr.docInsuranceLetter` etc. and caches it in `_documents` (line 110); only `load()`/`reset()` replace it and neither is called on a language change (`DriverLanguage.choose` → `_apply()` only flips `DriverAppTexts.language` and the notifier; no caller resets the store — grep shows no `DocumentExpiryStore.instance.reset()` in lib). The cached `title`/`shortTitle` feed the island and notification text (`home_account.dart:153-160` → `DriverNotices.documentExpiring(title: document.title, shortTitle: document.shortTitle)`), the Documents list (`documents.dart:224`) and the renewal sheet (`document_renewal.dart:65,168,304`). Reproduced with a throwaway test: with language `en` the first title is 'Insurance letter'; after setting the language to `sv` it is still 'Insurance letter' while `tr.docInsuranceLetter` is 'Försäkringsbrev'. The same pattern exists in `DriverNotificationFeed.items` (`driver_notifications.dart:127-128` caches `demoReceived`, whose first title is `tr.noticeNewScheduledRide` and whose bodies 'Tomorrow 07:40 · 126 kr · Tap to view', 'Bonus progress', 'Payout sent' are English literals even though a localised `tr.noticeScheduledBody` template exists).

**Suggested fix:** Keep language-independent ids/keys in `TrackedDocument` and resolve the title through `tr` at read time (or rebuild the demo list when `DriverLanguage.current` changes); build the demo notifications with the existing `tr.noticeScheduledBody` and arb keys.

### L9. Cash balance direction labels ('You owe Movera', 'Movera owes you', 'Settled') are hard-coded English and shown in the French/Swedish UI

`lib/core/earnings/cash_balance.dart:46` (found by driver2)

**What happens:** Driver app language is Svenska. A cash Premium reservation (fare 248,40 kr, cash 300,00 kr) is finished: the Collect-cash sheet and the trip's history detail show 'You owe Movera  −51,60 kr' in English between Swedish labels.

**Why:** `CashBalance.direction()` returns English literals and `directionLabel` is rendered on the cash-collect sheet (`cash_collect_sheet.dart:294`) and in history detail (`history_detail.dart:432`), screens that are otherwise fully localised through `tr`. The arb files only contain `totalYouOweMovera` / `totalMoveraOwesYou` (app_en.arb:911-912, app_fr.arb:422-423); there is no key for these three short labels, so a Swedish or French driver (the zone default for Sweden is `sv`, see `DriverLanguage`) sees an English line on every cash trip.

**Suggested fix:** Add `youOweMovera`, `moveraOwesYou`, `settled` keys to the arb files and return `tr.*` from `direction()` (or move the words to the presentation layer).

### L10. Offer, reservation and scheduled-ride distances and the rate percentages always use a '.' decimal in fr/sv, while the trip island and the route instruction copy use the localized ',' mark

`lib/core/geo/driver_distance.dart:9` (found by driver3)

**What happens:** Swedish driver on trip: island '1,2 km', navigation banner '1.2 km'; Radar card '4.2 km' beside a fare '104,80 kr'.

**Why:** `driverDistanceMeters` formats with `toStringAsFixed` (dot) and is used on offer cards, reservation maps and scheduled rides; `navigation_instruction_banner.dart:331-333` does the same for the banner distance; `driver_home_admin_content.dart:74` (`cancellationLabel`) and acceptance_rate.dart:30 / cancelation_rate.dart:30 format percentages with a dot. `adaptive_trip_island.dart:519-521`, by contrast, replaces '.' with `tr.navDecimalMark` (',' in fr/sv). During navigation the island says '1,2 km' while the banner under it says '1.2 km'. Swedish and French conventions use the comma, as Money already does ('104,80 kr').

**Suggested fix:** Route all decimal formatting through one helper that applies `tr.navDecimalMark` (or NumberFormat with the driver locale).

### L11. Corrupt-record warnings log the raw stored JSON (rider names, addresses, free-text notes) through FormatException.toString()

`lib/core/history/prefs_trip_history_repository.dart:88` (found by driver4)

**What happens:** A localStorage write is cut off mid-blob (web quota, process kill). On the next History open the console/crash log receives 'WARN History JSON malformed: FormatException: Unexpected end of input (at character N) ..."riderName":"Angelica Holm","pickup":"Sveavägen 12...' — rider PII in a log that is meant to be shippable to a crash reporter.

**Why:** `DriverLogRecord` documents that messages 'must not contain rider names, phone numbers or free text' (driver_log.dart:5-6), and the default sink prints to the console in release builds too (`debugPrint`, driver_log.dart:42). Several readers interpolate the `FormatException` thrown by `jsonDecode` into the message. Dart's `FormatException.toString()` appends a window of the `source` string around the failing offset, so the log line carries whatever personal data sits near the corruption. Verified with a dart script: `jsonDecode` of a truncated history blob logged `...:"Angelica Holm","pickup":"Sveavägen 12, Stockholm","phone":"+46701234567"` under 'History JSON malformed:'. Affected in-scope sites: history (`prefs_trip_history_repository.dart:88`, rider names/addresses), ride-check log (`ride_check_log.dart:104`, includes the driver's 'What happened' free text and answers), and settings (`settings_repository.dart:84` builds `reason: '$storageKey: $error'` which `local_quarantine.dart:62` logs; settings sections hold trusted-contact phone numbers and vehicle drafts). The same pattern exists in `prefs_active_ride_repository.dart:81` (out of scope) via `DriverLog.error(..., error, stack)` which the sink prints verbatim.

**Suggested fix:** Log only `error.message` (and offset) for FormatException, never `$error`/`error.toString()`; in `DriverLog._debugSink` scrub `FormatException.source` before printing so no sink can leak stored blobs.

### L12. Island strip message '<stop> next' concatenates a hardcoded English word onto a localized stop label

`lib/core/island/trip_island_controller.dart:322` (found by driver1)

**What happens:** A French- or Swedish-language driver on a multi-stop trip sees the island strip read 'Arrêt 1 next' / 'Stopp 1 next' when heading to a stop.

**Why:** TripStripController.update says `_say('${next.stopLabel} next')` when a stop leg starts. stopLabel comes from AdaptiveTripIsland.pointLabel (adaptive_trip_island.dart:271), which is `tr.stopNumber(_stopCursor + 1)` (accept_ride.dart:809) and is localized ('Arrêt 1' / 'Stopp 1' per app_fr.arb:27, app_sv.arb:27). Every other message in this controller goes through `tr.` (riderBags, trafficAheadValueMin, arrivingInEtaMinTimeTime2, nextTripSecuredNextTripFare, pickupOnPickupSideSide, tollAhead). There is no arb key for this string (grep of app_en.arb finds only holdToStopNextTrips / cancelReasonNextTripOtherDetail).

**Suggested fix:** Add an l10n key (e.g. `stopNext`: 'Stop {number} next' / 'Arrêt {number} ensuite' / 'Stopp {number} härnäst') and call `_say(tr.stopNext(...))`, or pass the already-localized full phrase in TripStripInput.

### L13. The 'same fix reported again' guard compares the route by identity, so every route refresh/reroute resolves the same GPS fix twice and doubles the per-fix zoom, speed and bearing smoothing steps

`lib/core/navigation/driver_camera_controller.dart:552` (found by driver4)

**What happens:** During a reroute mid-turn the camera rotates and zooms with a visibly bigger single step than on other fixes (e.g. zoom 0.5 instead of 0.25 in one frame), the exact effect the guard was written to prevent.

**Why:** `update()` returns early only when `identical(location, _location) && identical(route, _route) && ...`. The trip calls `_camera.update(location, route: _navigation.route)` in `_applyDriverPosition` (`accept_ride_trip.dart:665`) and again from `_followVehicle()` after `_refreshRoadRoute()` (`accept_ride_trip.dart:731`). Whenever that refresh produced a new `RoadRoute` object (every 90 s silent refresh, every reroute, and `NavigationController.ensureRoute` always allocates a new `RoadRoute` at line 404), the second call passes the identity check and `DriverCameraPolicy.resolve` runs twice for one fix: `_smoothedSpeed` applies its 0.3 blend twice, `_cruiseZoom` may step up to 2×0.25 out / 2×0.4 in instead of once, and the bearing damping at lines 320-323 applies 0.65 of the remaining delta twice. The guard's own comment states the intent: 'Resolving it twice would smooth the turn twice.'

**Suggested fix:** When only the route changed for an already-resolved location, update the policy's route/geometry without re-running the speed, zoom and bearing smoothing (e.g. resolve with `immediate: false` but skip the smoothing when `identical(location, _location)`).

### L14. Demo notifications (scheduled-ride body, Bonus progress, Payout sent) are hard-coded English although the arb has noticeScheduledBody; the event arrival texts are admin-authored by design

`lib/core/notifications/driver_notifications.dart:333` (found by driver2)

**What happens:** Swedish driver opens Notiser: 'Ny bokad resa' followed by the English body 'Tomorrow 07:40 · 126 kr · Tap to view', then 'Bonus progress' and 'Payout sent' cards; 50 s after Home opens the island says 'Event tonight · City'.

**Why:** `DriverNotices.demoReceived` and `demoArrivals` build notices with English literals: body 'Tomorrow 07:40 · 126 kr · Tap to view', title 'Bonus progress' + body '18 of 25 trips this week. 7 more for 350 kr.', title 'Payout sent' + body '2 450,00 kr is on its way to your bank.', and the event arrival title 'Stockholm evening demand', body '18:00–22:30 · Central Stockholm. Be online before the main departure window.', island 'Event tonight · City'. `driver_notifications_screen.dart:256,280` renders `notice.title`/`notice.body` directly; the island shows `notice.island`. Other notices in the same file use `tr.*`, so this is an omission, not a design choice. In addition the list is cached once (`_items ??= DriverNotices.demoReceived(_now())`, line 134) so the localized parts keep the first language after a switch.

**Suggested fix:** Move these texts into the ARB (they are app demo content, not admin content) and build the list lazily per language.

### L15. formatDistance chooses the unit before rounding: 999.5-999.99 m shows '1000 m' and 9950-9999 m shows '10.0 km'

`lib/core/routing/route_instruction.dart:539` (found by driver1)

**What happens:** Island reads 'Turn left in 1000 m' for one or more fixes just before switching to '1.0 km'/'999 m', an inconsistent unit boundary visible to the driver.

**Why:** The branch chooses the metre format on the raw value (`meters < 1000`) but prints `meters.round()`, so 999.5..999.99 rounds up to 1000 and is rendered as `1000 m`, while 1000.0 renders as `1.0 km`. This is the live banner distance (`navigation_controller.dart:593` `distanceLabel: RouteInstructionCopy.formatDistance(meters)`), fed every fix with continuous metres from `RouteProgressCalculator`.

**Suggested fix:** Round first (`final rounded = meters.round();`) and branch on the rounded value, or use `meters < 999.5`.

### L16. Ride-check recordings are written to the iOS Documents directory, which is included in iCloud/iTunes backups, contradicting the 'saved only on this phone' permission text

`lib/core/safety/ride_check_recorder_native.dart:31` (found by driver3)

**What happens:** Driver with iCloud Backup enabled records a Ride check conversation with a rider; the .m4a is uploaded to Apple's servers with the next device backup although the app told the driver it stays only on the phone.

**Why:** `start()` saves audio under `getApplicationDocumentsDirectory()/ride_check_audio`. On iOS that is `NSDocumentDirectory`, which Apple backs up to iCloud/Finder by default unless the file is flagged `NSURLIsExcludedFromBackupKey` or stored under Application Support/Caches. `ios/Runner/Info.plist:9-10` tells the user 'The recording is saved only on this phone' and `safety_alert_repository.dart:36` repeats 'recordings stay on the phone'. Cabin audio of riders therefore leaves the device whenever the driver has iCloud backup on, which the stated promise and GDPR expectations do not cover.

**Suggested fix:** Store recordings under `getApplicationSupportDirectory()` and mark the folder excluded from backup (or set `NSURLIsExcludedFromBackupKey` on each file).

### L17. NativeRideCheckRecorder never disposes its AudioRecorder, so each trip leaks a native recorder; an empty capture's file is also left on disk

`lib/core/safety/ride_check_recorder_native.dart:48` (found by driver3)

**What happens:** Driver taps Record then immediately Stop on several trips: each leaves an empty `ride-check-<trip>-<ms>.m4a` in Documents/ride_check_audio (grows forever) and one undisposed native recorder per trip for the life of the process.

**Why:** `stop()` returns null for an empty capture but does not delete the file it just created in `ride_check_audio/` (line 48), so every failed/instant stop leaves an orphan `.m4a` under the app documents folder; nothing in the app ever lists or prunes that directory. Separately, `AudioRecorder` (record 7.1.1 exposes `Future<void> dispose()`, record.dart:173) is created per `RideCheckController` via `services.createRecorder()` (ride_check_controller.dart:234) and neither `NativeRideCheckRecorder` nor `RideCheckController.dispose()` releases it, so each trip in which the driver taps Record leaves a native recorder instance (method-channel/stream subscription) alive.

**Suggested fix:** Delete the empty file before returning null; add `dispose()` to `RideCheckRecorder` that calls `AudioRecorder.dispose()` and invoke it from `RideCheckController.dispose()`.

### L18. French plurals written as =1{1 ...} render a literal '1 course' / '1 arrêt' for count 0 (gen-l10n maps =1 to the CLDR 'one' slot, which in fr covers 0)

`lib/l10n/app_fr.arb:713` (found by driver1)

**What happens:** French driver opens history with no rides or a reservation with zero stops; the counters read '0 courses' / '0 arrêts' instead of '0 course' / '0 arrêt'.

**Why:** French grammar uses the singular for 0 and 1 (CLDR 'one' covers 0 and 1 for fr). The ARB strings tripsCount (713), stopsCount (714), riderBags (676), inDaysCount (861), schedRidesHidden (904) and ratingAndRides (1319) are written as `{count, plural, =1{...} other{...}}`, so count 0 selects the 'other' branch and the UI shows '0 courses', '0 arrêts', 'Le passager a 0 bagages', 'dans 0 jours', '0 courses masquées'. The gen-l10n plural rules would do the right thing if the `one` category were used instead of `=1`. The English and Swedish files are fine with =1/other.

**Suggested fix:** In app_fr.arb use `one{...}` (CLDR category) instead of `=1{...}` for these keys, or add `=0{0 course}` branches.

### L19. A failed clearLocalUserData leaves the driver logged in with every long-lived storage repository invalidated (generation already bumped) and no recovery

`lib/main.dart:184` (found by driver2)

**What happens:** On a device where SharedPreferences commit fails for one key (full disk, broken prefs file), the driver taps Log out, sees 'Could not clear local data', continues driving; the next accepted trip is not persisted, so a crash mid-trip comes back to an empty Home.

**Why:** `clearLocalUserData()` calls `LocalWriteSession.beginCleanup()` (local_data.dart:114), which increments the generation before any key is removed; every repository instance created earlier (`_activeRide = PrefsActiveRideRepository()` in main.dart:93, the settings/vehicle stores held by open screens) now fails `LocalWriteSession.check` with 'Local session ended; reopen the screen before saving'. If a `prefs.remove` returns false the function throws (local_data.dart:135-137/148-150), `_logout` rethrows before reaching `_activeRide = PrefsActiveRideRepository()` (main.dart:187) and `_session.reset()`, and Profile just shows 'could not clear' and keeps the driver signed in (profile.dart:397-406). From then on active-ride snapshots and terminal markers can no longer be written (every enqueued op logs 'Active-ride storage operation failed'), so crash recovery of a trip silently stops working, and local data is half-cleared, until the process restarts.

**Suggested fix:** Recreate the composition-root repositories (and reset the session) in a `finally`, or bump the generation only after the removals succeeded / roll it back on failure.

### L20. Disposing AcceptRide while a Ride check is open makes Home call setState during finalizeTree: a debug-only 'widget tree was locked' error, and in debug the held radar offers are not released

`lib/presentation/driver/accept ride/accept_ride.dart:679` (found by driver1)

**What happens:** A Ride check card is open (long stop / off-route) when the rider cancels (or admin releases the trip); the trip screen pops. In a debug or profile build the framework reports "setState() or markNeedsBuild() called when widget tree was locked" during finalizeTree and AcceptRide's dispose is cut short, leaving its realtime subscription and timers alive.

**Why:** `_AcceptRideState.dispose` calls `_rideCheck.dispose()` (679). `RideCheckController.dispose` calls `_syncGate(false)` (ride_check_controller.dart 409), which, when the gate was held (a Ride check pill/card was open), sets `RideCheckGate.set(false)` → `ValueNotifier` notifies synchronously. Home is still mounted underneath and its listener `_rideCheckGateListener` → `_onRideCheckGate` (home_offer_radar.dart 473-478) runs `_rebuild(() {})`, i.e. `setState` (home.dart 338), from inside another State's `dispose`. State.dispose runs in `BuildOwner.finalizeTree` under `lockState`, where `markNeedsBuild` asserts "setState() or markNeedsBuild() called when widget tree was locked". In debug/profile builds the FlutterError is thrown out of `_rideCheck.dispose()`, so the remainder of `AcceptRide.dispose` (camera, realtime subscription/unsubscribe, timers, animation controllers at 680-700+) never runs, leaking the realtime subscription, the 20 s ride-check ticker already cancelled but `_waitTimer`, `_nextTrip*` timers and the two AnimationControllers (which then also report "disposed with an active Ticker"). Release builds only mark Home dirty and rebuild.

**Suggested fix:** Close the gate before the route is popped (e.g. in `_pauseLiveUpdates`/the exit paths) or defer the Home reaction with `WidgetsBinding.instance.addPostFrameCallback`/`scheduleMicrotask` in `_onRideCheckGate`; alternatively have `RideCheckController.dispose` schedule `RideCheckGate.set(false)` asynchronously.

### L21. Hard-coded English 'stop'/'pickup' is injected into the localized 'move within 100 m' message

`lib/presentation/driver/accept ride/accept_ride_trip.dart:503` (found by driver1)

**What happens:** App language Swedish; driver taps 'I've arrived' more than 100 m from the pickup: snackbar reads 'Kom inom 100 m (pickup) för att vara framme.'

**Why:** `_blockedArrival` builds `final where = _stage == ActiveRideStage.onTrip ? 'stop' : 'pickup';` and passes it to `tr.moveWithin100MOfWhere(where)`. The Swedish and French strings interpolate the raw word: `'Kom inom 100 m ($where) för att vara framme.'` / `'Approchez-vous à moins de 100 m ($where) ...'`, so Swedish and French drivers see 'Kom inom 100 m (pickup)'.

**Suggested fix:** Pass localized words (`tr.stop` / `tr.pickup`) or two separate localized messages.

### L22. After 'I've arrived', the pickup route line stays on the map during the wait until the car moves at least 0.4 m (or a GPS snapshot persist fires), because the route-cleared notification is dropped while _stageTransitioning is set

`lib/presentation/driver/accept ride/accept_ride_trip.dart:562` (found by driver1)

**What happens:** Driver taps 'I've arrived' at the pickup. The waiting stage starts but the black route line to the pickup (and the old ETA value) remain on the map for the whole wait.

**Why:** `_confirmPickupArrival` sets `_stageTransitioning = true` (541) and awaits `transitionTo(waitingForRider)`; the controller's commit notifies `_syncNavigationStage` → `NavigationController.setStage` which clears `_route` and notifies (navigation_controller.dart:163-188). `_onNavigationChanged` returns at once because `_stageTransitioning` is still true (562), so `_roadGeoPoints`/`_routeDurationSeconds` keep the pickup route; the following `_rebuild(() {})` (558) calls `_syncRouteLines()` which redraws that stale route. During waiting `ensureRoute` returns early and `setVehicle` does not notify while the car is parked (moved < 0.4 m, navigation_controller.dart:242-246), so nothing clears it until the car moves. `_routeEtaText` likewise keeps the old duration (`routeFraction` is null → full duration) while waiting.

**Suggested fix:** Do not skip `_onNavigationChanged` during a stage transition (or re-run it in `_unlockStageAfterFrame`), and clear `_roadGeoPoints`/`_routeDurationSeconds` explicitly when entering waiting.

### L23. DECISIONS.md's '20 m web GPS filter' is not applied: the active ride passes distanceFilter 0 on web, so every browser fix is processed (the per-fix rebuild cost is already handled by D-07)

`lib/presentation/driver/accept ride/accept_ride_trip.dart:605` (found by driver1)

**What happens:** Safari PWA on an active trip: each raw geolocation fix (no distance gating) drives _applyDriverPosition, route-refresh checks and island updates, the very load pattern the recorded decision says was limited by a 20 m filter.

**Why:** DECISIONS.md ('Active ride crash recovery (Safari / PWA)', line 85) states the Safari tab-kill fix included 'web GPS filter is 20m'. The active ride subscribes with `watchPosition(distanceFilterMeters: 0)` and DriverLocationService._streamSettings builds `LocationSettings(accuracy: high, distanceFilter: distanceFilterMeters)` for web, so on web every browser geolocation callback (typically ~1 Hz, more on some devices) reaches _applyDriverPosition. There is no kIsWeb branch anywhere in accept_ride*.dart (grep shows none) and no constant 20 in the location code. The documented decision and the shipped behaviour differ; the task rules treat that as a defect to report.

**Suggested fix:** Either pass `distanceFilterMeters: kIsWeb ? 20 : 0` from the active ride (or apply the web filter inside DriverLocationService) or correct DECISIONS.md so the record matches the code.

### L24. A next-trip offer hidden for a Ride check comes back with a new full exclusiveAcceptTime, ignoring the time it was already on screen

`lib/presentation/driver/accept ride/accept_ride_trip.dart:1161` (found by driver1)

**What happens:** Offer shown with 20 s left; a Ride check opens and is answered after 10 s; the offer returns with the full exclusiveAcceptTime again instead of ~10 s.

**Why:** `_onRideCheckGate` (1137-1162) hides an open offer while the Ride check is up and records `_nextTripOfferHeldAt`. After the answer it checks only whether the full lifetime has elapsed since `heldAt` and then calls `_presentOnTripOffer()`, which calls `_armOnTripOfferExpiry()` with `left == null` → `_nextTripOfferDeadline = now + lifetime` (1163-1173). Time already spent before the check (and `_nextTripOfferDeadline`) is ignored, so the rider's offer is held open longer than Dispatch's time to accept; the comment and D-05 say a surviving offer counts down the rest.

**Suggested fix:** Keep `_nextTripOfferDeadline` when holding and re-arm with `left: deadline - now` (drop the offer when it is <= 0), as `_resumeOnTripOffer` does.

### L25. Cancelling the current trip with a secured next trip starts the next AcceptRide without destination mode, unlike completion and the journal snapshot

`lib/presentation/driver/accept ride/accept_ride_trip.dart:1394` (found by driver1)

**What happens:** Driver has destination mode on, secures a next trip, then ends the current trip early. The next trip's screen has destination mode off; Exclusive offers no longer follow the destination.

**Why:** `_submitTripCancellation` builds the next `AcceptRide` (1394-1414) without `destinationModeActive`, `destinationAddress` or `destinationPosition`, whereas `_completeCurrentTrip` (954-956) passes them and the journal's `next` snapshot (`_snapshotForOffer`, 971-979) stores them. After a driver cancel the next trip therefore runs with destination mode off (no on-the-way filter for next-trip offers, the trip options row shows 'next trips on your way' as off), while a crash restore of that same trip from the journal snapshot would restore destination mode on — the two paths disagree.

**Suggested fix:** Pass the three destination fields (or use `AcceptRide.fromPersisted(_snapshotForOffer(offer))` as the rider-cancel path does).

### L26. Route-progress semantics value is read out in English ('42 percent') in fr/sv

`lib/presentation/driver/accept ride/adaptive_trip_island.dart:1123` (found by driver4)

**What happens:** VoiceOver/TalkBack in Swedish announces 'Ruttframsteg, 42 percent'.

**Why:** The accessibility value of the route progress bar is built as `'${…} percent'` while its label uses `tr.routeProgress`; screen readers in Swedish/French read the English word.

**Suggested fix:** Use `tr.rcPercent(n)` or a dedicated ARB message.

### L27. Ride check card tells the driver 'Movera safety team alerted · Trip, driver and rider details were sent' while alerts only go to an in-memory demo outbox

`lib/presentation/driver/accept ride/ride_check_card.dart:703` (found by driver3)

**What happens:** On a trip the Ride check opens (long stop / off route), the driver picks 'Accident or collision' (a red topic): the card shows 'Movera safety team alerted. Trip, driver and rider details were sent.' although only DemoSafetyAlertRepository._alerts was updated.

**Why:** docs/REVIEW_AND_MERGE_GATES.md 'Product truth gate': safety recording/sharing is not a connected service and 'UI must not claim those actions succeeded when only local state changed'. The composition root wires `DemoSafetyAlertRepository` (main.dart:96, an in-memory map/journal) into `RideCheckServices`; `RideCheckController._ensureAlert` marks `_alert` set as soon as that repository returns, and `_alertNote` then renders `tr.moveraSafetyTeamAlerted` + `tr.tripDriverAndRiderDetailsWere` with no demo qualifier, unlike the rating screen ('Rating not sent (demo)') and chat ('Local preview · not sent'). On a red topic (accident, safety concern) the driver is told help was notified when nothing left the phone. Mitigation: a persistent 'demo' banner sits at the top of the app, which is why confidence is low.

**Suggested fix:** Qualify the note while the demo repository is installed (e.g. 'Demo: alert kept on this phone') or expose a `supportsDelivery` flag on SafetyAlertRepository and only claim 'alerted' when a real transport confirms.

### L28. The 'photo storage full' budget error is shown in English in the vehicle documents SnackBar (the per-photo size error is already caught earlier with localized text)

`lib/presentation/driver/add vehicle/add_vehicle.dart:501` (found by driver2)

**What happens:** Swedish driver attaches a large registration photo: a SnackBar in English appears on an otherwise Swedish screen.

**Why:** `VehiclePhotoBudgetExceeded` is thrown with English copy in local_vehicle_store.dart:150 ('Photo is too large to keep on this device.') and :170 ('Photo storage on this device is full. Remove photos from another vehicle first.'); add_vehicle.dart catches it and shows `error.message` verbatim, while the generic catch right below uses a localized string.

**Suggested fix:** Give the exception a code/kind and map it to `tr` in the screen.

### L29. 'DEMO DATA' badges (Analytics, Driving log) and the 'DRIVING IN' header (Documents) are hardcoded English on localized screens

`lib/presentation/driver/analytics/analytics.dart:60` (found by driver4)

**What happens:** Swedish driver opens Dokument: a header 'DRIVING IN' sits above 'Stockholm'; Analys and Körlogg both open with an English 'DEMO DATA' badge.

**Why:** These eyebrow labels and sample rows are visible text on screens whose other strings all come from `tr`. analytics.dart:60 'DEMO DATA', :108 'Central Station → Södermalm', :117 'Comfort · 21:42'; driving_logs.dart:50 'DEMO DATA'; documents.dart:76 'DRIVING IN' (the section header above the zone name). No ARB key exists for 'DEMO DATA' or 'DRIVING IN'.

**Suggested fix:** Add ARB keys (demoDataBadge, drivingIn, sample trip row) and use them.

### L30. English copy 'Did you don’t get code?' is ungrammatical

`lib/presentation/driver/auth/phone verification/phone_verify.dart:122` (found by driver3)

**What happens:** Legacy auth > Create account > phone > Continue: the screen shows 'Did you don’t get code?'.

**Why:** `tr.didNotGetCode` is rendered on the phone verification screen; the English source string in app_en.arb:2150 is `"Did you don’t get code?"`. French and Swedish translations are correct ('Vous n’avez pas reçu de code ?', 'Fick du ingen kod?'), so only the English UI is broken.

**Suggested fix:** Change the English string to 'Didn’t get the code?'.

### L31. Divider word 'or' is hardcoded English and not translated

`lib/presentation/driver/auth/sign in/sign_in.dart:62` (found by driver4)

**What happens:** Set language to Svenska and open Sign in: 'Fortsätt med telefon' / 'or' / 'Fortsätt med Apple'.

**Why:** Every other string on the screen goes through `tr`, but the divider uses the literal `"or"`, so French and Swedish users see 'or' between the sign-in options. The app supports en/fr/sv via `AppLocalizations`.

**Suggested fix:** Add an `orWord` key to the arb files and use `tr.orWord`.

### L32. Destination search result count is the English literal '${results.length} found'

`lib/presentation/driver/destination mode/destination_picker.dart:361` (found by driver2)

**What happens:** French driver types a destination: header reads 'Résultats   3 found'.

**Why:** While the search field is non-empty the picker shows `'${results.length} found'` next to the localized section title; nothing in the ARB covers it.

**Suggested fix:** Add a plural ARB key (e.g. resultsFound) and use it.

### L33. Section label 'DRIVING IN' is hardcoded English on the Documents screen

`lib/presentation/driver/documents/documents.dart:76` (found by driver3)

**What happens:** Language Svenska > Profile > Documents: 'DRIVING IN' above 'Stockholm-resor'.

**Why:** Documents is a main-path screen (Profile > Documents). Its header eyebrow is `const Text('DRIVING IN', ...)` while the lines under it are localized (`tr.docStockholmTrips`, `tr.docEarnAnywhereSweden`), so French/Swedish drivers see an English label above a translated title.

**Suggested fix:** Add an arb key and use `tr`.

### L34. feeSuffix hardcodes 'kr' and a /100 divisor for whole cancel fees, ignoring the Money currency and exponent (latent until a non-SEK cancelFee arrives)

`lib/presentation/driver/home/components/home_island_notices.dart:72` (found by driver4)

**What happens:** In a French zone the backend sends cancelFee {amountMinor: 500, currency: 'EUR'}: the island and the rider-cancelled sheet say '· +5 kr' instead of '· +5,00 €'; for TND 5000 millimes they say '+50 kr' instead of '5,000 DT'.

**Why:** `feeSuffix(Money? fee)` prints `'${fee.minorUnits ~/ 100} kr'` whenever the amount is a whole number of minor-hundreds, ignoring `fee.currency` and its exponent (Money supports SEK/EUR with exponent 2 and TND with exponent 3; zone_settings maps EUR->FR and TND->TN). Only the non-whole branch uses `fee.formatted`. Callers: reservationCancelled island message (line 60-66), RiderCancelledSheet status line (rider_cancelled_sheet.dart:59-62), ScheduledRideStore.riderCancelled (scheduled_rides.dart:678). The fee is the backend's decision (R15-7) in the zone currency.

**Suggested fix:** Use `fee.formattedShort` (already drops a zero fraction and keeps the currency symbol/exponent) for both branches.

### L35. IslandMessages.posted grows without bound in production: every show() appends and only the test-only reset() clears it

`lib/presentation/driver/home/components/island_messages.dart:76` (found by driver1)

**What happens:** A driver keeps the app open for a long shift: every island message ever posted (and the closures of disposed Home states after logout/login) stays referenced in a static list until the process dies.

**Why:** `posted` is @visibleForTesting but show() unconditionally does `posted.add(message)` (line 76) in the production path; nothing in the app ever calls reset(). Each IslandMessage holds a title string and often a closure (onTap) that captures the Home state. Over a long online session (online/offline, matching, waiting tips are not posted here, but every match/taken/unavailable/cash/reminder/notification message is) the list keeps growing and keeps old State closures alive.

**Suggested fix:** Only record into `posted` under a test flag (kDebugMode/visibleForTesting hook) or cap its length.

### L36. _activateDestinationMode calls _goOnline() after its awaits without re-checking that destination mode is still active, so a driver who went offline or turned the destination off during the route fetch is put online

`lib/presentation/driver/home/home_map_sheet.dart:346` (found by driver1)

**What happens:** Driver confirms a destination, the road-route request is slow, and within those seconds they open the island sheet and tap "Turn off destination". The route request returns, and `_goOnline()` flips the driver online (radar starts, offers arrive) although destination mode is off and they never asked to go online.

**Why:** After the synchronous setup, `_activateDestinationMode` awaits `_refreshDestinationRoadRoute()` (a network road-route request) and `_fitDestinationRoute()` (341-342) and then unconditionally runs `_seedDemoDestinationTrips()`, `_maybeShowSoonReservation()` and `if (!_isOnline && !_isGoingOnline) { _goOnline(); }` (343-348). The inner helpers guard themselves, but `_goOnline` (home.dart 884-930) has no `mounted` check and calls `showDriverSuspendedSheet(context)`, `setState(...)`, `_startDriverLocation` and arms timers. If the driver turned the destination off during the fetch (island → details sheet → "Turn off destination" → `_endDestinationMode`, or the admin time limit timer at 313-318 fired) the driver is still switched online because of a destination that no longer exists; if Home was disposed during the await, `setState`/`context` are used after dispose.

**Suggested fix:** After the awaits add `if (!mounted || !_destinationModeActive || _destinationPosition != destination) { return; }` before seeding/going online (the same guard `_fitDestinationRoute` already uses at 404-406).

### L37. Re-showing the Exclusive offer already on screen restarts its countdown; the demo _directOfferTimer re-fires on every resume, so returning from any route resets the offer's time to the full lifetime (contradicts the D-04/R13-3 "time left" rule)

`lib/presentation/driver/home/home_offer_radar.dart:1175` (found by driver2)

**What happens:** Exclusive offer shows 9 s left; driver long-presses the radar, gets "Go offline?", taps "Stay online". The offer resumes at ~8 s, then 2.2 s later jumps back to 15 s and the Q16 miss clock runs again from scratch.

**Why:** _showOutsideRadarOffer lets an offer whose id equals the current _outsideRadarOffer through its guard (232) and then cancels _outsideOfferTimeoutTimer and calls _raiseExclusive → _startExclusiveClock, which resets the clock to 1 and the deadline to now+lifetime (251-259, home_exclusive.dart:89-93). _resumeHomeUpdates (home.dart:204-213) first restores the time left via _resumeOfferTimers → _resumeExclusiveTimeout, but it also calls _scheduleVisibleOffers, which re-arms _directOfferTimer (2.2 s) to show the demo Exclusive again (1175-1189). If the same offer is still up (e.g. the driver dismissed the Go-offline dialog, or came back from Ride history inside the 15 s), 2.2 s later its ring and pill jump back to 15 s. _seedDemoDestinationTrips (home_map_sheet.dart:458-466) and _releasePendingRadarOffers → _pendingAdminAssign have the same re-show shape.

**Suggested fix:** In _showOutsideRadarOffer return early when `_outsideRadarOffer?.id == offer.id` (the offer is already up), so only a new offer starts a clock.

### L38. '1 ride categories saved' – the saved-count snackbar is not pluralized

`lib/presentation/driver/preferences/preferences.dart:203` (found by driver4)

**What happens:** Leave only 'Movera' on and tap Save preferences: snackbar '1 ride categories saved'.

**Why:** `tr.prefCategoriesSaved(selectedCount)` is a plain placeholder string `"{count} ride categories saved"` (app_en.arb:2601; sv/fr likewise) rather than an ICU plural like `inDaysCount`. With exactly one category enabled, Save announces '1 ride categories saved' ('1 resekategorier sparade').

**Suggested fix:** Convert to `{count, plural, =1{1 ride category saved} other{{count} ride categories saved}}` in all arbs.

### L39. On first open, Profile shows 'Vehicle data unavailable' until primaryIdentity() resolves

`lib/presentation/driver/profile/profile.dart:162` (found by driver2)

**What happens:** Open Profile: the Vehicles row reads 'Vehicle data unavailable' for a frame or more, then 'Mercedes-Benz E 220'.

**Why:** The Vehicles link detail is `snapshot.data?.vehicle ?? tr.vehicleDataUnavailable` with no check of `snapshot.connectionState`. `primaryIdentity()` is async (SharedPreferences read through the serialized settings queue), so every open of Profile first paints the error text 'Vehicle data unavailable' and then replaces it with the vehicle name; after `_vehicleChanged` the same flash repeats. The same text is meant for the read-failure case (`primaryIdentity` returns null on error).

**Suggested fix:** Show an empty/loading detail while `snapshot.connectionState != ConnectionState.done`.

### L40. Cancelled/no-fare trip detail shows the quoted fare as 'Ride Cost' and an 'incl. +X kr Movera bonus' note

`lib/presentation/driver/ride history/history detail/history_detail.dart:400` (found by driver3)

**What happens:** Driver cancels a 152,40 kr admin radar-group trip with a 40 kr bonus before pickup. History list shows '—'; opening it shows 'Ride cost 152,40 kr' and 'incl. +40 kr Movera bonus' above 'Cancelled by driver'.

**Why:** `_buildSummaryRows` always renders `_detailRow(tr.rideCost, _ride.fare)` and, when `driverBonus` is set, the 'incl. +X kr Movera bonus' note (line 400-416), regardless of `_ride.status`. History records for driver/rider cancels are written with the waybill's quoted fare (`prefs_trip_history_repository.dart:212 'fare': record.fare`) and status `cancelled_by_*`/`searching`. The list is careful about this: earnings show '—' for non-completed rides (ride_history.dart:82) and the bonus note is guarded by `status == completed` (ride_history.dart:898). The detail contradicts it, presenting an amount and a bonus as the cost of a trip that ended with no fare.

**Suggested fix:** Guard the fare row and the bonus note on `status == TripStatus.completed` (show '—' otherwise), matching the list.

### L41. Cash balance direction row is English-only ('You owe Movera') in the localized detail screen

`lib/presentation/driver/ride history/history detail/history_detail.dart:432` (found by driver3)

**What happens:** Swedish driver opens a completed cash trip in History: 'Kontant insamlat 300,00 kr', then 'You owe Movera −51,60 kr', then the Swedish settlement note.

**Why:** The cash-trip rows use `cash.directionLabel`, which is `CashBalance.direction` returning hardcoded English strings (cash_balance.dart:46-50: 'You owe Movera' / 'Movera owes you' / 'Settled'). The surrounding rows (`tr.cashCollected`, `tr.cashMatchedYourFare`, `tr.settledInYourNextPayout`) are translated, so the Swedish/French screen mixes one English label into the money summary.

**Suggested fix:** Map the direction to `tr` keys at the presentation layer (the sheet already has `totalYouOweMovera`/`totalMoveraOwesYou`).

### L42. Overview counts and empty-state disagree about what a 'ride' is (cancelled trips counted in some places, not others)

`lib/presentation/driver/ride history/ride_history.dart:390` (found by driver1)

**What happens:** A week with 0 completed and 3 cancelled trips: Rides metric '0', no 'No completed rides in this period' text, two cancelled cards under Latest rides, button 'View all 3 rides', and the All rides header '0 rides in Last 7 days' above three cards.

**Why:** `_periodRidesList` (line 100-111) contains every record with a `completedAt`, cancelled ones included. The overview's 'Rides' metric uses `_periodRides` (completed only, line 145), but the empty state `tr.noCompletedRidesInThisPeriod` is shown only when the whole list is empty (line 390), 'Latest rides' takes the first two of all records (line 392) and the button says `viewAllVisibleRideCountRides(_periodRidesList.length)` (line 306, 403). The All-rides summary row then says '{_periodRides} rides in {period}' while listing more cards.

**Suggested fix:** Decide one definition (all finished trips vs completed) and use it for the metric, the empty state, the count and the summary row.

### L43. All-rides list prints raw wire status names and a hardcoded 'cancelled_by_driver'

`lib/presentation/driver/ride history/ride_history.dart:940` (found by driver1)

**What happens:** A rider cancels a trip. In History › All rides the card's status line reads `cancelled_by_rider`; tapping it shows 'Cancelled by rider'. In Swedish the list still shows the English snake_case token.

**Why:** The non-compact history card shows `ride.status == completed ? tr.completed : ride.status.isReleasedToDispatch ? 'cancelled_by_driver' : ride.status.wireName`. Every non-completed outcome is therefore shown as its wire identifier with underscores (`cancelled_by_rider`, `no_show`, `expired`, `cancelled_by_system`) and the released-to-dispatch case as the literal `cancelled_by_driver`, in every language. The detail screen for the same record translates these (`_buildMetaRows`, history_detail.dart:455-467), so the list and the detail disagree.

**Suggested fix:** Reuse the outcome mapping from `_buildMetaRows` (or add a `TripStatus` → label helper) and show the translated outcome in the list.

### L44. Hardcoded English UI strings in localized screens

`lib/presentation/driver/ride requests/ride_requests.dart:648` (found by driver3)

**What happens:** Driver language is French. Radar header shows '3 OFFERS', destination search shows '2 found', the bank form shows 'ACCOUNT', Analytics and Driving logs show 'DEMO DATA', the queue sheet shows '15-30 mins EST time'.

**Why:** The app ships en/fr/sv (`lib/l10n/app_*.arb`) and every other label on these screens goes through `tr`, but several user-visible strings are literals: ride_requests.dart:648 `label: 'OFFERS'` on the live count badge; destination_picker.dart:361 `'${results.length} found'` under the search box; add_new_account.dart:253 section header `'ACCOUNT'`; analytics.dart:60 and driving_logs.dart:50 `'DEMO DATA'`; my_queue_pos.dart:121 `"15-30 mins EST time"` (also an abbreviation the driver cannot read). They stay English in Swedish and French.

**Suggested fix:** Move each string into the ARB files and read it through `tr`.

### L45. On web builds without a tel: handler (desktop or non-telephony tablet browsers), the Safety toolkit says 'Emergency dialer opened' because url_launcher_web always returns true

`lib/presentation/driver/safety toolkits/safety_toolkits.dart:95` (found by driver4)

**What happens:** Driver using the PWA on a laptop/desktop (or a tablet without telephony) taps Call 112 -> browser does nothing or shows a silent protocol prompt -> app shows 'Dialer opened' / ride-check card advances to 'Called 112' with alertSent, though no call path exists.

**Why:** handoffEmergencyDial maps `launch()` true to EmergencyDialResult.opened, and the Safety toolkit then shows tr.safetyDialerOpened; RideCheckController.callEmergency likewise sets `_dialOpened = true` and moves the card to the 'called' state. The default launcher is `launchUrl(Uri.parse('tel:112'))`. url_launcher_web (2.4.3, url_launcher_web.dart:66-69, 112-115) documents that launchUrl 'Always returns true, except for disallowed schemes' because window.open with noopener cannot report success; on a desktop browser (or a mobile browser with no tel handler) nothing opens, yet the UI confirms the dialer opened. REVIEW_AND_MERGE_GATES.md's product-truth gate forbids claiming an action succeeded when it did not.

**Suggested fix:** On web, phrase the confirmation neutrally ('Opening 112…' / show the number to dial) instead of asserting the dialer opened, or gate the success copy on `!kIsWeb`.

### L46. 'PIN verification' tile title is hardcoded although tr.pinVerification exists

`lib/presentation/driver/safety toolkits/safety_toolkits.dart:179` (found by driver4)

**What happens:** Language Français > Settings > Safety > Safety preferences: tile reads 'PIN verification' with a French subtitle.

**Why:** In the Safety preferences sheet the first tile title is the literal `'PIN verification'` while its subtitle and the other tiles use `tr`. The key `pinVerification` exists in all three arb files (en 'Pin verification', fr 'Vérification par code') and is used by settings.dart:95, so this sheet shows English in fr/sv and even a different English spelling from Settings.

**Suggested fix:** Use `tr.pinVerification`.

### L47. Safety toolkit status banner shows a green success check for 'Could not open the dialer' and 'unavailable' messages

`lib/presentation/driver/safety toolkits/safety_toolkits.dart:452` (found by driver4)

**What happens:** On a device/browser where `launchUrl(Uri.parse('tel:112'))` returns false (web, tablet without telephony), tap Contact 112 > Call 112: a green check banner appears reading 'Could not open the dialer...'.

**Why:** `_status` is rendered in one fixed style: green background `0xFFE7F4EE` and `Icons.check_circle_outline_rounded` in green (lines 440-471). `_confirmEmergencyCall` puts `tr.couldNotOpenDialerDial112` ('Could not open the dialer. Dial 112 manually.') into the same banner when `handoffEmergencyDial` returns `unavailable`, and `_toggleRecording`/`_shareTrip` put 'Audio recording is unavailable in this demo.' there. The failure of the only real action in the sheet (112 dial) is thus visually confirmed as success.

**Suggested fix:** Carry a severity with `_status` (info/error) and style the banner/icon accordingly.

### L48. Sample accepted ride is seeded with a localized pickupDay, so its time logic silently differs by language

`lib/presentation/driver/scheduled rides/scheduled_rides.dart:445` (found by driver3)

**What happens:** In Swedish, a request whose time clashes with the sample 08:15 ride is still listed and can be accepted, and cancelling the sample ride 30 minutes before pickup is not counted as late; in English the same actions are blocked/counted.

**Why:** `_seedAccepted` sets `pickupDay: tr.tomorrow` on the `ReservationRequestPreview` (line 445). `pickupAt` only recognises the English keys 'today'/'tomorrow' (driver_home_admin_content.dart:246-251), so in Swedish ('Imorgon') or French the sample ride has `pickupAt == null`. Consequences inside this screen: `_clashWith` never treats it as clashing (smart_gap.dart:88-90 returns false), so the clash filter and the 'rides hidden' note behave differently from English; `freeCancelUntil` returns null so the cancel sheet shows the generic 'free X hours before' line instead of the real time and `isLateCancel` is never true; `upcoming` (line 626-634) excludes it so Home's reminders/leave-now never fire for it. The existing test (scheduled_rides_rules_test.dart:112) only asserts the English behaviour.

**Suggested fix:** Seed the model with the English key ('Tomorrow') and localize only for display (`ReservationWhen.dayWord`).

### L49. Scheduled ride cards show English 'Today'/'Tomorrow' in the Swedish and French UI

`lib/presentation/driver/scheduled rides/scheduled_rides.dart:1134` (found by driver3)

**What happens:** Driver language is Swedish. Scheduled rides lists 'Today, 07:40–07:45' and 'Tomorrow, 08:15' while the header, tabs and notes are Swedish; the same label is used in the details hero (line 1518).

**Why:** `_ScheduledRide.request` (line 1134) and `_ScheduledRide.fromRoute` (line 1117) format the card time with `tr.schedSeedTime(route.pickupDay, route.pickupTime)` using the model's raw English day key ('Today'/'Tomorrow', see `_DemoReservationSet._at` and `pickupAt`'s parsing of 'today'/'tomorrow'). The app has a localizer for exactly this (`ReservationWhen.dayWord`, reservation_when.dart:89-93, used by reservation_route_map.dart:427) but these two constructors do not use it. Every real request and every accepted ride in the list therefore reads 'Today, 07:40–07:45' / 'Tomorrow, 08:15' under Swedish or French.

**Suggested fix:** Pass `ReservationWhen.dayWord(route.pickupDay)` to `schedSeedTime` in both constructors.

### L50. 'tomorrow' is dropped from the free-cancel time on the spring DST day

`lib/presentation/driver/scheduled rides/scheduled_rides_notes.dart:11` (found by driver3)

**What happens:** On the last Sunday of March the driver opens an accepted ride for tomorrow 08:15. The plan card says 'Free cancel until 07:15.' with no day, which reads as today 07:15 (already passed), so the driver believes any cancel is now late.

**Why:** `_timeFrom` computes the day gap as `DateTime(y,m,d).difference(DateTime(y,m,d)).inDays`. On the day DST starts, local midnight to next local midnight is 23 h, so `inDays` is 0 and a time that is tomorrow is rendered as a bare clock ('07:15') instead of 'tomorrow 07:15'. Used by `_freeCancelLine` for `schedFreeCancelUntil` in the details plan card (scheduled_rides.dart:1705) and the cancel sheet (`_CancelRulesBox`). Reproduced in TZ=Europe/Stockholm: now 28 Mar 2027 12:00, until 29 Mar 07:00 → `inDays=0`.

**Suggested fix:** Compare calendar dates (`DateUtils.dateOnly` and compute the day number difference in UTC), e.g. `DateTime.utc(time.year, time.month, time.day).difference(DateTime.utc(now.year, now.month, now.day)).inDays`.

### L51. On web, if the Maps JavaScript script is blocked or fails to load, every CustomGoogleMap stays a plain land-colour box with no 'map unavailable' message (the poll is cancelled on dispose)

`lib/widgets/custom_google_map.dart:281` (found by driver1)

**What happens:** Driver opens the PWA with a content blocker that blocks maps.googleapis.com -> Home shows the beige placeholder forever, 'Finding your location' resolves, offers arrive, but no map, route or car is ever drawn and no message explains why; the 50 ms timer keeps polling until the screen is disposed.

**Why:** On web `_mapsReady` starts as `web.ready`, which is false until `google.maps` is installed by driver_map_camera.js. If the Maps script never arrives (ad/privacy blocker, key referrer rejection returning an error script, captive portal, offline PWA start) the widget keeps a `Timer.periodic(50 ms)` running for its whole lifetime and renders `ColoredBox(color: MoveraMapPalette.land)` indefinitely. Nothing surfaces the failure to the driver: Home's own 8 s `_startWaitLimit` only covers the start position, not the SDK, and no caller of CustomGoogleMap can observe the not-ready state. The driver sees a flat colour where the map should be, with markers, routes and offer previews silently missing, and the DemoModeBanner/offer flow continue as if the map existed.

**Suggested fix:** Bound the wait (e.g. 10-15 s) and then show a 'Map unavailable' state / retry, or expose an onUnavailable callback so Home and AcceptRide can tell the driver.

### L52. With reduced motion (and on the far-cut path) a GPS retarget that arrives during the single moveCamera await is dropped: retarget() requires _looping but _run has already captured the goal, and the controller nulls its pending pose after calling retarget

`lib/widgets/google_driver_camera_port.dart:259` (found by driver2)

**What happens:** Driver with 'reduce motion' enabled on a 1 Hz GPS trip: occasionally a fix lands while the previous moveCamera is awaiting acknowledgement; that fix never reaches the map and the camera holds the previous position for an extra second.

**Why:** `animate()` marks `_looping = true` and starts `_run`. In the `reducedMotion || _logical == null` branch `_run` reads `initial = _goal`, awaits one `_move(...)` and returns; the same happens on the `_far` cut (`await _move(destination ...); break;`). While that `moveCamera` platform call is in flight the controller still sees `_busy == true`, so a new fix goes through `_request` → `_port?.retarget(pending); _pending = null;` (driver_camera_controller.dart:732-737). `retarget` stores the pose in `_goal` (it passes the `_looping` check), but nobody reads `_goal` again: `_run` returns, `finally` clears `_looping`, the session completes, the controller sets `_busy = false` and arms a 16 ms throttle with `_pending` already null. The fix is lost until the next one, so under reduced motion the car/camera skip fixes whenever a platform round-trip overlaps a GPS event. Narrow window (a few ms per fix) but a real contract break of `DriverCameraPort.retarget` ('the in-flight animation steers toward this pose').

**Suggested fix:** After the single move / far cut, re-check `_goal` and issue one more `_move` if it changed during the await (or keep `_pending` in the controller until the port confirms it consumed the retarget).

### L53. Counter badges show hard-coded English 'NEW' (default label) on Scheduled rides and 'OFFERS' on Ride requests

`lib/widgets/led_count_badge.dart:12` (found by driver3)

**What happens:** Swedish/French driver sees 'NEW' beside the request count on Bokade resor and 'OFFERS' on the Radar list.

**Why:** `LedCountBadge` renders `label` as visible text (line 72-80). `scheduled_rides.dart:169` uses the default `label = 'NEW'`; `ride_requests.dart:648` passes `label: 'OFFERS'`. The ARB already has `rrNew`/`orbNew` and `allOffers` (used by home_offer_radar.dart:1102), so these two sites were simply missed. Reproduced in the Swedish dump of Scheduled rides: `... 88, 02, NEW, 126.75 kr ...`.

**Suggested fix:** Pass `tr.orbNew`/`tr.rrNew` and `tr.allOffers` (or a new `offers` key).

### L54. Source-grep test asserts a dead switch arm, and no behavioural test covers a rider_cancelled event without a status

`test/core/driver_realtime_test.dart:215` (found by driver-j2)

**What happens:** A refactor changes line 252 to `if (event.status != null)`. A rider_cancelled event without a projection status then falls to the switch, where `_handleRiderCancelled` runs without the drain's retry or backoff. The source-grep test stays green because the dead case label still exists.

**Why:** The test asserts that the active-ride source contains `case DriverRealtimeKind.riderCancelled`. In `_onRealtimeEvent`, every riderCancelled event is caught by the early branch at accept_ride_trip.dart:252-255 (`event.status != null || event.kind == DriverRealtimeKind.riderCancelled` → set pending → return). The switch arm at line 277 that calls `_handleRiderCancelled` directly is dead code. The test checks the presence of that dead arm plus two strings that appear elsewhere, so deleting or breaking the real routing at line 252 would not fail it.

**Suggested fix:** Remove the dead switch arm, or route through it. Replace the source-grep test with a behavioural test that emits a rider_cancelled event without a status and asserts the trip ends.

### L55. Test 'the Home sound releases the player it made' only covers the injected (not-owned) case; the owned-player dispose path is never tested

`test/core/radar_offer_sound_test.dart:92` (found by driver2)

**What happens:** A refactor stops disposing the internally created AudioPlayer on Home dispose; every test stays green; drivers accumulate live audio players across Home re-creations (sound keeps playing / memory grows).

**Why:** The test name promises coverage of the D-17 ownership rule (a player created by the Home sound is disposed by it), but it injects a player and then asserts `expect(audio.released, isFalse)` with the comment 'An injected player belongs to whoever passed it in'. The path where the sound creates its own player and must dispose it is never exercised, so a leak of the self-made AudioPlayer (and its platform channel / audio session) would not be caught, while the test title tells reviewers it is.

**Suggested fix:** Rename this case to 'an injected player is not released' and add a second case that lets the sound build its own player via a factory hook and asserts dispose is called.

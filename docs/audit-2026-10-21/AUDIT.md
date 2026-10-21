# Movera driver app: bug audit

Confirmed: 199 (high 11, medium 65, low 123). Rejected as false alarms: 62.

Runs finished: 13 of 18. Still running at this save: none.

Each finding was checked by an independent code tracer and a reproducer (often with a throwaway flutter test), with a third reviewer on disagreements. Findings from read-only runs were verified by code reading only. Possible duplicates across runs are not yet merged.

## High (11)

### H1. Pages deploy trusts workflow_run.head_branch == 'main', so a fork pull request from a branch named main gets built with secrets and deployed to the production Pages site

`.github/workflows/deploy-pages.yml:31` (found by r2-driver1)

**What happens:** An outside contributor forks the repository and opens a pull request from their fork's `main` branch, changing web/index.html or lib/ to show a phishing page. If CI runs without approval and passes, deploy-pages builds the fork's head_sha with the maps secret and publishes it to the official Movera Driver Pages URL. Any running main deployment in the `pages-main` concurrency group is cancelled.

**Why:** deploy-pages.yml runs on `workflow_run` after any completed 'Drider CI' run. Drider CI also runs on `pull_request`, including pull requests from forks. The build job's only check is `github.event.workflow_run.conclusion == 'success' && github.event.workflow_run.head_branch == 'main'`. For a fork pull request, head_branch is the fork's branch name, so a fork whose branch is called `main` passes the check. The job then checks out `github.event.workflow_run.head_sha`, which is the fork's commit (GitHub can fetch it through refs/pull). It runs `flutter pub get` and `flutter build web` on that attacker-controlled tree, with `secrets.newmap131189` in the environment and a job token that has `pages: write` and `id-token: write`. `deploy-pages@v4` then publishes the result. A workflow_run event runs in the default-branch context, so the github-pages environment's default-branch rule does not stop it. Nothing checks `workflow_run.event == 'push'` or `workflow_run.head_repository.full_name == github.repository`. The concurrency key (`pages-${{ ... github.event.workflow_run.head_branch ... }}`, line 21) also puts that fork run into the `pages-main` group, where `cancel-in-progress: true` lets it cancel a real main deployment.

**Suggested fix:** Also require `github.event.workflow_run.event == 'push'` and `github.event.workflow_run.head_repository.full_name == github.repository` in the `if:` and in the concurrency key. Move `pages`/`id-token` permissions to the deploy job only.

### H2. An OSRM 'continue' or 'new name' step with a turning modifier (uturn, left, right, sharp …) reads "Continue straight 300 m" while the arrow shows the turn

`lib/core/routing/route_instruction.dart:663` (found by r2-driver4)

**What happens:** The route reaches a junction where the main road bends left (OSRM: {type:'continue', modifier:'left'}), or OSRM routes a U-turn as {type:'continue', modifier:'uturn'}. The trip banner and island read "Continue straight 300 m" while the icon shows a left or U-turn arrow. A driver who trusts the words drives straight on.

**Why:** In RouteInstructionCopy.cue, the continueStraight/newName branch special-cases only highway 'slight left'/'slight right' and tunnel/toll. Every other modifier falls through to RouteCueKind.continueStraight. OSRM routinely emits type 'continue' with modifier 'left'/'right'/'sharp …', which osrm-text-instructions reads as "Turn left to stay on X", and 'continue' + 'uturn' for turnarounds ("Make a U-turn"). symbolFor() handles the same step correctly: the uturn branch at line 879 and the modifier switch at 909-921 draw a U-turn or left arrow. NavigationController._bannerFor (navigation_controller.dart:575-588) builds banner.primary and banner.instruction from cue(), so the words contradict the arrow. Because continueStraight isOnward, the line is also worded as cruising ('Continue straight 300 m') instead of 'in 300 m'. build() at 573-575 has the same gap ('Continue on X').

**Suggested fix:** In the continueStraight/newName branch, return _turn(modifier) for any modifier other than ''/'straight' (and map 'uturn*' to uTurn), the same way the turn branch does. Mirror this in build().

### H3. A screen-reader scroll action on the trip slide runs the trip step with no confirmation dialog

`lib/presentation/driver/accept ride/accept_ride.dart:1681` (found by r2-driver2)

**What happens:** A VoiceOver user focuses the slide ('Complete trip') and does a three-finger horizontal swipe, or a TalkBack user does the scroll gesture. The trip advances (completed, or started before the rider boards) with no 'Confirm this trip action?' dialog.

**Why:** PHASE_53 says assistive-technology activation of the slide shows a confirmation dialog before the trip action runs. Only the Semantics onTap (_accessibleConfirm) does that. The inner GestureDetector has onHorizontalDragUpdate/onHorizontalDragEnd and is not excluded from semantics, so Flutter's RawGestureDetector adds SemanticsAction.scrollLeft/scrollRight to the same node. In Flutter (checked in /opt/flutter widgets/gesture_detector.dart:1786-1806 and rendering/proxy_box.dart:4253), scrollRight calls onHorizontalDragUpdate with delta = size.width*0.8 and then calls onEnd straight away. _update sets _fraction = 0.8w/(w-58) >= 0.78, which snaps to 1. _finish() then sees _fraction >= _trigger and awaits widget.onConfirmed(), which is _advanceRide(): Start trip, Complete trip, Go to stop. No dialog is shown. The regression test (test/audit/accessible_confirmation_test.dart) only fires SemanticsAction.tap.

**Suggested fix:** Pass excludeFromSemantics: true to the slide's GestureDetector (or wrap it in ExcludeSemantics/BlockSemantics), so the only assistive path is the Semantics onTap that opens the confirmation dialog. Add a test that performs SemanticsAction.scrollRight and expects no stage change.

### H4. Terminal exits call Navigator.pop() on whatever route is on top, so a rider cancel (or any authoritative outcome) while Chat/Preferences/a modal sheet is open leaves the dead trip screen mounted

`lib/presentation/driver/accept ride/accept_ride_trip.dart:452` (found by driver1)

**What happens:** Driver is waiting at pickup, opens Message rider (Chat page on top). The rider cancels; realtime delivers rider_cancelled. The Chat page closes, the trip screen stays with GPS stopped and the waybill discarded; nothing on it works any more and Back is blocked. The 'Rider cancelled' island notice is queued for Home, which is not reached.

**Why:** Every authoritative exit from the trip screen ends with a plain pop of the navigator: `_handleRiderCancelled` (lines 452-458 `final home = Navigator.of(context); if (next == null && home.canPop()) { IslandMessages.show(...); ... home.pop(); return; }` and 478-481), `_leaveAfterAuthoritativeOutcome` (388-389), `_leaveAfterRelease` (403-407) and `_submitTripCancellation` (1444-1446). `Navigator.pop()` removes the topmost route, not the AcceptRide route. The trip screen itself pushes other routes onto the same navigator while the trip is live: `_messageRider` pushes `Chat` (accept_ride_panel.dart:860-867), `_openRidePreferences` pushes `Preferences` (536-541), `_openDestinationPicker` pushes the picker, the island pushes `DriverRideHistory` (accept_ride.dart:1307-1308), plus modal sheets (trip options, rider profile, cash collect, waiting time, safety toolkit, the accessible-confirm AlertDialog). A realtime `rider_cancelled`/terminal/`searching` event arriving while any of those is on top therefore pops that page instead of the trip: `_handleRiderCancelled` has already journaled the cancel, set the lifecycle terminal, run `_pauseLiveUpdates()` (GPS off, wait timer off), `_waybills.discardCurrent()` and queued an island notice for a Home that is never shown. The driver is left on a terminal AcceptRide: the slide/arrive actions return silently (`_advanceRide` checks `_rideLifecycle.terminal`), cancel says it cannot be cancelled, `PopScope(canPop:false)` blocks Back. Reproduced with a throwaway widget test (Home -> AcceptRide waiting -> a page pushed on top -> `realtime.emit(riderCancelled)`): result `chatPopped=true tripStillMounted=true homeVisible=false island=Rider cancelled`. Rider cancelling while the driver is in the chat with that rider is a very plausible sequence.

**Suggested fix:** Pop to the trip's own route instead of the top route: capture `ModalRoute.of(context)` in the trip state and use `navigator.popUntil((r) => r != tripRoute && !r.isCurrent ...)` / `removeRoute`-style exit (e.g. `Navigator.of(context).popUntil((route) => route.isFirst)` when Home is the root, or `navigator.removeRoute(tripRoute)` after closing routes above it); for the `pushReplacement` branches first pop everything above the trip route.

### H5. After a driver cancel or no-show the session never ends the trip, so Home stays 'on trip': no offers and Go online does nothing

`lib/presentation/driver/accept ride/accept_ride_trip.dart:1384` (found by driver-j2)

**What happens:** The driver is online on Home and accepts a Radar trip. At pickup the wait passes the no-show time. The driver taps 'Rider didn't show' and confirms (or picks Cancel trip with any reason and confirms). The SnackBar 'Trip cancelled · …' appears and Home comes back, but the radar shows OFF and no offers ever arrive. Tapping OFF/Go online shows the 'online' island message, but the session stays onTrip and the driver never becomes available. The driving-time clock keeps running and can force a rest. Only an app restart recovers. Worked out by hand from the code; nothing was run.

**Why:** Every other way a trip can end releases the trip in the session controller: rider cancel (accept_ride_trip.dart:456/469), an authoritative outcome (:379), an admin release (:402) and completion (ride_completed.dart:71) all call `widget.sessionController?.stayOnlineAfterTrip()` (endTrip). `_submitTripCancellation`, which handles both a driver cancel and the driver no-show, never calls it. It journals the trip, calls `_rideLifecycle.cancel/noShow`, shows a SnackBar and then just `navigator.pop()`s (1439-1445). Nothing else ends the trip: Home's push of AcceptRide (home_offer_radar.dart:940, home.dart:567) has no `.then`, and AcceptRide.dispose does not touch the session. The DriverSessionController therefore keeps `_activeTripId = <cancelled trip>` and `_status = onTrip`. On Home, `_isOnline => _liveVisible && _recoveryResolved && _driverSession.availableForOffers` (home.dart:335) is false because `availableForOffers` needs `status == online`. Tapping Go online runs `_goOnline` (home.dart:884), which calls `beginGoingOnline()`. That returns at once when `_activeTripId != null` (driver_session_controller.dart:129). The 1.4 s timer's `completeGoingOnline()` then does nothing because the status is not goingOnline, yet the island still shows the 'online' notice. `setOnline` during a trip only flips `_offlineAfterTrip`. `DrivingTimeClock.sync(online: isOnline)` keeps counting driving time, because `isOnline` is true for onTrip. `didPopNext` skips restore because `activeTripId != null`. The same happens when the driver cancels with a secured next trip: the next AcceptRide's `beginTrip(next.id)` is ignored (driver_session_controller.dart:58-61), so the session keeps the cancelled trip's id until some later trip completes. No test confirms a driver cancel and then checks Home (integration_test/driver_lifecycle_test.dart:165 and test/widget_test.dart:2659 both tap 'Keep trip').

**Suggested fix:** In `_submitTripCancellation`, call `widget.sessionController?.stayOnlineAfterTrip()` after the lifecycle cancel/noShow succeeds and before `pushReplacement`/`pop`, as the rider-cancel and authoritative paths do. Add a widget test that confirms a driver cancel and a no-show from Home and expects LIVE/availableForOffers.

### H6. Home passes translated text as matchedVia, so waiting rules for reservations and scheduled rides depend on the UI language and stored sources are no longer English

`lib/presentation/driver/home/home_offer_radar.dart:837` (found by r2-driver4)

**What happens:** An XL reservation is accepted from its Exclusive card. In English, termsFor applies the scheduled rule (includedWaitingMinutes = 5) on top of the XL rule (3 free minutes, no-show at 3): 5 free minutes, no-show from 5:00. In Swedish the same trip gets 3 free minutes, the waiting fee starts 2 minutes earlier and 'Rider didn't show' unlocks at 3:00. The rider's charge and the driver's no-show right depend on the phone's language. If an admin raises includedWaitingMinutes (say to 10), every sv/fr reservation loses the extra free minutes. The 'Scheduled ride' rule line also disappears from the waiting sheet.

**Why:** _openOfferTrip passes matchedVia from tr.exclusiveReservation / tr.exclusiveOffer (line 837), ExclusiveReasons.text(assigned), which is tr.assignedByMovera (line 860), and tr.scheduledRide (home_scheduled.dart:236). AcceptRide builds its waiting terms from that string: _waitTerms = WaitingRules.current.termsFor(type: WaitingRules.typeOf(matchedVia: widget.matchedVia, ...)) (accept_ride.dart:988-995). typeOf only matches the English substrings 'scheduled' / 'reservation' (waiting_rules.dart:251). Swedish 'Exklusiv bokning' / 'Bokad resa' and French 'Réservation exclusive' (accented é) / 'Course planifiée' never match, so in sv/fr a reservation or scheduled ride falls back to WaitingRideType.normal. The same string is stored as WaybillRecord.source and as PersistedActiveRide.matchedVia. waybill.dart:46-47 documents that source values 'stay in English in storage', and sourceText only translates the English constants.

**Suggested fix:** Pass stable English source constants (as ride_requests.dart does with 'Movera Radar') or an enum, decide the waiting ride type from offer.reservation / scheduled flags rather than display text, and translate only for display through WaybillRecord.sourceText.

### H7. Closing (×) the Radar card whose Match claim is in flight leaves Home permanently in "Matching": no other trip can be matched and the won claim is dropped

`lib/presentation/driver/home/home_offer_radar.dart:895` (found by driver2)

**What happens:** Driver taps Match on a Radar card, then (within the claim's network latency) taps the small × on that card. Dispatch answers success: the trip is assigned to this driver on the server, but no trip opens; the remaining cards' Match buttons are disabled and the radar says "Matching / please wait" indefinitely. The driver cannot accept any trip until they go offline and online again; a scheduled "Leave now" in that state is handed to a backup driver.

**Why:** RadarOfferCard always shows the corner × on Home (onClose is always passed; radar_offer_card.dart:589-616 draws it regardless of `state`, including `matching`). _closeRadarHomeOffer (home_offer_radar.dart:890-896) calls _dismissRadarHomeOffer, which removes the offer from _radarHomeOffers and _homeRadarMatchStates (479-492) but never clears _homeRadarMatchingOfferId or _claimedHomeOffer. From then on: every other card's onMatch is null (`blocked != null && blocked != id ? null : ...`, 1127-1129), the radar orb is `busy` ("Matching · please wait", home_map_sheet.dart:1753-1774), _canStartScheduled is false so a scheduled "Leave now" goes to the backup driver (home_scheduled.dart:166-170, 177-178). When the dispatch claim resolves successfully, _claimHomeRadarOffer passes its guard (`_homeRadarMatchingOfferId == offer.id`), _resolveHomeRadarMatchWon sets _claimedHomeOffer and _openClaimedHomeOffer → 850 ms → _acceptRadarHomeOffer returns because the offer is no longer in _radarHomeOffers (925-928). _claimedHomeOffer stays set, so every later _scheduleVisibleOffers (resume) returns early at 1167-1170. The only exit is going offline (which runs _cancelAllOfferTimers without preserveClaim). The same path is reachable through _setAcceptsCash/_onCategoriesChanged, which dismiss listed offers regardless of claim state (home_offer_rules.dart:31-35, 52-56). Reproduced with a throwaway widget test (two offers on the deck, Match on `first`, tap `radar-offer-close`, then complete the claim with ClaimResult.success): AcceptRide never opened, `radar-match-second` onPressed stayed null and the orb read "Matching" 30 s later. Test result: `00:07 +2: All tests passed!`.

**Suggested fix:** Refuse × (and rule-driven dismissals) while `_homeRadarMatchingOfferId == offer.id` (pass onClose: null for a matching card), or make _dismissRadarHomeOffer clear _homeRadarMatchingOfferId/_claimedHomeOffer and cancel _homeRadarNoticeTimer when it removes the matching offer; and let _acceptRadarHomeOffer open the trip from _claimedHomeOffer even if the card was removed.

### H8. "Leave now" removes the accepted scheduled ride from the store before a push that silently does nothing when Home is not the current route

`lib/presentation/driver/home/home_scheduled.dart:220` (found by driver4)

**What happens:** Driver is online, has an accepted reservation for 07:40, and at 07:0x opens Scheduled rides (or any other screen/sheet) over Home to check it. The "leave now" moment arrives while that screen is on top: the ride disappears from Scheduled rides › Accepted, the island later flashes "Leave now for 07:40" and a notification "Leave now for 07:40 pickup" appears, but no trip screen ever opens; returning to Home shows no trip and the ride is gone for good (no backup hand-off either, since `_scheduled.ride` was set to null).

**Why:** `_planScheduled` arms `Timer(_clock.realUntil(start), () => _leaveNow(ride))` (line 161). These timers live in `_scheduled.timers`, which `_pauseHomeUpdates` (home.dart 192-203) never cancels, and `_leaveNow`/`_canStartScheduled` (lines 166-170, 175-189) only check `mounted`, `_recoveryResolved`, `_driverSession.availableForOffers`, `_claimedHomeOffer` and `_homeRadarMatchingOfferId`; neither `_routeVisible` nor `ModalRoute.isCurrent` is consulted. `availableForOffers` is `_status == online` (driver_session_controller.dart 34), which stays true while the driver is on any non-trip screen pushed over Home (Scheduled rides, Notifications, Settings, Support, Wallet, Ride history, a modal sheet such as the destination details sheet or the queue sheet). When the timer fires in that state, `_startScheduledTrip` (218-239) first calls `ScheduledRideStore.start(ride)` which is `_removeAccepted(ride) != null` (scheduled_rides.dart 638-660) and permanently drops the ride from Accepted, posts the "Leave now" island message and notification, and only then calls `_HomeOfferRadar(this)._openOfferTrip(...)` (home_offer_radar.dart 931-981) whose `pushSingle(context, ActiveRideTransition(AcceptRide(...)))` returns `Future.value()` without pushing because `ModalRoute.of(context)?.isCurrent == false` (single_route_entry.dart 11-13). `_planScheduled()` then re-plans for the *next* ride. Nothing re-opens or restores the removed ride; `didPopNext` only re-runs `_restoreActiveRideIfNeeded`, and no AcceptRide/persisted trip was ever created.

**Suggested fix:** Make `_canStartScheduled` require Home to be current/visible (e.g. `_routeVisible && ModalRoute.of(context)?.isCurrent == true`) and treat the not-current case like `_lateScheduled`/defer; or defer `_leaveNow` until `didPopNext` (store a pending ride and run it in `_resumeHomeUpdates`). Alternatively only call `ScheduledRideStore.start(ride)` after `pushSingle` has actually pushed (check its return/`navigator` state) and roll back on a no-op push.

### H9. Same defect as driver-74: "Leave now" removes the accepted ride from Accepted, then pushSingle silently does nothing while any route or sheet covers Home, so the trip never opens and the ride is lost

`lib/presentation/driver/home/home_scheduled.dart:234` (found by driver4)

**What happens:** Driver has accepted the 07:40 reservation, is online, and opens Scheduled rides (or any other screen) at 07:33. The smart-gap timer fires "Leave now": the ride leaves Accepted, the island (hidden) says "Leave now", no trip screen opens. Driver returns to Home: no active trip, the reservation is no longer in Accepted, nothing is persisted. The rider's ride is silently lost on this phone.

**Why:** _leaveNow() fires from a Timer planned in _planScheduled(). Its only guard is _canStartScheduled (home_scheduled.dart:166-170: _recoveryResolved, availableForOffers, no claim in flight); it never checks that Home is the current route. _startScheduledTrip() first calls ScheduledRideStore.start(ride) (line 220), which removes the ride from Accepted (scheduled_rides.dart:638-639 / 652-660), posts "Leave now" and then calls _HomeOfferRadar._openOfferTrip (line 234). _openOfferTrip cancels every offer timer and calls pushSingle(context, ActiveRideTransition(AcceptRide(...))) (home_offer_radar.dart:940). pushSingle returns Future.value() without pushing when `ModalRoute.of(context)?.isCurrent == false` or while another push's entry animation is running (single_route_entry.dart:11-15). The return value is ignored, the post-frame callback clears the offers, _planScheduled() moves on to the next ride. Nothing is persisted (AcceptRide is what writes the active-ride snapshot), so the ride is gone from the phone: not in Accepted, not an active trip. Home's didPopNext restore only re-opens persisted snapshots, so returning to Home does not recover it. Any pushed route over Home triggers this: Scheduled rides screen (where a driver is likely to be looking at exactly this ride), Wallet, Preferences, Support inbox, Ride history, Notifications, Documents, the Go-offline confirm dialog, the driving-time/performance/waybill/destination/safety modal sheets. Reproduced with a throwaway widget test (fast demo day, ride accepted, a MaterialPageRoute pushed over Home at ~07:33, then 12 s): `Leave now for 07:40 pickup` was posted, ScheduledRideStore.upcoming no longer contained the ride, find.byType(AcceptRide) was findsNothing before and after popping the covering route. Test result: `00:07 +2: All tests passed!`.

**Suggested fix:** In _leaveNow/_startScheduledTrip require Home to be visible and current (e.g. `_liveVisible && ModalRoute.of(context)?.isCurrent == true`), otherwise treat it like a pause: keep the ride in Accepted and retry from didPopNext/_resumeHomeUpdates (_onRadarLive already re-plans). Alternatively make _openOfferTrip check pushSingle's outcome and roll back (re-add the ride / not clear offers) when nothing was pushed.

### H10. System/browser Back on the Ride completed screen skips _finish(): the session stays 'on trip' and a handed-off next trip is never opened

`lib/presentation/driver/ride completed/ride_completed.dart:61` (found by r2-driver4)

**What happens:** I reproduced this in a throwaway widget test. session.beginTrip('A'), then I pushed BottomToTopTransition(DriverRideCompleted(sessionController: session)) and called tester.binding.handlePopRoute(). Result: the screen pops to Home and 'C: activeTripId=A status=DriverOnlineStatus.onTrip available=false', even after session.setOnline(true).

**Why:** _completeCurrentTrip replaces AcceptRide with BottomToTopTransition(DriverRideCompleted(...)) (accept_ride_trip.dart:959). The session's trip only ends in DriverRideCompleted._finish (line 71). The next trip is only opened there too (line 72-75). DriverRideCompleted has no PopScope. BottomToTopTransition is a plain ModalRoute, so Android Back, or browser Back on the web/PWA (handlePopRoute -> maybePop), pops it straight back to Home. The session then keeps _activeTripId = A with status onTrip. Home.didPopNext does not restore because activeTripId != null (home.dart:182). If a next trip B was secured, the journal has already handed B's snapshot to storage but nothing opens it. The driver sees an idle Home that cannot go online, while B's rider waits.

**Suggested fix:** Wrap the page in PopScope(canPop: false, onPopInvokedWithResult: (_, __) => _finish()) so every exit from the completed screen goes through _finish.

### H11. System Back on the Ride completed screen skips _finish(): the session stays on_trip and Home can never go online again (a secured next trip is dropped too)

`lib/presentation/driver/ride completed/ride_completed.dart:117` (found by r2-driver4)

**What happens:** The driver finishes a cash trip, sees Ride completed and presses the Android Back button instead of Done. Home shows the radar OFF. Each tap on it shows the 'online' island notice, but the driver never goes online and gets no offers until the app is killed and restarted. If a next trip had been secured, CompletionJournal already handed its snapshot into storage, but that trip never opens and the waybill keeps showing it as 'Next trip secured'.

**Why:** _completeCurrentTrip (accept_ride_trip.dart:965) uses pushReplacement to put DriverRideCompleted over Home. Only the Done button runs _finish(), and _finish() is the only code on this path that calls sessionController.stayOnlineAfterTrip() (-> endTrip(), which clears _activeTripId), promotes or clears the next waybill, and pushes the queued next ride. The screen's Scaffold has no PopScope (a grep of lib finds PopScope only in accept_ride, ride_check_card, profile, ride_history, emergency_contacts, app_update_sheet, home_back and support_inbox), and BottomToTopTransition is a plain ModalRoute. So Android Back pops straight to Home. After that, DriverSessionController keeps _activeTripId set to the completed trip with status onTrip. On Home, _isOnline needs availableForOffers (status == online), so it is false and the radar shows 'OFF · Tap to scan'. Tapping it runs _goOnline(), which calls _driverSession.beginGoingOnline(). That method returns at once because _activeTripId != null, yet Home still posts IslandMessages.show(HomeIslandNotices.online). completeGoingOnline() then does nothing because the status is not goingOnline. didPopNext only re-runs recovery when activeTripId == null, so nothing repairs this. DrivingTimeClock.sync(online: isOnline) also keeps counting driving time, because isOnline is true for onTrip.

**Suggested fix:** Wrap the DriverRideCompleted Scaffold in PopScope(canPop: false, onPopInvokedWithResult: (didPop, _) { if (!didPop) _finish(); }) so Back takes the same exit as Done.

## Medium (65)

### M1. Device-to-device transfer rules leave the 'root' domain (app_flutter) included, so Ride-check audio recordings move to a new phone despite 'saved only on this phone'

`android/app/src/main/res/xml/data_extraction_rules.xml:10` (found by r2-driver2)

**What happens:** A driver records audio in a Ride check on an Android 12+ phone, then sets up a new phone with Google's 'copy apps & data' cable or wireless transfer. The rider-incident recordings in app_flutter/ride_check_audio/*.m4a are copied to the new device, although the app promised they stay only on the original phone.

**Why:** For apps targeting Android 12+ (targetSdk = flutter.targetSdkVersion = 36), `android:allowBackup="false"` no longer turns off device-to-device migration. Only the `<device-transfer>` rules control it. Those rules exclude only `sharedpref`, `database` and `file` (getFilesDir()). NativeRideCheckRecorder writes recordings to `getApplicationDocumentsDirectory()`, which on Android is `PathUtils.getDataDirectory` = `context.getDir("flutter")`, that is /data/data/se.movera.driver/app_flutter. That directory is in the `root` domain, which is not excluded. The recordings are therefore copied to a new device during setup. That contradicts the XML comment ('Driver data ... is excluded from cloud backup and device-to-device transfer'), the RECORD_AUDIO rationale in docs/ANDROID_PERMISSIONS.md ('saved only on this phone and never sent'), and the Ride-check UI copy. privacy_storage_test only checks that a `<device-transfer>` tag exists, so it cannot catch this. (The iOS Documents backup issue is already known; this is the Android counterpart, a different mechanism.)

**Suggested fix:** Add `<exclude domain="root" path="." />` (and `external`) to both `<device-transfer>` and `<cloud-backup>`, or store recordings under noBackupFilesDir. Make the test assert the domains.

### M2. The 'Keep trip' tests cannot catch Keep trip ending the trip: after a real driver cancel, AcceptRide stays mounted as the root route and the onTrip panel marker remains

`integration_test/driver_lifecycle_test.dart:167` (found by r2-driver1)

**What happens:** Regression: change the Keep trip button at accept_ride_trip.dart:1328 to `popOwned(sheetContext, true)`, or drop the `confirmed != true` check at :1349. Tapping 'Keep trip' would then journal the trip as cancelled_by_driver, mark it terminal and show 'Trip ended early'. Both tests stay green: AcceptRide is still found, the onTrip marker is still found and DriverHome is never built. CI's lifecycle gate would ship a build where 'Keep trip' ends the rider's trip. Verified by reading the code; no tests were run.

**Why:** Two tests claim to prove that dismissing the cancel confirmation with 'Keep trip' leaves the trip running: the CI 'Critical lifecycle' test 'driver cancel reason can be dismissed without ending the trip' and widget_test.dart:2617 'On-trip options allow safe early cancellation with reasons'. Both mount `MaterialApp(home: AcceptRide(...))`, so AcceptRide is the only route. When a driver cancel really completes, `_submitTripCancellation` (accept_ride_trip.dart:1439-1446) only pops `if (navigator.canPop())`, and canPop is false here, so the trip screen stays mounted. The stage marker `ValueKey('active-ride-panel-${_stage.name}')` (accept_ride_panel.dart:687) still reads `onTrip` after `cancel(clearSnapshot:false)`, because a terminal outcome is kept apart from the stage. Nothing in the build depends on `terminal`. AcceptRide never pushes DriverHome, so `find.byType(DriverHome), findsNothing` holds whatever happens. Each assertion passes whether the trip continued or was cancelled.

**Suggested fix:** Push AcceptRide over a stand-in Home route, as rider_cancel_returns_home_test does. After Keep trip, assert that the trip is still not terminal: no history row in PrefsTripHistoryRepository, the active snapshot is still present and the 'Trip ended early' SnackBar is absent.

### M3. iOS bundle identifier is still the template com.example.movera, while README and the 16-point record say the bundle id is se.movera.driver

`ios/Runner.xcodeproj/project.pbxproj:371` (found by r2-driver2)

**What happens:** The owner archives the iOS release for TestFlight or the App Store. Signing fails because the com.example.movera App ID cannot be registered, or a build goes out under a throwaway identifier that does not match the Android/README identity, so later updates cannot carry over to the real se.movera.driver listing.

**Why:** Android uses applicationId/namespace `se.movera.driver`. README.md:7 says 'Bundle id `se.movera.driver` is unchanged', and FRONTEND_16_POINT_RECORD.md (F04/F15) says the application and bundle id were kept. The Runner target's Debug, Release and Profile configurations all set PRODUCT_BUNDLE_IDENTIFIER to the Flutter template value `com.example.movera`, and RunnerTests uses `com.example.movera.RunnerTests`. Flutter's own `build ipa` validation flags this ('Your application still contains the default "com.example" bundle identifier'). Apple does not register App IDs under the reserved example domain, so the iOS release cannot be signed or uploaded under the intended identity. The `ios-release-preflight` job uses `--no-codesign` and never sees this. release_metadata_test.dart checks only the Android gradle file for 'se.movera.driver', so the mismatch passes CI.

**Suggested fix:** Set PRODUCT_BUNDLE_IDENTIFIER to se.movera.driver (RunnerTests: se.movera.driver.RunnerTests) in all three configurations. Extend release_metadata_test to assert it in project.pbxproj.

### M4. Info.plist has no NSPhotoLibraryUsageDescription (or NSAppleMusicUsageDescription) although the linked image_picker and file_picker reference those APIs; a test asserts the key stays absent

`ios/Runner/Info.plist:7` (found by r2-driver4)

**What happens:** The owner uploads the iOS archive to App Store Connect. Processing returns ITMS-90683 'Missing purpose string in Info.plist' for NSPhotoLibraryUsageDescription (and NSAppleMusicUsageDescription), and the build cannot be submitted. Adding the key makes the audit test fail.

**Why:** image_picker's README (pubspec image_picker 1.2.0) says NSPhotoLibraryUsageDescription must be in Info.plist even if the photo library is never requested: 'This permission will not be requested if you always pass false for requestFullMetadata, but App Store policy requires including the plist entry.' file_picker 10.3.2's iOS podspec builds by default with PICKER_MEDIA (DKImagePickerController/PhotoGallery, Photos framework) and PICKER_AUDIO (MPMediaPickerController, which needs NSAppleMusicUsageDescription). No Podfile sets `Pod::PICKER_MEDIA=false` or `PICKER_AUDIO=false`. App Store Connect's static scan rejects uploads that reference these APIs without the purpose strings (ITMS-90683). ios_camera_privacy_test.dart explicitly asserts the plist does NOT contain NSPhotoLibraryUsageDescription, which locks the defect in.

**Suggested fix:** Either add accurate NSPhotoLibraryUsageDescription/NSAppleMusicUsageDescription strings, or add an ios/Podfile with `Pod::PICKER_MEDIA = false` and `Pod::PICKER_AUDIO = false` for file_picker and pass requestFullMetadata: false. Update ios_camera_privacy_test to match.

### M5. Pickup pay is added to the fare shown on offer cards but is dropped on accept, so the trip, waybill earnings and history show less than the card promised

`lib/core/dispatch/pickup_pay.dart:38` (found by driver4)

**What happens:** While driving, the next-trip card says 132,20 kr (incl. 3,80 kr pickup) and the driver accepts. The secured-next banner, the next trip's screen, its waybill 'Your earnings' and the history row all say 128,40 kr; the 3,80 kr the card promised is gone. Same on Home radar/exclusive cards whenever pickup pay is non-zero.

**Why:** PickupPayQuote.totalOf(fare) returns fare + pickup pay and is what the cards display: the on-trip next-trip card shows `_NextTripRadarOffer.shownFare` (accept_ride.dart:333 `String get shownFare => pickupPay.totalOf(fare);`, rendered at accept_ride_panel.dart:309 and accept_ride_sheet.dart:132), the exclusive sheet shows `offer.shownFare(show)` and Home radar cards get a PickupPayQuote (home_offer_radar.dart:1069). PickupPayConfig.current defaults have every kind on with demo rates (pickup_pay_config.dart:188-209, demoRates), so for the default next-trip offer (Comfort, 1.6 km / 4 min: (1.6-1)*3 + (4-2)*1 = 3,80 kr) the card promises 132,20 kr. When the driver accepts, the trip is opened with the plain fare: _buildNextWaybill uses `offer.fare` (accept_ride_trip.dart:217), _snapshotForOffer uses `offer.fare` (:976), the next AcceptRide gets `fare: offer.fare` (:940, :1398), PersistedQueuedTrip.fare is the plain fare (:49), and Home's _openOfferTrip passes `fare: offer.fare` (home_offer_radar.dart:954). Nothing stores or adds the pickup pay afterwards, so the trip screen, completion journal, history and earnings all show the lower number the driver did not accept.

**Suggested fix:** Decide one truth: either carry the pickup pay into the trip (store it on the offer/snapshot/waybill and include it in earnings and the trip header), or show the card total as 'fare' plus a separate pickup-pay line that is clearly not part of the fare. At minimum pass `offer.shownFare` (or a stored PickupPayQuote) through _buildNextWaybill/_snapshotForOffer/_openOfferTrip so the accepted amount matches what was shown.

### M6. On web the 8 s GPS time limit is not enforced (geolocator_web 4.1.4 passes microseconds as ms, with no Dart timeout), so a browser that never answers blocks the one-shot fix and the GPS subscription on Home and the trip

`lib/core/location/driver_location_service.dart:29` (found by driver3)

**What happens:** Driver opens the PWA on a phone whose browser cannot obtain a fix right away: Home stays on the locating placeholder and the trip map shows no live car, no route and no status for as long as the browser withholds an answer (up to ~2.2 h) instead of falling back after 8 s as on native.

**Why:** `DriverLocationService.getCurrentPosition()` relies on `LocationSettings(timeLimit: 8 s)` to bound the one-shot fix. Both screens subscribe to `watchPosition()` only after that call resolves: `accept_ride_trip.dart:598-606` (`final position = await _locationService.getCurrentPosition(); ... _positionSubscription = _locationService.watchPosition(distanceFilterMeters: 0).listen(...)`) and `home_map_sheet.dart:38-45` (the catch path also subscribes, but only if the call completes). On native the platform-interface applies `.timeout(timeLimit)`, so after 8 s the service falls back to the last known fix or throws and the screens show `Location updating…` and keep working. On web the pinned geolocator_web 4.1.4 overrides `getCurrentPosition` with no Dart-side timeout and converts the limit with `timeout?.inMicroseconds` into the browser's millisecond `PositionOptions.timeout` (8 s becomes 8,000 s, about 2.2 h). The app's own guard therefore does not hold on its primary (web/PWA) deployment: when the browser's geolocation does not answer (device has location permission but no fix, e.g. indoors, or a slow provider), the one-shot neither resolves nor errors, no stream is ever subscribed, no `Location updating…` status is set, and on the trip no route request is made (`_refreshRoadRoute(force: true)` sits in the catch).

**Suggested fix:** Wrap `Geolocator.getCurrentPosition` in a Dart-side `.timeout(_settings.timeLimit!)` in `DriverLocationService.getCurrentPosition` (and `requestPermission` if it can block), and/or subscribe to `watchPosition` before awaiting the one-shot so a hung one-shot cannot block the stream.

### M7. Approximate-only location passes the permission check but every fix fails the 50 m accuracy gate, so in release builds Home has no live position and Arrived is always refused, with no prompt asking for precise location

`lib/core/location/driver_location_service.dart:109` (found by r2-driver4)

**What happens:** On an Android 13 phone the driver taps 'Approximate' in the location dialog (or turns 'Precise Location' off on iOS). Home stays on 'Finding your location' with no car marker. On an accepted trip, tapping Arrived at the pickup shows 'Location unavailable. Enable location to confirm arrival.' although location is enabled. The trip cannot progress in a release APK/IPA or the CI web release.

**Why:** The manifest declares both ACCESS_FINE_LOCATION and ACCESS_COARSE_LOCATION, and geolocator requests both. On Android 12+ the system dialog therefore offers 'Approximate'. geolocator_android.checkPermissionStatus returns `whileInUse` when either declared permission is granted, coarse alone included. iOS 14+ similarly lets the user turn Precise off, and the status stays whenInUse. `_ensurePermission` checks only denied/deniedForever, so it passes. The fixes then have accuracy of about 1–3 km. `DriverLocation.isUsableAt` rejects anything with `accuracy > 50`, so Home sets `_hasLiveDriverLocation = false` on every fix, the trip never follows the car, and `_nearArrivalTarget` returns false in every release build (simulatedArrival is false there). The code never calls `Geolocator.getLocationAccuracy()` or `requestTemporaryFullAccuracy`, and Info.plist has no `NSLocationTemporaryUsageDescriptionDictionary`, so the reduced-accuracy state is never detected or explained. docs/ANDROID_PERMISSIONS.md says ACCESS_COARSE_LOCATION is kept as a 'Coarse fallback for the same when-in-use location', but the code cannot use a coarse fix at all.

**Suggested fix:** After the permission check, call Geolocator.getLocationAccuracy(). On reduced accuracy, show a 'Precise location required' state with a settings link. On iOS, add NSLocationTemporaryUsageDescriptionDictionary and call requestTemporaryFullAccuracy. Alternatively drop COARSE from the manifest and fix the doc.

### M8. Trip auto-resume timer that fires while suspended is dropped and never re-armed; resume() does not reschedule it

`lib/core/navigation/driver_camera_controller.dart:474` (found by driver4)

**What happens:** Driver on an active trip pans the map (camera enters Free), switches to another app for more than 12 s on Android, comes back: the trip map stays where it was panned indefinitely; the camera never returns to the car until the driver touches the map again or taps recenter.

**Why:** `_scheduleResume()` arms a one-shot Timer whose callback returns early when `_suspended` is true without rescheduling, and `resume()` (lines 693-696) only calls `_request(immediate: true)`, which is a no-op in browsing mode (`_canFollow` is false). The trip screen relies on this timer to bring the camera back to the car 12 s after the driver lets go of the map (`accept_ride.dart:488` sets `autoResumeAfter = tripAutoResume`, `accept_ride_trip.dart:794` sets `onAutoResume`). `suspend()` is called from `_pauseLiveUpdates` (`accept_ride_trip.dart:117`) on every lifecycle pause. On Android and on the web (PWA tab in background) Dart timers keep firing while the app is hidden, so the 12 s timer runs during the pause, hits the `_suspended` guard and dies. After `resume()` nothing re-arms it: `mapActivity()` only reschedules when `_resumeTimer != null`, and a later `update()` only calls `_scheduleResume()` on `enteringGuidance`, which is false mid-trip. Reproduced with a throwaway Flutter test (controller with `autoResumeAfter` 50 ms: userGesture, touching=false, suspend, wait 120 ms, resume, wait 300 ms): `Expected: <1> Actual: <0> after resume the camera should still auto-return`, mode stayed `browsing`.

**Suggested fix:** In the timer callback, when `_suspended` is true, leave `_resumeTimer` unset but have `resume()` call `_scheduleResume()` (it already checks mode/guidance/touching); alternatively cancel the timer in `suspend()` and re-arm it in `resume()`.

### M9. Off-route fix makes routeFraction 0: the island ETA, remaining distance and leg progress reset to the full route (and can trigger a false 'traffic ahead' strip message) until the reroute lands

`lib/core/navigation/navigation_controller.dart:156` (found by r2-driver2)

**What happens:** 9 km into a 10 km trip, the driver takes a wrong turn or GPS drifts 60 m. The ETA chip jumps from '2 min' to the full original '18 min', the remaining distance shows the whole route, and route progress falls to 0%. They stay that way until the reroute lands, then jump back.

**Why:** _rebuildBanner sets _progressAlong = progress.offRoute ? null : progress.alongMeters (line 481), so the next projection starts from scratch. routeFraction then reads (_progressAlong ?? 0) / length, so off route the driven share becomes 0 instead of unknown or the last value. AcceptRide uses it directly: _remainingMeters = total * (1 - (routeFraction ?? 0)) and _routeEtaText = seconds * (1 - (routeFraction ?? 0)) (accept_ride.dart:920, 927). The leg progress derived from remaining also drops to 0%. This holds through the 2 s reroute debounce plus the network fetch, and on any single fix more than 50 m off (accuracy up to 50 m is accepted).

**Suggested fix:** Keep the last on-route along value for routeFraction (a separate _lastOnRouteAlong field), or return null while off route and let callers keep their previous ETA, instead of treating null as 0.

### M10. Once the car is off route, the ETA and leg progress jump back to the full leg until the reroute arrives

`lib/core/navigation/navigation_controller.dart:481` (found by r2-driver2)

**What happens:** On an 18-minute leg with 3 minutes left, the driver misses a turn, or GPS jumps more than 50 m off the polyline. For about 10 s while the reroute request hangs or fails, the island shows '18 min · <arrival 15 minutes later>' and the leg progress bar resets to empty. Then it shows the real value again, or 'En route' once the failed reroute clears the route. Verified by reading the code; not run.

**Why:** _rebuildBanner sets _progressAlong to null for an off-route fix. routeFraction then reads `(_progressAlong ?? 0) / length` = 0. AcceptRide's _routeEtaText computes `seconds * (1 - routeFraction)` and _remainingMeters computes `total * (1 - routeFraction)`, so the old route's full duration and distance are shown again. _legFraction then gets remaining == _legTotalMeters and the progress bar drops to 0. This holds for the whole reroute window: a 2 s debounce plus the request, up to the 8 s routing timeout when routing is failing, as in this journey. The same happens right after an accepted GPS jump off the route.

**Suggested fix:** Keep the last on-route progress while off route (keep _progressAlong, or a separate value for display), or hide the ETA while recalculating.

### M11. A single fix that projects onto a later leg moves the instruction hint forward for good: the banner skips the turns in between and the car snaps to the other street

`lib/core/navigation/route_progress.dart:100` (found by r2-driver2)

**What happens:** The pickup is around the block, or across a divided road that needs a U-turn. One GPS sample drifts toward the return leg. From then on the banner shows the arrival ('Pickup in 500 m') instead of the two turns ahead, for up to 90 s. The camera's turn framing is lost, and the car icon jumps onto the parallel street for that fix.

**Why:** measure() first projects inside [previousAlong-60, previousAlong+400]. The tie rule that prefers forward-consistent progress only applies within 10 m, so any later part of the route that is more than 10 m closer than the current leg wins. This can be a parallel street on an around-the-block route, or the opposite carriageway after a U-turn. The instruction search then starts at instructionHint and only moves forward. NavigationController stores the result unconditionally (_instructionHint = progress.instructionIndex, navigation_controller.dart:480), and DriverCameraPolicy does the same (driver_camera_controller.dart:266). When the next fixes project back onto the real leg (the window misses it, so the global projection is used), along goes back but the hint does not. The maneuvers between the two passes are skipped until a new route object resets the hint: the silent refresh comes after 90 s, or a reroute. The camera policy snaps vehiclePoint to the wrong leg for that fix (driver_camera_controller.dart:269-270), so the car marker jumps to the other street. Fixes with accuracy up to 50 m are accepted, and the jump filter subtracts both accuracies, so a 15-50 m urban-canyon drift is enough.

**Suggested fix:** Do not let the windowed projection jump forward past a maneuver unless it is clearly better (for example, require the forward candidate to be consistent with the elapsed distance or speed). Also recompute the instruction index from projection.along when along goes backwards (search from 0, or step the hint back while maneuverAlong[hint-1] > along).

### M12. Corrupt local JSON records leak rider name, pickup/dropoff addresses (and trusted-contact phones) into DriverLog via FormatException source excerpts

`lib/core/ride/prefs_active_ride_repository.dart:81` (found by driver2)

**What happens:** localStorage/SharedPreferences holds a half-written movera_driver_active_ride (e.g. tab killed mid-write) -> next launch Home calls read() -> the rider's name, phone and pickup address are printed to the device/browser log in a release build and would be shipped to any future crash-reporting sink.

**Why:** DriverLog's own contract (lib/core/logging/driver_log.dart:5-6: 'Messages must not contain rider names, phone numbers or free text') is violated by every storage reader that logs a jsonDecode error. Dart's FormatException.toString() appends ~78 characters of the offending source around the error offset, and the stored records are JSON blobs holding rider names, phone numbers and addresses (active ride), trusted-contact phone numbers (settings sections) and completion journals. Paths: PrefsActiveRideRepository.read -> `DriverLog.error('Active-ride snapshot parse failed', error, stack)` (line 81) and again through `_enqueue`'s catchError (line 57); LocalQuarantine.store builds `reason: '$error'` from callers (prefs_active_ride_repository.dart:125, completion_journal.dart:157, settings_repository.dart:84) and then logs it: `DriverLog.warn('Quarantined $source record as $key: $reason')` (local_quarantine.dart:62). The default sink prints with debugPrint (driver_log.dart:42-43), which is not stripped in release builds, so this lands in logcat / the browser console; the file also says a crash-reporting adapter will be attached to this sink later. Reproduced with a throwaway flutter test: a truncated active-ride snapshot produced a log line containing `"riderPhone":"+46701234567","pickup":"Sveavägen 12, Stockholm"`, and a truncated contacts section produced `"phone":"+46709998877"` in the quarantine warning.

**Suggested fix:** Log only the exception type/message without the source excerpt (e.g. `error is FormatException ? error.message : error.runtimeType`), and pass a scrubbed `reason` to LocalQuarantine (the raw text is already stored in the quarantine payload, so the reason need not repeat it).

### M13. Scheduled-ride waiting rule is found by searching the localized 'Scheduled ride' label, so French and Swedish drivers get different wait and no-show terms

`lib/core/ride/waiting_rules.dart:250` (found by driver-j2)

**What happens:** Take a scheduled Movera XL reservation (category rule free 3 / no-show 3) and press Leave now. In English, termsFor applies XL, then scheduled sets free to 5, and the final guard lifts no-show to 5: 5 free minutes, no-show at 5 min. With the app in Swedish or French the same trip gets 3 free minutes and no-show at 3 min. Paid waiting therefore starts 2 minutes earlier (12,26 kr/min) and the driver can mark a no-show 2 minutes earlier, only because of the UI language. The waiting sheet also loses its 'Rule for this pickup: Scheduled ride' line. Worked out by hand from termsFor; nothing was run.

**Why:** AcceptRide builds `_waitTerms` from `WaitingRules.typeOf(matchedVia: widget.matchedVia, ...)` (accept_ride.dart:989-996). `typeOf` sees a scheduled ride only if `matchedVia.toLowerCase()` contains 'scheduled' or 'reservation'. 'Leave now' opens the trip with `matchedVia: tr.scheduledRide` (home_scheduled.dart:236). That is 'Scheduled ride' in English, 'Course planifiée' in French and 'Bokad resa' in Swedish, so in fr/sv the type falls back to `WaitingRideType.normal`. The scheduled rule is skipped: its free wait (`ScheduledRideRules.current.includedWaitingMinutes`), any admin perMin/noShowFee for `rideTypes.scheduled` (driver_app_config.dart reads them), and its 'Scheduled ride' rule label. The matchedVia string is also saved in the snapshot, so a restored trip keeps the wrong type.

**Suggested fix:** Pass a language-neutral source (for example a WaybillRecord constant like 'scheduled' or an explicit WaitingRideType/TripKind) to AcceptRide for reservations, and localize only the display label.

### M14. Ride-check audio stops capturing when the app is backgrounded (no iOS background audio mode, no Android microphone foreground service), but the counter and the saved length keep counting wall-clock time

`lib/core/safety/ride_check_controller.dart:90` (found by r2-driver1)

**What happens:** During a frightening ride the driver taps Record audio, then Call 112 (or locks the phone). After 3 minutes they return and stop the recording. The card says 'Audio saved 3:12' and the trip detail stores 192 s, but the .m4a holds about 5 s (iOS) or 3 minutes of silence (Android). That evidence is missing when it matters.

**Why:** The Ride-check main step offers 'Call 112' and 'Record audio' side by side. Tapping Call 112 hands off to the dialer, which backgrounds the app; so does locking the screen. Info.plist has no UIBackgroundModes `audio`, so iOS suspends the app and the record session stops or is interrupted. Android 9+ gives silence to apps in the background, and the manifest has no microphone-type foreground service. AcceptRide.didChangeAppLifecycleState (accept_ride.dart:715-727) persists the trip and pauses GPS but does nothing about the recording. The controller computes `audioSeconds` as `now - _audioStartedAt`. When the driver comes back and taps stop, that wall-clock duration is shown ('Audio saved 3:12') and written to the Ride-check record (`copyWith(audioSeconds: seconds)`), although the file holds only the foreground part or silence.

**Suggested fix:** Stop (or pause and mark) the recording on paused/hidden and tell the driver. Take the saved duration from the file or the recorder's own amplitude/duration, not the wall clock. If background capture is wanted, add UIBackgroundModes audio and an Android microphone foreground service, with product and store sign-off.

### M15. 'Called 112' is recorded and sent to Movera as the alert topic before the dialer opens, and is never corrected when the dialer fails

`lib/core/safety/ride_check_controller.dart:154` (found by r2-driver1)

**What happens:** On a device with no dialer (a tablet, or web where tel: is blocked), the driver taps Call 112. The card says the dialer could not open, but the alert sent to admin and Dispatch says the topic is 'Called 112' and the trip history says 'Answer: Called 112'. Responders may assume emergency services are already involved.

**Why:** callEmergency writes the answer 'Called 112' to the record and sends an alert with topic 'Called 112' before handoffEmergencyDial runs. When launch returns false or throws, the card correctly shows 'Could not open the dialer…' (dialFailed), but the trip record (trip details show 'Answer: Called 112') and the alert to Movera still say the driver called 112. Even on success, the app only opens the dialer ('Movera never calls for you'), so 'Called 112' claims a call that may not have happened.

**Suggested fix:** Record the answer as 'Opened dialer for 112' or similar, and append or update with the dial result (opened or failed) after handoffEmergencyDial returns.

### M16. Ride-check audio that is still starting when the card closes keeps the microphone recording with no UI, and dispose() never stops it after a later check opens

`lib/core/safety/ride_check_controller.dart:260` (found by driver2)

**What happens:** Long-stop card opens, driver taps 'Record audio' and, while the OS mic permission sheet / recorder start is still in flight (hundreds of ms on a phone), taps 'I'm OK'. The card closes but the phone keeps recording the cabin to ride_check_audio/*.m4a with no indicator; after the next Ride check on the same trip and leaving the trip screen, the recorder is still running until the app process dies.

**Why:** `toggleRecording()` sets `_audio = starting`, awaits `recorder.requestPermission()` and then `recorder.start(...)` (lines 240-251). On native that start awaits `getApplicationDocumentsDirectory()`, `Directory.create` and the plugin. If the driver answers meanwhile (`imOk`/`done` → `_close()`), `_close()` calls `_stopRecording()` which returns immediately because `_audio != recording` (line 275), then marks the record answered and closes the card. When `start()` later completes, the only guard is `if (_disposed)` (line 260): `_audio` becomes `recording`, `_audioStartedAt` is set and a periodic 1 s ticker starts notifying listeners (lines 264-270) although the card is closed and `_answerable` is false, so nothing on screen shows a recording and no button can stop it. If a further Ride check opens later, `open()` resets `_audio = idle` (line 114) without touching the recorder or the ticker, after which `dispose()` skips the stop because `_audio != recording` (line 412) — the native recorder is never stopped for the rest of the process. Reproduced with a throwaway flutter test using a recorder whose `start()` awaits a Completer: after `imOk()` and completing start, `c.audio == RideCheckAudio.recording` and the fake recorder was still recording; after `open()` of a second event and `dispose()`, the recorder was still recording with `stops == 0` (test output: `after close: audio=RideCheckAudio.recording recorderRecording=true stops=0` / `after dispose: recorderRecording=true stops=0`). The test file was deleted afterwards.

**Suggested fix:** After `await recorder.start(...)` re-check `_disposed || _closing || !_answerable` and cancel/stop the recorder if the card is no longer open; in `open()` and `dispose()` stop any recorder that was started regardless of the `_audio` flag (track a `_recorderRunning` bool set around start/stop).

### M17. If the one-time prime() fails (play rejected), the radar player stays at volume 0 and is never primed again, so later offer alerts play silently

`lib/core/sound/radar_offer_sound.dart:141` (found by r2-driver4)

**What happens:** On a phone browser the driver's first touch on Home starts prime. play() rejects (not yet a user activation), so the player stays at volume 0. For the rest of the session, new Radar offers start the looped alert at volume 0. The driver hears nothing and misses offers.

**Why:** `prime()` sets volume 0, plays, stops, then sets volume 1, with no try/finally. If `setSource` or `play` throws, `setVolume(1)` never runs. On web, audioplayers_web awaits `player.play().toDart`, which rejects with NotAllowedError outside user activation. Home calls `tap()` from `Listener.onPointerDown` (home.dart:707), and a touch pointerdown is not an activation-triggering event on mobile browsers. The failure is swallowed by `_then`'s queue (`_queue = next.catchError(...)`) and by `tap()`'s `.catchError((Object _) {})`. `_primed` is already true, so prime never runs again. `startLoop()` only sets the release mode and plays; it never restores the volume. Once a later tap gives the page sticky activation, the loop plays, but silently. Home's `RadarOfferSound` lives as long as Home.

**Suggested fix:** Wrap the body of prime in try/finally and always `setVolume(1)` in the finally; reset `_primed = false` on failure so a later tap retries, or pass `volume: 1` in `startLoop`'s play call.

### M18. Saved Ride-preferences category choice is never restored at boot, so switched-off categories are offered again after every restart

`lib/core/vehicle/ride_categories.dart:53` (found by driver3)

**What happens:** Driver opens Ride preferences, switches off 'Movera Pet' (saved to settings), kills and relaunches the app, goes online. Home shows Radar/Exclusive/reservation offers in the Pet category (and scheduled Pet rides) because `DriverCategoryChoice.off` is empty; the filter only starts working again after the driver happens to open Ride preferences.

**Why:** `DriverCategoryChoice.off` (ride_categories.dart:56) is the in-memory set that every offer filter reads (`DriverCategoryChoice.takes` in home_offer_rules.dart:13/21/30, home_reservation.dart:107/132, scheduled_rides.dart:545). The only writer is the Ride preferences screen: `_publishChoice()` runs after `_restoreSettings()` or a toggle (preferences.dart:118/172), i.e. only once that screen has been opened. The choice is persisted to the `categories` settings section (preferences.dart:140), but nothing reads it back at app start: `main.dart:41-49` restores `MapTrafficSetting` and `DriverLanguage` and nothing else, and `DriverCategoryChoice` has no restore method. After a cold start `off` is the empty const set, so `takes()` returns true for every allowed category. The class comment (`ride_categories.dart:51`, 'kept for the session') documents the in-memory nature but the persisted setting and the Q27 promise ('offers follow that choice') make the restart behaviour wrong. The same global is also not reset on logout (`main.dart:180-195` calls `MapTrafficSetting.reset()` / `DriverLanguage.reset()` but not `DriverCategoryChoice.reset()`), so after logout the cleared storage and the stale in-memory set disagree until Preferences is opened again.

**Suggested fix:** Add `DriverCategoryChoice.restore([SettingsRepository])` that reads the `categories` section the same way `_restoreSettings` does and publishes the off-set; call it from `main()` beside `MapTrafficSetting.restore()`, and call `DriverCategoryChoice.reset()` in `_logout`.

### M19. WaybillPayment.fromFare reads only the first digit group of a thousands-grouped fare label, so earnings/fee are wrong for fares >= 1 000 kr

`lib/core/waybill/waybill.dart:296` (found by driver4)

**What happens:** A driver completes a 1 234,50 kr trip (any backend Offer.fare >= 100000 minor units, or a demo fare pushed over 1 000 kr by waiting fees). Opening the waybill shows "Your earnings 0.75 kr" and "Service fee 0.25 kr" instead of about 925,88 kr / 308,62 kr; with netFare on, the offer card shows a 0.75 kr net fare for a 1 234 kr trip.

**Why:** Money.formatted groups thousands with a space ("1 234,50 kr", lib/core/money/money.dart:187 via _group). RideOffer.fareLabel (dispatch_repository.dart:114) and WaitingTerms.addFee (waiting_rules.dart:77, used for _fareWithWaiting on completion) both produce this format, and it is what reaches WaybillRecord.fare. WaybillPayment.fromFare parses the label with `RegExp(r'\d+(?:[.,]\d{1,2})?').firstMatch(fare)` which matches only the leading "1" of "1 234,50 kr", so fareOre becomes 100 and _comma is false. Consumers: waybill_sheet.dart:70 (`WaybillPayment.fromFare(record.fare, bonus: record.driverBonus)` -> "Your earnings" row) and OfferCardDetails.fare (offer_rules.dart:157, the net-fare mode admin can switch on for offer cards). Money.parseSekLabel already accepts the grouped form (money.dart:73), so the producer and this consumer disagree. Reproduced with a throwaway flutter test: `Money(minorUnits:123450).formatted` = "1 234,50 kr"; `WaybillPayment.fromFare(that)` gave fare=1.00 kr, fee=0.25 kr, earnings=0.75 kr; `OfferCardDetails(netFare:true).fare(label)` = "0.75 kr".

**Suggested fix:** Parse the fare with Money.parseLabel/parseSekLabel (which understand grouped thousands and the currency suffix) instead of the ad-hoc regex, e.g. `final money = Money.parseLabel(fare); if (money == null) return null; fareOre = money.minorUnits;` and keep the comma flag from the label. Add a test for a >= 1 000 kr label.

### M20. Logout keeps the previous driver's notifications and document-renewal state (DriverNotificationFeed, DocumentExpiryStore)

`lib/main.dart:193` (found by r2-driver1)

**What happens:** Driver A gets 'Head to your 08:15 pickup · Södermalm, Stockholm' and uploads a new insurance letter (now 'in review'), then logs out. Driver B opens Notifications and sees A's reminders with A's rider pickup addresses, already marked read. B's Documents screen shows A's insurance in review.

**Why:** DriverNotificationFeed.instance and DocumentExpiryStore.instance are process singletons, and both have reset() methods ('Back to the demo list at the next reading'). No code in lib/ calls them, and _logout does not. Notifications that Home adds while driver A works stay in the feed for driver B: scheduled-ride reminders carrying the pickup address (home_scheduled.dart:271-282), Exclusive offers, rest-over notices. A's read/unread state stays too. A's document uploads ('in review' via uploadNew) and approvals stay in DocumentExpiryStore, so B's Documents screen, the going-online block and the island hold show A's document status. The test harness resets both before every test (flutter_test_config.dart:65-68) because they are per-driver state.

**Suggested fix:** Call DriverNotificationFeed.instance.reset() and DocumentExpiryStore.instance.reset() from _logout.

### M21. A restored trip loses its pickup distance (and bags), so the waiting terms change after the app is killed and reopened: far-pickup free wait and no-show fee are replaced by the defaults

`lib/presentation/driver/accept ride/accept_ride.dart:240` (found by r2-driver2)

**What happens:** A driver accepts an offer 7 km away and waits at pickup for 4 minutes (3 paid minutes under the far-pickup rule). Safari kills the tab, and Home restores the trip. The island now shows those 4 minutes as included free wait, so the paid wait and the waiting fee drop to 0. The no-show fee the driver is promised falls from 85 kr to 65 kr.

**Why:** _waitTerms is computed from widget.pickupKm (WaitingRules.termsFor applies the farPickup rule when pickupKm > 5: freeMinutes 1, noShowFee 85 kr). Home, Radar and Ride requests pass offer.pickupKm into AcceptRide. PersistedActiveRide has no pickupKm field, so _buildSnapshot cannot save it, and AcceptRide.fromPersisted does not pass it. After a crash, reload or PWA resume, the same trip gets base terms: 5 free minutes and a 65 kr no-show fee. The waiting clock, the paid seconds, the cash to collect, the driver's earnings and the no-show threshold all change in the middle of the trip. bags is also not saved or restored, so the island's bag notice disappears.

**Suggested fix:** Save pickupKm (and bags) in PersistedActiveRide.toJson/fromJson/stamped, write them in _buildSnapshot, and pass them through AcceptRide.fromPersisted. Better still, save the resolved WaitingTerms so the trip keeps the terms it was accepted under.

### M22. Resuming a stale (>6 h) waiting snapshot adds the whole gap to the pickup wait, putting thousands of kronor of waiting fee on the trip

`lib/presentation/driver/accept ride/accept_ride.dart:613` (found by r2-driver2)

**What happens:** I reproduced this in a throwaway widget test. AcceptRide.fromPersisted(stage waitingForRider, waitSeconds 0, savedAt now-7h) renders AdaptiveTripIsland with 'waitingSeconds=25200 paid=24900'. At 12,26 kr/min that is about 5 088 kr of waiting fee, added to the fare and the cash to collect, for a trip the driver resumed after the app sat dead overnight.

**Why:** Home offers 'Resume trip' for a snapshot that fails isFresh (home.dart:530-535, the button is enabled whenever endpoints are verified). AcceptRide.initState then adds now - savedAt to _waitSeconds whenever the restored stage is waitingForRider or a stop wait. The free 6-hour window, which exists so 'an abandoned trip cannot revive days later' (prefs_active_ride_repository.dart:16-17), is not respected for the wait clock, and WaitingTerms.waitingFee has no cap. When the driver slides to start, _paidWaitSeconds += paidWait, and the fee goes into the archived fare and the cash to collect.

**Suggested fix:** Do not credit elapsed wall-clock time beyond the freshness window, or cap it at the no-show point, when resuming a snapshot the driver confirmed as stale.

### M23. Next-trip ids are '<tripId>-next' for every offer during a trip, so a re-offered next trip collides in history and its completion is never archived

`lib/presentation/driver/accept ride/accept_ride.dart:964` (found by r2-driver2)

**What happens:** I reproduced this in a throwaway test. Archiving 'A-next' as a driver cancel (searching) and then running CompletionJournal.finish(record 'A-next') leaves history as 'rows=[A-next:TripStatus.searching]'. The completed trip and its earnings never appear, and History shows it as cancelled by the driver.

**Why:** _uniqueDemoNext (and _onTripRadarOfferForDestination at accept_ride_trip.dart:1038) gives every next-trip offer during trip A the same id: '${widget.tripId}-next' or '-next-destination'. trip_occurrence.dart says every accept path must use a per-occurrence id 'so a repeated demo ride is never hidden as an already-finished trip'; this path does not. Cancelling a secured next trip archives it in history with that id (accept_ride_sheet.dart:270-286). Radar then returns to scanning and the next offer reuses the same id. If the driver secures it, finishes A and completes B, the journal's non-authoritative archive finds an existing row with that tripId and returns without writing (prefs_trip_history_repository.dart:201-202).

**Suggested fix:** Give each next-trip offer occurrence its own id (tripOccurrenceId('${widget.tripId}-next')) so a cancelled and a later secured next trip never share an archive or terminal identity.

### M24. On any cash trip with a Movera bonus, the app tells the driver to collect the full fare, bonus included, from the rider (API offers never carry cashToCollect)

`lib/presentation/driver/accept ride/accept_ride.dart:1007` (found by r2-driver2)

**What happens:** An admin radar-group trip with fare 152,40 kr including a 40 kr Movera bonus, paid in cash, with no cashToCollect from the server. At drop-off the sheet says 'Collect 152,40 kr in cash', so the rider is charged Movera's 40 kr bonus. The cash balance then shows 'Settled' instead of Movera owing the driver the bonus.

**Why:** RideOffer.driverBonus is 'Movera-paid extra… [fare] already includes it', and WaybillPayment says of the bonus 'the rider never pays it'. On a cash trip whose offer has no explicit cashToCollect (null means 'the fare'), `_cashToCollect` falls back to `widget.fare`, which includes the bonus. That amount (plus the waiting fee) is what the Collect cash sheet shows in the big 'Collect … in cash' tray, and it is journaled as cashCollected. api_dispatch_repository parses driverBonus and paymentMethod independently, so a cash + bonus offer is a valid input.

**Suggested fix:** When cashToCollect is null, default the cash to fare − driverBonus (plus the rider's waiting fee), so the balance shows the bonus as owed by Movera.

### M25. On-trip next-trip offer card floats over the web map without PointerInterceptor or the map-gesture block that every other overlay uses

`lib/presentation/driver/accept ride/accept_ride.dart:1348` (found by r2-driver2)

**What happens:** In the Safari/PWA build, during a trip an Exclusive next-trip offer appears in the bottom card. When the driver taps Accept or Decline, the touch reaches the Google map, which pans or ignores it, instead of the card button. The offer can run out unanswered.

**Why:** When `_incomingOfferOpen` is true, the sliding panel collapses to 0 height (minHeight 0 / maxHeight 1), so the full-screen map (an HtmlElementView on web) lies under the card. Every other overlay on this screen goes through `_mapOverlay` (PointerInterceptor plus `_setMapGesturesBlocked`): the sheet, the island, the map controls and the Ride check layer. Home's equivalent offer sheet is also wrapped in PointerInterceptor, with the comment 'Opaque to touches: nothing under the sheet (dock, map) gets them'. The incoming ride card is added bare, so on web the map's DOM element receives pointer events in the card's area, and `_blockMapGestures` is never set while the driver touches it.

**Suggested fix:** Wrap the card in `_AcceptRidePanel(this)._mapOverlay(child: ...)`, as the other overlays are.

### M26. A destination set on the trip screen is lost when the trip returns to Home, but it still counts against today's limit

`lib/presentation/driver/accept ride/accept_ride_panel.dart:184` (found by r2-driver4)

**What happens:** Default rules allow 2 destinations per day. During a trip the driver sets destination 'Solna' from the island. On-trip offers follow it. After the trip ends, Home shows no destination: no route and no on-the-way filtering of Radar offers. If the driver sets it again on Home, that is the second use. A third attempt is refused with 'destinations used today', although only one was ever visible on Home.

**Why:** Destination mode lives in three places: Home's `_destinationModeActive/_destinationAddress/_destinationPosition`, AcceptRide's `_destinationActive/...` (copied from the widget at mount, accept_ride.dart:471-473), and the `DestinationModeSession.instance` singleton (daily count, `_activeSince`, route). Setting a destination during a trip (R13-18) calls `OnTripDestination.started()`, which adds one use for today and starts the time limit, and then updates only the trip screen's copy. Nothing writes it back to Home. After completion (popUntil first), a cancel (pop) or a rider cancel, Home still has `_destinationModeActive == false`. It never reads `DestinationModeSession` to restore it and never arms its `_destinationLimitTimer`. The next trip in the chain receives the destination, but Home never does.

**Suggested fix:** Make DestinationModeSession (or a shared notifier) the single owner of the active destination. Home and AcceptRide should read it and listen to it instead of keeping private copies, and Home should pick up a destination set during the trip when it becomes visible again.

### M27. The stale-location label above the trip map buttons has unbounded width: it is cut off at the left edge and blocks map gestures

`lib/presentation/driver/accept ride/accept_ride_panel.dart:546` (found by r2-driver4)

**What happens:** During a trip with no fresh GPS, a driver tries to pan or pinch the map in the band left of the Safety/Google/Recenter buttons (about 230-290 px wide, 200 px tall). Nothing happens. In French at 130% on a 320 px phone the label reads '…de démo — position en direct…' with its start cut off.

**Why:** _buildMapControls puts a plain Text (tr.demoOffersLiveLocationUnavailableStale while there is no fresh fix) at the top of a Column with crossAxisAlignment.end. That Column is placed with Positioned(right: 14) and no left or width (accept_ride.dart:1328), so it gets unbounded width and the text lays out on one line. FR 'Offres de démo — position en direct indisponible ou ancienne' is ~272 px at 1.0 and ~355 px at 1.3 (hand estimate), wider than the 306 px left of the buttons on a 320 px phone, so the start of the text is clipped off-screen. The Column is also wrapped by _mapOverlay: PointerInterceptor plus Listener(behavior: HitTestBehavior.opaque, onPointerDown: _setMapGesturesBlocked(true)). The whole Column rectangle (text width × ~204 px: text + 50 + 12 + 56 + 12 + 56) therefore swallows touches and absorbs the map, on web through the interceptor element. This happens whenever live GPS is missing or stale, which is common on web.

**Suggested fix:** Move the label out of the hit-tested overlay, or give it a bounded width (ConstrainedBox(maxWidth: viewport-28)) with wrapping or maxLines + ellipsis. Wrap only the buttons in _mapOverlay so the opaque area matches the controls.

### M28. A terminal projection (admin/system cancel, rider cancel, completed) that arrives while an earlier projection is still draining is never applied

`lib/presentation/driver/accept ride/accept_ride_trip.dart:300` (found by r2-driver1)

**What happens:** Reproduced with a throwaway widget test. AcceptRide is at headingToPickup and the repository save is held. Emitting the projection `arrived` and then `cancelled_by_admin`, releasing the save and pumping 10 s leaves the active snapshot at waitingForRider and the trip history empty (output: `AUDIT snapshot=ActiveRideStage.waitingForRider history=[]`). The driver keeps navigating to a trip Movera cancelled. After a kill and reopen, Home restores the cancelled trip from the snapshot.

**Why:** _onRealtimeEvent stores each status event in _pendingProjection and calls _drainProjection(). If a drain is already running (_drainingProjection true, e.g. it is awaiting applyProjection's save for an earlier stage projection), the new call returns at line 300 without scheduling a retry. When the first drain finishes, the non-terminal branch (lines 340-348) leaves the newer event in _pendingProjection because it is not identical to the one it drained, and the finally block only clears _drainingProjection. Nothing calls _drainProjection again. DriverRealtimeSequenceGate has already recorded the trip as terminal, so every later status event for the trip is dropped as blockedAfterTerminal, and a resync re-delivers the same eventId, which the gate drops as a duplicate. The terminal outcome is only picked up if the driver later tries to finish or cancel (through _yieldToAuthoritativeTerminal).

**Suggested fix:** When _drainProjection returns early because a drain is running, set a 'drain again' flag, or schedule _projectionRetry. At the end of a drain, run again whenever _pendingProjection is not the event just handled.

### M29. An authoritative `completed` projection archives a cash trip without its payment method, cash collected or waiting fee

`lib/presentation/driver/accept ride/accept_ride_trip.dart:316` (found by driver1)

**What happens:** Cash trip in progress; admin force-completes it (`POST /admin/trips/{id}/complete`) -> `trip_projection` status completed arrives -> history row shows the trip as card-paid with no 'Cash collected' line; the period's cash balance sheet omits it.

**Why:** The driver's own Finish (`_completeCurrentTrip`, lines 912-917) journals `_paidWaybill()` (fare incl. the driver's waiting fee) with `paymentMethod: 'Cash'` and `cashCollected` for a cash trip; `TripHistoryRecord.cashBalance` and the history 'Other earnings' cash accounting depend on `paymentMethod == 'cash'`. The realtime terminal path in `_drainProjection` (contract rows `complete` by admin from rider_onboard/in_trip/approaching_dropoff, or a server echo of `completed`) journals `_waybills.current ?? _buildCurrentWaybill()` with only `status` and `authoritative: true`. The archived row then has no `paymentMethod`/`cashCollected` and no waiting fee, so the driver's cash balance for that trip (what they owe or are owed) silently disappears from history, and with `authoritative: true` it also overwrites a correct local row if one was written first.

**Suggested fix:** In the authoritative terminal branch pass the same `paymentMethod`/`cashCollected` (and `_paidWaybill()`) as the local completion when `status == TripStatus.completed`.

### M30. A repeated same-stage (onTrip) projection restarts the next-trip radar: an accepted (matching) or shown Exclusive offer is dropped, and the route and camera are re-fitted

`lib/presentation/driver/accept ride/accept_ride_trip.dart:341` (found by driver1)

**What happens:** Driver on trip accepts the Exclusive next-trip offer; within a second the app is resumed or a projection echo arrives with status in_trip. The match timer is cancelled, the state goes back to scanning, the accepted trip is lost and the same offer pops up again (or is gone if declined before); the long-stop ride-check timer also restarts from zero.

**Why:** `_drainProjection` treats a successful `applyProjection` as a stage change: `if (!await _rideLifecycle.applyProjection(status)) { return; } if (mounted) { _rebuild(() {}); _resumeStageSideEffects(); }` (lines 340-342). But `ActiveRideController.applyProjection` returns true without changing anything when `next == _stage` (active_ride_controller.dart: 'Realtime may repeat the same stage each poll ... if (next == _stage) { return true; }'). Same-stage projections are normal: `reconnectAndResync` (called on every app resume, accept_ride.dart:719, and on every sequence gap, accept_ride_trip.dart:248) re-emits the cached projection with a new sequence (driver_realtime.dart:468-482), and a poll/echo would do the same. For `onTrip`, `_resumeStageSideEffects` (100-115) then calls `_rideCheckDetector.startTrip(...)` (forgetting any long-stop/off-route progress), `_demoDrive?.startTrip()`, `_startOnTripRadar()` (995-1008) which cancels `_nextTripRadarMatchTimer` and sets `scanning` with `_nextTripRadarOffer = null` — so an offer the driver has just accepted (900 ms `matching` window, 1190-1208) is silently discarded after `ExclusiveAnswers.accepted()` was already counted, and an offer on screen disappears — and finally `_refreshOnTripRoute(fitCamera: true)` forces a route re-fetch and camera re-follow. Reproduced with a throwaway widget test: on-trip demo offer shown, tap 'match next', emit an `in_trip` projection: `securedCardPresent=false offerVisible=true` (the same offer is re-presented as a new one instead of being secured).

**Suggested fix:** Only run `_resumeStageSideEffects()` when the stage actually changed (compare `_stage` before/after `applyProjection`, or have `applyProjection` report 'unchanged' distinctly), and make `_startOnTripRadar` a no-op when state is `matching`/`offerAvailable`.

### M31. An authoritative `completed` projection discards the waybill instead of completing it and journals the trip without payment method, cash collected or waiting fee

`lib/presentation/driver/accept ride/accept_ride_trip.dart:376` (found by driver1)

**What happens:** Backend/admin marks the trip completed while the driver is on the last leg. The outcome sheet says 'Movera recorded this trip as completed', but the Home island still shows the previous trip as last trip and the history entry for this cash trip has no payment method or cash collected.

**Why:** `_drainProjection` handles every terminal status through `_leaveAfterAuthoritativeOutcome` (313-323 → 371-390). For `TripStatus.completed` that path writes the journal with the bare current waybill (`_waybills.current ?? _buildCurrentWaybill()`, no `paymentMethod`, no `cashCollected`, no `_paidWaybill()` waiting fee — unlike `_completeCurrentTrip` at 912-917) and then calls `_waybills.discardCurrent()` (376) rather than `completeCurrent()`. `discardCurrent` only nulls `current` (waybill.dart:195-197) so `_waybills.last` is never updated; Home's `lastListenable` listener (`_onLastTripChanged`, `_lastTripFareLabel`, `_lastTripSettling`) and the island 'Last trip' amount keep the previous trip, and a cash trip completed by the backend is archived without 'Cash'/cash collected, so the history detail cannot show what is owed to Movera (Q23).

**Suggested fix:** Branch on `status == TripStatus.completed`: journal with `_paidWaybill()`, `paymentMethod`/`cashCollected` as in `_completeCurrentTrip`, and call `_waybills.completeCurrent()` (or route to DriverRideCompleted).

### M32. When the first GPS fix fails, the trip asks for and draws a road route from the hard-coded Stockholm placeholder position

`lib/presentation/driver/accept ride/accept_ride_trip.dart:628` (found by r2-driver1)

**What happens:** A driver in Gothenburg starts a trip with no GPS fix yet. The trip map draws a 470 km road line from Gamla Stan in Stockholm to the pickup. The ETA and turn instructions describe that drive, and the ride-check detector plans against it.

**Why:** `_driverPosition` starts as `_fallbackDriverPosition = LatLng(59.3262, 18.0595)` (accept_ride.dart:423 and 543) and changes only when a real fix is applied (`_applyDriverPosition`, line 660). When `getCurrentPosition` fails, the catch calls `_refreshRoadRoute(force: true)`. With external routing on, which is the build default (driver_runtime_config.dart:88-91), that calls `_navigation.ensureRoute(origin: GeoPointMaps.fromLatLng(_driverPosition), ...)` (line 704-709). It fetches a route from that placeholder to the pickup and draws it: `_roadGeoPoints`, `_routeDurationSeconds`, the turn banner and the ride-check plan all come from it. Combined with the missing stream subscription above, this route stays on screen.

**Suggested fix:** Do not request a road route until a real, usable fix exists; in the catch, clear the route or show the pickup only. Treat `_driverPosition` as unknown (nullable) until the first accepted fix.

### M33. Next-trip Exclusive offers arrive and expire behind a covering route (History, Chat and others) and count as misses, against D-05

`lib/presentation/driver/accept ride/accept_ride_trip.dart:1065` (found by r2-driver1)

**What happens:** On the last leg the driver opens Ride history from the island and reads it for 20 s. An Exclusive next trip appears behind the covering route and times out. The driver returns to an ordinary trip screen, but the offer was counted as missed. After enough of these, the driver is taken offline at the end of the trip for offers they never saw.

**Why:** The code says (D-05, lines 122-123 and 1123) that no next-trip offer comes or runs out while the driver cannot see the trip. The only gate is `_liveUpdatesPaused`, and `_pauseLiveUpdates` runs only on app lifecycle changes and terminal exits. `_AcceptRideState` is not RouteAware (mixins are TickerProviderStateMixin and WidgetsBindingObserver only), unlike Home, which pauses in didPushNext. While a full route covers the trip (the island's History, `pushSingle(... DriverRideHistory)` at accept_ride.dart:1307, or Chat from the trip options), GPS keeps flowing into `_applyDriverPosition`, which calls `_maybeScheduleOnTripRadarDemoOffer`. An offer is presented and its 15 s expiry runs. `_denyNextTripRadar` then counts it as missed through `ExclusiveAnswers.instance.missed()`; at the admin's limit that calls `setOnline(false)` and shows 'offline after missed'. It also sets `_onTripRadarDeclined`, which stops further offers.

**Suggested fix:** Subscribe the trip screen to driverRouteObserver. In didPushNext, pause the offer timers and keep the deadline (as `_pauseLiveUpdates` does for offers); in didPopNext, call `_resumeOnTripOffer`.

### M34. An Exclusive next-trip offer opens and runs out behind Chat, Support or Notifications, and counts as a miss that can send the driver offline

`lib/presentation/driver/accept ride/accept_ride_trip.dart:1122` (found by r2-driver1)

**What happens:** On a trip with Radar scanning, inside the next-trip radius, the driver taps the message icon to chat with the rider. 2.2 s later an Exclusive offer opens under the Chat route, and 15 s later it expires unseen. The driver comes back to no offer and Radar declined for the rest of the trip. One more miss is counted, and at admin's autoOfflineAfter count the driver goes offline after this trip with the 'offline after N missed' message.

**Why:** D-05 (comment at line 122) says no next-trip offer comes or runs out while the driver cannot see the trip. The only guard is _liveUpdatesPaused, and only didChangeAppLifecycleState sets it. AcceptRide is not route-aware. Several screens are pushed as opaque routes over the live trip: Chat (accept_ride_panel.dart:861, BottomToTopTransition opaque=true), the trip drawer's Support, Notifications and Scheduled rides, and the destination picker. While one of them is open, GPS fixes keep calling _maybeScheduleOnTripRadarDemoOffer (line 685). After 2.2 s, _presentOnTripOffer shows the offer on the hidden trip screen and _armOnTripOfferExpiry starts the full accept time (15 s by default). When that runs out, _denyNextTripRadar sets _onTripRadarDeclined = true, so no further offers come on this trip, and it calls ExclusiveAnswers.instance.missed().

**Suggested fix:** Make AcceptRide a RouteAware subscriber of driverRouteObserver, as Home is. In didPushNext, hold the offer (pause its deadline, as _pauseLiveUpdates does) and do not present new ones; in didPopNext, resume with the time left.

### M35. The 'offline after missed offers' notice posted during a trip is consumed by the hidden Home island, so the driver never sees it

`lib/presentation/driver/accept ride/accept_ride_trip.dart:1228` (found by r2-driver1)

**What happens:** During a trip the driver lets 3 next-trip Exclusive offers run out (the admin default auto-offline count). The session records offline-after-trip, but nothing appears on the trip screen. When the trip ends, Home is offline with no explanation, because the 'went offline after N missed offers' message was shown and expired on the covered Home island minutes earlier.

**Why:** `IslandMessages` is a static queue meant for the Home island. Home subscribes in initState (home.dart:487) and never pauses that listener when another route covers it (`_pauseHomeUpdates` does not touch it). `_showNextIslandMessage` (home_map_sheet.dart:1257) takes the next message as soon as it is posted and starts its display timer. It checks only `mounted`, not `_routeVisible`. When the trip screen (pushed over Home) reaches the missed-Exclusive limit, it calls `setOnline(false)`, which during a trip only records offline-after-trip, and posts `HomeIslandNotices.offlineAfterMissed`. The trip screen's own island never reads IslandMessages, so Home, which is not visible, dequeues the message and drops it after 4.5 s.

**Suggested fix:** Have Home stop taking IslandMessages while `!_liveVisible` and drain the queue on didPopNext, and/or show trip-time notices on the trip island or in a SnackBar on the trip screen.

### M36. Silent GPS (no fixes, no error) leaves _hasLiveLocation true, so the Ride-check tick reads a GPS outage as a long stop and safety alerts send a stale position as current

`lib/presentation/driver/accept ride/accept_ride_trip.dart:1489` (found by r2-driver1)

**What happens:** On a trip, the driver goes through a 4 km tunnel (about 3 minutes, no fixes). About 2 min 20 s in, the 'Long stop' Ride check opens. It covers and hides the navigation island (opacity 0 while covering) as the driver leaves the tunnel, and it uses up the one long-stop check for this trip. If the driver raises an alert, the position sent is the tunnel entrance from minutes earlier. Verified by reading the code; not run.

**Why:** _hasLiveLocation is cleared only by a stream error, an unusable fix or a pause. When the stream simply goes quiet (tunnel, garage), it stays true indefinitely. The 20 s ride-check ticker passes it as `gps:` to RideCheckDetector.tick. That method treats gps=true plus no new fix as 'the car stands still' and runs _longStop against the last fix's time. The admin default longStopMinutes is 2 (ride_check_admin_config.dart:10). Native streams use a 1 s interval with distanceFilter 0, so a parked car still gets fixes and 2 minutes of silence means lost GPS, not a stop. Elsewhere the screen treats a fix older than 30 s as unusable (_nearArrivalTarget, _approachDistanceMeters, _rideCheckFarDrop use isUsableAt). The tick and _safetyAlertTrip (line 1470) do not. During the silence nothing calls keepLastKnown either, so the island keeps showing the frozen 'Turn right in 120 m' and ETA with no location warning.

**Suggested fix:** Pass `gps: _lastLocation?.isUsableAt(now) == true` (fresh GPS) to tick. Send the alert position only when it is fresh, or with its timestamp. Start a staleness timer that calls keepLastKnown after 30 s without a fix.

### M37. Re-tapping Continue on Add vehicle after taking document photos silently deletes the saved photos

`lib/presentation/driver/add vehicle/add_vehicle.dart:76` (found by driver2)

**What happens:** Vehicles > + > fill make/model/year/plate > Continue > Registration certificate > Take photo (saved locally) > Back > Continue again: the photo row is overwritten; the documents page shows no saved photo and the base64 image is gone from preferences.

**Why:** `_save` always upserts the bare identity map `submitted` = {id, make, model, year, plate} (lines 76-85) using the fixed `_vehicleId`. `LocalVehicleStore._upsertSnapshot` replaces the whole row for that id (`rows.removeWhere((row) => row['id'] == vehicle['id']); rows.insert(..., Map.of(vehicle))`, local_vehicle_store.dart) and skips photo fields that are null (`if (value == null) continue;`). After the driver has taken a registration/insurance photo on VehicleDocuments (which upserts the row with `registrationPhoto`/`insurancePhoto`), pressing Back returns to the still-mounted AddVehicle whose `_ready` is still true; tapping Continue again writes the row without the photo keys and the photos are gone. The new VehicleDocuments then restores `_registrationDone = false` and shows 'Recommended next step' again with no message. Reproduced at store level with a throwaway test (upsert identity -> upsert with photo -> upsert identity -> list: `registrationPhoto` absent), test deleted afterwards.

**Suggested fix:** In `_save`, merge onto the existing row (`{...previousRow, ...submitted}`) or have the store preserve photo fields when the incoming map omits them; alternatively navigate with pushReplacement / disable re-save once the draft exists.

### M38. Home takes and plays island messages posted while a route covers Home (e.g. 'offline after N missed' during a trip), so the driver never sees them

`lib/presentation/driver/home/components/../home_map_sheet.dart:1257` (found by r2-driver1)

**What happens:** During a trip the driver misses the Nth Exclusive offer. AcceptRide calls setOnline(false) and posts 'offline after N missed' (high priority). Home, under the trip route, consumes it at once and its 4.5 s timer ends it. After the trip the driver lands on Home, offline, with no explanation. In the same way, the 20 s 'High demand' and 50 s event popups and a 'Reservation accepted' confirmation play unseen under the trip or the Scheduled rides screen.

**Why:** IslandMessages is documented as 'Messages waiting for the Home island. Any screen can post one'. Home's listener _onIslandMessagesChanged calls _showNextIslandMessage, which checks only mounted and whether a message is already showing, never whether Home is visible (_liveVisible / _routeVisible). didPushNext pauses GPS and offers but not the island queue. So a message posted while another route covers Home is taken from the queue, shown on the hidden island for 2 to 4.5 s, and dropped. Real posters during the journey: AcceptRide's offlineAfterMissed (accept_ride_trip.dart:1228, posted while the trip screen covers Home), demo arrival and document popups through _showNoticePopups (home_account.dart:237), and Scheduled rides' reservationAcceptedAt and reservationCancelled (scheduled_rides.dart:235, 678). The trip island (AdaptiveTripIsland) never reads IslandMessages.

**Suggested fix:** In _onIslandMessagesChanged and _showNextIslandMessage, return early while !_liveVisible, and call _showNextIslandMessage from _resumeHomeUpdates, so queued messages wait until Home is on screen.

### M39. AppLifecycleState.inactive is treated as not foreground, so Home renders the driver as offline (radar "OFF · Tap to scan", offline dock, no "Finding trips") while the session is online

`lib/presentation/driver/home/home.dart:189` (found by driver3)

**What happens:** Driver is online on Home; a phone call comes in on iOS (app stays visible behind the call banner, state = inactive). Home immediately shows "Radar · OFF · Tap to scan" and the offline dock for the whole call; the driver believes they were taken offline. When the call ends, the online face returns. Offers arriving during the call were not listed.

**Why:** didChangeAppLifecycleState sets `_foreground = state == AppLifecycleState.resumed` (line 189); _isOnline (line 335) is `_liveVisible && _recoveryResolved && availableForOffers`, and the radar layer, dock, side menu and island all branch on _isOnline (home_map_sheet.dart:1654-1694, 1594, home.dart:713). `inactive` is a visible state: iOS during a phone call banner, Control Center/notification centre, Face ID prompt, app switcher; Android during a system dialog, the location-permission dialog, multi-window without focus. In all of these the app is on screen and after _pauseHomeUpdates() (line 190) it draws the offline face, cancels the dispatch subscription and offer timers, although DriverSessionController still says online and dispatch still sends offers. On return it snaps back. An incoming phone call while online is a routine driver situation.

**Suggested fix:** Treat `inactive` as foreground for rendering (only `paused`/`hidden`/`detached` pause updates), or keep rendering from the session state and use _liveVisible only to gate timers/subscriptions.

### M40. System Back on the 'Unresolved trip' dialog closes the saved trip and marks it terminal

`lib/presentation/driver/home/home.dart:531` (found by r2-driver2)

**What happens:** The driver's phone restarts during a long trip, and the saved ride is more than 6 h old or the app is reopened late. Home shows 'Unresolved trip' with Resume enabled. The driver presses Android Back (or browser Back on the PWA) to get rid of the dialog. The trip is marked cancelled by the driver or released to dispatch, and its recovery record is deleted, with no confirmation.

**Why:** For a stale snapshot (older than 6 h) or one without verified endpoints, Home shows an AlertDialog with 'Close trip' and 'Resume trip'. barrierDismissible: false only blocks taps outside the dialog. The Android or browser Back button still pops the DialogRoute with a null result, because there is no PopScope in the builder. The code treats any result other than true as 'Close trip' (`if (resume != true)`). It then writes a terminal marker (driver cancel, or released to dispatch) and clears the saved ride. So Back, which the driver expects to dismiss the dialog, silently cancels a trip that could have been resumed.

**Suggested fix:** Wrap the AlertDialog in PopScope(canPop: false), or treat a null result as 'ask again' rather than 'close'.

### M41. _hasRideOffers set from the Radar list on close is never cleared when those offers leave dispatch: the orb says 'Trip found', 'Finding trips' never shows and Exclusive offers are held back

`lib/presentation/driver/home/home.dart:762` (found by r2-driver2)

**What happens:** The driver opens the Radar list. Meanwhile the only Home card is taken by another driver and removed, and the list still shows two other trips. The driver closes the list, and those two trips then expire in dispatch. Home keeps showing 'Trip found · NEW · Tap for all' with nothing to take, never shows 'Finding trips', and no Exclusive offer can rise until the driver taps the orb again.

**Why:** Closing the full Radar list sets `_hasRideOffers = hasOffers || _radarHomeOffers.isNotEmpty`, where hasOffers comes from the list's own dispatch offers. _hasRideOffers is reset only by _dismissRadarHomeOffer, _refreshRadarHomeOffers (which needs pending Home offers), _openOfferTrip, go online and go offline. The dispatch watcher (_watchDispatchRadar) updates _latestDispatchOffers but never recomputes _hasRideOffers. Suppose the Home deck was emptied while the list was open, for example when a card was withdrawn or taken and removed after 2.8 s, and the list still had other trips. The flag then stays true after those trips expire. While it is true: _buildTripRadarButton shows 'Trip found / NEW / Tap for all' with zero trips (totalTrips = max(0, 0)); _waitingForTrips is false, so the island never says 'Finding trips'; and _showOutsideRadarOffer returns early for every non-reservation Exclusive offer (`!offer.reservation && (_pendingRadarHomeOffers.isNotEmpty || _hasRideOffers)`).

**Suggested fix:** Recompute _hasRideOffers from live state (Home deck, pending, or _radarTripsOpen > 0) in the dispatch listener, or derive it instead of storing it.

### M42. Driving-limit auto-offline leaves the Radar list open, and Match there still claims and starts a trip

`lib/presentation/driver/home/home.dart:939` (found by r2-driver2)

**What happens:** At 11 h 59 m 50 s the driver opens the Radar list to compare trips. At 12 h 00 the limit fires: the island says 'Offline' and the session goes offline, but the Radar list stays on screen with live Match buttons. The driver taps Match and gets a new trip although they are supposed to be resting for 6 h.

**Why:** `_drivingLimitReached` (not on a trip) calls `_goOffline()`. `_goOffline` cancels Home's own dispatch subscription and clears Home's offer lists, but never sets `showRideRequests = false`. While the full Radar page is open, Home's body is the `RideRequests` Stack (home.dart:717), so the SlidingUpPanel and its `_closeHomeFloatingPopupsForSheet` are not mounted, and `_closeDriverSheet()` cannot close the page. RideRequests has its own dispatch subscription and offer list. `_matchTrip`/`_claimTrip` never check the session's availability. On a won claim it pushes AcceptRide, whose post-frame `beginTrip` puts the offline, limit-blocked driver onto a trip with the driving clock running again.

**Suggested fix:** Set `showRideRequests = false` in `_goOffline`. Also make RideRequests refuse to claim when `sessionController.availableForOffers` is false.

### M43. A Match claim that succeeds after the driver went offline is silently discarded although dispatch assigned the trip

`lib/presentation/driver/home/home_offer_radar.dart:546` (found by driver2)

**What happens:** Driver taps Match, then long-presses the radar and confirms "Go offline" before dispatch answers (slow network). Dispatch answers success → the trip is assigned to this driver server-side; the app shows nothing, stays offline, never opens the trip and never declines/cancels it.

**Why:** While a Radar claim is in flight the radar orb is still wrapped in _radarLongPressOff (home_map_sheet.dart:1689, 1716-1723) and the island long press also offers "Go offline?" (1110-1116). _goOffline() calls _HomeOfferRadar._cancelAllOfferTimers() without preserveClaim (home.dart:949), which sets _homeRadarMatchingOfferId = null (home_offer_radar.dart:796-800). When _dispatch.claimOffer later resolves with ClaimOutcome.success, _claimHomeRadarOffer returns at line 546 because `_homeRadarMatchingOfferId != offer.id`; nothing tells dispatch and nothing is shown. In the demo repository the offer was already removed from the feed by the claim (demo_dispatch_repository.dart:565-566), i.e. it is taken by this driver. The driver is offline, the rider is matched to a driver who is not coming.

**Suggested fix:** Either block going offline while a claim is in flight (disable the long press / show "please wait"), or keep the claim across _goOffline and, on a late success, open the trip or send dispatch a decline/cancel for that offer.

### M44. Two Radar offers lost within 2.8 s share one _homeRadarLostMatchTimer: only the last is dismissed, and the other stays in _radarHomeOffers (hidden by the deck), which keeps the deck slot and "trips found" up and holds back every Exclusive offer

`lib/presentation/driver/home/home_offer_radar.dart:692` (found by driver2)

**What happens:** Driver has two deck cards from destination mode and turns destination mode off. Both cards are marked taken; after 2.8 s only the second disappears, the first stays as a greyed "Taken by another driver" card and the radar keeps saying trips are found until the driver taps × or goes offline.

**Why:** _watchDispatchRadar's listener loops over every listed/pending offer missing from the new snapshot and calls _resolveHomeRadarMatchLost for each (604-611). _resolveHomeRadarMatchLost marks the offer claimedElsewhere and arms the single field _homeRadarLostMatchTimer after `_homeRadarLostMatchTimer?.cancel()` (691-702). The second call cancels the first offer's dismissal, so that offer keeps state claimedElsewhere, stays in _radarHomeOffers (shown blurred/"Taken"), keeps _hasRideOffers true (radar "trips found", island green ring) and is only removed by a manual ×, a pause/resume (_resumeOfferTimers) or going offline. _refreshRadarHomeOffers never drops claimedElsewhere offers. Concrete demo path: two destination-mode trips on the deck (home_map_sheet.dart:463-465), then "Turn off destination" → _clearDemoDestinationTrips → DemoDispatchRepository.clearDestinationTrips emits a snapshot without both (demo_dispatch_repository.dart:614-624) → both resolved lost in one loop. With a real feed any update that drops two listed offers at once does the same.

**Suggested fix:** Keep one dismissal timer per offer id (a Map<String, Timer> like _radarOfferTimeoutTimers), or have the timer dismiss every offer currently in claimedElsewhere state.

### M45. A waiting Radar offer that left dispatch is stuck as a 'Taken' card when Home is paused during its 2.8 s removal

`lib/presentation/driver/home/home_offer_radar.dart:765` (found by r2-driver4)

**What happens:** A Ride check is open and a Radar trip waits as pending. Dispatch drops it from the feed. Within 2.8 s the driver opens another screen (any route push) and comes back. The Ride check is then answered. Reproduced with a throwaway widget test (with driverRouteObserver installed): after resume the radar still reads '1 trip / NEW'; 25 s later the deck holds ids=[audit-card] taken={audit-card} and the radar reads 'Trip found / Tap for all', though dispatch has had no offers for over 30 s.

**Why:** The dispatch watcher (line 604-610) also resolves pending offers that left dispatch: they become claimedElsewhere, and the shared _homeRadarLostMatchTimer is meant to remove them 2.8 s later. A pause in that window (another route pushed, a dialog, app inactive) runs _cancelAllOfferTimers(preserveClaim: true), which cancels that timer but keeps the claimedElsewhere state. On resume, _resumeOfferTimers re-schedules removal only for claimedElsewhere offers in _radarHomeOffers, never for those in _pendingRadarHomeOffers. The pending offer stays forever. It counts in the radar button's homeTrips (home.dart:1053), and once the blocker clears, _refreshRadarHomeOffers moves it onto the deck as a 'Taken' card that no timer ever removes. The pick-window timer ignores non-available cards, and the external-claim demo picks only available ones.

**Suggested fix:** In _resumeOfferTimers, include claimedElsewhere offers from _pendingRadarHomeOffers, or remove pending offers that left dispatch right away instead of giving them a Taken state and a timer.

### M46. An admin direct-assign claim won after the driver goes offline mid-claim is silently discarded

`lib/presentation/driver/home/home_offer_radar.dart:856` (found by r2-driver4)

**What happens:** An admin direct assign is up. The driver taps the orb (Accept) and the island shows 'Matching…'. The driver long-presses the island and confirms Go offline. Dispatch answers success. Reproduced with a throwaway widget test (completer-controlled claim): island onLongPress enabled during claim: true; AcceptRide after the won claim: 0; island messages: [Radar online, Exclusive ride, Matching…, Radar offline]. The rider's trip is assigned to a driver who never sees it.

**Why:** _claimAdminAssign awaits dispatch.claimOffer and then returns early when `_outsideRadarOffer?.id != offer.id`. _goOffline (home.dart:957) sets `_outsideRadarOffer = null`. The Exclusive sheet turns its down arrow and the Back button off while a claim runs, but the top-island long-press does not. home_map_sheet.dart:1110 checks only `reservation != null || exclusive != null`, and `exclusive` is non-null only when no island message is showing (line 969). _claimAdminAssign itself posts the 'Matching…' message (line 847), so while the claim runs the island long-press opens 'Go offline?'. When the driver confirms, the claim then resolves `success`, the early return fires, and no trip opens, no message shows and nothing is declined. Dispatch has already given the trip to this driver. The known finding at home_offer_radar.dart:546 covers the same pattern only for the Radar-card Match path, not for this Exclusive admin-assign path.

**Suggested fix:** Turn the island (and any other) Go-offline entry off while `_HomeExclusive._exclusiveClaiming` is true, or have _goOffline wait for or decline the claim in flight. Alternatively, on success with the offer no longer on screen, show the trip or send dispatch a decline or release instead of returning silently.

### M47. A withdrawn waiting (pending) Radar offer leaves _hasRideOffers true: Home shows 'Trip found / NEW' with no trips and blocks later Exclusive offers

`lib/presentation/driver/home/home_offer_radar.dart:916` (found by r2-driver4)

**What happens:** A Ride check is open (or an Exclusive offer is up) when a Radar trip arrives and waits as pending. Dispatch withdraws it (for example, a radar-group trip another driver took). The Ride check is answered. Reproduced with a throwaway widget test: with dispatch offers at 0, the radar orb reads title='Trip found' status=NEW subtitle='Tap for all' offer=true, and 'Finding trips' is not shown. The driver is told a trip was found when none exists, and no further Exclusive offer can appear until they tap the radar.

**Why:** _showRadarHomeOffer sets `_hasRideOffers = true` when it parks an offer in _pendingRadarHomeOffers, which happens while an Exclusive offer, a Ride check or a reservation request is up. _onOfferWithdrawn removes that pending offer but never recomputes `_hasRideOffers`. The same happens with _setAcceptsCash(false) (home_offer_rules.dart:53) and _onCategoriesChanged (line 32). When the blocker goes away, _releasePendingRadarOffers returns on an empty pending list (line 459), so nothing resets the flag. Everything that reads the flag is then wrong: the radar button shows the 'Trip found / NEW / Tap for all' face (home.dart:1055-1071), the island gets the green offers ring (home_map_sheet.dart:1061), 'Finding trips' never shows (_waitingForTrips at line 1197), non-reservation Exclusive offers are refused (line 239), and the later Exclusive demo (line 1228) never shows.

**Suggested fix:** Wherever pending offers are removed (here, in _setAcceptsCash and in _onCategoriesChanged), recompute `_hasRideOffers = _radarHomeOffers.isNotEmpty || _pendingRadarHomeOffers.isNotEmpty`, as _dismissRadarHomeOffer already does.

### M48. Home Radar cards and the Exclusive sheet never show the CASH badge in Swedish or French

`lib/presentation/driver/home/home_offer_radar.dart:1052` (found by r2-driver4)

**What happens:** The app is in Svenska (the Stockholm zone default) or the driver switches to Français. A cash offer reaches Home (demo dispatch offers have payment: 'Cash'). The Radar card and the Exclusive sheet show no CASH chip, so the driver accepts without knowing they must collect cash. In English the same offer shows the chip.

**Why:** _radarOfferView turns the offer's wire payment into the display word before building the RadarOfferView: `payment: offer.cash ? tr.cash : offer.payment`. RadarOfferView then works out the cash flag from that same string: `bool get cash => isCash(payment);` with `isCash(String payment) => payment.trim().toLowerCase() == 'cash'` (lib/widgets/radar_offer_card.dart:87-89). In sv tr.cash is 'Kontant' and in fr it is 'Espèces', so `offer.cash` comes out false. Both Home surfaces gate the badge on it: RadarOfferCard `if (show.badges && offer.cash) OfferBadge.cash(...)` (radar_offer_card.dart:224) and ExclusiveRequestSheet `if (show.badges && offer.cash)` (exclusive_request_sheet.dart:80). RadarOfferView.payment is used nowhere else, so swapping in tr.cash has no visible benefit. The Radar list screen passes the raw value (`payment: offer.payment`, ride_requests.dart:164/730) and keeps the badge, so the two lists disagree. The Swedish zone defaults to sv, so most drivers are affected.

**Suggested fix:** Pass the raw `offer.payment` (or carry the bool) into RadarOfferView and translate only where a payment word is displayed.

### M49. A reservation's Exclusive claim that wins while the driving-time limit forces Go offline (or a cash-rule change dismisses the offer) is dropped: dispatch has given it to this driver, but the app keeps no record of the win

`lib/presentation/driver/home/home_reservation.dart:489` (found by r2-driver1)

**What happens:** The reservation's Exclusive offer is up and the driver taps Accept. While dispatch decides, the driving-time limit is reached (or the driver confirms Go offline). The claim comes back success, but the code returns early. Dispatch has given the reservation to this driver, yet the phone still lists it as Available in Scheduled rides and never starts it. Tapping Accept there later gets 'no longer available', and the rider's booking has a driver who has no record of it.

**Why:** _claimExclusiveReservation stops the offer timer and awaits dispatch.claimOffer. If _outsideRadarOffer is cleared meanwhile, the function returns before looking at the result. _goOffline (home.dart:957) and going online (home.dart:918) both set _outsideRadarOffer = null directly; going offline can happen through the Go-offline confirm or _drivingLimitReached (home_account.dart:137). _claimReservation only updates ScheduledRideStore when the claim is lost, so a win is never recorded: no take(upcoming:true), no take(), no trip. The demo dispatch has already removed the reservation from its open set (demo_dispatch_repository.dart:536), so the next claim attempt returns unavailable. This is the same pattern as the known home_offer_radar.dart:856 bug, but on the reservation path.

**Suggested fix:** On success, always record it: take(id, upcoming: true) when the Exclusive window has not been reached, otherwise keep it as a won trip for when the driver is back online. Only skip the UI work when the offer is gone.

### M50. Won admin direct assign or Exclusive reservation is lost (shows 'Trip matched' or 'accepted', no trip opens) when a drawer route covers Home as the claim resolves

`lib/presentation/driver/home/home_reservation.dart:509` (found by driver4)

**What happens:** Exclusive reservation (or admin direct assign) is up, driver taps Accept, edge-swipes the drawer and opens Ride history while the claim is pending. Dispatch answers success: the reservation disappears from Scheduled rides and from Home, the island says "accepted", but no trip screen ever opens and nothing is persisted; on the server the trip is this driver's.

**Why:** _claimExclusiveReservation (home_reservation.dart:484-509) and _claimAdminAssign (home_offer_radar.dart:843-860) await dispatch, then on success call ScheduledRideStore.take(offer.id) / show "matched" and _openOfferTrip, which pushes via pushSingle (home_offer_radar.dart:940). pushSingle silently does nothing when Home is not the current route (single_route_entry.dart:11-13). During the claim the Exclusive sheet covers the dock, but the Scaffold drawer is still reachable by edge swipe (it is not a route) and its items push screens (Ride history, Wallet, …). The claim result then arrives while a route covers Home: the reservation has left Scheduled rides (take()), _reservation.wonId is set, _outsideRadarOffer is cleared in the post-frame callback, and no trip opens. Unlike the Radar deck path (_openClaimedHomeOffer waits for _liveVisible and is retried from _scheduleVisibleOffers), these two paths have no deferral/retry.

**Suggested fix:** Route won Exclusive claims through the same deferred handoff as the Radar deck (_claimedHomeOffer + _openClaimedHomeOffer, retried from _scheduleVisibleOffers/didPopNext), and have _openOfferTrip verify that pushSingle actually pushed before clearing state.

### M51. After midnight, 'Today'/'Tomorrow' reservations are re-read against the new date: a 'Tomorrow 01:00' ride jumps 24 h ahead and never reaches its Exclusive step

`lib/presentation/driver/home/home_scheduled.dart:94` (found by r2-driver4)

**What happens:** The driver goes online at 23:00. The main reservation is 'Tomorrow 01:00'. At 00:40 the Exclusive timer fires, _exclusiveStepReached sees 24h20m left and returns false, so the ride never becomes Exclusive on this phone. The Home popup keeps offering it as 'Tomorrow 01:00' when it is 20 minutes away. An accepted 'Tomorrow 01:00' ride cancelled at 00:30 is treated as a free cancel ('Free cancel until tomorrow 00:00') and is not counted as late. A re-plan after midnight moves its 'leave now' to the next night.

**Why:** Reservations keep the relative words 'Today'/'Tomorrow' from when they were booked (DemoReservations._at). pickupAt reinterprets those words against whatever 'now' it is given (driver_home_admin_content.dart:240). The demo books relative to the real clock (main +2 h, clashing +2h25, airport +5 h), so any session opened after 22:00 has 'Tomorrow' rides. At 00:00 each of them silently moves to the day after. Scope code that reads it: _exclusiveStepReached/untilPickup here, _untilExclusiveStep:105, _planScheduled:131 (any re-plan after midnight, e.g. a store change or going online, schedules 'leave now' 24 h late), ReservationWhen.ofRequest (sheet and island labels), ScheduledRideStore.isLateCancel/freeCancelUntil (scheduled_rides.dart:510-519), ScheduledRideStore.upcoming ordering, and the fixed card text built in _ScheduledRide.request (scheduled_rides.dart:1134).

**Suggested fix:** Store an absolute pickup DateTime (or a date plus wall time) when the ride is booked. Derive the 'Today'/'Tomorrow' words only for display.

### M52. Accepted and requested rides store a relative 'Today'/'Tomorrow' that is re-read against the current date, so after midnight a ride moves a day later

`lib/presentation/driver/home/home_scheduled.dart:131` (found by r2-driver4)

**What happens:** Reproduced: a ride with pickupDay 'Tomorrow' and pickupTime '00:30' resolves to 2026-10-22 00:30 when seen at 22:30, but to 2026-10-23 00:30 when seen at 00:05 (leaveAt 2026-10-23 00:12). A driver accepts at 22:40 and goes online at 00:05. Leave now never fires for the real 00:30 pickup, no backup is triggered, and cancelling at 00:10 is not counted as late.

**Why:** Reservations carry pickupDay 'Today' or 'Tomorrow', fixed when they are built (DemoReservations books them once from the first clock reading; the seed accepted ride is 'Tomorrow'). Every consumer resolves them again with pickupAt(now) = today or tomorrow of the current `now`. Once the date changes, a 'Tomorrow 00:30' ride booked at 22:30 resolves to the day after. _planScheduled re-runs on every store change and every time Radar goes live (_onRadarLive). After midnight it recomputes pickupAt and cancels the correct Leave-now timer, replacing it with one 24 h later. The same shift reaches the late-cancel rule (isLateCancel calls a 20-minutes-to-pickup cancel free), the smart gap, the clash check and the cards, which still say 'Tomorrow'.

**Suggested fix:** Store an absolute pickup DateTime (or a date) on the reservation and derive the 'Today'/'Tomorrow' label from it when displaying.

### M53. Accepting a reservation whose pickup has already passed leaves it as the 'next' scheduled ride forever, and it then filters out every trip offer

`lib/presentation/driver/home/home_scheduled.dart:140` (found by r2-driver4)

**What happens:** Reproduced with a throwaway widget test on the fast test day. At 08:10 the 08:05 Lidingö request is still listed (openRequests=2). The driver accepts it, giving upcoming=[Today 08:05, Tomorrow 08:15], then goes online, and dispatch publishes a trip that ends near the driver. Control run without the stale accept: the Radar deck shows ['toward']. With the stale accept: no Radar deck at all (deck found=0). The driver gets no trips for the rest of the session, and the 08:05 ride sits in Accepted indefinitely.

**Why:** _nextScheduledRide is ScheduledRideStore.upcoming.first, and upcoming sorts accepted rides soonest first without dropping ones whose pickup has passed. When the next ride's pickup has passed and lateSince is null, _planScheduled returns at line 140 (`if (state.lateSince == null && !pickupAt.isAfter(now)) { return; }`), so no Leave-now, late warning or backup is ever planned and the ride never leaves Accepted. _fitsSchedule (305-320) then calls SmartGap.offerFits against that past pickup. offerFits returns `!now.add(needed).isAfter(at)`, which is always false for a past `at`, so every Radar deck trip, Live-list trip (_rideAllowed in home_offer_rules.dart:22) and Exclusive offer (home_offer_radar.dart:241/326) is rejected. _towardPickupTime also keeps saying 'Trips toward your HH:MM pickup'. There are several ways a past ride gets there. (1) Requests are never pruned when their time passes (see the next finding), so the driver can accept one from Scheduled rides. (2) The Home popup can raise a released request whose pickup has passed: _exclusiveStepReached returns false when untilPickup is null, so _waitsForHome is true. (3) An assignment that waited while the driver was offline can be accepted after its time (_maybeShowAssignment never checks the pickup time). (4) A won Exclusive claim whose pickup has just passed is saved 'for later' (home_reservation.dart:494-498).

**Suggested fix:** Leave rides whose pickup has passed out of `upcoming` and _nextScheduledRide, or move them out of Accepted (missed or backup) when they pass. Refuse to accept a request, popup or assignment whose pickup has passed.

### M54. When the estimated drive plus spare minutes exceeds the 'be online' window, Leave-now opens the trip at onlineBy, after the latest departure time, and the go-online reminder and the 15-min reminder are skipped

`lib/presentation/driver/home/home_scheduled.dart:157` (found by r2-driver4)

**What happens:** The driver is 12 km from a normal 10:00 pickup. The estimated drive is 31 min, so leave = 09:14 and onlineBy = 09:30. No 60-min reminder fires, because 09:00 is not before 09:14. The trip opens at 09:30, 16 minutes after the latest departure, and the driver arrives about 10:01 plus the spare time they no longer have.

**Why:** SmartGap.leaveAt is documented as 'the latest moment to set off'. _planScheduled clamps the trip start to `leave.isBefore(onlineBy) ? onlineBy : leave`, so when leave < onlineBy the ride opens at onlineBy, after the latest moment to leave. The reminders and the online reminder are also only scheduled when they are `isBefore(leave)`, so in this case none fire between leave and the clamped start. For a normal ride (online 30 min before, spare 15 min) this happens whenever the estimated drive exceeds 15 min, roughly 6 km straight-line. A code comment says 'never before the be online window' is intended, but that rule directly contradicts leaveAt's meaning.

**Suggested fix:** Open the trip at `leave` when it is earlier than onlineBy (or at least warn at `leave`), and schedule the reminders relative to the actual start.

### M55. Native: the map padding switches between the 75% driving anchor and the plain top inset the instant a pan is reported or recenter starts, which the SDK realizes as an immediate content shift under the finger and a snap at the start of the 'no snap' recenter flight

`lib/presentation/driver/overlays/map_overlay_insets.dart:34` (found by driver2)

**What happens:** Driver in guidance on Android/iOS starts dragging the map: as soon as the drag registers (6 px) the whole map lurches ~130 px up under the finger; tapping recenter produces an equal downward jump before the smooth flight begins.

**Why:** On native the 75% vehicle anchor is realized through `GoogleMap.padding` (`drivingInsets(... following:)` returns a top inset of `2*desired - height + bottom`, roughly 520 px on an 800 px screen with a 260 px top and 120 px sheet, versus 260 px when not following). `accept_ride.dart:1227-1234` passes `following: _camera.isGuidance && _camera.mode == DriverCameraMode.following`. `onUserGesture` (`accept_ride.dart:1242`) runs `_rebuild(_camera.userGesture)`, so on the first 6 px of a drag the widget rebuilds with the smaller top padding; Android `setPadding` and iOS `GMSMapView.padding` keep the camera target lat/lng and re-centre it in the new padded region, i.e. the map content jumps by about (520-260)/2 = 130 px while the driver's finger is on it. On recenter the padding flips back before the eased 1 s flight (`google_driver_camera_port.dart:102-106` documents the flight as landing with no snap), so the flight starts with an instant jump. The web path is guarded (`drivingInsets` returns `edgeInsets` on web and the JS `configure` only pans when `state.anchored`, which `release()` has already cleared); the native path has no equivalent guard. Not executable here (needs a device), hence the modest confidence.

**Suggested fix:** Keep the native padding constant across follow/browse (the anchor is only needed for follow frames, which the port can realize by offsetting the camera target instead), or defer the padding change until the gesture ends and apply it together with the first camera move.

### M56. A ride-category choice saved in Ride preferences is not applied to offers after a cold start until the driver reopens Ride preferences

`lib/presentation/driver/preferences/preferences.dart:122` (found by driver4)

**What happens:** Driver switches off 'Priority' and 'Comfort' in Ride preferences (snackbar '4 ride categories saved'), kills and relaunches the app, goes online: Priority/Comfort offers appear on Home and in the Live list; reopening Ride preferences shows them correctly off and only then stops the offers.

**Why:** `DriverCategoryChoice.off` (the set offers are filtered by: home_offer_rules.dart `_offerAllowed`/`_rideAllowed` -> `DriverCategoryChoice.takes`) is only populated by `_publishChoice()` which runs from `_restoreSettings` (line 122) and `_toggle` (line 183) inside the Preferences screen. Nothing reads the `'categories'` settings section at startup: `main.dart` restores only `MapTrafficSetting.restore()` (line 41) and `DriverLanguage.restore()` (line 46); grep shows `read('categories')` exists only in preferences.dart. So the screen says '{n} ride categories saved' and persists the choice, but after a cold start `off` is `const {}` and the driver receives offers of every category they switched off, until they happen to open Ride preferences again.

**Suggested fix:** Move the restore/publish logic into a `DriverCategoryChoice.restore(SettingsRepository)` and call it from the app root at startup next to MapTrafficSetting/DriverLanguage; Preferences keeps using the same code.

### M57. Logout clears the saved category preferences but leaves the in-memory offer filter, so the next session filters offers by the previous driver's choice

`lib/presentation/driver/profile/profile.dart:394` (found by driver2)

**What happens:** Switch off 'Comfort' in Ride preferences, Profile > Log out > Return to demo, go online: Comfort offers are still filtered out although Ride preferences (storage) now shows every category enabled; opening Ride preferences once makes them reappear.

**Why:** Logout runs `runtime.logout` (main.dart:180-193) which calls `clearLocalUserData()` (removes every `movera_driver_settings_section_*` key incl. 'categories') and resets `MapTrafficSetting` and `DriverLanguage`, but never calls `DriverCategoryChoice.reset()`. `DriverCategoryChoice.off` therefore keeps the switched-off set after logout and 'Return to demo'. Home's `_startAccount` only listens to the notifier, so offers of those categories stay hidden while a reopened Preferences screen shows all categories on (storage was cleared) and only then republishes an empty set. LOCAL_DATA.md says logout removes settings; this derived state survives.

**Suggested fix:** Call `DriverCategoryChoice.reset()` (and reset the other derived demo singletons such as DocumentExpiryStore/DriverNotificationFeed if intended) in `_MoveraAppState._logout`.

### M58. System Back while a Radar claim is in flight unmounts Radar and drops a won trip (the on-screen Back is covered by the Matching banner)

`lib/presentation/driver/ride requests/ride_requests.dart:322` (found by driver3)

**What happens:** Driver taps Match, changes their mind and taps Back within a second, then reopens Radar: the trip is no longer listed (claim succeeded and removed it) and no active trip exists on this phone, while dispatch considers it accepted.

**Why:** `_claimTrip` awaits `claimOffer` and then returns if `!mounted` (line 322) without handling the result. The Back button (`_closeRides`, line 270-282) stays enabled during Matching, and Home unmounts `RideRequests` on close (`showRideRequests = false`, home.dart:759-765, the whole Stack is replaced). `DemoDispatchRepository.claimOffer` removes the offer from the feed on success (line 565-566) and there is no other path that opens the accepted trip. So a Back tap during the ~1.45 s claim delay loses the trip: it is assigned (server side) but the driver never sees AcceptRide, and the card is gone from Radar when reopened.

**Suggested fix:** Disable Back while `_matchingOfferId != null`, or hand a successful claim result to Home (callback/repository) so the active trip opens even when the Radar sheet has been closed.

### M59. The 'Could not match' banner after a network error on the Radar screen never clears and covers the Back and Refresh buttons

`lib/presentation/driver/ride requests/ride_requests.dart:337` (found by r2-driver1)

**What happens:** The driver taps Match on the full Radar list while connectivity drops. The red 'Could not match · Connection interrupted' banner appears and stays after the connection returns. The header's Back button and the 'new trips' Refresh under it cannot be tapped (no system back on iOS), so the driver is stuck on Radar unless they try another Match.

**Why:** On `ClaimOutcome.networkError` `_claimTrip` sets an error `_matchNotice` and schedules no timer to clear it. Every other notice path does: lost match at line 452 (2800 ms), success through `_matchNoticeTimer`. The notice is drawn as a `TripStatusBanner` in `Positioned(top: 0)` over the whole screen (lines 531-536). It is an elevated opaque Material, 10+pad.top+44+12 px tall, while the header (Back and Refresh) is pad.top+8+44+12 px. It therefore fully covers and absorbs taps on the Back button (`_closeRides`) and the Refresh control. It goes away only when the driver taps Match on another card and that claim resolves.

**Suggested fix:** Schedule the same 2800 ms `_matchNoticeTimer` that clears `_matchNotice` in the networkError branch, after cancelling any previous one.

### M60. A withdrawal of another offer cancels the won-match timer: the claimed trip never opens and Radar is stuck in Matching

`lib/presentation/driver/ride requests/ride_requests.dart:435` (found by driver3)

**What happens:** Driver taps Match on a Radar trip, dispatch answers success; within half a second another driver's accept withdraws a different card. The 'Matched' banner is replaced by 'Taken by another driver', no trip screen opens, the matched card spins forever, and no other trip can be matched until the driver closes and reopens Radar. The accepted trip is gone from the server feed.

**Why:** `_resolveMatchWon` (line 351-418) keeps the AcceptRide push on `_matchNoticeTimer` (500 ms). `_resolveMatchLost` (line 435) unconditionally does `_matchNoticeTimer?.cancel()` for any trip, and `_onWithdrawn` (line 181-189) calls it for every `claimedElsewhere` withdrawal whose trip is still `available`. If dispatch withdraws trip B while trip A's win timer is pending, the timer is cancelled: `navigator.push(ActiveRideTransition(ride))` never runs, `_matchingOfferId` stays A (line 437 only clears it when it equals B), `_offerStates[A]` stays `resolving`, so A's card shows the spinner forever and every other card's Match is disabled (`blockOtherOffers`, line 724-725). The server already removed A from the feed (`DemoDispatchRepository.claimOffer` line 565-566), so the trip is lost. Reproduced: match A, complete claim with success, pump 100 ms, emit `OfferWithdrawal(offerId: 'b', reason: claimedElsewhere)`, pump 2 s → `AcceptRide mounted: false; matching text: 1`. The demo fires `withdrawOffer(radarGroupTaken)` on its own timer (demo_dispatch_repository.dart:710-714), so the window is real, and a backend's `offer_withdrawn` can arrive at any moment.

**Suggested fix:** Use a separate timer for the won-match navigation (or push immediately and keep only the banner on a timer), and never let `_resolveMatchLost` for another offer touch the win timer; also ignore withdrawals while `_matchingOfferId` names a won trip.

### M61. Reservation claim that succeeds after the list unmounts is lost and later reported 'No longer available'

`lib/presentation/driver/scheduled rides/scheduled_rides.dart:278` (found by driver3)

**What happens:** Driver taps Accept on an open reservation and presses Back during the claim. Later they open Scheduled rides, see the reservation still under Requests, tap Accept, and get 'No longer available'. The reservation was assigned to them by dispatch and never reaches the Accepted tab, so no reminder, 'leave now' or waybill will come.

**Why:** `_claim` awaits `dispatch.claimOffer(ride.id)` (line 273) with the list screen's Back button active (`_buildHeader`, line 310-313). On success after unmount it returns false (line 278) and `_openRideDetails` stops before `_requests.remove`/`_accepted.insert` (line 222-224). The demo dispatch has already removed the reservation from `_reservations` and the Radar feed (demo_dispatch_repository.dart:537-544). The ride stays in the store's Requests; the next Accept calls `claimOffer` again, which now returns `unavailable` (line 559-560), so `_claim` runs `ScheduledRideStore.take(ride.id)` and shows 'No longer available' (line 286-291) to the driver who actually won it. The same path is hit when `_requests.remove(ride)` at line 223 fails because the request left the store while the claim was pending.

**Suggested fix:** Move the claim and the store mutation into `ScheduledRideStore` (not the widget) so a successful claim always moves the ride to Accepted regardless of the screen's lifetime; disable Back while `_claiming` is non-empty.

### M62. Waybill always says payment 'In the app', even for a cash trip

`lib/presentation/driver/waybill/waybill_sheet.dart:90` (found by r2-driver2)

**What happens:** The driver finishes a cash trip, taps Waybill › Open on Ride completed, and the receipt reads 'Payment: In the app' for a trip that was paid in cash. A driver showing it to an inspector or the rider shows a false payment record.

**Why:** The payment section of every waybill hard-codes `_Row(tr.payment, tr.inApp)`. WaybillRecord carries no payment method, and the sheet is opened from the Ride-completed page and the trip options for cash trips too. A cash trip's waybill therefore states the passenger paid in the app, although the driver just took the cash in the car (Collect cash sheet), and the Ride-completed page right behind it says 'Cash'.

**Suggested fix:** Store the payment method on WaybillRecord (it is known when the waybill is built) and show the localized method, cash included.

### M63. The demo banner uses the status-bar inset but leaves it in MediaQuery, so every screen below adds the top inset a second time

`lib/widgets/demo_mode_banner.dart:6` (found by r2-driver4)

**What happens:** On an iPhone 14/15 (top inset ~47-59 px), Android builds included, the strip 'Demo mode — no account' sits under the status bar. Below it, every AppBar starts with another ~50 px blank band, and the Home and trip islands float that much lower over the map.

**Why:** MaterialApp.builder puts DemoModeBanner (SafeArea(bottom:false)) above Expanded(child: navigator) in a Column. SafeArea pads only its own subtree. The sibling navigator still gets the app's MediaQuery with the full padding.top, because LayoutViewport copies media.copyWith(size: surface) and keeps the padding. Every Scaffold/AppBar below the banner pads for the status bar again, Home places its island at paddingOf(context).top - 4, and AcceptRide reserves safeTop + 210 for the banner area. On a notched or Dynamic Island phone that is a 47-59 px empty band under the banner on every screen, and a shorter expanded trip sheet.

**Suggested fix:** Wrap the Expanded navigator in MediaQuery.removePadding(removeTop: true), or place the banner inside the safe area without SafeArea and let routes keep the inset.

### M64. Backup and device-transfer rules leave out the root domain, so ride-check audio under app_flutter is not excluded, and the test only checks that the tags exist

`test/audit/privacy_storage_test.dart:55` (found by r2-driver2)

**What happens:** A driver records audio in a Ride check, then sets up a new Android phone with device transfer. The .m4a files under app_flutter/ride_check_audio are copied to the new device. A rules file containing `<include domain="root" path="."/>` would also pass this test. Worked from the Android backup-domain rules and path_provider_android behaviour; nothing was run.

**Why:** The test 'Android excludes app data from backup and device transfer' only asserts that `<cloud-backup>` and `<device-transfer>` are present. It never checks what they exclude. The rules exclude the `sharedpref`, `database` and `file` domains only. Ride-check audio is written under `getApplicationDocumentsDirectory()`, which on Android is `context.getDir("flutter")`, i.e. `<dataDir>/app_flutter`. That is in the `root` domain, not `file`. For apps targeting Android 12+, `allowBackup="false"` does not stop device-to-device migration, so the recordings leave the phone when the driver moves to a new device. The rules file's own comment says driver data stays on this device, and the ride-check UI says the recording is saved only on this phone. The test cannot catch this, or any rule that includes data.

**Suggested fix:** Add `<exclude domain="root" path="."/>` to cloud-backup, device-transfer and full-backup-content (or store recordings under getFilesDir). Make the test parse the XML and assert every domain the app writes to is excluded in both sections.

### M65. Web zoom-about-finger compensation uses the requested zoom, not the capped one: on the default raster map, a double tap or pinch at zoom 18 pans the map instead of zooming

`web/driver_map_camera.js:263` (found by r2-driver4)

**What happens:** On the web app (raster default), the driver has zoomed in to 18 and double-taps a street 120 px right of centre. The zoom stays 18, but the map scrolls about 120 px sideways. A pinch-out held at the cap makes the map slide away from the fingers on every frame.

**Why:** zoomAt clamps the next zoom to 3..21 and calls map.moveCamera({zoom: next}). Without a configured cloud map ID (the default; the meta tag holds the 'DRIVER_GOOGLE_MAP_ID' placeholder), the map is RASTER with maxZoom capped at 18 (lines 539-541 and zoomCap). Google Maps clamps the applied zoom to maxZoom, but the pan compensation is computed with scale = 2 ** (next - current) using the unclamped next, then applied with pan(). At or near the cap, the map pans by (1 - 2^Δ) × (finger offset from centre) although the zoom did not change, or changed less. The tapped road then moves away from the finger. Pinch does the same on every touchmove frame. The comment at google_driver_camera_port.dart:78 says the bridge caps pinch zoom on raster, but zoomAt uses 21.

**Suggested fix:** After moveCamera, read the zoom actually applied (Number(map.getZoom())) and compute scale from that, or clamp next to the active maxZoom (zoomCap()) before moving.

## Low (123)

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

### L8. Eight admin-editable Driver app texts are never read by any screen, so admin's edits to them have no effect

`lib/core/content/driver_app_texts.dart:228` (found by r2-driver1)

**What happens:** Worked by hand, not run. Admin sets offer.viewRoute (sv) to 'Visa rutt nu' and trip.completeRide to 'Avsluta'. No driver screen changes, because no widget reads these keys.

**Why:** DriverTexts.all is 'Every key admin can change' (Content › Driver app texts, Q30). offerFare, offerHide, offerReservationRequest, offerYourNextRide, offerViewRoute, offerNewReservation, offerViewDetails and tripCompleteRide are listed and mapped in driver_text_l10n.dart, but nothing in lib calls driverText() with them, and the matching tr getters (tr.offerHide, tr.offerViewRoute, …) are not used either. An admin who edits these texts sees no change in the driver app.

**Suggested fix:** Either wire these keys into the widgets that show the matching text, or remove them from DriverTexts.all so admin is not offered dead keys.

### L9. Demo document titles and demo notifications are localised once and cached, so they stay in the old language after the driver switches language

`lib/core/documents/document_expiry.dart:110` (found by driver1)

**What happens:** App starts in Swedish (zone default), the Home island already read the documents; the driver picks English in Settings. The island later says 'Försäkringsbrev expires in 7 days', the notification is 'Försäkringsbrev expires tomorrow' and the Documents screen keeps the Swedish names until the app is restarted. Conversely a Swedish driver always sees the three demo notifications in English.

**Why:** `DocumentExpiryStore.documents` lazily builds the demo list with `tr.docInsuranceLetter` etc. and caches it in `_documents` (line 110); only `load()`/`reset()` replace it and neither is called on a language change (`DriverLanguage.choose` → `_apply()` only flips `DriverAppTexts.language` and the notifier; no caller resets the store — grep shows no `DocumentExpiryStore.instance.reset()` in lib). The cached `title`/`shortTitle` feed the island and notification text (`home_account.dart:153-160` → `DriverNotices.documentExpiring(title: document.title, shortTitle: document.shortTitle)`), the Documents list (`documents.dart:224`) and the renewal sheet (`document_renewal.dart:65,168,304`). Reproduced with a throwaway test: with language `en` the first title is 'Insurance letter'; after setting the language to `sv` it is still 'Insurance letter' while `tr.docInsuranceLetter` is 'Försäkringsbrev'. The same pattern exists in `DriverNotificationFeed.items` (`driver_notifications.dart:127-128` caches `demoReceived`, whose first title is `tr.noticeNewScheduledRide` and whose bodies 'Tomorrow 07:40 · 126 kr · Tap to view', 'Bonus progress', 'Payout sent' are English literals even though a localised `tr.noticeScheduledBody` template exists).

**Suggested fix:** Keep language-independent ids/keys in `TrackedDocument` and resolve the title through `tr` at read time (or rebuild the demo list when `DriverLanguage.current` changes); build the demo notifications with the existing `tr.noticeScheduledBody` and arb keys.

### L10. Cash balance direction labels ('You owe Movera', 'Movera owes you', 'Settled') are hard-coded English and shown in the French/Swedish UI

`lib/core/earnings/cash_balance.dart:46` (found by driver2)

**What happens:** Driver app language is Svenska. A cash Premium reservation (fare 248,40 kr, cash 300,00 kr) is finished: the Collect-cash sheet and the trip's history detail show 'You owe Movera  −51,60 kr' in English between Swedish labels.

**Why:** `CashBalance.direction()` returns English literals and `directionLabel` is rendered on the cash-collect sheet (`cash_collect_sheet.dart:294`) and in history detail (`history_detail.dart:432`), screens that are otherwise fully localised through `tr`. The arb files only contain `totalYouOweMovera` / `totalMoveraOwesYou` (app_en.arb:911-912, app_fr.arb:422-423); there is no key for these three short labels, so a Swedish or French driver (the zone default for Sweden is `sv`, see `DriverLanguage`) sees an English line on every cash trip.

**Suggested fix:** Add `youOweMovera`, `moveraOwesYou`, `settled` keys to the arb files and return `tr.*` from `direction()` (or move the words to the presentation layer).

### L11. Offer, reservation and scheduled-ride distances and the rate percentages always use a '.' decimal in fr/sv, while the trip island and the route instruction copy use the localized ',' mark

`lib/core/geo/driver_distance.dart:9` (found by driver3)

**What happens:** Swedish driver on trip: island '1,2 km', navigation banner '1.2 km'; Radar card '4.2 km' beside a fare '104,80 kr'.

**Why:** `driverDistanceMeters` formats with `toStringAsFixed` (dot) and is used on offer cards, reservation maps and scheduled rides; `navigation_instruction_banner.dart:331-333` does the same for the banner distance; `driver_home_admin_content.dart:74` (`cancellationLabel`) and acceptance_rate.dart:30 / cancelation_rate.dart:30 format percentages with a dot. `adaptive_trip_island.dart:519-521`, by contrast, replaces '.' with `tr.navDecimalMark` (',' in fr/sv). During navigation the island says '1,2 km' while the banner under it says '1.2 km'. Swedish and French conventions use the comma, as Money already does ('104,80 kr').

**Suggested fix:** Route all decimal formatting through one helper that applies `tr.navDecimalMark` (or NumberFormat with the driver locale).

### L12. Corrupt-record warnings log the raw stored JSON (rider names, addresses, free-text notes) through FormatException.toString()

`lib/core/history/prefs_trip_history_repository.dart:88` (found by driver4)

**What happens:** A localStorage write is cut off mid-blob (web quota, process kill). On the next History open the console/crash log receives 'WARN History JSON malformed: FormatException: Unexpected end of input (at character N) ..."riderName":"Angelica Holm","pickup":"Sveavägen 12...' — rider PII in a log that is meant to be shippable to a crash reporter.

**Why:** `DriverLogRecord` documents that messages 'must not contain rider names, phone numbers or free text' (driver_log.dart:5-6), and the default sink prints to the console in release builds too (`debugPrint`, driver_log.dart:42). Several readers interpolate the `FormatException` thrown by `jsonDecode` into the message. Dart's `FormatException.toString()` appends a window of the `source` string around the failing offset, so the log line carries whatever personal data sits near the corruption. Verified with a dart script: `jsonDecode` of a truncated history blob logged `...:"Angelica Holm","pickup":"Sveavägen 12, Stockholm","phone":"+46701234567"` under 'History JSON malformed:'. Affected in-scope sites: history (`prefs_trip_history_repository.dart:88`, rider names/addresses), ride-check log (`ride_check_log.dart:104`, includes the driver's 'What happened' free text and answers), and settings (`settings_repository.dart:84` builds `reason: '$storageKey: $error'` which `local_quarantine.dart:62` logs; settings sections hold trusted-contact phone numbers and vehicle drafts). The same pattern exists in `prefs_active_ride_repository.dart:81` (out of scope) via `DriverLog.error(..., error, stack)` which the sink prints verbatim.

**Suggested fix:** Log only `error.message` (and offset) for FormatException, never `$error`/`error.toString()`; in `DriverLog._debugSink` scrub `FormatException.source` before printing so no sink can leak stored blobs.

### L13. Local history is capped at 500 rows (completed and cancelled), so for a driver with more than 500 rows in a month the Month view's total and ride count silently leave out the oldest trips

`lib/core/history/prefs_trip_history_repository.dart:150` (found by r2-driver4)

**What happens:** The driver does 25 trips a day from 1 October. On 22 October, about 550 rows have been archived, so the 1-2 October trips are deleted from storage. History -> Month shows 'October 2026' earnings and ride count without them. The money shown for the month is wrong, and the old receipts cannot be recovered.

**Why:** Both `_decode` and `archive` keep only `rows.take(maxReceipts)` with maxReceipts = 500, counting completed and cancelled rows alike. Older rows are dropped from storage on the next archive. Ride history's 'Month' period sums `_periodRidesList`, filtered by calendar month from that truncated list, and labels it 'October 2026' with no hint that older trips were evicted. At the journey's 25 trips a day (plus cancels), 500 rows cover about 19 days, so from around the 20th of the month the month's 'Recorded fares' and ride count are too low, and the dropped receipts are gone for good.

**Suggested fix:** Evict by age (for example older than the period views need) rather than by count, or keep per-period aggregates. At minimum, mark a period total as partial when its oldest row may have been evicted.

### L14. Cash trips use two money models: History's cash balance treats the fare as the driver's money, while the waybill takes a 25 % Movera fee from the same fare

`lib/core/history/trip_history.dart:172` (found by r2-driver1)

**What happens:** Cash trip, fare 128,40 kr, the rider pays 128,40 kr in cash. The latest waybill shows Movera fee −32,10 kr, your earnings 96,30 kr. Ride history -> Other earnings shows +0,00 kr 'Settled' and does not show the 32,10 kr owed to Movera.

**Why:** The waybill sheet treats `fare` as what the rider pays: WaybillPayment takes a 25 % Movera fee and shows 'Your earnings' = fare − fee. History's cash balance treats the same `fare` as the driver's money: CashBalance.balance = fare − cashCollected. For a cash trip where the rider paid exactly the fare, History says 'Settled · cash matched your fare', but by the waybill the driver holds Movera's 25 % and owes it. The two screens give contradictory money for the same trip, and 'Other earnings' sums the History version.

**Suggested fix:** Use one money model: either compute the cash balance from the driver's earnings (fare − fee) or drop the fee from the waybill for these trips. Until pricing comes from the backend, make both screens read the same definition.

### L15. Outside the demo, the island shows 'Expect a trip in 2–5 min' and 'Demand rising near you' from the busiest admin area anywhere and a static 'Busy' label, not from the driver's own area or any trend

`lib/core/island/island_waiting_signals.dart:101` (found by r2-driver2)

**What happens:** Worked by hand, not run. With a real (non-demo) dispatch repository, the driver waits in Täby. The admin seed has Södermalm at 86% and Arlanda at 82%, so the island rotates 'Expect a trip in 2–5 min' and 'Demand rising' with nothing behind either claim.

**Why:** IslandWaitingSignals.fromHome is the non-demo path; its comment says a message only exists when its fact does, so the island never makes something up. Yet expectTripSoon is true when any of the 12 Greater Stockholm areas (Arlanda included) is at 80% or more, wherever the driver is. demandRising is true whenever any area's static label equals 'busy', which is a level, not a rise. A driver waiting in Täby (46%, 'Quiet') is told to expect a trip within 2–5 minutes and that demand is rising.

**Suggested fix:** Show these tips only when the driver's own area (by position) meets the threshold, and drop 'Demand rising' unless a trend value is sent.

### L16. Island strip message '<stop> next' concatenates a hardcoded English word onto a localized stop label

`lib/core/island/trip_island_controller.dart:322` (found by driver1)

**What happens:** A French- or Swedish-language driver on a multi-stop trip sees the island strip read 'Arrêt 1 next' / 'Stopp 1 next' when heading to a stop.

**Why:** TripStripController.update says `_say('${next.stopLabel} next')` when a stop leg starts. stopLabel comes from AdaptiveTripIsland.pointLabel (adaptive_trip_island.dart:271), which is `tr.stopNumber(_stopCursor + 1)` (accept_ride.dart:809) and is localized ('Arrêt 1' / 'Stopp 1' per app_fr.arb:27, app_sv.arb:27). Every other message in this controller goes through `tr.` (riderBags, trafficAheadValueMin, arrivingInEtaMinTimeTime2, nextTripSecuredNextTripFare, pickupOnPickupSideSide, tollAhead). There is no arb key for this string (grep of app_en.arb finds only holdToStopNextTrips / cancelReasonNextTripOtherDetail).

**Suggested fix:** Add an l10n key (e.g. `stopNext`: 'Stop {number} next' / 'Arrêt {number} ensuite' / 'Stopp {number} härnäst') and call `_say(tr.stopNext(...))`, or pass the already-localized full phrase in TripStripInput.

### L17. The 'same fix reported again' guard compares the route by identity, so every route refresh/reroute resolves the same GPS fix twice and doubles the per-fix zoom, speed and bearing smoothing steps

`lib/core/navigation/driver_camera_controller.dart:552` (found by driver4)

**What happens:** During a reroute mid-turn the camera rotates and zooms with a visibly bigger single step than on other fixes (e.g. zoom 0.5 instead of 0.25 in one frame), the exact effect the guard was written to prevent.

**Why:** `update()` returns early only when `identical(location, _location) && identical(route, _route) && ...`. The trip calls `_camera.update(location, route: _navigation.route)` in `_applyDriverPosition` (`accept_ride_trip.dart:665`) and again from `_followVehicle()` after `_refreshRoadRoute()` (`accept_ride_trip.dart:731`). Whenever that refresh produced a new `RoadRoute` object (every 90 s silent refresh, every reroute, and `NavigationController.ensureRoute` always allocates a new `RoadRoute` at line 404), the second call passes the identity check and `DriverCameraPolicy.resolve` runs twice for one fix: `_smoothedSpeed` applies its 0.3 blend twice, `_cruiseZoom` may step up to 2×0.25 out / 2×0.4 in instead of once, and the bearing damping at lines 320-323 applies 0.65 of the remaining delta twice. The guard's own comment states the intent: 'Resolving it twice would smooth the turn twice.'

**Suggested fix:** When only the route changed for an already-resolved location, update the policy's route/geometry without re-running the speed, zoom and bearing smoothing (e.g. resolve with `immediate: false` but skip the smoothing when `identical(location, _location)`).

### L18. Demo notifications (scheduled-ride body, Bonus progress, Payout sent) are hard-coded English although the arb has noticeScheduledBody; the event arrival texts are admin-authored by design

`lib/core/notifications/driver_notifications.dart:333` (found by driver2)

**What happens:** Swedish driver opens Notiser: 'Ny bokad resa' followed by the English body 'Tomorrow 07:40 · 126 kr · Tap to view', then 'Bonus progress' and 'Payout sent' cards; 50 s after Home opens the island says 'Event tonight · City'.

**Why:** `DriverNotices.demoReceived` and `demoArrivals` build notices with English literals: body 'Tomorrow 07:40 · 126 kr · Tap to view', title 'Bonus progress' + body '18 of 25 trips this week. 7 more for 350 kr.', title 'Payout sent' + body '2 450,00 kr is on its way to your bank.', and the event arrival title 'Stockholm evening demand', body '18:00–22:30 · Central Stockholm. Be online before the main departure window.', island 'Event tonight · City'. `driver_notifications_screen.dart:256,280` renders `notice.title`/`notice.body` directly; the island shows `notice.island`. Other notices in the same file use `tr.*`, so this is an omission, not a design choice. In addition the list is cached once (`_items ??= DriverNotices.demoReceived(_now())`, line 134) so the localized parts keep the first language after a switch.

**Suggested fix:** Move these texts into the ARB (they are app demo content, not admin content) and build the list lazily per language.

### L19. Logout leaves Ride-check audio recordings (.m4a) in the app documents folder, although the logout dialog says local data is cleared

`lib/core/privacy/local_data.dart:111` (found by r2-driver4)

**What happens:** Driver A records audio during a Ride check, then logs out and hands the phone to driver B. The .m4a files of A's trip stay in the app's documents folder (and in device backups) with no reference left and no way to remove them from the app.

**Why:** NativeRideCheckRecorder writes in-trip audio (rider and driver voices) to <documents>/ride_check_audio/<id>.m4a. clearLocalUserData removes the Ride-check log rows that point at those files but never deletes the directory. The logout dialog says local data on this device will be cleared. Afterwards the recordings stay on disk, orphaned, with no UI to reach or delete them, and they keep piling up across drivers on a shared phone.

**Suggested fix:** Delete the ride_check_audio directory in clearLocalUserData (native only), or record in LOCAL_DATA.md that recordings survive logout and give the driver a delete action.

### L20. Native only: persistNow is silently dropped while another save is in flight (active_ride_controller.dart:276-278), so a stop arrival or departure, a secured next trip or a next-trip cancel stays unsaved until the next save. Not reachable on web/Safari.

`lib/core/ride/active_ride_controller.dart:276` (found by r2-driver4)

**What happens:** A driver leaves stop 1 at the moment a GPS snapshot save is in flight, and the tab crashes a minute later. Restore puts them back in 'waiting at stop 1' and adds the whole drive since the last save to the paid stop wait. A next trip the driver cancelled can likewise come back as secured, while history already records it as cancelled.

**Why:** _write returns false at once when `_writing` is true. Several trip changes are persisted only through a single persistNow, and none of the callers check the result or retry: stop arrival (_onArrivedTap sets _paidStopWait, line 529), stop departure (_stopCursor += 1 and paid stop seconds folded in, line 862), a secured next trip (line 1206), and a next-trip cancel (accept_ride_sheet.dart:266). If a GPS snapshot save (every 2 minutes) or a lifecycle save is in flight at that moment, the change is not written until the next save. The documented Safari crash kills the tab with no pause event, so after a reload the trip restores from the older snapshot.

**Suggested fix:** Give persistNow a 'dirty' flag: when a write is in flight, mark the state dirty and save again when that write finishes, instead of returning false.

### L21. persistNow() silently drops a state change when another background save is in flight (stop advance, secured next trip, next-trip cancel)

`lib/core/ride/active_ride_controller.dart:317` (found by r2-driver4)

**What happens:** I reproduced this in a throwaway test. With a slow repository, a background persistNow() is in flight; stopIndex changes to 1 and a second persistNow() returns false. After the first save completes, the stored snapshot still has stopIndex 0 ('F: second=false saved=[0] error=null'). If the tab or app dies within the next 2 minutes, the restore puts the driver back at the already-finished stop, or brings back a next trip the driver cancelled (already archived as cancelled), or loses a just-secured next trip.

**Why:** persistNow calls _write, which returns false without saving or setting persistenceError when _writing is already true (line 276). The trip screen relies on persistNow to make non-stage progress durable. Examples: the stop wait starting (accept_ride_trip.dart:529), the stop wait ending with _stopCursor += 1 and _paidWaitSeconds (862), securing a next trip (1206), and cancelling the secured next trip (accept_ride_sheet.dart:269). A GPS snapshot (every 2 min, line 676) or a lifecycle save can be in flight at that moment. The newer state is then not written until the next 2-minute GPS save, no error SnackBar appears, and no retry runs. This is unlike driver commands, which wait for the background save (D-09).

**Suggested fix:** When a background save is in flight, mark the snapshot dirty and re-run the save when it completes (coalesce), instead of returning false.

### L22. Snapshot times are stored as local ISO strings with no offset, so on the autumn DST night a restore adds an extra hour of waiting (and the freshness check is off by 1 h)

`lib/core/ride/active_ride_repository.dart:251` (found by r2-driver1)

**What happens:** Tested with the SDK's dart under TZ=Europe/Stockholm: a time saved at 2026-10-25 02:20 CET parses as 00:20Z instead of 01:20Z, and 10 real minutes later the computed age is 1:10:00. A driver waiting at a pickup whose app reloads in that hour gets 3 600 s of extra paid waiting, about 735 kr at 12,26 kr/min.

**Why:** savedAt, arrivedAt, acceptedAt and startedAt are written with toIso8601String() on local DateTime values, which have no 'Z' or offset. They are parsed back with DateTime.tryParse as local time. During the repeated 02:00-03:00 hour in Europe/Stockholm, Dart resolves the ambiguous wall time to the first (CEST) instant. A snapshot saved in the second (CET) 02:xx therefore reads back one hour earlier than it was written. AcceptRide adds now - savedAt to the wait (accept_ride.dart:615), and isFreshAt uses the same difference.

**Suggested fix:** Store snapshot instants as UTC (toUtc().toIso8601String()), as the terminal markers already do.

### L23. Journal replay re-stamps the queued trip's savedAt to 'now', so an interrupted journal replayed days later restores the queued trip as fresh and skips the stale-trip prompt

`lib/core/ride/prefs_active_ride_repository.dart:184` (found by r2-driver2)

**What happens:** The driver finishes A with next trip B secured. The app dies right after the journal write (afterWrite 'journal'). Two days later the driver opens the app: reconcile hands off B with savedAt = now, and Home immediately restores B as a live trip heading to a pickup from two days ago, with no 'Unresolved trip' prompt.

**Why:** An interrupted CompletionJournal (app killed between writing the journal and finishing the handoff, or a storage failure) is replayed by Home on the next cold start (home.dart:508). handoff() writes next.stamped().toJson(), and stamped() sets savedAt = DateTime.now(). Neither handoff nor _replay compares the journal's completedAt with PersistedActiveRide.freshnessWindow. Home then reads a snapshot that is always isFresh and pushes AcceptRide.fromPersisted(B) directly, skipping the 'older than 6 hours' dialog that a normal snapshot of the same age would get.

**Suggested fix:** Stamp the handed-off trip with the journal's completedAt (or keep its original savedAt) so Home's freshness check still applies to an old replay.

### L24. formatDistance chooses the unit before rounding: 999.5-999.99 m shows '1000 m' and 9950-9999 m shows '10.0 km'

`lib/core/routing/route_instruction.dart:539` (found by driver1)

**What happens:** Island reads 'Turn left in 1000 m' for one or more fixes just before switching to '1.0 km'/'999 m', an inconsistent unit boundary visible to the driver.

**Why:** The branch chooses the metre format on the raw value (`meters < 1000`) but prints `meters.round()`, so 999.5..999.99 rounds up to 1000 and is rendered as `1000 m`, while 1000.0 renders as `1.0 km`. This is the live banner distance (`navigation_controller.dart:593` `distanceLabel: RouteInstructionCopy.formatDistance(meters)`), fed every fix with continuous metres from `RouteProgressCalculator`.

**Suggested fix:** Round first (`final rounded = meters.round();`) and branch on the rounded value, or use `meters < 999.5`.

### L25. Ride check reason is saved to local storage in the display language, unlike its answers, so Trip details mix languages after a switch

`lib/core/safety/ride_check_controller.dart:124` (found by r2-driver1)

**What happens:** A Ride check fires mid-trip while the app is in Swedish. Later the driver switches to French and opens the trip in History. The line reads '<French trigger> · Bilen har stått stilla i 4 min' while the answers below are in French.

**Why:** RideCheckRecord answers and questions are saved as English keys and translated when shown (rideCheckAnswerWords / rideCheckQuestionWords in ride_check_l10n.dart). The reason, however, is saved as rendered text: `reason: event.reason.text`. The text is built from tr.rcStoppedLead, tr.rcMinutes, tr.rcLongerLead and so on in RideCheckDetector. PrefsRideCheckLog persists it (`'reason': reason`, ride_check.dart:298), and History shows it as stored: `'${check.trigger.text} · ${check.reason}'` (ride_check_history_entry.dart:117). The trigger is translated when shown; the reason is frozen in the language of the trip.

**Suggested fix:** Store the trigger with its numbers (minutes, metres, percent, place) and build the reason when it is displayed, as the answers already are.

### L26. Ride check fired-trigger set and trip start are not restored after a reload, so an answered check can reopen and the 'longer trip' timer restarts

`lib/core/safety/ride_check_detector.dart:17` (found by r2-driver2)

**What happens:** The driver answers a long-stop check ('Traffic'), Safari kills the tab, and the trip is restored while the car is still stuck. A couple of minutes later, the same long-stop check opens again on the same trip.

**Why:** _fired lives in the detector, which AcceptRide recreates in didChangeDependencies (accept_ride.dart:664). AcceptRide.fromPersisted after a reload or PWA resume therefore starts with no fired triggers, and checks the driver already answered on this trip can open again. The restore path also passes the restore time instead of the saved start (accept_ride_trip.dart:108 `startTrip(_rideCheckNow)`), although the detector's doc says 'Restored trips pass their saved start'.

**Suggested fix:** Persist the fired triggers (and the trip start) in the active-ride snapshot, or seed them from the trip's saved RideCheckRecords on restore. Pass restored.startedAt to startTrip.

### L27. After a pause or an open card, a 20 s ride-check tick that lands before the first observe() uses the old stop clock and can fire a false long stop

`lib/core/safety/ride_check_detector.dart:82` (found by r2-driver2)

**What happens:** The driver switches to another navigation app for 5 minutes while driving, then returns. On resume, the routing request takes a few seconds. A ride-check tick lands in that window and opens 'Your car has stopped for 5 min', even though the car has been moving the whole time. The longStop trigger is then used up for the rest of the trip.

**Why:** _stillSince is only refreshed by observe(). The trip screen stops calling observe while the app is paused (_pauseLiveUpdates) and while any card is open (_rideCheckWatching is false). After resume, the first fix sets _hasLiveLocation = true (accept_ride_trip.dart:661) but calls _rideCheckObserve only after `await _refreshRoadRoute(force: true)` (up to the 8 s routing timeout, line 683-686). A 20 s ticker tick in that window calls tick(gps: true), which computes `at - _stillSince` from the old timestamp and fires longStop. Nothing resets _stillSince when observation resumes.

**Suggested fix:** Reset the stop clock (_stillAt = null / _stillSince = now) whenever observation resumes after a pause or after a card closes, or call observe before the awaited route refresh.

### L28. Ride check reason is stored and sent to Movera in the driver's UI language, contrary to the 'record and alert keep English' rule

`lib/core/safety/ride_check_detector.dart:163` (found by r2-driver2)

**What happens:** A Swedish-language driver gets a long-stop check. The alert to the English-speaking safety team reads topic 'Accident or collision' with the reason 'Bilen har stått still i 4 min'. Later, the driver switches the app to English, and the trip details still show 'Long stop · Bilen har stått still…'.

**Why:** ride_check_l10n.dart states that the topic, trigger and question values 'stay in English: they are what the trip record and the alert to Movera keep'. The reason, however, is built from tr.* (rcStoppedLead, rcMinutes, rcEndedLead, rcOffRouteLead, rcLongerLead, rcCrashLead…) at detection time. Its localized text is then saved in RideCheckRecord.reason (ride_check_controller.dart:124) and sent as SafetyAlert.reason (ride_check_controller.dart:318). As a result, the alert to Dispatch mixes an English topic and answers with a French or Swedish reason, and trip history (ride_check_history_entry.dart:117 `'${check.trigger.text} · ${check.reason}'`) shows the reason in whatever language was active when the check fired, even after the driver switches language.

**Suggested fix:** Keep a language-neutral reason (trigger plus parameters: minutes, meters, place) in the record and alert, and localize it only when displaying it.

### L29. Ride-check recordings are written to the iOS Documents directory, which is included in iCloud/iTunes backups, contradicting the 'saved only on this phone' permission text

`lib/core/safety/ride_check_recorder_native.dart:31` (found by driver3)

**What happens:** Driver with iCloud Backup enabled records a Ride check conversation with a rider; the .m4a is uploaded to Apple's servers with the next device backup although the app told the driver it stays only on the phone.

**Why:** `start()` saves audio under `getApplicationDocumentsDirectory()/ride_check_audio`. On iOS that is `NSDocumentDirectory`, which Apple backs up to iCloud/Finder by default unless the file is flagged `NSURLIsExcludedFromBackupKey` or stored under Application Support/Caches. `ios/Runner/Info.plist:9-10` tells the user 'The recording is saved only on this phone' and `safety_alert_repository.dart:36` repeats 'recordings stay on the phone'. Cabin audio of riders therefore leaves the device whenever the driver has iCloud backup on, which the stated promise and GDPR expectations do not cover.

**Suggested fix:** Store recordings under `getApplicationSupportDirectory()` and mark the folder excluded from backup (or set `NSURLIsExcludedFromBackupKey` on each file).

### L30. NativeRideCheckRecorder never disposes its AudioRecorder, so each trip leaks a native recorder; an empty capture's file is also left on disk

`lib/core/safety/ride_check_recorder_native.dart:48` (found by driver3)

**What happens:** Driver taps Record then immediately Stop on several trips: each leaves an empty `ride-check-<trip>-<ms>.m4a` in Documents/ride_check_audio (grows forever) and one undisposed native recorder per trip for the life of the process.

**Why:** `stop()` returns null for an empty capture but does not delete the file it just created in `ride_check_audio/` (line 48), so every failed/instant stop leaves an orphan `.m4a` under the app documents folder; nothing in the app ever lists or prunes that directory. Separately, `AudioRecorder` (record 7.1.1 exposes `Future<void> dispose()`, record.dart:173) is created per `RideCheckController` via `services.createRecorder()` (ride_check_controller.dart:234) and neither `NativeRideCheckRecorder` nor `RideCheckController.dispose()` releases it, so each trip in which the driver taps Record leaves a native recorder instance (method-channel/stream subscription) alive.

**Suggested fix:** Delete the empty file before returning null; add `dispose()` to `RideCheckRecorder` that calls `AudioRecorder.dispose()` and invoke it from `RideCheckController.dispose()`.

### L31. French plurals written as =1{1 ...} render a literal '1 course' / '1 arrêt' for count 0 (gen-l10n maps =1 to the CLDR 'one' slot, which in fr covers 0)

`lib/l10n/app_fr.arb:713` (found by driver1)

**What happens:** French driver opens history with no rides or a reservation with zero stops; the counters read '0 courses' / '0 arrêts' instead of '0 course' / '0 arrêt'.

**Why:** French grammar uses the singular for 0 and 1 (CLDR 'one' covers 0 and 1 for fr). The ARB strings tripsCount (713), stopsCount (714), riderBags (676), inDaysCount (861), schedRidesHidden (904) and ratingAndRides (1319) are written as `{count, plural, =1{...} other{...}}`, so count 0 selects the 'other' branch and the UI shows '0 courses', '0 arrêts', 'Le passager a 0 bagages', 'dans 0 jours', '0 courses masquées'. The gen-l10n plural rules would do the right thing if the `one` category were used instead of `=1`. The English and Swedish files are fine with =1/other.

**Suggested fix:** In app_fr.arb use `one{...}` (CLDR category) instead of `=1{...}` for these keys, or add `=0{0 course}` branches.

### L32. A failed clearLocalUserData leaves the driver logged in with every long-lived storage repository invalidated (generation already bumped) and no recovery

`lib/main.dart:184` (found by driver2)

**What happens:** On a device where SharedPreferences commit fails for one key (full disk, broken prefs file), the driver taps Log out, sees 'Could not clear local data', continues driving; the next accepted trip is not persisted, so a crash mid-trip comes back to an empty Home.

**Why:** `clearLocalUserData()` calls `LocalWriteSession.beginCleanup()` (local_data.dart:114), which increments the generation before any key is removed; every repository instance created earlier (`_activeRide = PrefsActiveRideRepository()` in main.dart:93, the settings/vehicle stores held by open screens) now fails `LocalWriteSession.check` with 'Local session ended; reopen the screen before saving'. If a `prefs.remove` returns false the function throws (local_data.dart:135-137/148-150), `_logout` rethrows before reaching `_activeRide = PrefsActiveRideRepository()` (main.dart:187) and `_session.reset()`, and Profile just shows 'could not clear' and keeps the driver signed in (profile.dart:397-406). From then on active-ride snapshots and terminal markers can no longer be written (every enqueued op logs 'Active-ride storage operation failed'), so crash recovery of a trip silently stops working, and local data is half-cleared, until the process restarts.

**Suggested fix:** Recreate the composition-root repositories (and reset the session) in a `finally`, or bump the generation only after the removals succeeded / roll it back on failure.

### L33. Chat's 'Save message locally' saves nothing: messages live only in the route's State and are lost when Chat is closed

`lib/presentation/common/chat/chat.dart:24` (found by r2-driver2)

**What happens:** During a trip the driver writes 'I'm at the north entrance' and taps 'Save message locally', then goes back to the map. Reopening Chat for the same rider shows no messages.

**Why:** The send button is labelled tr.chatSaveLocally ('Save message locally'), and each bubble says 'Local preview · not sent'. The messages live only in _ChatState._messages, a field of the route's State. Closing Chat with Back disposes it, and reopening Chat from the same trip shows an empty conversation. Nothing is saved locally, so the action label does not match what happens.

**Suggested fix:** Keep the per-trip local messages in a store keyed by tripId (pass tripId to Chat), or relabel the action as preview-only.

### L34. Driver's own unsent chat messages render as incoming messages (left-aligned with a stock avatar)

`lib/presentation/common/chat/chat.dart:113` (found by r2-driver2)

**What happens:** The driver types 'I'm outside' and saves it. The message appears on the left with a face avatar under the rider's name 'Angelica', which reads as the rider's message.

**Why:** _sendMessage stores the driver's own text, but every entry is drawn with SenderMessage, which puts a circular profile image (assets/images/chat_prof1.png, a generic memoji) on the left and a grey bubble with an 80 px right margin. That is the usual layout for messages from the other party. The screen title is the rider's name, so the driver's own drafts look like messages from the rider.

**Suggested fix:** Right-align the driver's own local messages and drop the rider-style avatar, as the support conversation does.

### L35. Crash/reload restore drops the rider's bag count, so the island's bag notice is lost

`lib/presentation/driver/accept ride/accept_ride.dart:253` (found by r2-driver2)

**What happens:** A rider booked with 2 bags. The PWA reloads while the driver is heading to the pickup. After the restore the island never says 'Rider has 2 bags'.

**Why:** AcceptRide.bags drives the island strip's 'Rider has N bags' notice on the pickup leg (accept_ride.dart:1314 → adaptive_trip_island.dart:275 → trip_island_controller.dart:318-320). Neither _buildSnapshot nor AcceptRide.fromPersisted carries bags, so a restored trip always has bags = 0.

**Suggested fix:** Persist bags in PersistedActiveRide and pass it through fromPersisted.

### L36. Disposing AcceptRide while a Ride check is open makes Home call setState during finalizeTree: a debug-only 'widget tree was locked' error, and in debug the held radar offers are not released

`lib/presentation/driver/accept ride/accept_ride.dart:679` (found by driver1)

**What happens:** A Ride check card is open (long stop / off-route) when the rider cancels (or admin releases the trip); the trip screen pops. In a debug or profile build the framework reports "setState() or markNeedsBuild() called when widget tree was locked" during finalizeTree and AcceptRide's dispose is cut short, leaving its realtime subscription and timers alive.

**Why:** `_AcceptRideState.dispose` calls `_rideCheck.dispose()` (679). `RideCheckController.dispose` calls `_syncGate(false)` (ride_check_controller.dart 409), which, when the gate was held (a Ride check pill/card was open), sets `RideCheckGate.set(false)` → `ValueNotifier` notifies synchronously. Home is still mounted underneath and its listener `_rideCheckGateListener` → `_onRideCheckGate` (home_offer_radar.dart 473-478) runs `_rebuild(() {})`, i.e. `setState` (home.dart 338), from inside another State's `dispose`. State.dispose runs in `BuildOwner.finalizeTree` under `lockState`, where `markNeedsBuild` asserts "setState() or markNeedsBuild() called when widget tree was locked". In debug/profile builds the FlutterError is thrown out of `_rideCheck.dispose()`, so the remainder of `AcceptRide.dispose` (camera, realtime subscription/unsubscribe, timers, animation controllers at 680-700+) never runs, leaking the realtime subscription, the 20 s ride-check ticker already cancelled but `_waitTimer`, `_nextTrip*` timers and the two AnimationControllers (which then also report "disposed with an active Ticker"). Release builds only mark Home dirty and rebuild.

**Suggested fix:** Close the gate before the route is popped (e.g. in `_pauseLiveUpdates`/the exit paths) or defer the Home reaction with `WidgetsBinding.instance.addPostFrameCallback`/`scheduleMicrotask` in `_onRideCheckGate`; alternatively have `RideCheckController.dispose` schedule `RideCheckGate.set(false)` asynchronously.

### L37. Trip camera approach loop and 33 ms car-marker ticker keep updating the hidden trip map while another route covers AcceptRide

`lib/presentation/driver/accept ride/accept_ride.dart:715` (found by r2-driver2)

**What happens:** Mid-trip, the driver opens Ride history from the island and reads it for 2 minutes while driving. The invisible trip map gets about 7,200 camera moves and about 3,600 marker pushes, which wastes CPU and battery on native and grows memory on web. Worked out from the code; not run.

**Why:** AcceptRide pauses live updates only on app lifecycle changes (didChangeAppLifecycleState -> `_pauseLiveUpdates` -> `_camera.suspend()`). Unlike Home (didPushNext -> `_pauseHomeUpdates`), it is not RouteAware. When the driver opens a full-screen route from the trip, for example `onHistory: () => pushSingle(context, MaterialPageRoute(builder: (_) => const DriverRideHistory()))` (accept_ride.dart:1307), the chat, destination picker or safety screens, GPS keeps arriving and `_camera.update` keeps retargeting. GoogleDriverCameraPort's loop paces itself with `Timer`-based `_sleep(16 ms)`, not vsync, so it keeps calling `controller.moveCamera` about 60 times a second on the hidden map. Each frame's `onFrame` snaps the vehicle pose, so the 33 ms `_ThrottledVehicleMap` timer keeps pushing marker updates. On web each of those pushes also leaks a Blob URL (see the first finding).

**Suggested fix:** Make AcceptRide RouteAware (or check TickerMode/ModalRoute.isCurrent). On didPushNext suspend the camera and stop the 33 ms ticker, keeping GPS and the trip logic running. On didPopNext resume and recenter.

### L38. The slide action is read twice: its Semantics label is merged with the child Text

`lib/presentation/driver/accept ride/accept_ride.dart:1672` (found by r2-driver2)

**What happens:** TalkBack reads 'Start trip, Start trip, button'. While the action runs, it reads the stale label plus the new confirmed text.

**Why:** The slide's Semantics sets label: widget.label but does not set excludeSemantics. The child Text shows the same string (or confirmedLabel while confirming), and its label merges into the same node, which has tap, scroll and focus actions. Other controls in the app (Ride check buttons, offer pill, LedCountBadge) use excludeSemantics: true to avoid this.

**Suggested fix:** Add excludeSemantics: true (together with removing the GestureDetector's semantics, see the scroll-action finding) and keep the label in sync with the confirmed state.

### L39. The enabled 'I've arrived' button is drawn at 2.6:1 contrast until the car is near

`lib/presentation/driver/accept ride/accept_ride_panel.dart:894` (found by r2-driver4)

**What happens:** Approaching pickup, the driver sees a washed-out 'Je suis arrivé' that looks disabled but is tappable, and its label is hard to read in sunlight.

**Why:** The primary heading-to-pickup action stays enabled when !_nearArrivalTarget (tapping runs _blockedArrival with a message), but its label is 8E979B on EEEFF1, about 2.6:1. That is under 4.5:1 for an active control, and the semantics give no hint why it looks disabled.

**Suggested fix:** Keep a readable foreground (≥4.5:1, e.g. 5F6B72) in the not-near state, and add a semantics hint (e.g. 'available within 100 m').

### L40. A radar the driver held off comes back on after a crash or reload restore

`lib/presentation/driver/accept ride/accept_ride_trip.dart:110` (found by r2-driver1)

**What happens:** On the last leg the driver holds the radar to stop next-trip offers. Safari reloads the PWA and the trip is restored. A few seconds later an Exclusive next-trip offer pops up, and ignoring it counts toward the auto-offline limit.

**Why:** Holding the trip radar sets `_OnTripRadarState.stopped`, but the persisted snapshot (`_buildSnapshot`) does not save the radar state. On restore the state starts as `off`, and `_resumeStageSideEffects` calls `_startOnTripRadar`, whose only guard is `stopped`. The radar therefore scans again, and the driver gets Exclusive next-trip offers they turned off; letting them run out counts as misses.

**Suggested fix:** Persist whether next-trip offers were stopped in PersistedActiveRide and restore `stopped` from it.

### L41. Waybill driver name and the vehicle/plate placeholders are stored as translated text, so a mid-trip language switch leaves them in the old language

`lib/presentation/driver/accept ride/accept_ride_trip.dart:189` (found by r2-driver1)

**What happens:** The driver accepts a trip in Svenska, switches to Français from the trip's side menu › Settings, and opens the current-trip waybill. All labels are in French but 'Chauffeur: Movera-förare'. Without a saved vehicle it also shows 'Fordonsuppgifter saknas' / 'Registreringsnummer saknas'. The Ride completed 'last waybill' shows the same mix.

**Why:** waybill.dart:45-46 states that stored waybill values 'stay in English in storage; the screens show them in the driver's language'. The trip screen nevertheless fills the record with translated text: `driverName: tr.moveraDriver`, `vehicle: _vehicleLabel` and `licensePlate: _vehiclePlate`, whose defaults are `tr.vehicleDataUnavailable` / `tr.plateUnavailable` (accept_ride.dart:553-554). Home's restore does the same: `riderName: snapshot.riderName ?? tr.riderDataUnavailable, driverName: tr.demoDriverIdentityUnavailable, vehicle: tr.vehicleDataUnavailable, licensePlate: tr.plateUnavailable` (home.dart:631-637, 653-655). waybill_sheet.dart:84-85 prints these fields as stored. The same frozen strings go into the safety alert (accept_ride_trip.dart:1468). AcceptRide.fromPersisted also turns a missing riderName into `tr.riderDataUnavailable` (accept_ride.dart:257), and that text is then persisted as if it were the rider's name.

**Suggested fix:** Store null or a sentinel for unknown values, store the brand driver name as a constant id, and translate in waybill_sheet.

### L42. The trip-save error SnackBar fires again on later state changes, and its Retry does not retry the failed slide

`lib/presentation/driver/accept ride/accept_ride_trip.dart:485` (found by r2-driver1)

**What happens:** A 2-minute GPS snapshot save fails once (web storage quota), and the error SnackBar shows. Later the driver finishes the trip and the journal saves fine, but the Ride completed screen shows 'Trip progress could not be saved · Retry'. Or: the 'Start trip' slide's save fails, the driver taps Retry, nothing visible happens, and the trip is still 'Waiting'.

**Why:** `_onPersistenceChanged` is an `ActiveRideController` listener that shows 'Trip progress could not be saved' whenever `persistenceError != null`. `persistenceError` is cleared only at the start of a new `_write`. `_end(clearSnapshot: false)` (active_ride_controller.dart:228-231), which completion, cancel and no-show use, notifies listeners without writing. So an old background-save failure re-shows the error SnackBar while the trip is being finished successfully, and the SnackBar is carried to the next route on the root messenger. Separately, when `transitionTo` (Arrive or Start trip) fails its save, the SnackBar's Retry calls `persistNow()`. That re-saves the current stage, not the stage change. It succeeds silently and leaves the trip where it was, so Retry looks like it did something when it did not.

**Suggested fix:** Show the SnackBar only on the notify that ends a failed write (track the write revision), clear `persistenceError` in `_end`, and make Retry repeat the failed command rather than calling `persistNow`.

### L43. Hard-coded English 'stop'/'pickup' is injected into the localized 'move within 100 m' message

`lib/presentation/driver/accept ride/accept_ride_trip.dart:503` (found by driver1)

**What happens:** App language Swedish; driver taps 'I've arrived' more than 100 m from the pickup: snackbar reads 'Kom inom 100 m (pickup) för att vara framme.'

**Why:** `_blockedArrival` builds `final where = _stage == ActiveRideStage.onTrip ? 'stop' : 'pickup';` and passes it to `tr.moveWithin100MOfWhere(where)`. The Swedish and French strings interpolate the raw word: `'Kom inom 100 m ($where) för att vara framme.'` / `'Approchez-vous à moins de 100 m ($where) ...'`, so Swedish and French drivers see 'Kom inom 100 m (pickup)'.

**Suggested fix:** Pass localized words (`tr.stop` / `tr.pickup`) or two separate localized messages.

### L44. After 'I've arrived', the pickup route line stays on the map during the wait until the car moves at least 0.4 m (or a GPS snapshot persist fires), because the route-cleared notification is dropped while _stageTransitioning is set

`lib/presentation/driver/accept ride/accept_ride_trip.dart:562` (found by driver1)

**What happens:** Driver taps 'I've arrived' at the pickup. The waiting stage starts but the black route line to the pickup (and the old ETA value) remain on the map for the whole wait.

**Why:** `_confirmPickupArrival` sets `_stageTransitioning = true` (541) and awaits `transitionTo(waitingForRider)`; the controller's commit notifies `_syncNavigationStage` → `NavigationController.setStage` which clears `_route` and notifies (navigation_controller.dart:163-188). `_onNavigationChanged` returns at once because `_stageTransitioning` is still true (562), so `_roadGeoPoints`/`_routeDurationSeconds` keep the pickup route; the following `_rebuild(() {})` (558) calls `_syncRouteLines()` which redraws that stale route. During waiting `ensureRoute` returns early and `setVehicle` does not notify while the car is parked (moved < 0.4 m, navigation_controller.dart:242-246), so nothing clears it until the car moves. `_routeEtaText` likewise keeps the old duration (`routeFraction` is null → full duration) while waiting.

**Suggested fix:** Do not skip `_onNavigationChanged` during a stage transition (or re-run it in `_unlockStageAfterFrame`), and clear `_roadGeoPoints`/`_routeDurationSeconds` explicitly when entering waiting.

### L45. After a timer-driven reroute, the new route is drawn split at the old route's progress until the next GPS fix (usually about a second)

`lib/presentation/driver/accept ride/accept_ride_trip.dart:574` (found by r2-driver1)

**What happens:** 4 km into the leg the driver leaves the route and the reroute arrives from the timer. The first 4 km of the new route draw grey 'travelled' and the blue route starts 4 km ahead of the car until the next fix, which never comes while GPS is silent. Verified by reading the code; not run.

**Why:** _onNavigationChanged puts the new route into _roadGeoPoints and _rebuild calls _syncRouteLines(_roadGeoPoints, _camera.alongMeters, ...). _camera.alongMeters is DriverCameraPolicy._along, which still refers to the old route: it resets only in the next camera.update, which needs a new usable fix. The reroute timer and 'Retry route' deliver routes outside any fix. Their new polyline (starting at the car) is drawn with its first N metres (N = old route progress) faded as already driven, and the remaining line starts far ahead of the car. This lasts until a fix arrives, which can be a long time when GPS is silent.

**Suggested fix:** Reset the split to 0 when the polyline identity changes (or have the camera policy take the new route at once), and sync the lines after _followVehicle.

### L46. DECISIONS.md's '20 m web GPS filter' is not applied: the active ride passes distanceFilter 0 on web, so every browser fix is processed (the per-fix rebuild cost is already handled by D-07)

`lib/presentation/driver/accept ride/accept_ride_trip.dart:605` (found by driver1)

**What happens:** Safari PWA on an active trip: each raw geolocation fix (no distance gating) drives _applyDriverPosition, route-refresh checks and island updates, the very load pattern the recorded decision says was limited by a 20 m filter.

**Why:** DECISIONS.md ('Active ride crash recovery (Safari / PWA)', line 85) states the Safari tab-kill fix included 'web GPS filter is 20m'. The active ride subscribes with `watchPosition(distanceFilterMeters: 0)` and DriverLocationService._streamSettings builds `LocationSettings(accuracy: high, distanceFilter: distanceFilterMeters)` for web, so on web every browser geolocation callback (typically ~1 Hz, more on some devices) reaches _applyDriverPosition. There is no kIsWeb branch anywhere in accept_ride*.dart (grep shows none) and no constant 20 in the location code. The documented decision and the shipped behaviour differ; the task rules treat that as a defect to report.

**Suggested fix:** Either pass `distanceFilterMeters: kIsWeb ? 20 : 0` from the active ride (or apply the web filter inside DriverLocationService) or correct DECISIONS.md so the record matches the code.

### L47. The GPS-lost status keeps the old language after a switch, and the 'GPS restored' notice is then skipped

`lib/presentation/driver/accept ride/accept_ride_trip.dart:616` (found by r2-driver1)

**What happens:** In Swedish, GPS drops during the trip and the island shows 'Platsen uppdateras…'. The driver switches to French via the side menu and returns. The island still shows Swedish, and when the fix returns the island goes straight back to guidance without 'GPS rétabli'.

**Why:** When the GPS stream errors, the trip saves the rendered text both in `_locationStatus = tr.locationUpdatingEllipsis` and in NavigationController `_locationWarning` (keepLastKnown, navigation_controller.dart:298). Both stay until a usable fix arrives. Covering the trip with Settings does not pause GPS (live updates pause only on app lifecycle, accept_ride.dart:713-726), so returning does not refresh the text, and the island keeps showing the old-language warning. When GPS comes back, TripIslandController decides whether to say 'GPS restored' by comparing the stored old-language text with the new language: `fault == tr.locationUpdatingEllipsis || fault.contains('Location')`. Neither test matches a Swedish string while the app is in French, so the notice is never shown.

**Suggested fix:** Keep the warning as an enum or flag (as NavigationRouteStatus does) and render it with tr when building the status; test the enum, not the text.

### L48. After the trip ends (outcome sheet up), a GPS fix after an app resume can still schedule an on-trip Exclusive offer; when it expires unseen it counts as a missed offer

`lib/presentation/driver/accept ride/accept_ride_trip.dart:684` (found by r2-driver1)

**What happens:** Movera cancels a trip while the driver is on board, and the outcome sheet is shown. The driver switches apps and comes back without closing the sheet. 2.2 s later a hidden next-trip offer appears and then expires, and it counts toward the auto-offline missed-offer streak.

**Why:** _leaveAfterAuthoritativeOutcome pauses live updates and then awaits showTripOutcomeSheet. If the app is backgrounded and resumed while that sheet is open, _resumeLiveUpdates restarts GPS. _resumeOnTripOffer checks `_rideLifecycle.terminal`, but _applyDriverPosition calls _maybeScheduleOnTripRadarDemoOffer when `_stage == onTrip`, and that function has no terminal check. An offer is then shown under the modal, its expiry timer runs, and _denyNextTripRadar calls ExclusiveAnswers.instance.missed(), which can switch the driver offline after the trip.

**Suggested fix:** Return early from _maybeScheduleOnTripRadarDemoOffer, _presentOnTripOffer and _resumeLiveUpdates when _rideLifecycle.terminal is true.

### L49. Non-cash trips are archived with no payment method, so History detail shows 'Payment Method —' while Ride completed shows 'Card'

`lib/presentation/driver/accept ride/accept_ride_trip.dart:916` (found by r2-driver1)

**What happens:** Complete a card-paid trip. Ride completed shows 'Payment: Card'. Open Ride history and tap the trip: 'Payment Method' shows '—' with no wallet icon (history_detail.dart:373 hides it for '—'). This happens on every card trip.

**Why:** _completeCurrentTrip journals the trip with `paymentMethod: widget.paidByCash ? 'Cash' : null`. For a card trip the journal record has no 'paymentMethod' key. history.archive therefore writes none, and TripHistoryRecord falls back to '—'. A few lines later the same method opens DriverRideCompleted with `paymentMethod: widget.paidByCash ? 'Cash' : 'Card'`. The history layer supports 'Card' (prefs_trip_history_test and history_record_handoff_test store and expect it), so the information is simply dropped.

**Suggested fix:** Pass `widget.paidByCash ? 'Cash' : 'Card'` to CompletionJournal.finish as well.

### L50. Island menu offers 'Turn Exclusive offers off' while a next trip is secured, and choosing it does nothing

`lib/presentation/driver/accept ride/accept_ride_trip.dart:1011` (found by r2-driver1)

**What happens:** With a next trip secured, the driver opens the island menu and taps 'Turn Exclusive offers off'. The menu closes and nothing changes, with no feedback.

**Why:** The island menu labels the radar item from `radarOn: _onTripRadarOn`, which is true for `secured`. Choosing it calls `_toggleOnTripRadar`, which returns at once when the state is `secured`. The driver gets a menu action that silently has no effect.

**Suggested fix:** Hide or disable the radar item while a next trip is secured, or pass `radarOn` excluding `secured` and have the toggle explain why.

### L51. A next-trip offer hidden for a Ride check comes back with a new full exclusiveAcceptTime, ignoring the time it was already on screen

`lib/presentation/driver/accept ride/accept_ride_trip.dart:1161` (found by driver1)

**What happens:** Offer shown with 20 s left; a Ride check opens and is answered after 10 s; the offer returns with the full exclusiveAcceptTime again instead of ~10 s.

**Why:** `_onRideCheckGate` (1137-1162) hides an open offer while the Ride check is up and records `_nextTripOfferHeldAt`. After the answer it checks only whether the full lifetime has elapsed since `heldAt` and then calls `_presentOnTripOffer()`, which calls `_armOnTripOfferExpiry()` with `left == null` → `_nextTripOfferDeadline = now + lifetime` (1163-1173). Time already spent before the check (and `_nextTripOfferDeadline`) is ignored, so the rider's offer is held open longer than Dispatch's time to accept; the comment and D-05 say a surviving offer counts down the rest.

**Suggested fix:** Keep `_nextTripOfferDeadline` when holding and re-arm with `left: deadline - now` (drop the offer when it is <= 0), as `_resumeOnTripOffer` does.

### L52. Cancelling the current trip with a secured next trip starts the next AcceptRide without destination mode, unlike completion and the journal snapshot

`lib/presentation/driver/accept ride/accept_ride_trip.dart:1394` (found by driver1)

**What happens:** Driver has destination mode on, secures a next trip, then ends the current trip early. The next trip's screen has destination mode off; Exclusive offers no longer follow the destination.

**Why:** `_submitTripCancellation` builds the next `AcceptRide` (1394-1414) without `destinationModeActive`, `destinationAddress` or `destinationPosition`, whereas `_completeCurrentTrip` (954-956) passes them and the journal's `next` snapshot (`_snapshotForOffer`, 971-979) stores them. After a driver cancel the next trip therefore runs with destination mode off (no on-the-way filter for next-trip offers, the trip options row shows 'next trips on your way' as off), while a crash restore of that same trip from the journal snapshot would restore destination mode on — the two paths disagree.

**Suggested fix:** Pass the three destination fields (or use `AcceptRide.fromPersisted(_snapshotForOffer(offer))` as the rider-cancel path does).

### L53. Route-progress semantics value is read out in English ('42 percent') in fr/sv

`lib/presentation/driver/accept ride/adaptive_trip_island.dart:1123` (found by driver4)

**What happens:** VoiceOver/TalkBack in Swedish announces 'Ruttframsteg, 42 percent'.

**Why:** The accessibility value of the route progress bar is built as `'${…} percent'` while its label uses `tr.routeProgress`; screen readers in Swedish/French read the English word.

**Suggested fix:** Use `tr.rcPercent(n)` or a dedicated ARB message.

### L54. Ride check card tells the driver 'Movera safety team alerted · Trip, driver and rider details were sent' while alerts only go to an in-memory demo outbox

`lib/presentation/driver/accept ride/ride_check_card.dart:703` (found by driver3)

**What happens:** On a trip the Ride check opens (long stop / off route), the driver picks 'Accident or collision' (a red topic): the card shows 'Movera safety team alerted. Trip, driver and rider details were sent.' although only DemoSafetyAlertRepository._alerts was updated.

**Why:** docs/REVIEW_AND_MERGE_GATES.md 'Product truth gate': safety recording/sharing is not a connected service and 'UI must not claim those actions succeeded when only local state changed'. The composition root wires `DemoSafetyAlertRepository` (main.dart:96, an in-memory map/journal) into `RideCheckServices`; `RideCheckController._ensureAlert` marks `_alert` set as soon as that repository returns, and `_alertNote` then renders `tr.moveraSafetyTeamAlerted` + `tr.tripDriverAndRiderDetailsWere` with no demo qualifier, unlike the rating screen ('Rating not sent (demo)') and chat ('Local preview · not sent'). On a red topic (accident, safety concern) the driver is told help was notified when nothing left the phone. Mitigation: a persistent 'demo' banner sits at the top of the app, which is why confidence is low.

**Suggested fix:** Qualify the note while the demo repository is installed (e.g. 'Demo: alert kept on this phone') or expose a `supportsDelivery` flag on SafetyAlertRepository and only claim 'alerted' when a real transport confirms.

### L55. The 'photo storage full' budget error is shown in English in the vehicle documents SnackBar (the per-photo size error is already caught earlier with localized text)

`lib/presentation/driver/add vehicle/add_vehicle.dart:501` (found by driver2)

**What happens:** Swedish driver attaches a large registration photo: a SnackBar in English appears on an otherwise Swedish screen.

**Why:** `VehiclePhotoBudgetExceeded` is thrown with English copy in local_vehicle_store.dart:150 ('Photo is too large to keep on this device.') and :170 ('Photo storage on this device is full. Remove photos from another vehicle first.'); add_vehicle.dart catches it and shows `error.message` verbatim, while the generic catch right below uses a localized string.

**Suggested fix:** Give the exception a code/kind and map it to `tr` in the screen.

### L56. 'DEMO DATA' badges (Analytics, Driving log) and the 'DRIVING IN' header (Documents) are hardcoded English on localized screens

`lib/presentation/driver/analytics/analytics.dart:60` (found by driver4)

**What happens:** Swedish driver opens Dokument: a header 'DRIVING IN' sits above 'Stockholm'; Analys and Körlogg both open with an English 'DEMO DATA' badge.

**Why:** These eyebrow labels and sample rows are visible text on screens whose other strings all come from `tr`. analytics.dart:60 'DEMO DATA', :108 'Central Station → Södermalm', :117 'Comfort · 21:42'; driving_logs.dart:50 'DEMO DATA'; documents.dart:76 'DRIVING IN' (the section header above the zone name). No ARB key exists for 'DEMO DATA' or 'DRIVING IN'.

**Suggested fix:** Add ARB keys (demoDataBadge, drivingIn, sample trip row) and use them.

### L57. Analytics shows the English seed labels 'Busy'/'Steady'/'Quiet' and 'Around Stockholm' untranslated on the fr/sv Analytics screen

`lib/presentation/driver/analytics/analytics.dart:353` (found by r2-driver4)

**What happens:** Worked by hand, not run. With the app in Swedish (the zone default), Analytics lists 'Södermalm  Busy  86%' and an 'Around Stockholm' card. If admin localizes the labels, every chip turns the neutral colour and the island's 'Demand rising' tip never appears.

**Why:** The admin seed content holds English labels ('Busy', 'Steady', 'Quiet', 'Around Stockholm'). Analytics renders area.demandLabel and stats.surroundingTitle as-is, next to localized headings (tr.anaSampleStrongestArea etc.), so a Swedish driver (the zone default) sees 'Busy'/'Steady' chips. _chip colours an area by comparing demandLabel.toLowerCase() with 'busy'/'quiet', so a label admin writes in the zone language ('Hög', 'Lugnt') always gets the 'steady' colour. IslandWaitingSignals.fromHome (island_waiting_signals.dart:101) uses the same English comparison for its 'Demand rising' tip. This is not among the known Analytics literals ('DEMO DATA', 'Central Station → Södermalm', 'Comfort · 21:42').

**Suggested fix:** Send a demand level enum and localize it in the app (tr.demandBusy, …), or treat the label as display-only and drive colour and tips from demandPercent.

### L58. Android system back (or predictive back) on any onboarding step closes the whole onboarding wizard instead of going to the previous step

`lib/presentation/driver/auth/additional detail/navigation.dart:117` (found by r2-driver1)

**What happens:** Reproduced with a throwaway widget test. I pushed AdditionalInfoNavigation, tapped Continue twice (page == 2) and called tester.binding.handlePopRoute(), which is the Android back button. Output: 'AUDIT onboarding still mounted: false'. The whole wizard was popped, not just step 3 to step 2.

**Why:** The onboarding wizard is one route that holds a PageView. Its on-screen back button calls controller.moveToPreviousStep(context), which goes back one page and only pops the route on page 0. The Scaffold has no PopScope or onPopInvoked handler, so the Android system back button, the predictive back gesture and the iOS edge swipe all pop the whole AdditionalInfoNavigation route from every step. The driver then leaves the flow and loses every value typed or picked on earlier steps. The on-screen arrow and the system back behave differently on the same screen.

**Suggested fix:** Wrap the Scaffold in PopScope(canPop: currentPageIndex == 0, onPopInvokedWithResult: (didPop, _) { if (!didPop) controller.moveToPreviousStep(context); }), and rebuild it from currentPageIndex.

### L59. Onboarding Add-vehicle type list ('Luxury', 'Standard', 'Economy', 'SUV') and the prefilled sample values are hard-coded English, not localized, and do not match the contract categories

`lib/presentation/driver/auth/additional detail/screens/add_vehicle.dart:38` (found by r2-driver4)

**What happens:** In Swedish, the Add vehicle onboarding step shows 'Luxury/Standard/Economy/SUV' in English. Tapping Continue without editing moves on with Toyota Mark X, plate AQS - 140.

**Why:** The vehicle-type dropdown items are English literals shown as-is in the French and Swedish UI. They also do not match the contract categories (economy, comfort, premium, priority, xl, electric, pet). Separately, make, model, plate and type are initialised as controller text ('Toyota', 'Mark X', 'AQS - 140', 'Luxury'), not as hints. A driver who does not overwrite them keeps sample data as their vehicle. The hint repeats the same value, which makes them look like placeholders.

**Suggested fix:** Start the controllers empty (keep the values as hints only) and build the type list from CategoryCatalog with localized labels.

### L60. English copy 'Did you don’t get code?' is ungrammatical

`lib/presentation/driver/auth/phone verification/phone_verify.dart:122` (found by driver3)

**What happens:** Legacy auth > Create account > phone > Continue: the screen shows 'Did you don’t get code?'.

**Why:** `tr.didNotGetCode` is rendered on the phone verification screen; the English source string in app_en.arb:2150 is `"Did you don’t get code?"`. French and Swedish translations are correct ('Vous n’avez pas reçu de code ?', 'Fick du ingen kod?'), so only the English UI is broken.

**Suggested fix:** Change the English string to 'Didn’t get the code?'.

### L61. Phone sign-in and create-account screens show a US flag by default in the Swedish (SE) market; the selected code is never used

`lib/presentation/driver/auth/sign in phone/sign_in_phone.dart:31` (found by r2-driver2)

**What happens:** A Swedish driver opens 'Sign in with phone' and sees the US flag. They type 0701234567, which would be read as +1 0701234567.

**Why:** The sign-in phone screen and both create-account screens set the default country to US/+1 in initState, after first declaring '+92' as the field initialiser. DECISIONS.md P2 fixes the market as SEK/Stockholm, and the rest of the app (documents 'Stockholm trips', SEK money) is Swedish. Every Swedish driver has to change the country before typing a number, and a number typed without changing it would be read as a US number.

**Suggested fix:** Default to 'SE' / '+46', or to the market country from DriverAccountRules.current.country.

### L62. Divider word 'or' is hardcoded English and not translated

`lib/presentation/driver/auth/sign in/sign_in.dart:62` (found by driver4)

**What happens:** Set language to Svenska and open Sign in: 'Fortsätt med telefon' / 'or' / 'Fortsätt med Apple'.

**Why:** Every other string on the screen goes through `tr`, but the divider uses the literal `"or"`, so French and Swedish users see 'or' between the sign-in options. The app supports en/fr/sv via `AppLocalizations`.

**Suggested fix:** Add an `orWord` key to the arb files and use `tr.orWord`.

### L63. Destination confirm summary always uses a '.' decimal ('38.1 km') in fr/sv

`lib/presentation/driver/destination mode/destination_confirm.dart:19` (found by r2-driver4)

**What happens:** A French driver confirms a destination and reads '38.1 km · 34 min' instead of '38,1 km'.

**Why:** `destinationDistanceTimeLabel` formats with `toStringAsFixed(1)` and a hard-coded 'km · … min'. The confirm sheet shows it unchanged, so French and Swedish drivers see '38.1 km' while the trip island uses the localized ',' mark. This is a separate formatter from the known driver_distance.dart one.

**Suggested fix:** Format the number with the active locale's decimal separator (NumberFormat or the shared distance helper).

### L64. Destination confirm close (×) button has no accessible name

`lib/presentation/driver/destination mode/destination_confirm.dart:283` (found by r2-driver4)

**What happens:** A screen-reader driver on the destination confirm map hears 'Button' for the control that backs out of destination mode setup.

**Why:** The close control on the destination confirmation map (opened from the destination picker) is an InkWell around SvgPicture.asset(AppAssets.solarClose) with no Tooltip, Semantics or semanticsLabel. It is announced as an unlabelled button. The same kind of icon-only close in waiting_time_sheet.dart:464 (36 px, Icons.close_rounded without semanticLabel) has the same problem, although that sheet also has a text 'Close' button.

**Suggested fix:** Wrap the button in Tooltip(message: tr.close) or Semantics(button: true, label: tr.close). Do the same for the waiting-sheet ×.

### L65. Destination search result count is the English literal '${results.length} found'

`lib/presentation/driver/destination mode/destination_picker.dart:361` (found by driver2)

**What happens:** French driver types a destination: header reads 'Résultats   3 found'.

**Why:** While the search field is non-empty the picker shows `'${results.length} found'` next to the localized section title; nothing in the ARB covers it.

**Suggested fix:** Add a plural ARB key (e.g. resultsFound) and use it.

### L66. Section label 'DRIVING IN' is hardcoded English on the Documents screen

`lib/presentation/driver/documents/documents.dart:76` (found by driver3)

**What happens:** Language Svenska > Profile > Documents: 'DRIVING IN' above 'Stockholm-resor'.

**Why:** Documents is a main-path screen (Profile > Documents). Its header eyebrow is `const Text('DRIVING IN', ...)` while the lines under it are localized (`tr.docStockholmTrips`, `tr.docEarnAnywhereSweden`), so French/Swedish drivers see an English label above a translated title.

**Suggested fix:** Add an arb key and use `tr`.

### L67. feeSuffix hardcodes 'kr' and a /100 divisor for whole cancel fees, ignoring the Money currency and exponent (latent until a non-SEK cancelFee arrives)

`lib/presentation/driver/home/components/home_island_notices.dart:72` (found by driver4)

**What happens:** In a French zone the backend sends cancelFee {amountMinor: 500, currency: 'EUR'}: the island and the rider-cancelled sheet say '· +5 kr' instead of '· +5,00 €'; for TND 5000 millimes they say '+50 kr' instead of '5,000 DT'.

**Why:** `feeSuffix(Money? fee)` prints `'${fee.minorUnits ~/ 100} kr'` whenever the amount is a whole number of minor-hundreds, ignoring `fee.currency` and its exponent (Money supports SEK/EUR with exponent 2 and TND with exponent 3; zone_settings maps EUR->FR and TND->TN). Only the non-whole branch uses `fee.formatted`. Callers: reservationCancelled island message (line 60-66), RiderCancelledSheet status line (rider_cancelled_sheet.dart:59-62), ScheduledRideStore.riderCancelled (scheduled_rides.dart:678). The fee is the backend's decision (R15-7) in the zone currency.

**Suggested fix:** Use `fee.formattedShort` (already drops a zero fraction and keeps the currency symbol/exponent) for both branches.

### L68. The Exclusive/Reservation decline control is a 34×34 target

`lib/presentation/driver/home/components/home_offer_sheet.dart:393` (found by r2-driver2)

**What happens:** A driver at a red light trying to skip an Exclusive offer has to hit a 34 px circle. Misses land on the sheet, and the countdown keeps running.

**Why:** ReservationCloseArrow is the only way to take an Exclusive offer or reservation request off Home (onDecline). Its touch area is the 34 px circle with no hit slop, below the 44/48 px minimum. It sits in the sheet's top-right corner next to the 104 px Accept orb.

**Suggested fix:** Keep the 34 px visual but wrap it in a 48×48 SizedBox/Padding hit area (as IslandSideHitSlop does for the island).

### L69. IslandMessages.posted grows without bound in production: every show() appends and only the test-only reset() clears it

`lib/presentation/driver/home/components/island_messages.dart:76` (found by driver1)

**What happens:** A driver keeps the app open for a long shift: every island message ever posted (and the closures of disposed Home states after logout/login) stays referenced in a static list until the process dies.

**Why:** `posted` is @visibleForTesting but show() unconditionally does `posted.add(message)` (line 76) in the production path; nothing in the app ever calls reset(). Each IslandMessage holds a title string and often a closure (onTap) that captures the Home state. Over a long online session (online/offline, matching, waiting tips are not posted here, but every match/taken/unavailable/cash/reminder/notification message is) the list keeps growing and keeps old State closures alive.

**Suggested fix:** Only record into `posted` under a test flag (kDebugMode/visibleForTesting hook) or cap its length.

### L70. When browser storage is blocked outright, recovery never resolves, so the driver can never go online and is told about a saved trip that does not exist

`lib/presentation/driver/home/home.dart:519` (found by r2-driver2)

**What happens:** Fresh install opened in a browser with site storage blocked: Home shows 'The saved trip could not be opened'. Every radar tap answers 'Finish or close the saved trip before going online', and 'Open saved trip' fails again. The driver can never go online.

**Why:** _restoreActiveRideIfNeeded runs CompletionJournal.reconcile() and repo.read(). Both call SharedPreferences.getInstance(), which throws when the browser blocks localStorage (Safari 'Block all cookies', some private modes). Any non-ActiveRideUnreadable error lands in the generic catch, which shows 'The saved trip could not be opened' and leaves _recoveryResolved false. _goOnline refuses while !_recoveryResolved and shows 'Finish or close the saved trip before going online' with 'Open saved trip', which only retries the same failing read. On a first launch with no storage there is no saved trip, yet the driver is blocked from going online for the whole session.

**Suggested fix:** Tell 'storage unavailable' apart from 'a saved trip exists but failed'. When the store cannot be opened, nothing can be recovered: resolve recovery (with a warning) instead of blocking going online.

### L71. A restored trip's waybill shows the time of the last background save as its issue time, not when the trip was accepted

`lib/presentation/driver/home/home.dart:627` (found by r2-driver2)

**What happens:** A trip accepted at 14:02 is restored after a reload at 14:40 whose last GPS snapshot was at 14:38. The waybill shown to the driver (and to an inspector) says the trip was issued at 14:38.

**Why:** _waybillFromSnapshot sets issuedAt: snapshot.savedAt. savedAt is re-stamped on every save (GPS every 2 minutes, lifecycle, stage changes), while the snapshot also carries acceptedAt. After any crash or reload the current waybill's Time row (waybill_sheet.dart:74 formatWaybillTime(record.issuedAt)) shows the last-save time instead of when the trip was accepted. AcceptRide's own path uses DateTime.now() at accept time.

**Suggested fix:** Use snapshot.acceptedAt (falling back to savedAt) for the restored waybill's issuedAt.

### L72. An Exclusive offer that arrives while the side menu is open is shown under the drawer, keeps its timeout and counts as missed (Q16)

`lib/presentation/driver/home/home.dart:712` (found by r2-driver2)

**What happens:** An Exclusive offer rises and the driver opens the side menu from the island to check Notifications, reading the menu for 15 s. The offer runs out under the drawer and counts as a missed Exclusive. At the admin's limit, the driver is taken offline.

**Why:** The drawer is not a route, so opening it does not trigger didPushNext or pause. The Exclusive sheet sits under the drawer's 90%-wide panel and its scrim, where the driver cannot see it or tap Accept, and its _outsideOfferTimeoutTimer keeps running. When it fires, the offer is dismissed with missed: true, which feeds ExclusiveAnswers (Q16), and enough misses in a row take the driver offline. The same offer hidden by a pushed route is paused and, per R13-3, 'ran out while the driver could not see it: not a miss'.

**Suggested fix:** Pause the Exclusive timeout while the drawer is open (Scaffold.onDrawerChanged), or do not count a timeout as a miss while the drawer covers the offer.

### L73. Matching from the full Radar list leaves Home's copy of the card live: it is marked 'unavailable' at match time and the driven trip briefly reappears as 'Taken' after the trip

`lib/presentation/driver/home/home.dart:746` (found by r2-driver2)

**What happens:** The driver is online with three Radar cards on Home, taps the orb to open the full Radar list, and taps Match on the first trip. They drive it and complete it 20 minutes later. Back on Home, the deck still holds the pre-trip cards: the trip just completed is shown as 'Taken', and the rest have Match faded. If that card was the expanded front card, the island also posted 'Trip unavailable' at the moment of the match.

**Why:** When the driver matches from the Home deck, _openOfferTrip clears all Home offer state in a post-frame callback (_outsideRadarOffer, _radarHomeOffers, _pendingRadarHomeOffers, _hasRideOffers = false). When the driver matches from the embedded RideRequests list (shown when showRideRequests is true), Home only receives onCloseRides and the session callbacks, and nothing clears Home's deck. The sequence is as follows. (1) RideRequests claims the offer. The demo dispatch _removeOffer emits the new offer list to Home's still-live _watchDispatchRadar listener, which calls _resolveHomeRadarMatchLost(offer, unavailable) on Home's copy of the same trip and marks it claimedElsewhere. (2) Within 500 ms AcceptRide is pushed, and didPushNext -> _cancelAllOfferTimers(preserveClaim: true) cancels the 2.8 s cleanup but keeps every list and deadline. (3) After the trip, endTrip sets resumeHomeAfterTrip, and _onDriverSessionChanged only sets showRideRequests = false. didPopNext -> _resumeOfferTimers shows the driven trip as a 'Taken' card for 1.2 s. Other cards have old deadlines and come back already expired (Match faded), and _hasRideOffers stays true.

**Suggested fix:** Give RideRequests an onMatched callback, or clear Home's deck in _onDriverSessionChanged when a trip begins, in the same way as the Home-deck accept path.

### L74. _activateDestinationMode calls _goOnline() after its awaits without re-checking that destination mode is still active, so a driver who went offline or turned the destination off during the route fetch is put online

`lib/presentation/driver/home/home_map_sheet.dart:346` (found by driver1)

**What happens:** Driver confirms a destination, the road-route request is slow, and within those seconds they open the island sheet and tap "Turn off destination". The route request returns, and `_goOnline()` flips the driver online (radar starts, offers arrive) although destination mode is off and they never asked to go online.

**Why:** After the synchronous setup, `_activateDestinationMode` awaits `_refreshDestinationRoadRoute()` (a network road-route request) and `_fitDestinationRoute()` (341-342) and then unconditionally runs `_seedDemoDestinationTrips()`, `_maybeShowSoonReservation()` and `if (!_isOnline && !_isGoingOnline) { _goOnline(); }` (343-348). The inner helpers guard themselves, but `_goOnline` (home.dart 884-930) has no `mounted` check and calls `showDriverSuspendedSheet(context)`, `setState(...)`, `_startDriverLocation` and arms timers. If the driver turned the destination off during the fetch (island → details sheet → "Turn off destination" → `_endDestinationMode`, or the admin time limit timer at 313-318 fired) the driver is still switched online because of a destination that no longer exists; if Home was disposed during the await, `setState`/`context` are used after dispose.

**Suggested fix:** After the awaits add `if (!mounted || !_destinationModeActive || _destinationPosition != destination) { return; }` before seeding/going online (the same guard `_fitDestinationRoute` already uses at 404-406).

### L75. A pick window that ends during a Match claim is never re-armed: after a network error the card keeps Match enabled indefinitely

`lib/presentation/driver/home/home_offer_radar.dart:438` (found by r2-driver4)

**What happens:** A Radar card has about 2 s left in its 15 s pick window. The driver taps Match, the claim takes longer than 2 s and fails with a network error. Reproduced with a throwaway widget test: 30 s after the deadline, 'radar-match-audit-card' onPressed is still enabled. The radar sound also keeps treating the card as live.

**Why:** _startRadarPickWindow stores a Timer in _radarOfferTimeoutTimers and refuses to start another while that key exists (line 425). When the timer fires while the card is `resolving` (a Match claim in flight), the callback returns without adding the id to _radarOfferExpired and leaves the dead timer in the map. If the claim then ends with ClaimOutcome.networkError, _claimHomeRadarOffer only removes the match state (line 560-563), which puts the card back to `available`. It never re-checks the deadline, and no later _startRadarPickWindow call can re-arm, because the stale key is still there. The D-04 rule ('the window has one deadline… Match fades at once when the window ran out') is broken: Match stays live past the deadline until the next pause/resume clears the map. This is a different path from the known :425 finding, which is about expired offers dropped by refresh and listed again.

**Suggested fix:** On networkError, compare _radarOfferDeadlines[offer.id] with now: mark the card expired if the deadline has passed, otherwise remove the stale timer entry and call _startRadarPickWindow. Alternatively, have the timer callback remove its own map entry.

### L76. A Home-accepted trip invents a 4.9 rider rating when the offer's rating does not parse

`lib/presentation/driver/home/home_offer_radar.dart:952` (found by r2-driver4)

**What happens:** Dispatch sends a first-time rider whose rating is '' or '—'. The driver accepts it from the Home deck, and the trip screen shows the rider as 4.9.

**Why:** _openOfferTrip passes `double.tryParse(offer.rating) ?? 4.9` to AcceptRide. An offer with no usable rating (empty, '—', 'New') therefore reaches the active ride as a 4.9-star rider. This is the same defect as the known ride_requests.dart:379 entry, but it is a separate call site: every trip accepted from Home (Exclusive offers, the Radar deck, admin assigns, reservations) goes through this line, so fixing only ride_requests leaves it in place.

**Suggested fix:** Pass a nullable rating and show 'New' or 'unknown' on the trip screen, as the ride_requests fix should.

### L77. The deck's 'All offers' count includes the admin direct assign, which the Radar list and the radar button both exclude

`lib/presentation/driver/home/home_offer_radar.dart:1005` (found by r2-driver4)

**What happens:** In the default demo build the feed holds admin-group-1, nearby-1..3, admin-group-2 and admin-assign-1. The deck badge reads one more trip than the radar button shows, and one more than the full Radar screen lists when the driver taps it.

**Why:** _radarTripTotal feeds the LedCountBadge above the Home deck (line 1101). Its count of dispatch trips filters on isNearby, the destination rule and _rideAllowed, but not on isAdminDirectAssign. _radarTripsOpen (line 615-621, used by the radar button) and RideRequests._visibleOffers (ride_requests.dart:134, the list the badge opens) both exclude direct assigns, because 'an admin direct assign is an Exclusive offer, not a Radar trip'. Demo admin offers are on by default outside production (driver_runtime_config.dart:84), and DemoAdminOffers.directAssign has isNearby: true.

**Suggested fix:** Add `!offer.isAdminDirectAssign` to the filter in _radarTripTotal, or reuse _radarTripsOpen.

### L78. The 'All offers' opener is a 27 px-high target with no button role (tap action is exposed)

`lib/presentation/driver/home/home_offer_radar.dart:1097` (found by r2-driver4)

**What happens:** The driver has to hit a ~27 px strip to open the full offer list, and screen readers do not announce it as actionable.

**Why:** The Home deck's 'All offers' control is a GestureDetector around LedCountBadge. The badge is padding 5+5 around 14 px DSEG digits with a 1.5 px border, about 27 px tall. LedCountBadge sets Semantics(label, excludeSemantics: true) without button: true, so assistive tech reads 'N all offers' without a button role.

**Suggested fix:** Wrap the badge in Semantics(button: true) and give it a 44 px minimum height hit area (Padding or ConstrainedBox around the GestureDetector child).

### L79. Re-showing the Exclusive offer already on screen restarts its countdown; the demo _directOfferTimer re-fires on every resume, so returning from any route resets the offer's time to the full lifetime (contradicts the D-04/R13-3 "time left" rule)

`lib/presentation/driver/home/home_offer_radar.dart:1175` (found by driver2)

**What happens:** Exclusive offer shows 9 s left; driver long-presses the radar, gets "Go offline?", taps "Stay online". The offer resumes at ~8 s, then 2.2 s later jumps back to 15 s and the Q16 miss clock runs again from scratch.

**Why:** _showOutsideRadarOffer lets an offer whose id equals the current _outsideRadarOffer through its guard (232) and then cancels _outsideOfferTimeoutTimer and calls _raiseExclusive → _startExclusiveClock, which resets the clock to 1 and the deadline to now+lifetime (251-259, home_exclusive.dart:89-93). _resumeHomeUpdates (home.dart:204-213) first restores the time left via _resumeOfferTimers → _resumeExclusiveTimeout, but it also calls _scheduleVisibleOffers, which re-arms _directOfferTimer (2.2 s) to show the demo Exclusive again (1175-1189). If the same offer is still up (e.g. the driver dismissed the Go-offline dialog, or came back from Ride history inside the 15 s), 2.2 s later its ring and pill jump back to 15 s. _seedDemoDestinationTrips (home_map_sheet.dart:458-466) and _releasePendingRadarOffers → _pendingAdminAssign have the same re-show shape.

**Suggested fix:** In _showOutsideRadarOffer return early when `_outsideRadarOffer?.id == offer.id` (the offer is already up), so only a new offer starts a clock.

### L80. The 'New scheduled ride' notification body uses the raw English pickupDay ('Today'/'Tomorrow') in the sv/fr feed

`lib/presentation/driver/home/home_reservation.dart:214` (found by r2-driver1)

**What happens:** Swedish UI: the Notifications screen shows 'Today 09:30 · 126.75 kr · Tryck för att visa'.

**Why:** _onReservationRising adds DriverNotices.newScheduledRide(day: request.pickupDay, ...). The day is the stored English 'Today'/'Tomorrow' from _DemoReservationSet._at. It is inserted verbatim into tr.noticeScheduledBody, even though ReservationWhen.dayWord exists for exactly this mapping.

**Suggested fix:** Pass ReservationWhen.dayWord(request.pickupDay), or better the ReservationWhen label.

### L81. Scheduled rides reminder/backup notes and ride card time/distance strings are frozen in the language they were made in

`lib/presentation/driver/home/home_scheduled.dart:264` (found by r2-driver4)

**What happens:** In English, a '1 h before pickup' reminder fires. The driver switches to Swedish and opens Scheduled rides › Accepted. The note titled 'Påminnelse' still reads 'Pickup at 14:00 in 1 h · …', and the cards keep 'Today, 07:40–07:45'.

**Why:** ScheduledRideStore.reminder and backupNote are static ValueNotifier<String?> that hold rendered text: `tr.pickupAtPickupTimeInLeft(...)`, `tr.headToYourPickupTimePickup(...)`, `tr.goOnlineNowForYourPickup(...)` (home_scheduled.dart:198, 264, 287) and `tr.schedBackupNote(ride.pickupTime)` (scheduled_rides.dart:647). The Scheduled rides screen shows them under translated titles (tr.reminder / tr.islandGivenToBackup). Each _ScheduledRide also caches `time: tr.schedSeedTime(...)` and `distance: driverDistanceKm(...)` once, in the static store that lives for the whole app run (scheduled_rides.dart:1117-1119, 1134-1144). The sv template is '{day} {time}' while en/fr use '{day}, {time}', so the cards keep the first language's format.

**Suggested fix:** Store the ride and the reminder kind/minutes, and format the text in build.

### L82. Queue position preview sheet has hard-coded English text (categories incl. non-canonical 'Van', '15-30 mins EST time') and sample ranks that contradict the '10 drivers ahead' card

`lib/presentation/driver/my queue position/my_queue_pos.dart:27` (found by r2-driver1)

**What happens:** A Swedish driver opens 'My queue position' and sees English category names and a 'Van' category that the app does not offer, next to rank numbers that contradict the '10 drivers ahead' card.

**Why:** The ranks table prints the hard-coded list 'Electric', 'Comfort', 'Electric', 'Electric', 'Van', 'Van' unchanged in every language. 'Van' is not one of the canonical categories in DECISIONS.md P1 (economy, comfort, premium, priority, xl, electric, pet). The airport card opening this sheet says 'Sample: 10 drivers ahead' (tr.queueSample10Ahead), while the sheet shows ranks '2' and '1', so the same sample metric shows two values.

**Suggested fix:** Use CategoryCatalog display names through tr, use only canonical categories, and keep the sample numbers consistent between the card and the sheet.

### L83. 'See all' under Recent payouts opens the bank-account screen, not the payouts list

`lib/presentation/driver/my wallet/wallet.dart:281` (found by r2-driver2)

**What happens:** Wallet › Recent payouts › See all opens 'My bank' (payout account) instead of a list of payouts.

**Why:** _sectionHeader(title: tr.recentPayouts, action: tr.seeAll) wires its button to push MyBank, the same destination as the payout-account card below. A driver who taps 'See all' expecting the payout history lands on the bank account page.

**Suggested fix:** Hide or disable 'See all' until a payout history exists, or point it at a payouts screen.

### L84. '1 ride categories saved' – the saved-count snackbar is not pluralized

`lib/presentation/driver/preferences/preferences.dart:203` (found by driver4)

**What happens:** Leave only 'Movera' on and tap Save preferences: snackbar '1 ride categories saved'.

**Why:** `tr.prefCategoriesSaved(selectedCount)` is a plain placeholder string `"{count} ride categories saved"` (app_en.arb:2601; sv/fr likewise) rather than an ICU plural like `inDaysCount`. With exactly one category enabled, Save announces '1 ride categories saved' ('1 resekategorier sparade').

**Suggested fix:** Convert to `{count, plural, =1{1 ride category saved} other{{count} ride categories saved}}` in all arbs.

### L85. On first open, Profile shows 'Vehicle data unavailable' until primaryIdentity() resolves

`lib/presentation/driver/profile/profile.dart:162` (found by driver2)

**What happens:** Open Profile: the Vehicles row reads 'Vehicle data unavailable' for a frame or more, then 'Mercedes-Benz E 220'.

**Why:** The Vehicles link detail is `snapshot.data?.vehicle ?? tr.vehicleDataUnavailable` with no check of `snapshot.connectionState`. `primaryIdentity()` is async (SharedPreferences read through the serialized settings queue), so every open of Profile first paints the error text 'Vehicle data unavailable' and then replaces it with the vehicle name; after `_vehicleChanged` the same flash repeats. The same text is meant for the read-failure case (`primaryIdentity` returns null on error).

**Suggested fix:** Show an empty/loading detail while `snapshot.connectionState != ConnectionState.done`.

### L86. Ride-completed payment row shows hard-coded English 'Cash'/'Card' instead of tr.cash, and labels Apple Pay / Google Pay trips as 'Card'

`lib/presentation/driver/ride completed/ride_completed.dart:215` (found by r2-driver4)

**What happens:** A French driver completes an Apple Pay trip. Ride completed shows 'Paiement: Card': the method is wrong and the word is English. A Swedish cash trip shows 'Betalning: Cash'.

**Why:** accept_ride_trip.dart:966 passes `paymentMethod: widget.paidByCash ? 'Cash' : 'Card'`, and the page prints it as-is (`Text(widget.paymentMethod ?? '—')`). The value is an English literal, so it is never localized. It is also derived only from the paidByCash bool, while offers carry 'Apple Pay', 'Google Pay' or 'Swish' (api_dispatch_repository.dart:14-19, RideOffer.payment). Every non-cash trip is therefore reported as paid by 'Card'.

**Suggested fix:** Carry the offer's payment method into AcceptRide and the snapshot, and map it to localized labels (tr.cash, tr.card, …) on display.

### L87. Ride-completed chip shows the stored English source ('Exclusive offer', 'Local demo', 'Demo Radar') instead of sourceText

`lib/presentation/driver/ride completed/ride_completed.dart:342` (found by r2-driver4)

**What happens:** A Swedish or French driver completes a trip that came from an Exclusive offer (or a demo trip). The completion chip reads 'Movera · Exclusive offer' or 'Comfort · Local demo' in English, while the waybill opened from the same page shows the translated source.

**Why:** WaybillRecord.source holds English storage values (`exclusiveOfferSource = 'Exclusive offer'`, `localDemoSource`, `demoRadarSource`). Its doc says screens must show `sourceText` in the driver's language, and the waybill sheet does (`_Row(tr.via, record.sourceText)`). The Ride-completed chip joins the raw `record.source` instead. A secured next trip is always started with `matchedVia: WaybillRecord.exclusiveOfferSource` (accept_ride_trip.dart:942/1401), and that value becomes the waybill's source (accept_ride_trip.dart:186).

**Suggested fix:** Use `record.sourceText` in the chip.

### L88. Dragging across the rating stars queues one 'Rating not sent' SnackBar per drag update, so SnackBars keep showing for minutes

`lib/presentation/driver/ride completed/ride_completed.dart:388` (found by r2-driver4)

**What happens:** The driver slides a finger from the first to the fifth star (about 0.5 s, about 30 move events), then taps Done. Home's dock and radar orb sit under 'Rating not sent (demo)' SnackBars, one after another, for about 2 minutes.

**Why:** The RatingBar has updateOnDrag: true, and onRatingUpdate calls ScaffoldMessenger.of(context).showSnackBar on every call. In flutter_rating_bar 4.0.1, _onDragUpdate calls widget.onRatingUpdate on every drag update (each pointer move) and _onDragEnd calls it once more. Each call adds another SnackBar to the root ScaffoldMessenger queue (default 4 s each). The queue survives Done and popUntil and keeps showing over Home's bottom dock.

**Suggested fix:** Show the notice once (hideCurrentSnackBar before showing, or show only when the rating first goes from 0 to a value), or set updateOnDrag: false.

### L89. The Ride detail back button is an unlabelled ~24 px InkWell

`lib/presentation/driver/ride history/history detail/history_detail.dart:118` (found by r2-driver2)

**What happens:** A VoiceOver user opening a past trip finds an unnamed 'button' at the top. A sighted driver has to hit a ~24 px circle to go back.

**Why:** The only on-screen way back from DriverRideHistoryDetail (opened from every history card) is an InkWell over a ResSize 24×24 circle holding Icons.arrow_back_ios_rounded with no semanticLabel/Tooltip. Screen readers announce an unnamed button, and the target is about 24 px. The R07 tooltip test covers IconButton only.

**Suggested fix:** Use an IconButton with tooltip: tr.back (44-48 px), or wrap it in Semantics(button: true, label: tr.back) and enlarge the hit area.

### L90. Cancelled/no-fare trip detail shows the quoted fare as 'Ride Cost' and an 'incl. +X kr Movera bonus' note

`lib/presentation/driver/ride history/history detail/history_detail.dart:400` (found by driver3)

**What happens:** Driver cancels a 152,40 kr admin radar-group trip with a 40 kr bonus before pickup. History list shows '—'; opening it shows 'Ride cost 152,40 kr' and 'incl. +40 kr Movera bonus' above 'Cancelled by driver'.

**Why:** `_buildSummaryRows` always renders `_detailRow(tr.rideCost, _ride.fare)` and, when `driverBonus` is set, the 'incl. +X kr Movera bonus' note (line 400-416), regardless of `_ride.status`. History records for driver/rider cancels are written with the waybill's quoted fare (`prefs_trip_history_repository.dart:212 'fare': record.fare`) and status `cancelled_by_*`/`searching`. The list is careful about this: earnings show '—' for non-completed rides (ride_history.dart:82) and the bonus note is guarded by `status == completed` (ride_history.dart:898). The detail contradicts it, presenting an amount and a bonus as the cost of a trip that ended with no fare.

**Suggested fix:** Guard the fare row and the bonus note on `status == TripStatus.completed` (show '—' otherwise), matching the list.

### L91. History detail shows the stored English word 'Cash' as the payment method in fr/sv, and card trips show '—' although the completion screen said 'Card'

`lib/presentation/driver/ride history/history detail/history_detail.dart:420` (found by r2-driver2)

**What happens:** A Swedish driver opens a cash trip in history and reads 'Cash' instead of the Swedish word. For a card trip just completed as 'Card', the history detail shows 'Payment method —'.

**Why:** The journal stores the literal 'Cash' for cash trips and null for card trips (accept_ride_trip.dart:916 `paymentMethod: widget.paidByCash ? 'Cash' : null`). The detail row prints `_ride.paymentMethod` raw, so French and Swedish drivers read 'Cash' although `tr.cash` exists. Because card trips are stored as null, their history shows '—', while DriverRideCompleted showed 'Card' for the same trip (accept_ride_trip.dart:966 `paymentMethod: widget.paidByCash ? 'Cash' : 'Card'`).

**Suggested fix:** Map the stored code to tr.cash or tr.card when displaying it, and record 'Card' (or a code) for card trips in the journal.

### L92. Cash balance direction row is English-only ('You owe Movera') in the localized detail screen

`lib/presentation/driver/ride history/history detail/history_detail.dart:432` (found by driver3)

**What happens:** Swedish driver opens a completed cash trip in History: 'Kontant insamlat 300,00 kr', then 'You owe Movera −51,60 kr', then the Swedish settlement note.

**Why:** The cash-trip rows use `cash.directionLabel`, which is `CashBalance.direction` returning hardcoded English strings (cash_balance.dart:46-50: 'You owe Movera' / 'Movera owes you' / 'Settled'). The surrounding rows (`tr.cashCollected`, `tr.cashMatchedYourFare`, `tr.settledInYourNextPayout`) are translated, so the Swedish/French screen mixes one English label into the money summary.

**Suggested fix:** Map the direction to `tr` keys at the presentation layer (the sheet already has `totalYouOweMovera`/`totalMoveraOwesYou`).

### L93. Trip details keep claiming 'Movera safety team alerted' for Ride checks whose alert only reached the in-memory demo outbox

`lib/presentation/driver/ride history/history detail/ride_check_history_entry.dart:156` (found by r2-driver4)

**What happens:** After a red Ride check answer, the trip's history detail tells the driver that Movera's safety team was alerted, although nothing left the phone.

**Why:** For every record with `alertSent`, the history entry shows `tr.moveraSafetyTeamAlerted` with a red bell. REVIEW_AND_MERGE_GATES.md says safety recording and sharing are not connected services and the UI must not claim they succeeded. The known finding covers the live Ride check card (ride_check_card.dart:703). This archived copy in History repeats the claim permanently for each such trip.

**Suggested fix:** Use wording that says the alert is a demo or was saved locally, consistent with the fix for the live card.

### L94. Overview counts and empty-state disagree about what a 'ride' is (cancelled trips counted in some places, not others)

`lib/presentation/driver/ride history/ride_history.dart:390` (found by driver1)

**What happens:** A week with 0 completed and 3 cancelled trips: Rides metric '0', no 'No completed rides in this period' text, two cancelled cards under Latest rides, button 'View all 3 rides', and the All rides header '0 rides in Last 7 days' above three cards.

**Why:** `_periodRidesList` (line 100-111) contains every record with a `completedAt`, cancelled ones included. The overview's 'Rides' metric uses `_periodRides` (completed only, line 145), but the empty state `tr.noCompletedRidesInThisPeriod` is shown only when the whole list is empty (line 390), 'Latest rides' takes the first two of all records (line 392) and the button says `viewAllVisibleRideCountRides(_periodRidesList.length)` (line 306, 403). The All-rides summary row then says '{_periodRides} rides in {period}' while listing more cards.

**Suggested fix:** Decide one definition (all finished trips vs completed) and use it for the metric, the empty state, the count and the summary row.

### L95. All-rides list prints raw wire status names and a hardcoded 'cancelled_by_driver'

`lib/presentation/driver/ride history/ride_history.dart:940` (found by driver1)

**What happens:** A rider cancels a trip. In History › All rides the card's status line reads `cancelled_by_rider`; tapping it shows 'Cancelled by rider'. In Swedish the list still shows the English snake_case token.

**Why:** The non-compact history card shows `ride.status == completed ? tr.completed : ride.status.isReleasedToDispatch ? 'cancelled_by_driver' : ride.status.wireName`. Every non-completed outcome is therefore shown as its wire identifier with underscores (`cancelled_by_rider`, `no_show`, `expired`, `cancelled_by_system`) and the released-to-dispatch case as the literal `cancelled_by_driver`, in every language. The detail screen for the same record translates these (`_buildMetaRows`, history_detail.dart:455-467), so the list and the detail disagree.

**Suggested fix:** Reuse the outcome mapping from `_buildMetaRows` (or add a `TripStatus` → label helper) and show the translated outcome in the list.

### L96. Trips hidden with × in the Live list come back immediately when the list is reopened (hidden state is destroyed with the widget)

`lib/presentation/driver/ride requests/ride_requests.dart:103` (found by r2-driver1)

**What happens:** The driver hides 'Hantverkargatan → Bandhagen' with × in the Live list, closes the list and taps the radar orb again 10 s later. The hidden trip is back at the top with Match enabled, instead of staying away for the admin's 2 minutes.

**Why:** Q17 says a trip hidden with × comes back only after `hiddenComesBackAfter` (2 min by default), and only if it is still open. The hidden set `_dismissed` and its `_comeBackTimers` live in `_RideRequestsState`. Home mounts RideRequests only while `showRideRequests` is true (home.dart:717/746) and unmounts it when the driver closes the list. Reopening creates a fresh state with an empty `_dismissed` and a new first dispatch snapshot, so every hidden trip is listed again at once. The widget test for Q17 never closes and reopens the list, so it cannot catch this.

**Suggested fix:** Keep the hidden-until deadlines outside the widget (on Home's state or a small static store keyed by offer id with its come-back time), and apply them when the list is rebuilt.

### L97. Radar's 'N new' refresh pill counts trips that the driver's filter will never show, so Refresh adds nothing

`lib/presentation/driver/ride requests/ride_requests.dart:229` (found by r2-driver1)

**What happens:** A driver with cash rides switched off has Radar open. The demo or the server releases cash trips, the pill says '7 new', and tapping it adds no cards. The same happens in destination mode with off-route trips: the pill says 'New' and nothing is added.

**Why:** `hasNew` lights the refresh pill for any new nearby offer that is not an admin direct assign. It ignores `widget.offerFilter` (Home's `_rideAllowed`: cash rides off, ride categories, the window before an accepted scheduled ride) and ignores destination mode. The pill text `fresh` in `_header` applies the destination filter but not `offerFilter` or admin direct assigns. `_visibleOffers` applies all of them, so after the driver taps Refresh the promised trips do not appear.

**Suggested fix:** Compute `hasNew` and `fresh` with the same predicate as `_visibleOffers`: offerFilter, admin direct assign, destination and dismissed.

### L98. Hardcoded English UI strings in localized screens

`lib/presentation/driver/ride requests/ride_requests.dart:648` (found by driver3)

**What happens:** Driver language is French. Radar header shows '3 OFFERS', destination search shows '2 found', the bank form shows 'ACCOUNT', Analytics and Driving logs show 'DEMO DATA', the queue sheet shows '15-30 mins EST time'.

**Why:** The app ships en/fr/sv (`lib/l10n/app_*.arb`) and every other label on these screens goes through `tr`, but several user-visible strings are literals: ride_requests.dart:648 `label: 'OFFERS'` on the live count badge; destination_picker.dart:361 `'${results.length} found'` under the search box; add_new_account.dart:253 section header `'ACCOUNT'`; analytics.dart:60 and driving_logs.dart:50 `'DEMO DATA'`; my_queue_pos.dart:121 `"15-30 mins EST time"` (also an abbreviation the driver cannot read). They stay English in Swedish and French.

**Suggested fix:** Move each string into the ARB files and read it through `tr`.

### L99. On web builds without a tel: handler (desktop or non-telephony tablet browsers), the Safety toolkit says 'Emergency dialer opened' because url_launcher_web always returns true

`lib/presentation/driver/safety toolkits/safety_toolkits.dart:95` (found by driver4)

**What happens:** Driver using the PWA on a laptop/desktop (or a tablet without telephony) taps Call 112 -> browser does nothing or shows a silent protocol prompt -> app shows 'Dialer opened' / ride-check card advances to 'Called 112' with alertSent, though no call path exists.

**Why:** handoffEmergencyDial maps `launch()` true to EmergencyDialResult.opened, and the Safety toolkit then shows tr.safetyDialerOpened; RideCheckController.callEmergency likewise sets `_dialOpened = true` and moves the card to the 'called' state. The default launcher is `launchUrl(Uri.parse('tel:112'))`. url_launcher_web (2.4.3, url_launcher_web.dart:66-69, 112-115) documents that launchUrl 'Always returns true, except for disallowed schemes' because window.open with noopener cannot report success; on a desktop browser (or a mobile browser with no tel handler) nothing opens, yet the UI confirms the dialer opened. REVIEW_AND_MERGE_GATES.md's product-truth gate forbids claiming an action succeeded when it did not.

**Suggested fix:** On web, phrase the confirmation neutrally ('Opening 112…' / show the number to dial) instead of asserting the dialer opened, or gate the success copy on `!kIsWeb`.

### L100. 'PIN verification' tile title is hardcoded although tr.pinVerification exists

`lib/presentation/driver/safety toolkits/safety_toolkits.dart:179` (found by driver4)

**What happens:** Language Français > Settings > Safety > Safety preferences: tile reads 'PIN verification' with a French subtitle.

**Why:** In the Safety preferences sheet the first tile title is the literal `'PIN verification'` while its subtitle and the other tiles use `tr`. The key `pinVerification` exists in all three arb files (en 'Pin verification', fr 'Vérification par code') and is used by settings.dart:95, so this sheet shows English in fr/sv and even a different English spelling from Settings.

**Suggested fix:** Use `tr.pinVerification`.

### L101. Safety toolkit status banner shows a green success check for 'Could not open the dialer' and 'unavailable' messages

`lib/presentation/driver/safety toolkits/safety_toolkits.dart:452` (found by driver4)

**What happens:** On a device/browser where `launchUrl(Uri.parse('tel:112'))` returns false (web, tablet without telephony), tap Contact 112 > Call 112: a green check banner appears reading 'Could not open the dialer...'.

**Why:** `_status` is rendered in one fixed style: green background `0xFFE7F4EE` and `Icons.check_circle_outline_rounded` in green (lines 440-471). `_confirmEmergencyCall` puts `tr.couldNotOpenDialerDial112` ('Could not open the dialer. Dial 112 manually.') into the same banner when `handoffEmergencyDial` returns `unavailable`, and `_toggleRecording`/`_shareTrip` put 'Audio recording is unavailable in this demo.' there. The failure of the only real action in the sheet (112 dial) is thus visually confirmed as success.

**Suggested fix:** Carry a severity with `_status` (info/error) and style the banner/icon accordingly.

### L102. Sample accepted ride is seeded with a localized pickupDay, so its time logic silently differs by language

`lib/presentation/driver/scheduled rides/scheduled_rides.dart:445` (found by driver3)

**What happens:** In Swedish, a request whose time clashes with the sample 08:15 ride is still listed and can be accepted, and cancelling the sample ride 30 minutes before pickup is not counted as late; in English the same actions are blocked/counted.

**Why:** `_seedAccepted` sets `pickupDay: tr.tomorrow` on the `ReservationRequestPreview` (line 445). `pickupAt` only recognises the English keys 'today'/'tomorrow' (driver_home_admin_content.dart:246-251), so in Swedish ('Imorgon') or French the sample ride has `pickupAt == null`. Consequences inside this screen: `_clashWith` never treats it as clashing (smart_gap.dart:88-90 returns false), so the clash filter and the 'rides hidden' note behave differently from English; `freeCancelUntil` returns null so the cancel sheet shows the generic 'free X hours before' line instead of the real time and `isLateCancel` is never true; `upcoming` (line 626-634) excludes it so Home's reminders/leave-now never fire for it. The existing test (scheduled_rides_rules_test.dart:112) only asserts the English behaviour.

**Suggested fix:** Seed the model with the English key ('Tomorrow') and localize only for display (`ReservationWhen.dayWord`).

### L103. Scheduled ride cards show English 'Today'/'Tomorrow' in the Swedish and French UI

`lib/presentation/driver/scheduled rides/scheduled_rides.dart:1134` (found by driver3)

**What happens:** Driver language is Swedish. Scheduled rides lists 'Today, 07:40–07:45' and 'Tomorrow, 08:15' while the header, tabs and notes are Swedish; the same label is used in the details hero (line 1518).

**Why:** `_ScheduledRide.request` (line 1134) and `_ScheduledRide.fromRoute` (line 1117) format the card time with `tr.schedSeedTime(route.pickupDay, route.pickupTime)` using the model's raw English day key ('Today'/'Tomorrow', see `_DemoReservationSet._at` and `pickupAt`'s parsing of 'today'/'tomorrow'). The app has a localizer for exactly this (`ReservationWhen.dayWord`, reservation_when.dart:89-93, used by reservation_route_map.dart:427) but these two constructors do not use it. Every real request and every accepted ride in the list therefore reads 'Today, 07:40–07:45' / 'Tomorrow, 08:15' under Swedish or French.

**Suggested fix:** Pass `ReservationWhen.dayWord(route.pickupDay)` to `schedSeedTime` in both constructors.

### L104. 'tomorrow' is dropped from the free-cancel time on the spring DST day

`lib/presentation/driver/scheduled rides/scheduled_rides_notes.dart:11` (found by driver3)

**What happens:** On the last Sunday of March the driver opens an accepted ride for tomorrow 08:15. The plan card says 'Free cancel until 07:15.' with no day, which reads as today 07:15 (already passed), so the driver believes any cancel is now late.

**Why:** `_timeFrom` computes the day gap as `DateTime(y,m,d).difference(DateTime(y,m,d)).inDays`. On the day DST starts, local midnight to next local midnight is 23 h, so `inDays` is 0 and a time that is tomorrow is rendered as a bare clock ('07:15') instead of 'tomorrow 07:15'. Used by `_freeCancelLine` for `schedFreeCancelUntil` in the details plan card (scheduled_rides.dart:1705) and the cancel sheet (`_CancelRulesBox`). Reproduced in TZ=Europe/Stockholm: now 28 Mar 2027 12:00, until 29 Mar 07:00 → `inDays=0`.

**Suggested fix:** Compare calendar dates (`DateUtils.dateOnly` and compute the day number difference in UTC), e.g. `DateTime.utc(time.year, time.month, time.day).difference(DateTime.utc(now.year, now.month, now.day)).inDays`.

### L105. A failed 'Show traffic on map' save is dropped as an unhandled future: the switch shows the new value, nothing tells the driver, and it reverts on the next start

`lib/presentation/driver/settings/settings.dart:270` (found by r2-driver1)

**What happens:** On web with localStorage full (vehicle photos fill most of the ~5 MB quota), the driver turns traffic off. The switch shows Off and the trip map hides traffic for this run. No error is shown. After the next app start traffic is back on.

**Why:** `toggle` calls `MapTrafficSetting.set(value, _settings)` and throws the returned Future away. `set` updates `enabled.value` immediately, then returns `SettingsRepository.save`. That save throws (`StateError('Settings save failed')` or a `LocalWriteSession` StateError) when storage refuses the write. The error is never awaited or caught, so it becomes an uncaught async error (logged by `installGlobalErrorHooks`). The switch shows the unsaved value and no failure message or retry appears, unlike Sound & voice, Accessibility and Preferences, which show `_saveFailed` with Retry. On the next cold start `MapTrafficSetting.restore()` (main.dart:41) loads the old value.

**Suggested fix:** Await the save in the Settings row; on failure revert `enabled.value` and show a SnackBar or retry like the other settings screens.

### L106. The ONLINE/OFFLINE status pill in the menu header has 2.3:1 / 2.8:1 contrast

`lib/presentation/driver/side menu/side_menu.dart:371` (found by r2-driver4)

**What happens:** A driver opening the menu in bright light cannot read whether the pill says ONLINE or OFFLINE.

**Why:** The live-status pill draws 10.5 px w800 text. Online is MoveraRadarOrb.onlineGreen 5FB87D on the same green at 10% over white (≈EFF8F2), 2.3:1. Offline is 8A9390 on F1F2F2, 2.8:1. Both are well below the 4.5:1 needed for small text, on the one place in the menu that states the driver's availability.

**Suggested fix:** Use a darker text tone (e.g. 1C6B45 for online, 5F6B72 for offline) on the tinted pill.

### L107. Selected support category is discarded when the ticket is saved

`lib/presentation/driver/support/support_inbox.dart:335` (found by r2-driver1)

**What happens:** The driver picks 'Wallet & payments', writes the ticket and saves it. The stored ticket has no category, and the next draft defaults back to 'Trip & rider'.

**Why:** The draft sheet asks for a category, saves it in the draft, and validates it. The _Ticket built on save has no category field, toJson writes none, and the draft (including the category) is then reset to 'Trip & rider' (line 394-398). The driver's choice is lost as soon as the ticket is created and is never shown again.

**Suggested fix:** Add category to _Ticket (constructor, toJson, fromJson, _valid) and show it on the ticket card or conversation.

### L108. On web, if the Maps JavaScript script is blocked or fails to load, every CustomGoogleMap stays a plain land-colour box with no 'map unavailable' message (the poll is cancelled on dispose)

`lib/widgets/custom_google_map.dart:281` (found by driver1)

**What happens:** Driver opens the PWA with a content blocker that blocks maps.googleapis.com -> Home shows the beige placeholder forever, 'Finding your location' resolves, offers arrive, but no map, route or car is ever drawn and no message explains why; the 50 ms timer keeps polling until the screen is disposed.

**Why:** On web `_mapsReady` starts as `web.ready`, which is false until `google.maps` is installed by driver_map_camera.js. If the Maps script never arrives (ad/privacy blocker, key referrer rejection returning an error script, captive portal, offline PWA start) the widget keeps a `Timer.periodic(50 ms)` running for its whole lifetime and renders `ColoredBox(color: MoveraMapPalette.land)` indefinitely. Nothing surfaces the failure to the driver: Home's own 8 s `_startWaitLimit` only covers the start position, not the SDK, and no caller of CustomGoogleMap can observe the not-ready state. The driver sees a flat colour where the map should be, with markers, routes and offer previews silently missing, and the DemoModeBanner/offer flow continue as if the map existed.

**Suggested fix:** Bound the wait (e.g. 10-15 s) and then show a 'Map unavailable' state / retry, or expose an onUnavailable callback so Home and AcceptRide can tell the driver.

### L109. With reduced motion (and on the far-cut path) a GPS retarget that arrives during the single moveCamera await is dropped: retarget() requires _looping but _run has already captured the goal, and the controller nulls its pending pose after calling retarget

`lib/widgets/google_driver_camera_port.dart:259` (found by driver2)

**What happens:** Driver with 'reduce motion' enabled on a 1 Hz GPS trip: occasionally a fix lands while the previous moveCamera is awaiting acknowledgement; that fix never reaches the map and the camera holds the previous position for an extra second.

**Why:** `animate()` marks `_looping = true` and starts `_run`. In the `reducedMotion || _logical == null` branch `_run` reads `initial = _goal`, awaits one `_move(...)` and returns; the same happens on the `_far` cut (`await _move(destination ...); break;`). While that `moveCamera` platform call is in flight the controller still sees `_busy == true`, so a new fix goes through `_request` → `_port?.retarget(pending); _pending = null;` (driver_camera_controller.dart:732-737). `retarget` stores the pose in `_goal` (it passes the `_looping` check), but nobody reads `_goal` again: `_run` returns, `finally` clears `_looping`, the session completes, the controller sets `_busy = false` and arms a 16 ms throttle with `_pending` already null. The fix is lost until the next one, so under reduced motion the car/camera skip fixes whenever a platform round-trip overlaps a GPS event. Narrow window (a few ms per fix) but a real contract break of `DriverCameraPort.retarget` ('the in-flight animation steers toward this pose').

**Suggested fix:** After the single move / far cut, re-check `_goal` and issue one more `_move` if it changed during the await (or keep `_pending` in the controller until the port confirms it consumed the retarget).

### L110. The camera's coasted chase point reaches the car marker through onFrame, so between fixes the car icon moves in a straight line along the camera bearing (up to 21° off course) and overshoots by up to 22 m when the driver brakes

`lib/widgets/google_driver_camera_port.dart:281` (found by r2-driver2)

**What happens:** The driver brakes hard for a light, or makes a turn while the camera bearing lags. Between fixes, the car icon keeps sliding up to 22 m along the old or look-ahead bearing, beyond the stop line or off the road at the corner, then rubber-bands back when the next fix arrives.

**Why:** Each loop frame aims at _at(goal, _coasted(goal)). _coasted extrapolates up to 1.1 s / 22 m along goal.bearing, which is the smoothed camera heading blended up to 21° toward the route ahead, not the car's course. _move calls onFrame(logical) whenever _trackCar is true (target within 25 m of goal.target, which a 22 m coast always is). AcceptRide's onFrame calls _vehicle.snapTo(position.target, …) every frame while following, which overrides the route-snapped _vehicle.moveTo(camera.vehiclePoint). The car marker is therefore drawn at the damped, coasted camera target. DriverCameraPose.speedMetersPerSecond is documented as 'Used only to coast the chase point between GPS fixes. Never the car marker.'

**Suggested fix:** Publish the un-coasted vehicle point (goal.target, or the policy's vehiclePoint) to onFrame, and keep the coasted target only for the camera.

### L111. The recenter/locate flight clock advances only by the 16 ms sleep. Time spent awaiting moveCamera is never counted, so on native platforms the 1 s flight runs longer by about (moveCamera latency / 16 ms) × 100%

`lib/widgets/google_driver_camera_port.dart:313` (found by r2-driver2)

**What happens:** On a phone where each moveCamera await takes about 10-16 ms, a Recenter/Locate tap flies for about 1.6-2 s instead of 1 s, which brings back part of the slow glide #325 removed.

**Why:** In the flight branch, flown advances by dt, and dt is measured from a stamp taken after `await _move(...)` returns, around the 16 ms _sleep only. The time spent awaiting controller.moveCamera (a platform-channel round trip on Android/iOS) is never added. The flight therefore lasts flightDuration × (frame time / sleep time) instead of the documented 1 s ('runs on the clock … start to rest'). The #325 measurement was taken on a release web build, where moveCamera resolves almost at once. frame() and tiltTo() in the same class use absolute elapsed time from start, so the inconsistency is only here and in the damped loop (line 333).

**Suggested fix:** Measure dt from the previous frame's stamp, taken before _move, or compute the flight progress from a start timestamp like frame() does.

### L112. Counter badges show hard-coded English 'NEW' (default label) on Scheduled rides and 'OFFERS' on Ride requests

`lib/widgets/led_count_badge.dart:12` (found by driver3)

**What happens:** Swedish/French driver sees 'NEW' beside the request count on Bokade resor and 'OFFERS' on the Radar list.

**Why:** `LedCountBadge` renders `label` as visible text (line 72-80). `scheduled_rides.dart:169` uses the default `label = 'NEW'`; `ride_requests.dart:648` passes `label: 'OFFERS'`. The ARB already has `rrNew`/`orbNew` and `allOffers` (used by home_offer_radar.dart:1102), so these two sites were simply missed. Reproduced in the Swedish dump of Scheduled rides: `... 88, 02, NEW, 126.75 kr ...`.

**Suggested fix:** Pass `tr.orbNew`/`tr.rrNew` and `tr.allOffers` (or a new `offers` key).

### L113. Radar orb is always marked as a semantic button, even when tapping it does nothing (scanning with no offers, connecting)

`lib/widgets/movera_radar_orb.dart:151` (found by r2-driver2)

**What happens:** A TalkBack or VoiceOver user is online with no trips found. Focus on the orb announces a button. Activating it does nothing, and nothing says the control is disabled.

**Why:** MoveraRadarOrb wraps its content in Semantics(button: true, ...) whatever the value of onTap. Home passes onTap: null while scanning with no offers (_buildTripRadarButton: `onTap: hasRadarOffer ? _openRideOffers : null`) and while going online (_buildGoingOnlineButton has no onTap). A screen reader then reads 'Radar, LIVE. Scanning, button', and a double-tap does nothing.

**Suggested fix:** Use `button: onTap != null`, or add `enabled: onTap != null`.

### L114. The radar orb's status and subtitle text is about 4-6 logical px, with about 1.6-3.4:1 contrast on the grey disc

`lib/widgets/movera_radar_orb.dart:397` (found by r2-driver2)

**What happens:** In daylight an offline driver cannot read 'OFF · Tap to scan' on the radar, and on a trip the dock's 'Hold · OFF · Stop radar' is 4 px text.

**Why:** The orb is the main Home control (Go online, Accept, Hold to go offline) and the trip's next-trip toggle. Its status line is fontSize 6.1*s and its subtitle 5.9*s, with s = size/104: 6.1/5.9 px on Home and 4.1/4.0 px on the 70 px TripRadarDock. Colours: offline status E2E9E6 on the ~8F999C-727D80 grey disc is 2.4-3.4:1. The subtitle B7C2BE on the same disc is 1.6-2.3:1. The 'hot' status in offerAccent 969CA1 on 727D80 is 1.5:1. These are the words telling the driver whether Radar is off, live or matching. The Semantics label covers screen readers but not low-vision sighted drivers.

**Suggested fix:** Raise the status/subtitle to at least 10-11 px at the 104 px size and use colours that reach 4.5:1 on the disc, or move the state word outside the orb.

### L115. Radar sweep wedge never fades: SweepGradient with a negative startAngle clamps the whole arc to the end colour

`lib/widgets/movera_radar_orb.dart:491` (found by r2-driver2)

**What happens:** The driver goes online. Home's radar orb shows a uniform bright 60° slice rotating around the ring instead of a soft sweep that fades out behind its leading edge.

**Why:** RadarWedgePainter draws the arc from -tail to 0 rad with SweepGradient(startAngle: -tail, endAngle: 0). Both Skia and Impeller compute a pixel's sweep parameter from its angle in [0, 2π), then remap it with (t - start) / (end - start). Pixels in the drawn arc (-60°..0°) have t in [5/6, 1), which remaps to [6, 7) and is clamped by the default TileMode.clamp to stop 1.0 (white at 0.6 alpha). The documented 'light wedge that fades behind its leading edge' therefore renders as a solid 60° white fan with a hard trailing edge. Worked by hand: a pixel at -30° has t_raw = 11/12, so (11/12 + 1/6) * 6 = 6.5, which clamps to 1.

**Suggested fix:** Use startAngle: 2*math.pi - tail and endAngle: 2*math.pi (the same position as -tail..0 in the gradient's [0, 2π) domain), or draw from 0 to tail and rotate by lead - tail.

### L116. Offer-route pin bitmaps are cached without their localized title, so after a language change Home map pins keep the old language's 'Pickup'/'Drop-off'

`lib/widgets/offer_route_marks.dart:79` (found by r2-driver1)

**What happens:** An English-speaking driver sees an Exclusive offer with a '4 min' pickup, then switches to Swedish in Settings. The next offer with a 4-minute pickup shows the pin 'Pickup / 4 min' in English on the Swedish Home map until the app restarts.

**Why:** `OfferRouteMarks.pin` caches the painted bitmap under `'${kind.name}|$value'`. The bitmap's title text is `titleOf(kind)` = `tr.pickup` / `tr.dropOff` (localized). The value is language-neutral for Exclusive and Radar offers ('4 min' comes from `minutes()`, which hardcodes 'min'). DriverLanguage can change at runtime (main.dart:102 listener). After a switch, the next offer with the same minute value reuses the bitmap painted with the old language's title.

**Suggested fix:** Include the title (or the current locale) in the cache key, e.g. `'${kind.name}|${titleOf(kind)}|$value'`, or clear `_cache` when DriverLanguage changes.

### L117. D-04 test 'a pause before the end keeps the window' cannot tell a kept deadline from a fresh window: it pauses only 300 ms and then waits a full radarTime + 1 s after resume

`test/audit/offers_lifecycle_test.dart:158` (found by r2-driver4)

**What happens:** Regression: in `_cancelAllOfferTimers`, move `_radarOfferDeadlines.clear()` out of the `if (!preserveClaim)` block. Every pause/resume (notification shade, app switch) would then hand each Radar card a fresh 15 s pick window. 'a pause before the end keeps the window, then it ends' still passes, because 15 s + 1 s after resume is past the regressed window too. 'an expired Radar offer stays expired' still passes, because `_radarOfferExpired` is untouched. Verified by reading the code; no tests were run.

**Why:** Home's Radar pick window stores a deadline from `DateTime.now()` (home_offer_radar.dart:429-432). In a widget test that is the real wall clock, not the test's fake clock, so the 300 ms fake-time pause and all the earlier fake time cost almost nothing off the window. The test then pumps `radarTime + 1 s` after resume and expects Match to be disabled. That is true whether the deadline survived the pause or a fresh full window was started at resume. The test is named for D-04 (keep one deadline across pause/resume) but would pass with that rule removed.

**Suggested fix:** Inject a clock into Home's pick-window deadline (as AcceptRide does with waitNow) so fake time counts. Pause for a large part of the window, then assert Match fades after the remaining time, well before a full window has passed since resume.

### L118. D-05 'counts down the rest after resume' passes even if resume gives the offer its full lifetime again

`test/audit/offers_lifecycle_test.dart:222` (found by r2-driver4)

**What happens:** Regression: change accept_ride_trip.dart:164 to `_armOnTripOfferExpiry();`, which resets to the full lifetime and writes a new deadline. Every background/foreground cycle would then give the offer a fresh 15 s, so a driver who keeps switching apps keeps the offer alive indefinitely. All three D-05 tests still pass. Worked by hand with lifetime L = 15 s: the regressed timer fires at resume + 15 s and the test checks at resume + 15.3 s. No tests were run.

**Why:** The test says an on-trip Exclusive offer that is hidden and then shown again 'counts down the rest' (it resumes with the time it had left). It hides for 2 s, shows, pumps 300 ms, then pumps the full `exclusiveAcceptTime` and expects the offer gone. Suppose resume restarted a fresh full lifetime. The new timer would fire at resume + L, and the test has pumped to resume + 0.3 s + L by then, so the offer still disappears and still counts as a miss. The test never checks that the offer is gone before a full lifetime has passed since resume, so it cannot tell the remaining time from a fresh full window. This is the D-05/D-04 'time left, not a fresh window' rule.

**Suggested fix:** After resume, pump only (L − 2 s − 0.3 s + a small margin) and expect the offer to be gone. A fresh-window implementation would still be showing it at that point.

### L119. Source-grep test asserts a dead switch arm, and no behavioural test covers a rider_cancelled event without a status

`test/core/driver_realtime_test.dart:215` (found by driver-j2)

**What happens:** A refactor changes line 252 to `if (event.status != null)`. A rider_cancelled event without a projection status then falls to the switch, where `_handleRiderCancelled` runs without the drain's retry or backoff. The source-grep test stays green because the dead case label still exists.

**Why:** The test asserts that the active-ride source contains `case DriverRealtimeKind.riderCancelled`. In `_onRealtimeEvent`, every riderCancelled event is caught by the early branch at accept_ride_trip.dart:252-255 (`event.status != null || event.kind == DriverRealtimeKind.riderCancelled` → set pending → return). The switch arm at line 277 that calls `_handleRiderCancelled` directly is dead code. The test checks the presence of that dead arm plus two strings that appear elsewhere, so deleting or breaking the real routing at line 252 would not fail it.

**Suggested fix:** Remove the dead switch arm, or route through it. Replace the source-grep test with a behavioural test that emits a rider_cancelled event without a status and asserts the trip ends.

### L120. Pickup pay tests never exercise a fractional öre, so a switch from round() to floor() would pass the whole file

`test/core/pickup_pay_test.dart:71` (found by r2-driver4)

**What happens:** Regression: change pickup_pay.dart:81 to `.floor()`. A 1.235 km leg at 3 kr/km gives 370.5 öre, which should show 3,71 kr but would show 3,70 kr, and every test still passes. Worked by hand; no tests were run.

**Why:** The test is meant to guard pickup-pay rounding to öre. Its inputs are 1.234 km × 3 kr = 370.2 öre and 2.1 × 2.5 + 7 × 0.8 = 1085.0000000000002 öre, and both give the same result with `.floor()` and `.round()`. The other expectations in the file land on whole öre too. With the code's `+ 1e-6` epsilon, `floor(kronor*100 + 1e-6)` reproduces every expected string in the file. A switch to truncation, which underpays the driver by up to 1 öre per offer, goes unnoticed.

**Suggested fix:** Add a case whose öre value has a fractional part of .5 or more, e.g. km: 1.235, minutes: 0 → '3,71 kr', and one just below .5.

### L121. Test 'the Home sound releases the player it made' only covers the injected (not-owned) case; the owned-player dispose path is never tested

`test/core/radar_offer_sound_test.dart:92` (found by driver2)

**What happens:** A refactor stops disposing the internally created AudioPlayer on Home dispose; every test stays green; drivers accumulate live audio players across Home re-creations (sound keeps playing / memory grows).

**Why:** The test name promises coverage of the D-17 ownership rule (a player created by the Home sound is disposed by it), but it injects a player and then asserts `expect(audio.released, isFalse)` with the comment 'An injected player belongs to whoever passed it in'. The path where the sound creates its own player and must dispose it is never exercised, so a leak of the self-made AudioPlayer (and its platform channel / audio session) would not be caught, while the test title tells reviewers it is.

**Suggested fix:** Rename this case to 'an injected player is not released' and add a second case that lets the sound build its own player via a factory hook and asserts dispose is called.

### L122. home_scheduled_test's _end (and the same bare takeException() calls in offer_rules_flow, reservation_near_pickup and radar_offer_gone tests) would hide a future exception; none is being hidden today

`test/widget/home_scheduled_test.dart:164` (found by r2-driver1)

**What happens:** Regression: a 'Leave now' push that calls setState on a disposed Home, or a reservation sheet overflow, throws a FlutterError during the test. `_end` swallows it and the test passes. Verified by reading the flutter_test takeException semantics; no tests were run.

**Why:** Every test in home_scheduled_test.dart ends with `await _end(tester)`, which calls `tester.takeException()` and ignores the result. None of these tests asserts `takeException() isNull`. In flutter_test, takeException clears the pending error, and with it the 'multiple exceptions' failure, so overflows, setState-after-dispose or assertion errors during 'Leave now', the backup-driver handoff, assigned-ride claims and Exclusive reservations can never fail these tests. offer_rules_flow_test.dart does the same in 7 tests, including the cash 'Collect cash → Finish' completion path (line 484), as do reservation_near_pickup_test (5) and radar_offer_gone_test (3). These sites are separate from the already-reported account_flow_test.

**Suggested fix:** Replace the bare calls with `expect(tester.takeException(), isNull)`. Where an exception is truly expected, assert its type.

### L123. Regression guards assert findsNothing on keys no code builds ('radar-reserve-icon', 'home-reservation-barrier', 'radar-home-refresh', 'island-radar')

`test/widget/reservation_request_popup_test.dart:575` (found by r2-driver2)

**What happens:** Regression: change movera_radar_orb.dart:124 to `final tinted = exclusive || reserve;`. The reservation orb on Home then shows the white check icon (and the Exclusive spacing), and reservation_request_popup_test still passes. Verified by grep and by reading the code; no tests were run.

**Why:** Several assertions check that UI is absent by looking for a ValueKey that appears nowhere in lib/, so they pass whatever the widget tree contains. The clearest case: 'the normal Radar-offer orb ... no icon' checks `radar-reserve-icon` findsNothing. The orb's only icon carries the key `radar-exclusive-icon` and appears when `tinted` (`exclusive && !reserve`) is true. If an icon were added to the reservation orb, it would carry that key, and this assertion would not see it. The same holds for 'home-reservation-barrier' ('no map is dimmed', no Home code has such a key), 'radar-home-refresh' (radar_offer_gone_test.dart:173, the real refresh pill key is 'radar-refresh-new') and 'island-radar' (adaptive_trip_island_test.dart:291).

**Suggested fix:** Assert absence with the key the real widget would carry (e.g. `radar-exclusive-icon` scoped to the reservation orb, `radar-refresh-new`), or with a type/predicate finder (ModalBarrier, SvgPicture inside the orb).

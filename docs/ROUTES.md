# Driver route inventory

Refreshed against main `2b46a5711a9590da76b82d978f7103d045ad7f92` (F10d, pull request #90). Phase 46 is historical and is not the current gate. Canonical entry: MoveraApp → DriverHome. Legacy auth is opt-in via MOVERA_ENABLE_LEGACY_AUTH and disabled by default. Demo/local services remain labelled. Home and AcceptRide are split into `part` files of the same library; the public widgets are still `DriverHome` and `AcceptRide`.

| Screen | Source | Classification | Constructor references outside its source |
|---|---|---|---|
| AcceptRide | `lib/presentation/driver/accept ride/accept_ride.dart` | demo reachable | `lib/presentation/driver/ride requests/ride_requests.dart`, `lib/presentation/driver/home/home_offer_radar.dart`, `lib/presentation/driver/accept ride/accept_ride_trip.dart` |
| AcceptanceRate | `lib/presentation/driver/analytics/acceptance rate/acceptance_rate.dart` | demo reachable | `lib/presentation/driver/analytics/analytics.dart` |
| Accessibility | `lib/presentation/driver/settings/accessibility/accessibility.dart` | demo reachable | `lib/presentation/driver/settings/settings.dart` |
| AddNewAccount | `lib/presentation/driver/my bank/add new account/add_new_account.dart` | demo reachable | `lib/presentation/driver/my bank/my_bank.dart` |
| AddVehicle | `lib/presentation/driver/add vehicle/add_vehicle.dart` | demo reachable | `lib/presentation/driver/vehicles/vehicles.dart` |
| AdditionalInfoNavigation | `lib/presentation/driver/auth/additional detail/navigation.dart` | legacy gated | `lib/presentation/driver/auth/sign in/sign_in.dart` |
| Analytics | `lib/presentation/driver/analytics/analytics.dart` | demo reachable | `lib/presentation/driver/profile/profile.dart` |
| CancelationRate | `lib/presentation/driver/analytics/cancelation rate/cancelation_rate.dart` | demo reachable | `lib/presentation/driver/analytics/analytics.dart` |
| Chat | `lib/presentation/common/chat/chat.dart` | demo reachable | `lib/presentation/driver/accept ride/accept_ride_panel.dart` |
| DriverCreateAccount | `lib/presentation/driver/auth/create acc/create_acc.dart` | legacy gated | `lib/presentation/driver/auth/sign in/sign_in.dart` |
| DriverCreateAccountPhone | `lib/presentation/driver/auth/create acc/create_acc_phone.dart` | legacy gated | `lib/presentation/driver/auth/create acc/create_acc.dart` |
| DriverDestinationPicker | `lib/presentation/driver/destination mode/destination_picker.dart` | demo reachable | `lib/presentation/driver/home/home_map_sheet.dart` |
| DriverDocuments | `lib/presentation/driver/documents/documents.dart` | demo reachable | `lib/presentation/driver/profile/profile.dart`, `lib/presentation/driver/home/home.dart` |
| DriverHome | `lib/presentation/driver/home/home.dart` | demo reachable | `lib/main.dart`, `lib/presentation/driver/ride completed/ride_completed.dart` |
| DriverPhoneVerification | `lib/presentation/driver/auth/phone verification/phone_verify.dart` | legacy gated | `lib/presentation/driver/auth/create acc/create_acc_phone.dart` |
| DriverProfile | `lib/presentation/driver/profile/profile.dart` | demo reachable | `lib/core/driver/driver_profile.dart`, `lib/presentation/driver/side menu/side_menu.dart` |
| DriverRideCompleted | `lib/presentation/driver/ride completed/ride_completed.dart` | demo reachable | `lib/presentation/driver/accept ride/accept_ride_trip.dart` |
| DriverRideHistory | `lib/presentation/driver/ride history/ride_history.dart` | demo reachable | `lib/presentation/driver/home/home_map_sheet.dart`, `lib/presentation/driver/side menu/side_menu.dart` |
| DriverRideHistoryDetail | `lib/presentation/driver/ride history/history detail/history_detail.dart` | demo reachable | `lib/presentation/driver/ride history/ride_history.dart` |
| DriverSignIn | `lib/presentation/driver/auth/sign in/sign_in.dart` | legacy gated | (none; the demo landing screen was removed) |
| DriverSignInPhone | `lib/presentation/driver/auth/sign in phone/sign_in_phone.dart` | legacy gated | `lib/presentation/driver/auth/sign in/sign_in.dart` |
| DriverVehicles | `lib/presentation/driver/vehicles/vehicles.dart` | demo reachable | `lib/presentation/driver/profile/profile.dart` |
| DrivingLogs | `lib/presentation/driver/driving logs/driving_logs.dart` | demo reachable | `lib/presentation/driver/side menu/side_menu.dart` |
| EarningStatsScreen | `lib/presentation/driver/earning stats/earning_stats.dart` | demo reachable | `lib/presentation/driver/analytics/analytics.dart` |
| EmergencyContactsScreen | `lib/presentation/driver/settings/emergency_contacts.dart` | demo reachable | `lib/presentation/driver/settings/settings.dart` |
| LegalDocumentScreen | `lib/presentation/driver/profile/legal_document.dart` | demo reachable | `lib/presentation/driver/profile/profile.dart` |
| MyBank | `lib/presentation/driver/my bank/my_bank.dart` | demo reachable | `lib/presentation/driver/profile/profile.dart`, `lib/presentation/driver/my wallet/wallet.dart` |
| PinVerification | `lib/presentation/driver/pin verification/pin_verification.dart` | demo reachable | `lib/presentation/driver/settings/settings.dart` |
| Preferences | `lib/presentation/driver/preferences/preferences.dart` | demo reachable | `lib/presentation/driver/side menu/side_menu.dart` |
| ProgressWidget | `lib/presentation/driver/auth/additional detail/navigation.dart` | legacy gated | none |
| Promotions | `lib/presentation/driver/promotions/promotions.dart` | demo reachable | `lib/presentation/driver/side menu/side_menu.dart` |
| ScheduledRidesScreen | `lib/presentation/driver/scheduled rides/scheduled_rides.dart` | demo reachable | `lib/presentation/driver/home/home.dart`, `lib/presentation/driver/side menu/side_menu.dart` |
| SelectDocumentType | `lib/presentation/driver/auth/additional detail/screens/upload document/select document type/select_doc_typ.dart` | legacy gated | `lib/presentation/driver/auth/additional detail/navigation.dart` |
| SenderMessage | `lib/presentation/common/chat/chat.dart` | internal local-chat helper | used by `Chat._sendMessage()` |
| Settings | `lib/presentation/driver/settings/settings.dart` | demo reachable | `lib/presentation/driver/profile/profile.dart`, `lib/presentation/driver/side menu/side_menu.dart` |
| SoundAndVoice | `lib/presentation/driver/settings/sound & voice/sound_voice.dart` | demo reachable | `lib/presentation/driver/settings/settings.dart` |
| SupportInboxScreen | `lib/presentation/driver/support/support_inbox.dart` | demo reachable | `lib/presentation/driver/profile/profile.dart`, `lib/presentation/driver/side menu/side_menu.dart`, `lib/presentation/driver/home/components/driver_sheet_nav.dart` |
| TakeIdPhoto | `lib/presentation/driver/auth/additional detail/screens/upload document/take id photo/take_id_photo.dart` | legacy gated | `lib/presentation/driver/auth/additional detail/screens/upload document/select document type/select_doc_typ.dart` |
| VehicleDocuments | `lib/presentation/driver/add vehicle/add_vehicle.dart` | demo reachable | `lib/presentation/driver/vehicles/vehicles.dart` |
| WalletScreen | `lib/presentation/driver/my wallet/wallet.dart` | demo reachable | `lib/presentation/driver/side menu/side_menu.dart`, `lib/presentation/driver/home/components/driver_sheet_nav.dart` |

## Canonical tasks
- Active trips: Home → AcceptRide → DriverRideCompleted → Home or queued AcceptRide.
- History: RideHistory → detail, with illustrative route map.
- Documents: DriverDocuments → UploadGuideScreen per document (group 2, owner item 4; the demo uploads nothing) or InfoSessionScreen ("How to book"); live: LiveDocumentsScreen → the same. DocumentPreview was removed with the demo expiry code (contract v0.17.0).
- Support: SupportInboxScreen → local conversation draft.
- Reservations: ScheduledRidesScreen → nonbinding preview detail.
- Logout: back to Home in demo mode (the demo landing screen was removed); legacy sign-in is disabled by default.

Phase 45 removed the unreferenced legacy Splash, UploadVehiclePhotos screen, stale `accept ride/components/cancel_ride.dart` helper and unused ReceiverMessage widget. LegalDocumentScreen remains reachable from Profile. F11 (pull request #81, merge `ca9c0089c532c3280d261c4ed13909145636cff7`) removed the unreachable withdrawal screens `choose_bank.dart` and `withdraw_sucess.dart`. `OnboardingScreen`, `recent_rides.dart`, and the analytics `insights.dart` / `earnings.dart` component files are not in the tree at this SHA; this note does not invent an earlier deletion commit for them. Constructor calls that moved with the F10 split are cited on the part file that contains the call: offer acceptance in `home_offer_radar.dart`, destination and history entry in `home_map_sheet.dart`, queued completion in `accept_ride_trip.dart`, and `Chat(riderDisplayName: widget.riderName)` in `accept_ride_panel.dart`. Remaining orphan candidates are not deleted without new reachability proof. This inventory does not by itself certify runtime navigation behavior.

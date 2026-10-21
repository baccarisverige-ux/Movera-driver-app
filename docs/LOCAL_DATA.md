# Local data

SharedPreferences is recoverable demo state. On the web it is stored in
localStorage with a `flutter.` prefix. It is not secure storage and it is not
a server.

Logout calls `clearLocalUserData` and returns the driver offline. That removes:

- active-trip recovery and terminal markers
- completion journal
- trip history
- Ride checks shown in the trip details (time, trigger, answers)
- support drafts
- settings, including trusted-contact phone numbers and vehicle drafts

Logout also clears the in-memory notification feed (with its read state) and
the document-renewal state, so the next driver on this phone starts from the
demo lists.

Active-trip recovery still works until logout. A corrupt value is treated as
missing by the readers and is deleted by the same clear. Keys that are not in
`localDataInventory` are not removed.

Production storage should move to a server or a platform secure store in a
later product change. That work is outside this frontend pass.

/// G4 decision 2: what the phone's own sound is like right now.
enum PhoneSound {
  /// Sound can play.
  on,

  /// Silent, very low, or (web) not allowed yet: offers may go unheard.
  off,

  /// This device cannot tell (no notice is shown then).
  unknown,
}

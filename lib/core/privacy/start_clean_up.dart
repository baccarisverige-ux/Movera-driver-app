import 'dart:async';

/// Owner 2026-11-19 (N1): the start clean-up (the local data made the kept
/// session's driver's, `main.dart` `_claimKeptSession`) gets
/// [StartCleanUp.limit]; longer, the gate shows Sign in without reading
/// the session, and the next sign-in clears everything first, so the other
/// driver's data is never used.
class StartCleanUp {
  StartCleanUp(Future<void> run) {
    run.whenComplete(() => _finished = true).ignore();
  }

  /// How long the start waits for the clean-up before Sign in shows.
  static const limit = Duration(seconds: 10);

  bool _finished = false;
  bool _abandoned = false;

  /// The start clean-up ran to its end.
  bool get finished => _finished;

  /// A sign-in came before the start clean-up ended: whatever it still
  /// does must not touch the new driver's data.
  bool get abandoned => _abandoned;

  /// Throws once the clean-up is abandoned; the start clean-up checks it
  /// before and after it clears, so a late one never claims the data.
  void check() {
    if (_abandoned) throw const StartCleanUpAbandoned();
  }

  /// Before a sign-in claims the local data: a start clean-up that has not
  /// ended is abandoned and [clear] runs now, in full.
  Future<void> beforeSignIn(Future<void> Function() clear) async {
    if (_finished) return;
    _abandoned = true;
    await clear();
  }
}

/// A start clean-up overtaken by a sign-in ([StartCleanUp.beforeSignIn]).
class StartCleanUpAbandoned implements Exception {
  const StartCleanUpAbandoned();
}

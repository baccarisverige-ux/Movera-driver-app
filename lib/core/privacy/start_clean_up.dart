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

/// The start clean-up of `main.dart` (`_claimKeptSession`), testable on its
/// own. [claim] makes the local data the kept [readAccess] session's
/// driver's: it runs the clear it is given when another driver is
/// recorded and must call the guard right before it records the owner.
/// [clear] gets the guard too and calls it before each destructive step,
/// so a clean-up that resumes after a sign-in overtook it
/// ([StartCleanUp.beforeSignIn]) stops before it deletes or records
/// anything of the new driver. A clean-up that fails ends the session
/// ([endSession], tokens first, then [signedOut]); an abandoned one never
/// does: the new driver's tokens stay.
Future<void> claimKeptSession({
  required StartCleanUp Function() cleanUp,
  required Future<String?> Function() readAccess,
  required Future<void> Function(
    String? session,
    Future<void> Function() clear,
    void Function() guard,
  )
  claim,
  required Future<void> Function(void Function() guard) clear,
  required Future<void> Function(String? session) endSession,
  required void Function() signedOut,
}) async {
  String? session;
  void guard() => cleanUp().check();
  try {
    session = await readAccess();
    await claim(session, () async {
      guard();
      await clear(guard);
      guard();
    }, guard);
  } on StartCleanUpAbandoned {
    // The sign-in cleared everything itself; its tokens stay.
  } catch (_) {
    if (cleanUp().abandoned) return;
    try {
      await endSession(session);
    } catch (_) {
      // A token store that cannot be read or cleared: nothing more.
    }
    signedOut();
  }
}

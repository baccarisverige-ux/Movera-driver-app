/// Invalidates repository instances owned by a departing local session.
class LocalWriteSession {
  LocalWriteSession._();
  static int _generation = 0;
  static bool _clearing = false;
  static int get generation => _generation;

  /// Logout is clearing the local data right now.
  static bool get clearing => _clearing;
  static void check(int generation) {
    if (_clearing || generation != _generation) {
      throw StateError('Local session ended; reopen the screen before saving');
    }
  }

  static int? _before;

  static void beginCleanup() {
    if (_clearing) throw StateError('Local cleanup already in progress');
    _clearing = true;
    _before = _generation;
    _generation++;
  }

  /// The cleanup failed and the driver stays signed in: the repositories
  /// of this session keep working (driver-34), instead of every save
  /// failing until the app restarts.
  static void cancelCleanup() {
    final before = _before;
    if (_clearing && before != null) _generation = before;
  }

  static void endCleanup() {
    _clearing = false;
    _before = null;
  }
}

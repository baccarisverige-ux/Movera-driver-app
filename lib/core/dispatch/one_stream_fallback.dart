/// L20 stream backup (contract v0.18.150, contract.json#driverOneStreamFallback;
/// owner 2026-11-21 "Switch to old two (Rec.)": "when first down we can use
/// second as backup"): `DriverAppConfig.realtime.oneStreamFallback`. After
/// [failuresInARow] failed tries of `GET /driver/stream` in a row the offer
/// feed opens the two old streams, and asks the one stream again after
/// [retryOneAfterMinutes] (or at app restart).
class OneStreamFallback {
  const OneStreamFallback({
    this.failuresInARow = defaultFailuresInARow,
    this.retryOneAfterMinutes = defaultRetryOneAfterMinutes,
  });

  /// `configDefaults.driverOneStreamFallback` (3 and 10).
  static const defaultFailuresInARow = 3;
  static const defaultRetryOneAfterMinutes = 10;

  /// The served object; a missing, non-whole or out-of-range value (1-10,
  /// 1-60) takes its default, as the server serves it.
  factory OneStreamFallback.fromJson(Object? json) {
    final map = json is Map ? json : const {};
    int whole(Object? value, int max, int fallback) =>
        value is int && value >= 1 && value <= max ? value : fallback;
    return OneStreamFallback(
      failuresInARow: whole(map['failuresInARow'], 10, defaultFailuresInARow),
      retryOneAfterMinutes: whole(
        map['retryOneAfterMinutes'],
        60,
        defaultRetryOneAfterMinutes,
      ),
    );
  }

  final int failuresInARow;
  final int retryOneAfterMinutes;

  Duration get retryOneAfter => Duration(minutes: retryOneAfterMinutes);

  @override
  bool operator ==(Object other) =>
      other is OneStreamFallback &&
      other.failuresInARow == failuresInARow &&
      other.retryOneAfterMinutes == retryOneAfterMinutes;

  @override
  int get hashCode => Object.hash(failuresInARow, retryOneAfterMinutes);
}

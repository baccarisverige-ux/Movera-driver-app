/// Records Ride check audio to a file on this phone. Never uploads.
abstract class RideCheckRecorder {
  bool get supported;

  /// Asks for the microphone if needed; false when refused.
  Future<bool> requestPermission();
  Future<void> start(String recordingId);

  /// The saved file, or null when nothing was captured.
  Future<String?> stop();
  Future<void> cancel();
}

RideCheckRecorder createRideCheckRecorder() =>
    const UnsupportedRideCheckRecorder();

class UnsupportedRideCheckRecorder implements RideCheckRecorder {
  const UnsupportedRideCheckRecorder();

  @override
  bool get supported => false;
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<void> start(String recordingId) async =>
      throw UnsupportedError('Audio recording is not available here.');
  @override
  Future<String?> stop() async => null;
  @override
  Future<void> cancel() async {}
}

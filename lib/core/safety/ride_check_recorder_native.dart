import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'ride_check_recorder_stub.dart';

export 'ride_check_recorder_stub.dart'
    show RideCheckRecorder, UnsupportedRideCheckRecorder;

RideCheckRecorder createRideCheckRecorder() => NativeRideCheckRecorder();

/// Saves to the app's own documents folder on this phone. Nothing here
/// sends the file anywhere.
class NativeRideCheckRecorder implements RideCheckRecorder {
  AudioRecorder? _recorder;

  // Created on first use: the plugin is never touched unless the driver
  // taps Record audio.
  AudioRecorder get _audio => _recorder ??= AudioRecorder();

  @override
  bool get supported => Platform.isAndroid || Platform.isIOS;

  // hasPermission asks for the microphone if needed.
  @override
  Future<bool> requestPermission() => _audio.hasPermission();

  @override
  Future<void> start(String recordingId) async {
    final directory = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/ride_check_audio',
    );
    await directory.create(recursive: true);
    await _audio.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: '${directory.path}/$recordingId.m4a',
    );
  }

  @override
  Future<String?> stop() async {
    final recorder = _recorder;
    if (recorder == null) return null;
    final path = await recorder.stop();
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists() || await file.length() == 0) return null;
    return path;
  }

  @override
  Future<void> cancel() async {
    await _recorder?.cancel();
  }
}

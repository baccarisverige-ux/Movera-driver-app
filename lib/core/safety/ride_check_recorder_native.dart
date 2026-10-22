import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'ride_check_recorder_stub.dart';

export 'ride_check_recorder_stub.dart'
    show RideCheckRecorder, UnsupportedRideCheckRecorder;

RideCheckRecorder createRideCheckRecorder() => NativeRideCheckRecorder();

/// driver-29: the app's support folder, not Documents (which iOS backs
/// up to iCloud and Finder); iOS also marks the folder excluded from
/// backups, so a recording stays on this phone as the driver was told.
@visibleForTesting
Future<Directory> Function() rideCheckStorageRoot =
    getApplicationSupportDirectory;

const MethodChannel _backup = MethodChannel('movera/backup');

/// The folder Ride check recordings are saved in, created if needed.
Future<Directory> rideCheckAudioDirectory() async {
  final directory = Directory(
    '${(await rideCheckStorageRoot()).path}/ride_check_audio',
  );
  await directory.create(recursive: true);
  if (Platform.isIOS) {
    await _backup.invokeMethod<void>('excludeFromBackup', {
      'path': directory.path,
    });
  }
  return directory;
}

/// Saves to the app's own support folder on this phone, outside backups.
/// Nothing here sends the file anywhere.
class NativeRideCheckRecorder implements RideCheckRecorder {
  NativeRideCheckRecorder({AudioRecorder Function()? createAudio})
    : _createAudio = createAudio ?? AudioRecorder.new;

  final AudioRecorder Function() _createAudio;
  AudioRecorder? _recorder;

  // Created on first use: the plugin is never touched unless the driver
  // taps Record audio.
  AudioRecorder get _audio => _recorder ??= _createAudio();

  @override
  bool get supported => Platform.isAndroid || Platform.isIOS;

  // hasPermission asks for the microphone if needed.
  @override
  Future<bool> requestPermission() async {
    final audio = _audio;
    final granted = await audio.hasPermission();
    if (!granted) await _release(audio);
    return granted;
  }

  @override
  Future<void> start(String recordingId) async {
    final directory = await rideCheckAudioDirectory();
    await _audio.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: '${directory.path}/$recordingId.m4a',
    );
  }

  @override
  Future<String?> stop() async {
    final recorder = _recorder;
    if (recorder == null) return null;
    final String? path;
    try {
      path = await recorder.stop();
    } finally {
      await _release(recorder);
    }
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    if (await file.length() == 0) {
      // driver-30: nothing was captured; no empty file is left behind.
      try {
        await file.delete();
      } on FileSystemException {
        // Already gone.
      }
      return null;
    }
    return path;
  }

  @override
  Future<void> cancel() async {
    final recorder = _recorder;
    if (recorder == null) return;
    try {
      await recorder.cancel();
    } finally {
      await _release(recorder);
    }
  }

  /// driver-30: each recording gets its own native recorder, released
  /// once it is stopped or cancelled; the next Record makes a new one.
  Future<void> _release(AudioRecorder recorder) async {
    if (identical(_recorder, recorder)) _recorder = null;
    try {
      await recorder.dispose();
    } catch (_) {
      // Released anyway.
    }
  }
}

// Web and tests without dart:io get the stub; phones get the native one.
export 'ride_check_recorder_stub.dart'
    if (dart.library.io) 'ride_check_recorder_native.dart';

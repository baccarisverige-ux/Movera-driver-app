/// Owner decisions of 2026-10-29, driver group 2 items 5 and 6: how a
/// document photo goes up. The photo is shrunk before it is sent, the app
/// waits up to 60 s for the server, and a failed upload keeps the photo
/// with "Try again". A camera the driver blocked says so, with "Open
/// Settings" and "Choose file".
library;

import 'package:flutter/services.dart';

abstract final class DocumentUploadPolicy {
  /// "Wait up to 60 s".
  static const Duration timeout = Duration(seconds: 60);

  /// "Shrink photo": the long side, in pixels, and the JPEG quality the
  /// camera and the photo library hand over.
  static const double photoMaxSide = 1600;
  static const int photoQuality = 75;
}

/// The camera or the photo library was refused (image_picker's
/// `camera_access_denied` / `photo_access_denied`, or the browser's
/// `NotAllowedError`).
bool isCameraBlocked(Object error) {
  if (error is PlatformException) {
    final code = error.code.toLowerCase();
    return code.contains('access_denied') ||
        code.contains('permission') ||
        code.contains('notallowed');
  }
  final text = error.toString().toLowerCase();
  return text.contains('notallowederror') || text.contains('permission denied');
}

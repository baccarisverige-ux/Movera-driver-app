import 'dart:io';

/// The real operating system is iOS or Android (not defaultTargetPlatform,
/// which tests set to Android with no Keychain plugin).
bool get isMobileOs => Platform.isIOS || Platform.isAndroid;

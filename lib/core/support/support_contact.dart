import 'package:url_launcher/url_launcher.dart';

/// Opens an external link; resolves with whether it opened.
typedef SupportUriLauncher = Future<bool> Function(Uri uri);

/// Owner 2026-10-29, decision 2: "Contact support" where the driver cannot
/// reach the app's own support inbox (the start screen failed). The
/// address comes from the build (`--dart-define=MOVERA_SUPPORT_EMAIL=...`),
/// as in the rider app; without one nothing is invented and the caller
/// says so.
class SupportContact {
  const SupportContact({
    this.email = const String.fromEnvironment('MOVERA_SUPPORT_EMAIL'),
    SupportUriLauncher? launcher,
  }) : _launcher = launcher;

  final String email;
  final SupportUriLauncher? _launcher;

  bool get available => email.trim().contains('@');

  Uri mailto({String? subject}) => Uri(
    scheme: 'mailto',
    path: email.trim(),
    query: subject == null || subject.trim().isEmpty
        ? null
        : 'subject=${Uri.encodeComponent(subject.trim())}',
  );

  /// False when no address is set or no mail app could be opened.
  Future<bool> openEmail({String? subject}) async {
    if (!available) return false;
    try {
      return await (_launcher ?? _launch)(mailto(subject: subject));
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _launch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}

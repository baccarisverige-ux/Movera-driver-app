import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/auth/otp_challenge.dart';
import 'package:movera/core/destination/destination_search.dart';
import 'package:movera/presentation/driver/account/account_style.dart';
import 'package:movera/presentation/driver/signup/signup_checklist_screen.dart';
import 'package:movera/presentation/driver/signup/signup_common.dart';
import 'package:movera/presentation/driver/signup/signup_info_screen.dart';

/// Contract v0.18.166 (`signupV2`): where a driver who has not sent his
/// registration lands after the SMS code (and on every opening until the
/// server took it): "Vos informations" first, the checklist once that step
/// is done ("Continuer plus tard" keeps it).
class SignupEntry extends StatefulWidget {
  const SignupEntry({
    super.key,
    required this.account,
    required this.phone,
    required this.onHome,
    this.flow,
    this.prefill,
  });

  final DriverAccountSession account;
  final String? phone;
  final void Function(BuildContext context) onHome;

  /// Tests hand in a prepared flow.
  final SignupFlow? flow;

  /// What Apple / Google gave at sign-in.
  final ProviderLink? prefill;

  @override
  State<SignupEntry> createState() => _SignupEntryState();
}

class _SignupEntryState extends State<SignupEntry> {
  late final SignupFlow _flow =
      widget.flow ??
      SignupFlow(
        account: widget.account,
        phone: widget.phone,
        onHome: widget.onHome,
        places: ApiDestinationSearch(api: widget.account.repository.api),
        deviceCountry: deviceCountryIfAllowed,
        prefill: widget.prefill,
      );
  bool? _checklist;

  @override
  void initState() {
    super.initState();
    _flow.restore().then((_) {
      if (!mounted) return;
      final needsCountry = widget.account.account?.needsCountry ?? true;
      setState(() => _checklist = !needsCountry && _flow.data.detailsDone);
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (_checklist) {
      null => const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: AccountStyle.ink)),
      ),
      true => SignupChecklistScreen(flow: _flow),
      false => SignupInfoScreen(flow: _flow),
    };
  }
}

/// Contract v0.18.166 (`signupV2.infoScreen.countryFromPhone`): the device's
/// country only when the location permission is ALREADY granted; never asks.
Future<String?> deviceCountryIfAllowed() async {
  try {
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      return null;
    }
    final at = await Geolocator.getLastKnownPosition();
    if (at == null) return null;
    return countryOfPoint(at.latitude, at.longitude);
  } catch (_) {
    return null;
  }
}

/// A rough box per open country (Sweden, mainland France).
String? countryOfPoint(double lat, double lng) {
  if (lat >= 55 && lat <= 69.1 && lng >= 10.9 && lng <= 24.2) return 'SE';
  if (lat >= 41.3 && lat <= 51.2 && lng >= -5.2 && lng <= 9.6) return 'FR';
  return null;
}

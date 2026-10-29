import 'package:flutter/material.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_rules.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/onboarding/onboarding_settings.dart';
import 'package:movera/presentation/driver/account/account_style.dart';
import 'package:movera/presentation/driver/documents/document_file_picker.dart';
import 'package:movera/presentation/driver/documents/live_documents_screen.dart';
import 'package:movera/presentation/driver/documents/upload_guide_screen.dart';
import 'package:movera/widgets/navigation_transition.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:movera/widgets/single_route_entry.dart';

/// Contract v0.17.0 (owner item 11): right after a car is added, the four
/// photos the admin asks (front and back with the plate, side, inside),
/// each with its upload guide. The car cannot be picked or driven before
/// Movera approves them; they can also be sent later from Documents.
class CarPhotosScreen extends StatefulWidget {
  const CarPhotosScreen({
    super.key,
    required this.account,
    required this.vehicle,
    required this.photoTypes,
    this.filePicker = const DeviceDocumentFilePicker(),
  });

  final DriverAccountSession account;
  final FleetVehicle vehicle;
  final List<String> photoTypes;
  final DocumentFilePicker filePicker;

  @override
  State<CarPhotosScreen> createState() => _CarPhotosScreenState();
}

class _CarPhotosScreenState extends State<CarPhotosScreen> {
  final Map<String, String> _status = {};

  Future<void> _open(String type) async {
    final result = await pushSingle<Object?>(
      context,
      RightToLeftTransition(
        UploadGuideScreen(
          account: widget.account,
          type: type,
          ownerId: widget.vehicle.vehicleId,
          isCar: true,
          country:
              widget.account.account?.country ??
              DriverAccountRules.current.country,
          status: _status[type] ?? 'needed',
          filePicker: widget.filePicker,
        ),
      ),
    );
    if (!mounted || result is! AccountDocument) return;
    setState(() => _status[type] = result.status);
  }

  @override
  Widget build(BuildContext context) {
    final car = widget.vehicle.plate.isEmpty
        ? widget.vehicle.title
        : widget.vehicle.plate;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AccountStyle.appBar(
        context,
        tr.carPhotosTitle,
        onBack: () => maybePopOwned(context),
      ),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('car-photos'),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(tr.carPhotosIntro(car), style: AccountStyle.body()),
            const SizedBox(height: 12),
            for (final type in widget.photoTypes)
              DocumentRow(
                key: ValueKey('car-photo-$type'),
                title: OnboardingSettingsStore.instance.nameOf(
                  type,
                  tr.localeName,
                ),
                status: _status[type] ?? 'needed',
                onTap: () => _open(type),
              ),
            const SizedBox(height: 22),
            AccountButton(
              key: const ValueKey('car-photos-done'),
              label: tr.carPhotosDone,
              onPressed: () => maybePopOwned(context),
            ),
          ],
        ),
      ),
    );
  }
}

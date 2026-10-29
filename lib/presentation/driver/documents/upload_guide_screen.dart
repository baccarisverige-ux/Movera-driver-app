import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:movera/core/account/account_error_message.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/contracts/driver_onboarding_rules.dart';
import 'package:movera/core/contracts/status_words.g.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/onboarding/document_upload.dart';
import 'package:movera/core/onboarding/onboarding_settings.dart';
import 'package:movera/core/onboarding/upload_guide.dart';
import 'package:movera/presentation/driver/account/account_style.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_style.dart';
import 'package:movera/presentation/driver/documents/document_file_picker.dart';
import 'package:movera/presentation/driver/documents/guide_example_drawing.dart';
import 'package:movera/widgets/movera_modal_sheet.dart';
import 'package:movera/widgets/owned_route_exit.dart';

/// Owner decisions of 2026-10-29, driver group 2 items 4, 5 and 6: the
/// upload guide of one document in the driver's country, from the
/// published settings (the admin's own types and texts included): a
/// Movera-drawn example, what must be visible, "Tips for a good photo"
/// (open / close) and one Upload button (Take photo / Photo library /
/// Choose file). A blocked camera says so with "Open Settings" and
/// "Choose file"; a slow upload is waited for up to 60 s and a failed one
/// keeps the photo with "Try again". Pops with the uploaded document.
class UploadGuideScreen extends StatefulWidget {
  const UploadGuideScreen({
    super.key,
    this.account,
    required this.type,
    required this.ownerId,
    required this.isCar,
    required this.country,
    this.status,
    this.expiresAt,
    this.filePicker = const DeviceDocumentFilePicker(),
    this.openSettings = Geolocator.openAppSettings,
  });

  /// Null in the demo: the guide shows, nothing goes up.
  final DriverAccountSession? account;
  final String type;

  /// The driverId, or the car's vehicleId.
  final String ownerId;
  final bool isCar;

  /// `SE`, `FR`: the guide's country.
  final String country;

  /// The shown status now (`needed`, `rejected`, `expiring`, …).
  final String? status;
  final DateTime? expiresAt;
  final DocumentFilePicker filePicker;

  /// The phone's settings page for Movera (camera access).
  final Future<bool> Function() openSettings;

  @override
  State<UploadGuideScreen> createState() => _UploadGuideScreenState();
}

class _UploadGuideScreenState extends State<UploadGuideScreen> {
  PickedDocumentFile? _picked;
  bool _uploading = false;
  bool _cameraBlocked = false;
  String? _error;

  /// The last upload failed; the photo is still here.
  bool _kept = false;

  UploadGuide get _guide => UploadGuides.forType(
    widget.type,
    country: widget.country,
    settings: OnboardingSettingsStore.instance.settings,
  );

  Future<void> _chooseHow() async {
    if (widget.account == null) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(tr.docPreviewNotAvailable)));
      return;
    }
    final choice = await showMoveraModalSheet<String>(
      context: context,
      fitContent: true,
      builder: (sheet) => Material(
        color: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Text(tr.docChooseHow, style: AccountStyle.rowTitle()),
                ),
                for (final (id, icon, label) in [
                  (
                    'camera',
                    Icons.photo_camera_outlined,
                    tr.guidePickTakePhoto,
                  ),
                  (
                    'gallery',
                    Icons.photo_library_outlined,
                    tr.guidePickLibrary,
                  ),
                  ('file', Icons.insert_drive_file_outlined, tr.guidePickFile),
                ])
                  ListTile(
                    key: ValueKey('doc-pick-$id'),
                    leading: Icon(icon, color: AccountStyle.ink),
                    title: Text(label, style: AccountStyle.body()),
                    onTap: () => Navigator.of(sheet).pop(id),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    await _pick(choice);
  }

  Future<void> _pick(String how) async {
    PickedDocumentFile? picked;
    try {
      picked = switch (how) {
        'camera' => await widget.filePicker.takePhoto(),
        'gallery' => await widget.filePicker.choosePhoto(),
        _ => await widget.filePicker.chooseFile(),
      };
    } catch (error) {
      if (!mounted) return;
      // Owner item 5: a refused camera says so, with Settings and a file.
      if (isCameraBlocked(error)) setState(() => _cameraBlocked = true);
      return;
    }
    if (picked == null || !mounted) return;
    if (picked.bytes.length > DriverOnboardingRules.uploadMaxBytes) {
      setState(() => _error = tr.docFileTooLarge);
      return;
    }
    if (!DriverOnboardingRules.uploadMediaTypes.contains(picked.mediaType)) {
      setState(() => _error = tr.docUnsupportedFile);
      return;
    }
    setState(() {
      _picked = picked;
      _cameraBlocked = false;
    });
    await _send();
  }

  Future<void> _send() async {
    final picked = _picked;
    final account = widget.account;
    if (picked == null || account == null || _uploading) return;
    setState(() {
      _uploading = true;
      _error = null;
      _kept = false;
    });
    try {
      final doc = await account.repository.uploadDocument(
        type: widget.type,
        bytes: picked.bytes,
        fileName: picked.fileName,
        mediaType: picked.mediaType,
        ownerId: widget.isCar ? widget.ownerId : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(tr.docUploaded)));
      popOwned<AccountDocument>(context, doc);
    } catch (error) {
      if (!mounted) return;
      // Owner item 6: the photo stays; "Try again" sends it again.
      setState(() {
        _kept = true;
        _error = accountErrorMessage(error, fallback: tr.docUploadFailed);
      });
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final guide = _guide;
    final status = widget.status;
    final statusLabel = status == null
        ? null
        : statusWord(tr, 'documentStatus', status);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AccountStyle.appBar(
        context,
        guide.title,
        onBack: _uploading ? null : () => maybePopOwned(context),
      ),
      body: SafeArea(
        // Not lazy: the Upload button is always built (short page).
        child: SingleChildScrollView(
          key: const ValueKey('upload-guide'),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GuideExampleDrawing(
                example: guide.example,
                label: tr.guideExampleLabel,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  tr.guideExampleLabel,
                  textAlign: TextAlign.center,
                  style: AccountStyle.hint(),
                ),
              ),
              if (statusLabel != null || widget.expiresAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    [
                      if (statusLabel != null)
                        tr.guideCurrentStatus(statusLabel),
                      if (widget.expiresAt case final at?)
                        tr.guideExpiresOn(
                          DriverDates.dayMonthYear(at.toLocal()),
                        ),
                    ].join(' · '),
                    key: const ValueKey('guide-status'),
                    style: AccountStyle.body(),
                  ),
                ),
              const SizedBox(height: 18),
              Text(
                tr.guideMustBeVisible.toUpperCase(),
                style: AccountStyle.section(),
              ),
              const SizedBox(height: 8),
              for (final (i, line) in guide.checklist.indexed)
                Padding(
                  key: ValueKey('guide-check-$i'),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 20,
                        color: AccountStyle.green,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(line, style: AccountStyle.body())),
                    ],
                  ),
                ),
              if (guide.expires)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    tr.guideExpiryNote(guide.warnDays),
                    style: AccountStyle.hint(),
                  ),
                ),
              const SizedBox(height: 10),
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: const ValueKey('guide-tips'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  iconColor: AccountStyle.ink,
                  collapsedIconColor: AccountStyle.ink,
                  title: Text(
                    tr.guideTipsTitle,
                    style: AccountStyle.rowTitle(),
                  ),
                  children: [
                    for (final tip in guide.tips)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 7),
                              child: Icon(
                                Icons.circle,
                                size: 6,
                                color: AccountStyle.muted,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(tip, style: AccountStyle.body()),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (_cameraBlocked) ...[
                const SizedBox(height: 8),
                _CameraBlockedCard(
                  onSettings: () => widget.openSettings(),
                  onChooseFile: _uploading ? null : () => _pick('file'),
                ),
              ],
              if (_picked case final picked?) ...[
                const SizedBox(height: 12),
                _PickedPreview(file: picked),
              ],
              if (_uploading) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(
                  key: ValueKey('doc-progress'),
                  color: AccountStyle.ink,
                  minHeight: 3,
                ),
                const SizedBox(height: 6),
                Text(tr.guideUploadingSlow, style: AccountStyle.hint()),
              ],
              if (_kept)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    tr.guideKeptPhoto,
                    key: const ValueKey('guide-kept'),
                    style: AccountStyle.body(),
                  ),
                ),
              if (_error != null) AccountErrorLine(_error!),
              const SizedBox(height: 18),
              if (_kept) ...[
                AccountButton(
                  key: const ValueKey('guide-try-again'),
                  label: tr.guideTryAgain,
                  busy: _uploading,
                  onPressed: _send,
                ),
                const SizedBox(height: 10),
                AccountButton(
                  key: const ValueKey('guide-choose-another'),
                  label: tr.guideChooseAnother,
                  outlined: true,
                  onPressed: _uploading ? null : _chooseHow,
                ),
              ] else
                AccountButton(
                  key: const ValueKey('guide-upload'),
                  label: tr.guideUpload,
                  busy: _uploading,
                  onPressed: _uploading ? null : _chooseHow,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraBlockedCard extends StatelessWidget {
  const _CameraBlockedCard({
    required this.onSettings,
    required this.onChooseFile,
  });

  final VoidCallback onSettings;
  final VoidCallback? onChooseFile;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('guide-camera-blocked'),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4E5),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFF0D2A6)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr.guideCameraBlockedTitle, style: AccountStyle.rowTitle()),
        const SizedBox(height: 4),
        Text(tr.guideCameraBlockedBody, style: AccountStyle.body()),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AccountButton(
                key: const ValueKey('guide-open-settings'),
                label: tr.guideOpenSettings,
                onPressed: onSettings,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AccountButton(
                key: const ValueKey('guide-choose-file'),
                label: tr.guidePickFile,
                outlined: true,
                onPressed: onChooseFile,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// The chosen photo (or file name), kept while it goes up and after a
/// failed try.
class _PickedPreview extends StatelessWidget {
  const _PickedPreview({required this.file});

  final PickedDocumentFile file;

  @override
  Widget build(BuildContext context) {
    final image =
        file.mediaType == 'image/jpeg' || file.mediaType == 'image/png';
    return Container(
      key: const ValueKey('guide-picked'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AccountStyle.field,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AccountStyle.line),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56,
              height: 56,
              child: image
                  ? Image.memory(
                      file.bytes,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.image_outlined,
                        color: AccountStyle.muted,
                      ),
                    )
                  : const Icon(
                      Icons.insert_drive_file_outlined,
                      color: AccountStyle.muted,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tr.guideSelectedFile(file.fileName),
              style: AuthText.urbanist(size: 14, weight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

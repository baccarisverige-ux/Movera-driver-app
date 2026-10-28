import 'package:flutter/material.dart';
import 'package:movera/core/account/account_error_message.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/contracts/driver_onboarding_rules.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/driver/account/account_style.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_style.dart';
import 'package:movera/presentation/driver/documents/document_file_picker.dart';
import 'package:movera/widgets/movera_modal_sheet.dart';
import 'package:movera/widgets/owned_route_exit.dart';

/// Documents, live (contract v0.5.3 §14): the person's required documents
/// ("You"), the company's for a fleet account ("Company") and each car's
/// ("Car PLATE"), from the lists the server sends. A file document is
/// uploaded from the camera, the photo library or a PDF; the terms are
/// approved at sign-up; the information session is booked by Movera.
class LiveDocumentsScreen extends StatefulWidget {
  const LiveDocumentsScreen({
    super.key,
    required this.account,
    this.filePicker = const DeviceDocumentFilePicker(),
  });

  final DriverAccountSession account;
  final DocumentFilePicker filePicker;

  @override
  State<LiveDocumentsScreen> createState() => _LiveDocumentsScreenState();
}

class _LiveDocumentsScreenState extends State<LiveDocumentsScreen> {
  List<AccountDocument> _docs = const [];
  List<FleetVehicle> _cars = const [];
  bool _loading = true;
  String? _error;

  /// `ownerId/type` of the upload in flight.
  String? _uploading;
  String? _uploadError;

  @override
  void initState() {
    super.initState();
    widget.account.addListener(_changed);
    _load();
  }

  @override
  void dispose() {
    widget.account.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final repository = widget.account.repository;
    try {
      final results = await Future.wait([
        repository.documents(),
        repository.vehicles().catchError((Object _) => <FleetVehicle>[]),
        if (widget.account.account == null)
          widget.account.refresh()
        else
          widget.account.refresh().catchError(
            (Object _) => widget.account.account!,
          ),
      ]);
      if (!mounted) return;
      setState(() {
        _docs = results[0] as List<AccountDocument>;
        _cars = results[1] as List<FleetVehicle>;
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = accountErrorMessage(error, fallback: tr.docCouldNotLoad),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  AccountDocument? _doc(String ownerId, String type) {
    for (final doc in _docs) {
      if (doc.ownerId == ownerId && doc.type == type) return doc;
    }
    return null;
  }

  /// The status to show: the uploaded document's, else the summary the
  /// server put on the owner, else missing.
  String _status(String ownerId, String type, List<DocumentSummary> summary) {
    final doc = _doc(ownerId, type);
    if (doc != null) return doc.status;
    for (final item in summary) {
      if (item.type == type) return item.status;
    }
    return 'missing';
  }

  Future<void> _upload(String ownerId, String type, bool isCar) async {
    final picked = await _pickFile();
    if (picked == null || !mounted) return;
    if (picked.bytes.length > DriverOnboardingRules.uploadMaxBytes) {
      setState(() => _uploadError = tr.docFileTooLarge);
      return;
    }
    if (!DriverOnboardingRules.uploadMediaTypes.contains(picked.mediaType)) {
      setState(() => _uploadError = tr.docUnsupportedFile);
      return;
    }
    setState(() {
      _uploading = '$ownerId/$type';
      _uploadError = null;
    });
    try {
      final doc = await widget.account.repository.uploadDocument(
        type: type,
        bytes: picked.bytes,
        fileName: picked.fileName,
        mediaType: picked.mediaType,
        ownerId: isCar ? ownerId : null,
      );
      if (!mounted) return;
      setState(() {
        _docs = [
          for (final d in _docs)
            if (!(d.ownerId == doc.ownerId && d.type == doc.type)) d,
          doc,
        ];
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr.docUploaded)));
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _uploadError = accountErrorMessage(
          error,
          fallback: tr.docUploadFailed,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  /// "Take photo / Choose photo / Choose PDF".
  Future<PickedDocumentFile?> _pickFile() async {
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
                  ('camera', Icons.photo_camera_outlined, tr.docTakePhoto),
                  ('gallery', Icons.photo_library_outlined, tr.docChoosePhoto),
                  ('pdf', Icons.picture_as_pdf_outlined, tr.docChoosePdf),
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
    if (choice == null) return null;
    try {
      return switch (choice) {
        'camera' => await widget.filePicker.takePhoto(),
        'gallery' => await widget.filePicker.choosePhoto(),
        _ => await widget.filePicker.choosePdf(),
      };
    } catch (_) {
      // A refused camera or a closed picker: nothing to upload.
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.account.account;
    final language = DriverAppTexts.language;
    final cars = [
      for (final car in _cars)
        if ((me?.isFleetAccount ?? false) || car.isApproved) car,
    ];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AccountStyle.appBar(
        context,
        tr.documents,
        onBack: () => maybePopOwned(context),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AccountStyle.ink,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              if (_loading)
                const LinearProgressIndicator(color: AccountStyle.ink),
              if (_error != null) ...[
                AccountErrorLine(_error!),
                const SizedBox(height: 10),
                AccountButton(
                  label: tr.retry,
                  outlined: true,
                  onPressed: _load,
                ),
              ],
              if (_uploadError != null) AccountErrorLine(_uploadError!),
              if (me != null) ...[
                _section(tr.docYou),
                if (me.requiredDocuments.isEmpty)
                  Text(tr.docNoneYet, style: AccountStyle.hint()),
                for (final type in me.requiredDocuments)
                  _row(me.driverId, type, me.documents, language, isCar: false),
                if (me.requiredFleetDocuments.isNotEmpty) ...[
                  _section(tr.docCompany),
                  for (final type in me.requiredFleetDocuments)
                    _row(
                      me.driverId,
                      type,
                      me.documents,
                      language,
                      isCar: false,
                    ),
                ],
                for (final car in cars) ...[
                  _section(tr.docCar(car.plate)),
                  for (final type in car.requiredDocuments)
                    _row(
                      car.vehicleId,
                      type,
                      car.documents,
                      language,
                      isCar: true,
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 22, 0, 6),
    child: Text(title.toUpperCase(), style: AccountStyle.section()),
  );

  Widget _row(
    String ownerId,
    String type,
    List<DocumentSummary> summary,
    String language, {
    required bool isCar,
  }) {
    final kind = DriverOnboardingRules.kindOf(type);
    final status = kind == DocumentKind.acceptance
        ? 'approved'
        : _status(ownerId, type, summary);
    final doc = _doc(ownerId, type);
    final uploading = _uploading == '$ownerId/$type';
    final canUpload = kind == DocumentKind.file && _uploading == null;
    return DocumentRow(
      key: ValueKey('doc-row-$ownerId-$type'),
      title: DriverOnboardingRules.documentName(type, language),
      status: status,
      note: kind == DocumentKind.adminCheck
          ? tr.docMoveraBooks
          : status == 'rejected'
          ? doc?.reviewNote
          : doc?.fileName,
      uploading: uploading,
      onTap: canUpload ? () => _upload(ownerId, type, isCar) : null,
    );
  }
}

/// One document line: its name, the status chip (and the rejection note),
/// a progress bar while its file goes up.
class DocumentRow extends StatelessWidget {
  const DocumentRow({
    super.key,
    required this.title,
    required this.status,
    this.note,
    this.uploading = false,
    this.onTap,
  });

  final String title;
  final String status;
  final String? note;
  final bool uploading;
  final VoidCallback? onTap;

  static (String, Color) chipOf(String status) => switch (status) {
    // v0.10.4: contract words (statusWords documentStatus).
    'approved' => (tr.swDocumentStatusApproved, AccountStyle.green),
    'in_review' => (tr.swDocumentStatusInReview, AccountStyle.amber),
    'rejected' => (tr.swDocumentStatusRejected, AccountStyle.error),
    'expired' => (tr.swDocumentStatusExpired, AccountStyle.error),
    'expiring' => (tr.swDocumentStatusExpiring, AccountStyle.amber),
    // missing (stored) and needed (required, not uploaded) show "needed".
    _ => (tr.swDocumentStatusNeeded, AccountStyle.error),
  };

  @override
  Widget build(BuildContext context) {
    final (label, color) = chipOf(status);
    return InkWell(
      onTap: uploading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AccountStyle.line)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AccountStyle.rowTitle()),
                      if (note != null && note!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            note!,
                            style: AuthText.urbanist(
                              size: 12.5,
                              height: 1.35,
                              color: status == 'rejected'
                                  ? AccountStyle.error
                                  : AccountStyle.muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                StatusChip(label, color: color),
                if (onTap != null && !uploading) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.upload_rounded,
                    color: AccountStyle.ink,
                    size: 20,
                  ),
                ],
              ],
            ),
            if (uploading)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: LinearProgressIndicator(
                        key: ValueKey('doc-progress'),
                        color: AccountStyle.ink,
                        minHeight: 3,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(tr.docUploading, style: AccountStyle.hint()),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/contracts/driver_onboarding_rules.dart';
import 'package:movera/core/onboarding/document_upload.dart';
import 'package:movera/core/onboarding/onboarding_settings.dart';
import 'package:movera/presentation/driver/account/account_style.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_style.dart';
import 'package:movera/presentation/driver/documents/document_file_picker.dart';
import 'package:movera/presentation/driver/documents/document_scanner.dart';
import 'package:movera/presentation/driver/signup/signup_common.dart';
import 'package:movera/presentation/driver/signup/signup_texts.dart';

/// Contract v0.18.166 (`signupV2.documentsScreen`, mockup screen 4):
/// "Vos documents" / "Dina dokument", optional. Sections "Vous" (the
/// country's person documents) and "Votre société" (company documents,
/// only for `fleet`). Each row: name, "Recto et verso" or its hint, and
/// "Ajouter" (the add flow), or "Envoyé ✓" once the server confirmed.
class SignupDocumentsScreen extends StatefulWidget {
  const SignupDocumentsScreen({super.key, required this.flow});

  final SignupFlow flow;

  @override
  State<SignupDocumentsScreen> createState() => _SignupDocumentsScreenState();
}

/// Types never sent from this screen: the photo (profile screen), the
/// terms and the checks Movera does.
const _notHere = {'profile_photo'};

class _SignupDocumentsScreenState extends State<SignupDocumentsScreen> {
  SignupFlow get flow => widget.flow;
  OnboardingSettings? _settings;
  final Set<String> _sentNow = {};

  @override
  void initState() {
    super.initState();
    later(_load());
  }

  Future<void> _load() async {
    final settings = await flow.settingsOf(flow.data.country ?? 'FR');
    if (mounted) setState(() => _settings = settings);
  }

  bool _isFile(String type) {
    final custom = _settings?.documentTypes[type];
    if (custom != null) return custom.kind == DocumentKind.file;
    return DriverOnboardingRules.kindOf(type) == DocumentKind.file;
  }

  String _name(String type) {
    final custom = _settings?.documentTypes[type]?.name?.inLanguage(
      DriverAppTexts.language,
    );
    return custom ??
        DriverOnboardingRules.documentName(
          type,
          DriverAppTexts.language,
          country: flow.data.country,
        );
  }

  String? _status(String type) {
    if (_sentNow.contains(type)) return 'in_review';
    for (final d in flow.profile?.documents ?? const <DocumentSummary>[]) {
      if (d.type == type) return d.status;
    }
    return null;
  }

  Future<void> _add(String type) async {
    final sent = await startDocumentAdd(
      context,
      flow: flow,
      type: type,
      name: _name(type),
      twoSided: _settings?.twoSidedTypes.contains(type) ?? false,
    );
    if (sent == true && mounted) {
      setState(() => _sentNow.add(type));
      later(flow.account.refresh().then((_) {}, onError: (_) {}));
    }
  }

  Widget _row(String type) {
    final status = _status(type);
    final twoSided = _settings?.twoSidedTypes.contains(type) ?? false;
    final help = _settings?.documentTypes[type]?.help?.inLanguage(
      DriverAppTexts.language,
    );
    final sent = status != null && status != 'missing' && status != 'rejected';
    return Padding(
      key: ValueKey('doc-row-$type'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AccountStyle.field,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.description_outlined, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name(type),
                  style: AuthText.urbanist(size: 14.5, weight: FontWeight.w600),
                ),
                Text(
                  status == 'rejected'
                      ? st('rejected')
                      : twoSided
                      ? st('twoSides')
                      : (help ?? st('onePage')),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AccountStyle.hint().copyWith(
                    fontSize: 12.5,
                    color: status == 'rejected' ? AccountStyle.error : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (sent)
            SignupTag(
              status == 'approved' ? '✓ ${st('approved')}' : '✓ ${st('sent')}',
              green: true,
            )
          else
            OutlinedButton.icon(
              key: ValueKey('doc-add-$type'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AccountStyle.ink,
                side: const BorderSide(color: AccountStyle.ink),
                shape: const StadiumBorder(),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => _add(type),
              icon: const Icon(Icons.add, size: 16),
              label: Text(
                st('add'),
                style: AuthText.urbanist(size: 13, weight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final country = flow.data.country ?? 'FR';
    final mine = [
      for (final t in settings?.driverDocuments ?? const <String>[])
        if (!_notHere.contains(t) && _isFile(t)) t,
    ];
    final company = flow.data.accountType == 'fleet'
        ? [
            for (final t in settings?.fleetDocuments ?? const <String>[])
              if (!_notHere.contains(t) && _isFile(t)) t,
          ]
        : const <String>[];
    return SignupScaffold(
      key: const ValueKey('signup-documents-screen'),
      title: st('docsTitle'),
      body: st('docsBody'),
      onBack: () => Navigator.of(context).maybePop(),
      button: SignupButton(
        key: const ValueKey('signup-documents-done'),
        label: st('done'),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      children: [
        if (settings == null)
          const Center(
            child: CircularProgressIndicator(color: AccountStyle.ink),
          )
        else if (mine.isEmpty && company.isEmpty)
          Text(st('noDocuments'), style: AccountStyle.hint())
        else ...[
          if (mine.isNotEmpty)
            SignupCard(
              title: st('docsYou'),
              children: [for (final t in mine) _row(t)],
            ),
          if (company.isNotEmpty)
            SignupCard(
              title: st('docsCompany'),
              tag: st(country == 'SE' ? 'withCompany' : 'withKbis'),
              children: [for (final t in company) _row(t)],
            ),
        ],
      ],
    );
  }
}

/// The Ajouter flow (mockup PROPOSAL-upload-scan): the sheet "Scanner"
/// (when available) or "Choisir une photo ou un fichier", then for a recto
/// verso type Recto (1/2), Verso (2/2), Vérifier, Envoyer; for a one-page
/// type one photo, Vérifier, Envoyer. True once the server answered 201.
Future<bool?> startDocumentAdd(
  BuildContext context, {
  required SignupFlow flow,
  required String type,
  required String name,
  required bool twoSided,
}) async {
  final mode = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => _AddSheet(
      name: name,
      twoSided: twoSided,
      scanner: flow.scanner.available,
    ),
  );
  if (mode == null || !context.mounted) return null;
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      settings: const RouteSettings(name: 'signup-document-add'),
      builder: (_) => DocumentAddScreen(
        flow: flow,
        type: type,
        name: name,
        twoSided: twoSided,
        mode: mode,
      ),
    ),
  );
}

class _AddSheet extends StatelessWidget {
  const _AddSheet({
    required this.name,
    required this.twoSided,
    required this.scanner,
  });

  final String name;
  final bool twoSided;
  final bool scanner;

  Widget _option(
    BuildContext context,
    String value,
    IconData icon,
    String title,
    String hint, {
    String? tag,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AccountStyle.field,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AccountStyle.line),
        ),
        child: InkWell(
          key: ValueKey('add-option-$value'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).pop(value),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, color: AccountStyle.ink),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AuthText.urbanist(
                          size: 15,
                          weight: FontWeight.w700,
                        ),
                      ),
                      Text(hint, style: AccountStyle.hint()),
                    ],
                  ),
                ),
                if (tag != null) SignupTag(tag, green: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              name,
              style: AuthText.urbanist(size: 18, weight: FontWeight.w700),
            ),
            Text(
              st(twoSided ? 'twoSidesPhotos' : 'onePagePhotos'),
              style: AccountStyle.hint(),
            ),
            const SizedBox(height: 14),
            if (scanner)
              _option(
                context,
                'scan',
                Icons.document_scanner_outlined,
                st('scanner'),
                twoSided ? st('scannerHint') : '${st('scannerHint')} · 1 photo',
                tag: st('recommended'),
              ),
            _option(
              context,
              'pick',
              Icons.photo_library_outlined,
              st('pickFile'),
              st('pickFileHint'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The steps of one document: Recto (1/2) and Verso (2/2) for a recto
/// verso type, one page otherwise, then Vérifier and Envoyer.
class DocumentAddScreen extends StatefulWidget {
  const DocumentAddScreen({
    super.key,
    required this.flow,
    required this.type,
    required this.name,
    required this.twoSided,
    required this.mode,
  });

  final SignupFlow flow;
  final String type;
  final String name;
  final bool twoSided;

  /// `scan` (the system scanner) or `pick` (gallery / files).
  final String mode;

  @override
  State<DocumentAddScreen> createState() => _DocumentAddScreenState();
}

class _DocumentAddScreenState extends State<DocumentAddScreen> {
  PickedDocumentFile? _front;
  PickedDocumentFile? _back;
  bool _sending = false;
  bool _sent = false;
  String? _error;
  String? _uploadKey;

  bool get _isPdf => _front?.mediaType == 'application/pdf';

  /// Recto then verso; a PDF chosen as the recto is the whole document.
  bool get _verify =>
      _front != null && (!widget.twoSided || _isPdf || _back != null);
  bool get _backStep =>
      widget.twoSided && _front != null && !_isPdf && _back == null;

  Future<void> _take({String? source}) async {
    setState(() => _error = null);
    PickedDocumentFile? picked;
    try {
      if (widget.mode == 'scan') {
        picked = await widget.flow.scanner.scanOnePage();
      } else if (source == 'files') {
        picked = await widget.flow.picker.chooseFile();
      } else {
        picked = await widget.flow.picker.choosePhoto();
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = isCameraBlocked(error)
              ? st('cameraBlocked')
              : st('sendFailed'),
        );
      }
      return;
    }
    if (picked == null || !mounted) return;
    setState(() {
      _uploadKey = null;
      if (_front == null) {
        _front = picked;
      } else {
        _back = picked;
      }
    });
  }

  void _retake() => setState(() {
    _front = null;
    _back = null;
    _error = null;
    _uploadKey = null;
  });

  /// "Envoyé ✓" only after the server answered 201 with the Document.
  Future<void> _send() async {
    if (_sending || _front == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      var file = _front!;
      if (widget.twoSided && !_isPdf && _back != null) {
        file = await widget.flow.joiner(_front!, _back!);
      }
      _uploadKey ??= ApiClient.randomKey();
      await widget.flow.account.repository.uploadDocument(
        type: widget.type,
        bytes: file.bytes,
        fileName: file.fileName,
        mediaType: file.mediaType,
        idempotencyKey: _uploadKey,
      );
      if (!mounted) return;
      setState(() => _sent = true);
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.of(context).pop(true);
    } on UnsupportedSidesError {
      if (mounted) setState(() => _error = st('sidesUnreadable'));
    } catch (_) {
      if (mounted) setState(() => _error = st('sendFailed'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _preview(PickedDocumentFile file, String label) {
    final image =
        file.mediaType.startsWith('image/') && file.mediaType != 'image/heic';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AccountStyle.label()),
        const SizedBox(height: 6),
        Container(
          height: 170,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AccountStyle.field,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AccountStyle.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: image
              ? Image.memory(file.bytes, fit: BoxFit.contain)
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.picture_as_pdf_outlined, size: 40),
                      Text(st('pdfFile'), style: AccountStyle.hint()),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _stepView() {
    final back = _backStep;
    final step = back ? 2 : 1;
    return Scaffold(
      key: ValueKey('doc-step-$step'),
      backgroundColor: const Color(0xFF111A17),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    key: const ValueKey('doc-step-close'),
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      widget.twoSided
                          ? st('stepOf', [st(back ? 'back' : 'front'), step])
                          : widget.name,
                      textAlign: TextAlign.center,
                      style: AuthText.urbanist(
                        size: 16,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              if (widget.twoSided)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      for (var i = 1; i <= 2; i++)
                        Expanded(
                          child: Container(
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: i <= step ? Colors.white : Colors.white24,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              if (back)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: SignupTag('✓ ${st('frontSaved')}', green: true),
                  ),
                ),
              const Spacer(),
              AspectRatio(
                aspectRatio: 1.586,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    widget.mode == 'scan'
                        ? Icons.document_scanner_outlined
                        : Icons.photo_library_outlined,
                    color: Colors.white54,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.twoSided
                    ? st(back ? 'placeBack' : 'placeFront')
                    : widget.name,
                textAlign: TextAlign.center,
                style: AuthText.urbanist(
                  size: 16,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              if (widget.mode == 'scan')
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    st('autoHint'),
                    textAlign: TextAlign.center,
                    style: AuthText.urbanist(size: 13, color: Colors.white70),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: AuthText.urbanist(
                      size: 13,
                      color: const Color(0xFFFF8A80),
                    ),
                  ),
                ),
              const Spacer(),
              if (widget.mode == 'scan')
                _whiteButton('doc-open-scanner', st('startScan'), () => _take())
              else ...[
                _whiteButton(
                  'doc-pick-gallery',
                  st('gallery'),
                  () => _take(source: 'gallery'),
                ),
                if (!back) ...[
                  const SizedBox(height: 10),
                  _whiteButton(
                    'doc-pick-files',
                    st('files'),
                    () => _take(source: 'files'),
                    outline: true,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _whiteButton(
    String key,
    String label,
    VoidCallback onTap, {
    bool outline = false,
  }) => SizedBox(
    height: 52,
    child: outline
        ? OutlinedButton(
            key: ValueKey(key),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: onTap,
            child: Text(
              label,
              style: AuthText.urbanist(
                size: 15,
                weight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          )
        : FilledButton(
            key: ValueKey(key),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AccountStyle.ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: onTap,
            child: Text(
              label,
              style: AuthText.urbanist(size: 15, weight: FontWeight.w700),
            ),
          ),
  );

  @override
  Widget build(BuildContext context) {
    if (!_verify) return _stepView();
    final front = _front!;
    return SignupScaffold(
      key: const ValueKey('doc-verify'),
      title: widget.name,
      body: st('checkBody'),
      onBack: _sending ? null : () => Navigator.of(context).pop(),
      button: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SignupButton(
            key: const ValueKey('doc-send'),
            label: _sent ? st('sentOk') : st('send'),
            busy: _sending,
            onPressed: _sent ? null : _send,
          ),
          const SizedBox(height: 6),
          TextButton(
            key: const ValueKey('doc-retake'),
            onPressed: _sending || _sent ? null : _retake,
            child: Text(
              st('retake'),
              style: AuthText.urbanist(size: 14.5, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
      children: [
        _preview(front, widget.twoSided && !_isPdf ? st('front') : widget.name),
        if (_back != null) _preview(_back!, st('back')),
        if (widget.twoSided && _back != null)
          Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(0xFF1E7B3A),
                size: 18,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(st('bothSharp'), style: AccountStyle.hint()),
              ),
            ],
          ),
        if (_sent)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              st('sentOk'),
              key: const ValueKey('doc-sent-ok'),
              style: AuthText.urbanist(
                size: 15,
                weight: FontWeight.w700,
                color: const Color(0xFF1E7B3A),
              ),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _error!,
              key: const ValueKey('doc-error'),
              style: AuthText.urbanist(size: 13.5, color: AccountStyle.error),
            ),
          ),
      ],
    );
  }
}

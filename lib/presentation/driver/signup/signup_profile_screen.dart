import 'package:flutter/material.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/onboarding/document_upload.dart';
import 'package:movera/presentation/driver/account/account_style.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_style.dart';
import 'package:movera/presentation/driver/documents/document_file_picker.dart';
import 'package:movera/presentation/driver/signup/signup_common.dart';
import 'package:movera/presentation/driver/signup/signup_texts.dart';
import 'package:movera/presentation/driver/signup/solar_icons.dart';

/// Contract v0.18.166 (`signupV2.profilePhoto` + `accountTypeLabels`):
/// "Votre profil" / "Din profil". The round photo is the existing document
/// `profile_photo` (camera or gallery), a normal picture: NOT the virtual
/// session (info_session untouched). Before approval the driver may take
/// another one; once approved only support changes it (owner "Peut pas").
/// "Vous êtes" opens the sheet mapped to the EXISTING accountType; `fleet`
/// shows the company fields below.
class SignupProfileScreen extends StatefulWidget {
  const SignupProfileScreen({
    super.key,
    required this.flow,
    this.openAccountType = false,
  });

  final SignupFlow flow;

  /// Opened from the checklist's "Vous êtes": the sheet opens at once.
  final bool openAccountType;

  @override
  State<SignupProfileScreen> createState() => _SignupProfileScreenState();
}

class _SignupProfileScreenState extends State<SignupProfileScreen> {
  SignupFlow get flow => widget.flow;
  SignupData get data => flow.data;
  final _name = TextEditingController();
  final _org = TextEditingController();
  final _address = TextEditingController();
  PickedDocumentFile? _photo;
  bool _sending = false;
  String? _photoMessage;
  bool _photoError = false;
  final Map<String, String> _errors = {};

  bool get _typeLocked => flow.profile?.accountType != null;

  @override
  void initState() {
    super.initState();
    data.accountType ??= flow.profile?.accountType;
    _name.text = data.companyName;
    _org.text = data.orgNumber;
    _address.text = data.companyAddress;
    if (widget.openAccountType && !_typeLocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickType());
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _org.dispose();
    _address.dispose();
    later(flow.draft.flush());
    super.dispose();
  }

  Future<void> _pickType() async {
    final picked = await showAccountTypeSheet(
      context,
      country: data.country ?? 'FR',
      selected: data.accountType,
    );
    if (picked == null || !mounted) return;
    setState(() => data.accountType = picked);
    flow.save();
  }

  Future<void> _photoSheet() async {
    if (flow.profilePhotoLocked || _sending) return;
    final choice = await showSignupList<String>(
      context,
      title: st('profilePhoto'),
      rows: [('camera', st('takePhoto')), ('gallery', st('choosePhoto'))],
      selected: null,
      keyPrefix: 'photo-source',
    );
    if (choice == null) return;
    PickedDocumentFile? picked;
    try {
      picked = choice == 'camera'
          ? await flow.picker.takePhoto()
          : await flow.picker.choosePhoto();
    } catch (error) {
      if (mounted) {
        setState(() {
          _photoError = true;
          _photoMessage = isCameraBlocked(error)
              ? st('cameraBlocked')
              : st('sendFailed');
        });
      }
      return;
    }
    if (picked == null || !mounted) return;
    await _upload(picked);
  }

  /// "Envoyé ✓" only after the server answered with the Document.
  Future<void> _upload(PickedDocumentFile file) async {
    setState(() {
      _photo = file;
      _sending = true;
      _photoError = false;
      _photoMessage = st('photoSending');
    });
    final key = ApiClient.randomKey();
    try {
      await flow.account.repository.uploadDocument(
        type: 'profile_photo',
        bytes: file.bytes,
        fileName: file.fileName,
        mediaType: file.mediaType,
        idempotencyKey: key,
      );
      await flow.account.refresh();
      if (!mounted) return;
      setState(() => _photoMessage = st('photoSent'));
    } catch (error) {
      if (!mounted) return;
      final locked =
          error is ApiError && error.reason == 'profile_photo_locked';
      if (locked) await flow.account.refresh().catchError((_) => flow.profile!);
      setState(() {
        _photoError = true;
        _photoMessage = locked ? st('photoLocked') : st('sendFailed');
        if (!locked) _photo = null;
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _keepCompany() {
    data
      ..companyName = _name.text
      ..orgNumber = _org.text
      ..companyAddress = _address.text;
    flow.save();
  }

  void _done() {
    _errors.clear();
    if (data.accountType == 'fleet') {
      _keepCompany();
      final need = st('required');
      if (_name.text.trim().isEmpty) _errors['companyName'] = need;
      if (_org.text.trim().isEmpty) _errors['orgNumber'] = need;
      if (_address.text.trim().isEmpty) _errors['companyAddress'] = need;
    }
    if (_errors.isNotEmpty) {
      setState(() {});
      return;
    }
    Navigator.of(context).maybePop();
  }

  Widget _circle() {
    final locked = flow.profilePhotoLocked;
    final has = _photo != null || flow.profilePhotoDone;
    final image = _photo != null && _photo!.mediaType.startsWith('image/')
        ? MemoryImage(_photo!.bytes)
        : null;
    return Column(
      children: [
        GestureDetector(
          key: const ValueKey('profile-photo-circle'),
          onTap: locked ? null : _photoSheet,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 58,
                backgroundColor: AccountStyle.field,
                backgroundImage: image,
                child: image == null
                    ? SolarIcon(
                        has ? Solar.check : Solar.user,
                        size: 44,
                        color: AccountStyle.muted,
                      )
                    : null,
              ),
              Positioned(
                right: -2,
                bottom: 4,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: locked
                      ? AccountStyle.muted
                      : AccountStyle.ink,
                  child: SolarIcon(
                    locked ? Solar.lock : Solar.camera,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          locked
              ? st('photoLocked')
              : has
              ? st('retakePhoto')
              : st('tapPhoto'),
          key: const ValueKey('profile-photo-hint'),
          textAlign: TextAlign.center,
          style: AccountStyle.hint(),
        ),
        if (_photoMessage != null && !locked)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _photoMessage!,
              key: const ValueKey('profile-photo-status'),
              style: AuthText.urbanist(
                size: 13,
                weight: FontWeight.w600,
                color: _photoError
                    ? AccountStyle.error
                    : const Color(0xFF1E7B3A),
              ),
            ),
          ),
      ],
    );
  }

  Widget _companyField(String key, TextEditingController c, String label) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SignupLabel(label),
          TextField(
            key: ValueKey('signup-$key'),
            controller: c,
            readOnly: _typeLocked,
            onChanged: (_) => _keepCompany(),
            decoration: AccountStyle.decoration(error: _errors[key]),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final country = data.country ?? 'FR';
    final type = data.accountType;
    return SignupScaffold(
      key: const ValueKey('signup-profile-screen'),
      title: st('profileTitle'),
      body: st('profileBody'),
      onBack: () => Navigator.of(context).maybePop(),
      button: SignupButton(
        key: const ValueKey('signup-profile-done'),
        label: st('done'),
        busy: _sending,
        onPressed: _done,
      ),
      children: [
        Center(child: _circle()),
        const SizedBox(height: 10),
        SignupLabel(st('youAre')),
        SignupSelectBox(
          key: const ValueKey('signup-account-type'),
          value: type == null ? null : accountTypeLabel(type, country),
          placeholder: st('choose'),
          onTap: _typeLocked ? null : _pickType,
        ),
        if (_typeLocked)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(st('typeLocked'), style: AccountStyle.hint()),
          ),
        if (type == 'fleet') ...[
          const SizedBox(height: 18),
          Text(st('company'), style: AccountStyle.section()),
          _companyField('companyName', _name, st('companyName')),
          _companyField(
            'orgNumber',
            _org,
            st(country == 'SE' ? 'orgNumberSE' : 'orgNumberFR'),
          ),
          _companyField('companyAddress', _address, st('companyAddress')),
        ],
      ],
    );
  }
}

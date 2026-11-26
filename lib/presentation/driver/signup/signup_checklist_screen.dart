import 'package:flutter/material.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/account_error_message.dart';
import 'package:movera/presentation/driver/account/account_style.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_style.dart';
import 'package:movera/presentation/driver/signup/signup_common.dart';
import 'package:movera/presentation/driver/signup/signup_documents_screen.dart';
import 'package:movera/presentation/driver/signup/signup_info_screen.dart';
import 'package:movera/presentation/driver/signup/signup_profile_screen.dart';
import 'package:movera/presentation/driver/signup/signup_texts.dart';

/// Contract v0.18.166 (`signupV2.checklist`): "Configurons votre compte" /
/// "Nu skapar vi ditt konto". Progress over 3 items (Vos informations,
/// Photo de profil, Vous êtes); Documents are optional and not counted.
/// "Envoyer l'inscription" sends `POST /driver/onboarding` without any
/// document; "Continuer plus tard ✕" goes Home and the list comes back on
/// the next opening until the server took the registration. No car step.
class SignupChecklistScreen extends StatefulWidget {
  const SignupChecklistScreen({super.key, required this.flow});

  final SignupFlow flow;

  @override
  State<SignupChecklistScreen> createState() => _SignupChecklistScreenState();
}

class _SignupChecklistScreenState extends State<SignupChecklistScreen> {
  SignupFlow get flow => widget.flow;
  SignupData get data => flow.data;
  bool _busy = false;
  String? _error;

  int get _done => [
    data.detailsDone,
    flow.profilePhotoDone,
    data.accountTypeDone,
  ].where((done) => done).length;

  int get _documentsSent {
    final types = {
      ...?flow.settingsHeld(data.country ?? '')?.driverDocuments,
      if (data.accountType == 'fleet')
        ...?flow.settingsHeld(data.country ?? '')?.fleetDocuments,
    };
    return (flow.profile?.documents ?? const <DocumentSummary>[])
        .where(
          (d) =>
              d.type != 'profile_photo' &&
              types.contains(d.type) &&
              d.status != 'missing' &&
              d.status != 'rejected',
        )
        .length;
  }

  @override
  void initState() {
    super.initState();
    final country = data.country;
    if (country != null) {
      later(
        flow.settingsOf(country).then((_) => mounted ? setState(() {}) : null),
      );
    }
  }

  Future<void> _open(Widget screen, String name) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: name),
        builder: (_) => screen,
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _send() async {
    if (_busy) return;
    if (_done < 3) {
      setState(() => _error = st('finishFirst'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final hasAddress = data.street.trim().isNotEmpty;
    final request = DriverDetailsRequest(
      firstName: data.firstName,
      lastName: data.lastName,
      dateOfBirth: data.dateOfBirth,
      email: data.email,
      country: data.country!,
      cityId: data.cityId!,
      language: data.language ?? 'en',
      accountType: data.accountType!,
      personalNumber: data.personalNumber.isEmpty ? null : data.personalNumber,
      taxiLicenseNumber: data.taxiLicenseNumber.isEmpty
          ? null
          : data.taxiLicenseNumber,
      address: hasAddress
          ? DriverAddress(
              street: data.street,
              postalCode: data.postalCode,
              city: data.city,
            )
          : null,
      company: data.accountType == 'fleet'
          ? FleetCompany(
              name: data.companyName,
              orgNumber: data.orgNumber,
              address: data.companyAddress,
            )
          : null,
    );
    try {
      final account = await flow.account.repository.submitDetails(request);
      flow.account.replace(account);
      await flow.draft.clear();
      if (!mounted) return;
      flow.onHome(context);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = accountErrorMessage(error, fallback: st('saveError')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _row({
    required String key,
    required IconData icon,
    required String title,
    String? subtitle,
    bool done = false,
    bool dark = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: ValueKey('checklist-$key'),
      onTap: _busy ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: dark ? AccountStyle.ink : AccountStyle.field,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 19,
                color: dark ? Colors.white : AccountStyle.ink,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AuthText.urbanist(
                      size: 14.5,
                      weight: FontWeight.w600,
                    ),
                  ),
                  if (done) ...[
                    const SizedBox(height: 4),
                    SignupTag('✓ ${st('added')}', green: true),
                  ] else if (subtitle != null)
                    Text(
                      subtitle,
                      style: AccountStyle.hint().copyWith(fontSize: 12.5),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AccountStyle.muted),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final country = data.country ?? 'FR';
    final sent = _documentsSent;
    return PopScope(
      canPop: false,
      child: SignupScaffold(
        key: const ValueKey('signup-checklist-screen'),
        title: st('listTitle'),
        body: st('listBody'),
        topRight: ActionChip(
          key: const ValueKey('signup-later'),
          backgroundColor: AccountStyle.field,
          side: BorderSide.none,
          shape: const StadiumBorder(),
          label: Text(
            '${st('later')}  ✕',
            style: AuthText.urbanist(size: 12.5, weight: FontWeight.w600),
          ),
          onPressed: _busy
              ? null
              : () async {
                  await flow.draft.flush();
                  if (context.mounted) flow.onHome(context);
                },
        ),
        button: SignupButton(
          key: const ValueKey('signup-send'),
          label: st('sendSignup'),
          busy: _busy,
          onPressed: _send,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AccountStyle.field,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        st('progress'),
                        style: AuthText.urbanist(
                          size: 13.5,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '$_done/3',
                      key: const ValueKey('signup-progress'),
                      style: AccountStyle.hint(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: _done / 3,
                    minHeight: 5,
                    color: AccountStyle.ink,
                    backgroundColor: AccountStyle.line,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SignupCard(
            title: st('personal'),
            children: [
              _row(
                key: 'details',
                icon: Icons.list_alt,
                title: st('infoTitle'),
                done: data.detailsDone,
                dark: data.detailsDone,
                onTap: () => _open(SignupInfoScreen(flow: flow), 'signup-info'),
              ),
              _row(
                key: 'photo',
                icon: Icons.person_outline,
                title: st('profilePhoto'),
                done: flow.profilePhotoDone,
                dark: flow.profilePhotoDone,
                onTap: () =>
                    _open(SignupProfileScreen(flow: flow), 'signup-profile'),
              ),
              _row(
                key: 'account-type',
                icon: Icons.work_outline,
                title: st('youAre'),
                subtitle: st(country == 'SE' ? 'youAreHintSE' : 'youAreHintFR'),
                done: data.accountTypeDone,
                dark: data.accountTypeDone,
                onTap: () => _open(
                  SignupProfileScreen(flow: flow, openAccountType: true),
                  'signup-profile',
                ),
              ),
            ],
          ),
          SignupCard(
            title: st('documents'),
            tag: st('optional'),
            children: [
              _row(
                key: 'documents',
                icon: Icons.description_outlined,
                title: st('sendDocuments'),
                subtitle: sent > 0
                    ? st('documentsSent', [sent])
                    : st('sendDocumentsHint'),
                onTap: () => _open(
                  SignupDocumentsScreen(flow: flow),
                  'signup-documents',
                ),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _error!,
                key: const ValueKey('signup-send-error'),
                style: AuthText.urbanist(size: 13.5, color: AccountStyle.error),
              ),
            ),
        ],
      ),
    );
  }
}

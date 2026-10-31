import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:movera/core/account/account_error_message.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/account/org_number.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/driver/account/account_style.dart';
import 'package:movera/presentation/driver/account/fleet_actions.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_style.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:movera/widgets/keep_above_keyboard.dart';

/// Owner decision of 2026-10-29, driver group 2 item 7: "Start my own
/// company" from My fleet (`POST /driver/fleet/start-company`). The
/// account becomes a fleet (company) account and waits for Movera like a
/// new fleet; the documents it has stay (nothing is uploaded again), only
/// the company's and the cars' documents are new. Pops with the account.
class StartCompanyScreen extends StatefulWidget {
  const StartCompanyScreen({super.key, required this.account});

  final DriverAccountSession account;

  @override
  State<StartCompanyScreen> createState() => _StartCompanyScreenState();
}

class _StartCompanyScreenState extends State<StartCompanyScreen> {
  final _name = TextEditingController();
  final _orgNumber = TextEditingController();
  final _address = TextEditingController();
  bool _busy = false;
  String? _error;

  String get _country => widget.account.account?.country ?? 'SE';

  @override
  void dispose() {
    for (final c in [_name, _orgNumber, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _complete =>
      _name.text.trim().isNotEmpty &&
      OrgNumber.isValid(_orgNumber.text, _country) &&
      _address.text.trim().isNotEmpty;

  Future<void> _send() async {
    if (_busy || !_complete) return;
    final yes = await confirmAccountAction(
      context,
      question: tr.startCompanyConfirmQ,
      yes: tr.startCompanySend,
    );
    if (!yes || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = widget.account;
    final company = FleetCompany(
      name: _name.text,
      orgNumber: _orgNumber.text,
      address: _address.text,
    );
    try {
      var version = session.account?.version ?? 1;
      DriverAccount? result;
      for (var attempt = 0; attempt < 2 && result == null; attempt++) {
        try {
          result = await session.repository.startCompany(company, version);
        } catch (error) {
          final stale =
              accountErrorMessage(error, fallback: '') == tr.acctChangedReload;
          if (!stale || attempt > 0) rethrow;
          version = (await session.refresh()).version;
        }
      }
      if (!mounted || result == null) return;
      session.replace(result);
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(tr.startCompanySent)));
      popOwned<DriverAccount>(context, result);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = accountErrorMessage(
          error,
          fallback: tr.startCompanyFailed,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fleet = widget.account.account?.fleet;
    final orgError =
        _orgNumber.text.trim().isNotEmpty &&
            !OrgNumber.isValid(_orgNumber.text, _country)
        ? (_country == 'FR' ? tr.acctOrgNumberFrRule : tr.acctOrgNumberSeRule)
        : null;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AccountStyle.appBar(
        context,
        tr.startCompanyTitle,
        onBack: _busy ? null : () => maybePopOwned(context),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([_name, _orgNumber, _address]),
          builder: (context, _) => ListView(
            key: const ValueKey('start-company'),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Text(tr.startCompanyIntro, style: AccountStyle.body()),
              if (fleet != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    tr.startCompanyLeavesFleet(fleet.name),
                    style: AccountStyle.hint(),
                  ),
                ),
              const SizedBox(height: 20),
              _field(
                'start-company-name',
                tr.acctCompanyName,
                _name,
                capitalization: TextCapitalization.words,
              ),
              _field(
                'start-company-org',
                _country == 'FR' ? tr.acctOrgNumberFr : tr.acctOrgNumberSe,
                _orgNumber,
                hint: OrgNumber.hintFor(_country),
                error: orgError,
                keyboard: TextInputType.number,
                formatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9 \-]')),
                  LengthLimitingTextInputFormatter(
                    OrgNumber.maxLengthFor(_country),
                  ),
                ],
              ),
              _field(
                'start-company-address',
                tr.acctCompanyAddress,
                _address,
                hint: tr.acctCompanyAddressHint,
                capitalization: TextCapitalization.sentences,
              ),
              if (_error != null) AccountErrorLine(_error!),
              const SizedBox(height: 16),
              KeepAboveKeyboard(
                child: AccountButton(
                  key: const ValueKey('start-company-send'),
                  label: tr.startCompanySend,
                  busy: _busy,
                  onPressed: _complete ? _send : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String key,
    String label,
    TextEditingController controller, {
    String? hint,
    String? error,
    TextInputType? keyboard,
    TextCapitalization capitalization = TextCapitalization.none,
    List<TextInputFormatter>? formatters,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(label, style: AccountStyle.label()),
        ),
        TextField(
          key: ValueKey(key),
          controller: controller,
          enabled: !_busy,
          keyboardType: keyboard,
          textCapitalization: capitalization,
          inputFormatters: formatters,
          style: AuthText.urbanist(size: 15),
          cursorColor: AccountStyle.ink,
          decoration: AccountStyle.decoration(hint: hint, error: error),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:movera/core/account/account_error_message.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/l10n/driver_l10n.dart';

/// What [ContactChangeScreen] changes.
enum ContactKind { phone, email }

/// Decision driver-g1 "One phone at a time" (owner 2026-11-02): the driver
/// changes his phone number or e-mail himself. Step 1: the new value
/// (`POST /account/phone/change` or `/account/email/change`); step 2: the
/// code sent to it (`…/verify`); then saved, and the account read again.
/// Contract v0.18.14 `deepFix1.accountChange`.
///
/// G30 (contract v0.18.76 / v0.18.77 `contract.json#emailVerified`): the
/// e-mail start answers `delivery`; only `sent` means a code went out (Rule
/// 35). Anything else (`pending_provider`, or no `delivery` from an older
/// server) says `texts.codeNotSentYet` and shows no code field. With
/// [verifyCurrent] the screen checks the driver's own current address.
class ContactChangeScreen extends StatefulWidget {
  const ContactChangeScreen({
    super.key,
    required this.account,
    required this.kind,
    this.verifyCurrent,
  });

  final DriverAccountSession account;
  final ContactKind kind;

  /// G30 `emailVerified.verifyCurrent`: the driver's current, Not verified
  /// e-mail. The field is filled with it and read-only; "Change e-mail"
  /// switches to the normal change.
  final String? verifyCurrent;

  @override
  State<ContactChangeScreen> createState() => _ContactChangeScreenState();
}

class _ContactChangeScreenState extends State<ContactChangeScreen> {
  final _value = TextEditingController();
  final _code = TextEditingController();
  String? _challenge;
  String? _error;
  bool _busy = false;

  /// G30: the last e-mail start was not sent (`delivery` not `sent`).
  bool _notSent = false;

  /// G30: checking the current address (until "Change e-mail" is tapped).
  late bool _verifyCurrent;

  bool get _phone => widget.kind == ContactKind.phone;

  @override
  void initState() {
    super.initState();
    final current = widget.verifyCurrent?.trim() ?? '';
    _verifyCurrent = !_phone && current.isNotEmpty;
    if (_verifyCurrent) _value.text = current;
  }

  void _changeInstead() => setState(() {
    _verifyCurrent = false;
    _notSent = false;
    _error = null;
    _value.clear();
  });

  @override
  void dispose() {
    _value.dispose();
    _code.dispose();
    super.dispose();
  }

  String _message(Object error) {
    if (error is ApiError) {
      switch (error.detail) {
        case 'phone_taken':
          return tr.contactPhoneTaken;
        case 'email_taken':
          return tr.contactEmailTaken;
        case 'invalid_otp_code' || 'invalid_otp':
          return tr.authErrWrongCode;
        case 'otp_expired' ||
            'invalid_otp_session' ||
            'invalid_email_challenge':
          return tr.authCodeExpired;
        case 'invalid_phone':
          return tr.authInvalidMobileNumber;
        case 'invalid_email':
          return tr.acctInvalidEmail;
        case 'reauth_required':
          return tr.contactReauthRequired;
        case 'change_too_many':
          return tr.contactChangeTooMany;
      }
    }
    return accountErrorMessage(error, fallback: tr.contactChangeFailed);
  }

  Future<void> _send() async {
    final value = _value.text.trim();
    if (value.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notSent = false;
    });
    final repo = widget.account.repository;
    try {
      if (_phone) {
        final id = await repo.changePhone(value);
        if (!mounted) return;
        setState(() => _challenge = id);
        return;
      }
      final started = await repo.changeEmail(value);
      if (!mounted) return;
      // G30 (Rule 35): only `delivery: sent` means a code went out.
      setState(() {
        if (started.sent) {
          _challenge = started.challengeId;
        } else {
          _notSent = true;
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final challenge = _challenge;
    final code = _code.text.trim();
    if (challenge == null || code.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = widget.account.repository;
    try {
      if (_phone) {
        await repo.verifyPhone(
          phone: _value.text.trim(),
          sessionId: challenge,
          code: code,
        );
      } else {
        await repo.verifyEmail(challengeId: challenge, code: code);
      }
      try {
        await widget.account.refresh();
      } catch (_) {
        // Saved on the server; the next profile read shows it.
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _phone
                ? tr.contactPhoneSaved
                : _verifyCurrent
                ? tr.contactEmailVerifiedDone
                : tr.contactEmailSaved,
          ),
        ),
      );
      Navigator.of(context).maybePop();
    } catch (error) {
      if (!mounted) return;
      _code.clear();
      setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sent = _challenge != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _phone
              ? tr.contactChangePhone
              : _verifyCurrent
              ? tr.contactVerifyEmail
              : tr.contactChangeEmail,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              key: const ValueKey('contact-value'),
              controller: _value,
              enabled: !sent && !_busy,
              readOnly: _verifyCurrent,
              keyboardType: _phone
                  ? TextInputType.phone
                  : TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: _phone
                    ? tr.contactNewPhone
                    : _verifyCurrent
                    ? tr.acctEmail
                    : tr.contactNewEmail,
              ),
            ),
            if (_verifyCurrent && !sent)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: const ValueKey('contact-change-instead'),
                  onPressed: _busy ? null : _changeInstead,
                  child: Text(tr.contactChangeEmail),
                ),
              ),
            if (_notSent && !sent) ...[
              const SizedBox(height: 12),
              Text(
                tr.contactCodeNotSentYet,
                key: const ValueKey('contact-not-sent'),
              ),
            ],
            if (sent) ...[
              const SizedBox(height: 12),
              Text(
                _phone
                    ? tr.contactCodeSentPhone
                    : tr.contactCodeSentTo(_value.text.trim()),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('contact-code'),
                controller: _code,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: tr.contactCode),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const ValueKey('contact-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('contact-submit'),
              onPressed: _busy ? null : (sent ? _verify : _send),
              child: Text(sent ? tr.contactSave : tr.contactSendCode),
            ),
          ],
        ),
      ),
    );
  }
}

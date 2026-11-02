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
class ContactChangeScreen extends StatefulWidget {
  const ContactChangeScreen({
    super.key,
    required this.account,
    required this.kind,
  });

  final DriverAccountSession account;
  final ContactKind kind;

  @override
  State<ContactChangeScreen> createState() => _ContactChangeScreenState();
}

class _ContactChangeScreenState extends State<ContactChangeScreen> {
  final _value = TextEditingController();
  final _code = TextEditingController();
  String? _challenge;
  String? _error;
  bool _busy = false;

  bool get _phone => widget.kind == ContactKind.phone;

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
        case 'otp_expired' || 'invalid_otp_session':
          return tr.authCodeExpired;
        case 'invalid_phone':
          return tr.authInvalidMobileNumber;
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
    });
    final repo = widget.account.repository;
    try {
      final id = _phone
          ? await repo.changePhone(value)
          : await repo.changeEmail(value);
      if (!mounted) return;
      setState(() => _challenge = id);
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
          content: Text(_phone ? tr.contactPhoneSaved : tr.contactEmailSaved),
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
        title: Text(_phone ? tr.contactChangePhone : tr.contactChangeEmail),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              key: const ValueKey('contact-value'),
              controller: _value,
              enabled: !sent && !_busy,
              keyboardType: _phone
                  ? TextInputType.phone
                  : TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: _phone ? tr.contactNewPhone : tr.contactNewEmail,
              ),
            ),
            if (sent) ...[
              const SizedBox(height: 12),
              Text(_phone ? tr.contactCodeSentPhone : tr.contactCodeSentEmail),
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

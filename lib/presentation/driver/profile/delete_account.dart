import 'package:flutter/material.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/l10n/driver_l10n.dart';

/// Contract v0.18.140 (`contract.json#accountDeletion.driver`; owner button
/// 2026-11-20 "Accept, keep debt (Rec.)", Rules
/// decisions/session-2026-11-06.md): Profile > Delete my account. What
/// closes at once and what is kept, then a confirm step, then
/// `POST /driver/account/deletion`. On 202 [onDeleted] signs out and wipes
/// the phone; 409 `deletion_open_trip` says to finish or cancel the ride.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({
    super.key,
    required this.account,
    required this.onDeleted,
  });

  final DriverAccountSession account;
  final Future<void> Function(BuildContext context) onDeleted;

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _start() async {
    if (_busy) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr.acctDeleteConfirmQ),
        content: Text(tr.acctDeleteConfirmBody),
        actions: [
          TextButton(
            key: const ValueKey('delete-account-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr.stay),
          ),
          FilledButton(
            key: const ValueKey('delete-account-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB3261E),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(tr.acctDeleteConfirm),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.account.repository.requestAccountDeletion();
      if (!mounted) return;
      await widget.onDeleted(context);
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error.reason == 'deletion_open_trip'
            ? tr.acctDeleteOpenTrip
            : tr.acctDeleteFailed,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = tr.acctDeleteFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr.acctDeleteTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              tr.acctDeleteBody,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              tr.acctDeleteKept,
              style: const TextStyle(fontSize: 14, color: Color(0xFF5B6670)),
            ),
            if (_error case final error?) ...[
              const SizedBox(height: 16),
              Text(
                error,
                key: const ValueKey('delete-account-error'),
                style: const TextStyle(
                  color: Color(0xFFB3261E),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              key: const ValueKey('delete-account-button'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB3261E),
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: _busy ? null : _start,
              child: Text(tr.acctDeleteTitle),
            ),
          ],
        ),
      ),
    );
  }
}

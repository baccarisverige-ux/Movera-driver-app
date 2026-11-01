import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/ride/pickup_pin.dart';
import 'package:movera/widgets/movera_modal_sheet.dart';

/// Contract v0.18.8 (owner G6 decision 2): before "Start trip" on a trip
/// with `pinRequired`, the driver types the rider's 4-digit code. [submit]
/// sends it (with `board`); the sheet closes with true once it was right.
/// The driver never sees the code itself. [first] is a refusal already
/// known (a lock, a `pin_required` from the slide).
Future<bool> showPickupPinSheet(
  BuildContext context, {
  required Future<PickupPinOutcome> Function(String pin) submit,
  PickupPinOutcome? first,
}) async {
  final done = await showMoveraModalSheet<bool>(
    context: context,
    fitContent: true,
    heightFactor: 0.9,
    builder: (_) => PickupPinSheet(submit: submit, first: first),
  );
  return done ?? false;
}

class PickupPinSheet extends StatefulWidget {
  const PickupPinSheet({super.key, required this.submit, this.first});

  final Future<PickupPinOutcome> Function(String pin) submit;
  final PickupPinOutcome? first;

  @override
  State<PickupPinSheet> createState() => _PickupPinSheetState();
}

class _PickupPinSheetState extends State<PickupPinSheet> {
  static const _ink = Color(0xFF1C242C);
  static const _muted = Color(0xFF7D898F);
  static const _red = Color(0xFF9E2B33);

  final _field = TextEditingController();
  final _focus = FocusNode();
  PickupPinOutcome? _outcome;
  bool _sending = false;
  DateTime? _lockedUntil;
  Timer? _unlock;

  @override
  void initState() {
    super.initState();
    _show(widget.first);
    _field.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _unlock?.cancel();
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _locked =>
      _outcome?.result == PickupPinResult.blocked ||
      _lockedUntil != null && DateTime.now().isBefore(_lockedUntil!);

  void _show(PickupPinOutcome? outcome) {
    _outcome = outcome == null || outcome.result == PickupPinResult.required
        ? null
        : outcome;
    _unlock?.cancel();
    _lockedUntil = null;
    if (outcome?.result == PickupPinResult.locked) {
      final wait = outcome!.lockedFor ?? const Duration(minutes: 5);
      _lockedUntil = DateTime.now().add(wait);
      // The field opens again when the lock is over.
      _unlock = Timer(wait, () {
        if (!mounted) return;
        setState(() {
          _lockedUntil = null;
          _outcome = null;
        });
      });
    }
  }

  Future<void> _send() async {
    final pin = _field.text;
    if (_sending || _locked || !PickupPinOutcome.valid(pin)) return;
    setState(() => _sending = true);
    final outcome = await widget.submit(pin);
    if (!mounted) return;
    if (outcome.ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _sending = false;
      _field.clear();
      _show(outcome);
    });
  }

  @override
  Widget build(BuildContext context) {
    final error = _outcome?.text;
    final canSend =
        !_sending && !_locked && PickupPinOutcome.valid(_field.text);
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6E8EA),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tr.g6PinTitle,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tr.g6PinAsk,
                style: const TextStyle(color: _muted, fontSize: 15),
              ),
              const SizedBox(height: 18),
              TextField(
                key: const ValueKey('pickup-pin-field'),
                controller: _field,
                focusNode: _focus,
                autofocus: true,
                enabled: !_locked && !_sending,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 4,
                obscureText: false,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                style: const TextStyle(
                  color: _ink,
                  fontSize: 32,
                  letterSpacing: 16,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••',
                  helperText: error == null || error.isEmpty
                      ? tr.g6PinFourDigits
                      : null,
                  errorText: error == null || error.isEmpty ? null : error,
                  errorMaxLines: 3,
                  filled: true,
                  fillColor: const Color(0xFFF6F7F8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _red),
                  ),
                ),
                onSubmitted: (_) => _send(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 54,
                child: FilledButton(
                  key: const ValueKey('pickup-pin-confirm'),
                  onPressed: canSend ? _send : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _ink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          tr.g6PinConfirm,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(tr.cancel, style: const TextStyle(color: _muted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

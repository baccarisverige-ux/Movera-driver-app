import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:flutter/material.dart';
import 'package:movera/core/money/bank_account.dart';
import 'package:movera/widgets/keep_above_keyboard.dart';

/// Local-only validation preview; no account details are persisted or sent.
class AddNewAccount extends StatefulWidget {
  const AddNewAccount({super.key});

  @override
  State<AddNewAccount> createState() => _AddNewAccountState();
}

class _AddNewAccountState extends State<AddNewAccount> {
  static const Color _ink = Color(0xFF111614);
  static const Color _muted = Color(0xFF8A9390);
  static const Color _line = Color(0xFFE7E9EA);
  static const Color _green = Color(0xFF1FA463);
  static const Color _red = Color(0xFFC2453A);

  final _holder = TextEditingController();
  final _clearing = TextEditingController();
  final _account = TextEditingController();
  final _iban = TextEditingController();
  final _bic = TextEditingController();
  bool _international = false;
  bool _tried = false;
  bool get _ownsRoute => mounted && ModalRoute.of(context)?.isCurrent == true;

  @override
  void dispose() {
    for (final c in [_holder, _clearing, _account, _iban, _bic]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _bank => _international
      ? BankAccountRules.bankForIban(_iban.text)
      : BankAccountRules.bankForClearing(_clearing.text);

  String? get _problem {
    if (_holder.text.trim().isEmpty) return tr.bankAddHolderName;
    if (_international) {
      if (!BankAccountRules.validIban(_iban.text)) {
        return tr.bankCheckIban;
      }
      if (!BankAccountRules.validBic(_bic.text)) {
        return tr.bankBicFormat;
      }
      return null;
    }
    if (_bank == null) {
      return tr.bankCheckClearing;
    }
    if (!BankAccountRules.validAccount(_account.text)) {
      return tr.bankAccountDigits;
    }
    return null;
  }

  void _save() {
    if (!_ownsRoute) return;
    setState(() => _tried = true);
    final problem = _problem;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(problem ?? tr.bankPreviewNotSaved)));
  }

  Widget _tabs() => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFFF2F3F3),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        for (final (label, intl) in [
          (tr.countrySweden, false),
          (tr.international, true),
        ])
          Expanded(
            child: TextButton(
              key: ValueKey<String>('bank-tab-$label'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              onPressed: () {
                if (!_ownsRoute) return;
                setState(() {
                  _international = intl;
                  _tried = false;
                });
              },
              child: Semantics(
                selected: _international == intl,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  constraints: const BoxConstraints(minHeight: 36),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _international == intl
                        ? Colors.white
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: _international == intl
                          ? _line
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _international == intl ? _ink : _muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _row(
    String label, {
    TextEditingController? controller,
    String? value,
    String hint = '',
    bool ok = false,
    bool last = false,
    TextInputType? keyboard,
    TextCapitalization caps = TextCapitalization.none,
    int maxLines = 1,
  }) {
    const valueStyle = TextStyle(
      color: _ink,
      fontSize: 15.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    );
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(color: _muted, fontSize: 15),
            ),
          ),
          Expanded(
            child: controller == null
                ? Text(
                    value ?? '—',
                    key: ValueKey<String>('bank-row-$label'),
                    textAlign: TextAlign.right,
                    style: value == null
                        ? valueStyle.copyWith(color: const Color(0xFFB4BBB8))
                        : valueStyle,
                  )
                : TextField(
                    key: ValueKey<String>('bank-field-$label'),
                    controller: controller,
                    textAlign: TextAlign.right,
                    keyboardType: keyboard,
                    textCapitalization: caps,
                    minLines: 1,
                    maxLines: maxLines,
                    autocorrect: false,
                    style: valueStyle,
                    cursorColor: _ink,
                    onChanged: (_) {
                      if (_ownsRoute) setState(() {});
                    },
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: hint,
                      hintStyle: valueStyle.copyWith(
                        color: const Color(0xFFB4BBB8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: ok
                ? const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.check_rounded, color: _green, size: 18),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bank = _bank;
    final foreignIban =
        _international &&
        !BankAccountRules.compact(_iban.text).startsWith('SE');
    final problem = _tried ? _problem : null;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: tr.back,
          onPressed: () => maybePopOwned(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _ink, size: 24),
        ),
        centerTitle: true,
        title: Text(
          tr.bankAccount,
          style: TextStyle(
            color: _ink,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          _tabs(),
          const SizedBox(height: 26),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              tr.bankAccountSection,
              style: const TextStyle(
                color: _muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: _line),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _row(
                  tr.bankHolder,
                  controller: _holder,
                  hint: tr.fullName,
                  caps: TextCapitalization.words,
                ),
                _row(foreignIban ? tr.country : tr.bank, value: bank),
                if (!_international) ...[
                  _row(
                    tr.clearing,
                    controller: _clearing,
                    hint: '8327-9',
                    ok: bank != null,
                    keyboard: TextInputType.number,
                  ),
                  _row(
                    tr.account,
                    controller: _account,
                    hint: '123 456 789-0',
                    ok: BankAccountRules.validAccount(_account.text),
                    keyboard: TextInputType.number,
                    last: true,
                  ),
                ] else ...[
                  _row(
                    'IBAN',
                    controller: _iban,
                    hint: 'SE45 5000 0000 …',
                    ok: BankAccountRules.validIban(_iban.text),
                    caps: TextCapitalization.characters,
                    // 24+ characters: wraps rather than scrolling out of sight.
                    maxLines: 2,
                  ),
                  _row(
                    'BIC',
                    controller: _bic,
                    hint: 'ESSESESS',
                    ok: BankAccountRules.validBic(_bic.text),
                    caps: TextCapitalization.characters,
                    last: true,
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: Text(
              problem ??
                  (_international ? tr.bankUseIban : tr.bankFoundFromClearing),
              key: const ValueKey<String>('bank-note'),
              style: TextStyle(
                color: problem == null ? _muted : _red,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 30),
          KeepAboveKeyboard(
            child: SizedBox(
              height: 52,
              child: FilledButton(
                key: const ValueKey<String>('bank-save'),
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: _ink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                child: Text(
                  tr.checkDetails,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded, size: 14, color: _muted),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  tr.bankDemoNotSaved,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

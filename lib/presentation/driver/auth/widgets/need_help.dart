import 'package:flutter/material.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/support/support_details.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_style.dart';

/// A small "Need help?" before sign-in (owner 2026-10-29: "It's not help
/// page !! It's only written need help ? When clic user can see info").
/// A tap shows a small box with Movera's support e-mail, phone and company
/// details, or "Contact details coming soon" while they are not filled in.
class NeedHelpLink extends StatelessWidget {
  const NeedHelpLink({super.key, this.details = moveraSupportDetails});

  final SupportDetails details;

  void _show(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('auth-need-help-box'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(tr.authNeedHelp, style: AuthText.cardTitle()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: details.isEmpty
              ? [
                  Text(
                    tr.authHelpComingSoon,
                    key: const ValueKey('auth-need-help-soon'),
                    style: AuthText.cardSub(),
                  ),
                ]
              : [
                  if (details.email.trim().isNotEmpty)
                    _row(tr.authHelpEmail, details.email.trim()),
                  if (details.phone.trim().isNotEmpty)
                    _row(tr.authHelpPhone, details.phone.trim()),
                  if (details.company.trim().isNotEmpty)
                    _row(tr.authHelpCompany, details.company.trim()),
                ],
        ),
        actions: [
          TextButton(
            key: const ValueKey('auth-need-help-close'),
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: AuthColors.ink),
            child: Text(tr.authHelpClose),
          ),
        ],
      ),
    );
  }

  static Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AuthText.label()),
        SelectableText(value, style: AuthText.input()),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      key: const ValueKey('auth-need-help'),
      onPressed: () => _show(context),
      style: TextButton.styleFrom(
        foregroundColor: AuthColors.muted,
        minimumSize: const Size(0, 36),
      ),
      child: Text(
        tr.authNeedHelp,
        style: AuthText.urbanist(
          size: 13,
          weight: FontWeight.w600,
          color: AuthColors.muted,
        ),
      ),
    ),
  );
}

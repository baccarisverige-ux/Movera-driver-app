import 'package:flutter/material.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_style.dart';

/// The plain, professional look of the account screens (details, fleet,
/// live documents): white ground, Urbanist, ink buttons, boxed fields.
abstract final class AccountStyle {
  static const ink = AuthColors.ink;
  static const muted = AuthColors.muted;
  static const line = Color(0xFFE1E7E3);
  static const field = Color(0xFFF6F7F5);
  static const green = AuthColors.green;
  static const error = AuthColors.error;
  static const amber = Color(0xFFB8740F);

  static TextStyle title() =>
      AuthText.urbanist(size: 24, weight: FontWeight.w800, height: 1.15);

  static TextStyle section() => AuthText.urbanist(
    size: 12,
    weight: FontWeight.w700,
    color: muted,
    letterSpacing: 1.2,
  );

  static TextStyle body() => AuthText.urbanist(size: 14.5, height: 1.4);

  static TextStyle hint() =>
      AuthText.urbanist(size: 13.5, height: 1.4, color: muted);

  static TextStyle label() =>
      AuthText.urbanist(size: 13, weight: FontWeight.w600);

  static TextStyle rowTitle() =>
      AuthText.urbanist(size: 16, weight: FontWeight.w600);

  static InputDecoration decoration({String? hint, String? error}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: AuthText.urbanist(size: 15, color: const Color(0xFF9AA79F)),
        errorText: error,
        errorStyle: AuthText.urbanist(size: 12.5, color: AccountStyle.error),
        filled: true,
        fillColor: field,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ink, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AccountStyle.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AccountStyle.error, width: 1.4),
        ),
      );

  static AppBar appBar(
    BuildContext context,
    String title, {
    VoidCallback? onBack,
    List<Widget>? actions,
  }) => AppBar(
    automaticallyImplyLeading: false,
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    leading: onBack == null
        ? null
        : IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, color: ink),
          ),
    titleSpacing: onBack == null ? 20 : 0,
    title: Text(
      title,
      style: AuthText.urbanist(size: 18, weight: FontWeight.w700),
    ),
    actions: actions,
  );
}

/// Black call to action in the account screens.
class AccountButton extends StatelessWidget {
  const AccountButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: outlined ? AccountStyle.ink : Colors.white,
            ),
          )
        : Text(
            label,
            style: AuthText.urbanist(
              size: 15,
              weight: FontWeight.w700,
              color: outlined ? AccountStyle.ink : Colors.white,
            ),
          );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    return SizedBox(
      height: 52,
      child: outlined
          ? OutlinedButton(
              onPressed: busy ? null : onPressed,
              style: OutlinedButton.styleFrom(
                shape: shape,
                side: const BorderSide(color: AccountStyle.ink, width: 1.2),
                foregroundColor: AccountStyle.ink,
              ),
              child: child,
            )
          : FilledButton(
              onPressed: busy ? null : onPressed,
              style: FilledButton.styleFrom(
                shape: shape,
                backgroundColor: AccountStyle.ink,
                disabledBackgroundColor: AuthColors.disabled,
                foregroundColor: Colors.white,
              ),
              child: child,
            ),
    );
  }
}

/// A small coloured status chip.
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AuthText.urbanist(
          size: 12,
          weight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// A short error line under a form or a list.
class AccountErrorLine extends StatelessWidget {
  const AccountErrorLine(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
          message,
          key: const ValueKey('account-error'),
          style: AuthText.urbanist(
            size: 13,
            height: 1.4,
            color: AccountStyle.error,
          ),
        ),
      ),
    );
  }
}

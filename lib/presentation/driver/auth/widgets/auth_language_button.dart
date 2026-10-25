import 'package:flutter/material.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_style.dart';
import 'package:movera/widgets/movera_modal_sheet.dart';

/// The globe in the sign-in screens' top corner: an ink outline globe with
/// the current language as two letters beside it and a small chevron
/// underneath. Opens a small sheet of the app languages, each in its own
/// name.
///
/// It changes the language through [DriverLanguage], the same choice and
/// phone storage Settings uses, so the screen redraws at once (the app
/// root rebuilds every screen on a change) and the choice is kept.
class AuthLanguageButton extends StatelessWidget {
  const AuthLanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: DriverLanguage.current,
      builder: (context, code, _) => Tooltip(
        message: tr.authChangeLanguage,
        child: Semantics(
          button: true,
          label: tr.authChangeLanguage,
          value: DriverLanguage.names[code] ?? code,
          onTap: () => showAuthLanguageSheet(context),
          excludeSemantics: true,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => showAuthLanguageSheet(context),
              child: SizedBox(
                key: const ValueKey('auth-language'),
                width: 56,
                height: 48,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Large text: the pair shrinks into the button rather
                    // than overflowing it.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CustomPaint(
                            size: Size(20, 20),
                            painter: _GlobePainter(),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            code.toUpperCase(),
                            style: AuthText.body(
                              size: 12,
                              weight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 1),
                    const Icon(
                      Icons.expand_more_rounded,
                      size: 13,
                      color: AuthColors.ink,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A plain ink globe: circle, equator, meridian and one ellipse.
class _GlobePainter extends CustomPainter {
  const _GlobePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    final ink = Paint()
      ..color = AuthColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r - 0.75, ink);
    canvas.drawLine(Offset(0.75, r), Offset(size.width - 0.75, r), ink);
    canvas.drawLine(Offset(r, 0.75), Offset(r, size.height - 0.75), ink);
    canvas.drawOval(
      Rect.fromCenter(center: c, width: r * 0.95, height: size.height - 1.5),
      ink,
    );
  }

  @override
  bool shouldRepaint(_GlobePainter oldDelegate) => false;
}

/// The language sheet: [DriverLanguage.available], the current one ticked.
Future<void> showAuthLanguageSheet(BuildContext context) async {
  final current = DriverLanguage.current.value;
  final next = await showMoveraModalSheet<String>(
    context: context,
    fitContent: true,
    builder: (sheet) => Material(
      color: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AuthColors.stepIdle,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                child: Semantics(
                  header: true,
                  child: Text(tr.language, style: AuthText.cardTitle()),
                ),
              ),
              for (final code in DriverLanguage.available)
                _LanguageRow(
                  code: code,
                  selected: code == current,
                  onTap: () => Navigator.of(sheet).pop(code),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  if (next == null || next == current) return;
  await DriverLanguage.choose(next);
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.code,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = DriverLanguage.names[code] ?? code;
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('auth-language-$code'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: selected
              ? BoxDecoration(
                  color: AuthColors.noteGround,
                  borderRadius: BorderRadius.circular(14),
                )
              : null,
          child: Row(
            children: [
              Container(
                width: 34,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: AuthColors.line),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  code.toUpperCase(),
                  style: AuthText.body(
                    size: 11,
                    weight: FontWeight.w600,
                    color: AuthColors.muted,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  name,
                  style: AuthText.body(
                    size: 15,
                    weight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: AuthColors.green,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

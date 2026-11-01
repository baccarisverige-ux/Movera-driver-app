import 'package:flutter/material.dart';
import 'package:movera/widgets/owned_route_exit.dart';

/// G3-D7 (owner 2026-10-30, "Black/green"): every dialog of the driver
/// app ("Go offline?" and every similar box) in Movera's black/green
/// style, never Material's default purple.
///
/// Wrap a dialog in [MoveraDialogTheme]; [moveraDialogThemeData] is also
/// the app theme's dialog part (main.dart), so a dialog without the
/// wrapper looks the same.
class MoveraDialogTheme extends StatelessWidget {
  const MoveraDialogTheme({super.key, required this.child});

  final Widget child;

  /// Movera ink: titles and the main action.
  static const Color ink = Color(0xFF111614);

  /// Movera green: the other actions.
  static const Color green = Color(0xFF19865C);

  /// Body text.
  static const Color muted = Color(0xFF4F5B57);

  @override
  Widget build(BuildContext context) =>
      Theme(data: moveraDialogThemeData(Theme.of(context)), child: child);
}

/// [base] with Movera's dialog look: white box, black title, black main
/// button, green text buttons and switches.
ThemeData moveraDialogThemeData(ThemeData base) {
  const ink = MoveraDialogTheme.ink;
  const green = MoveraDialogTheme.green;
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: ink,
      onPrimary: Colors.white,
      secondary: green,
      onSecondary: Colors.white,
      surface: Colors.white,
      surfaceTint: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      // From the app's text theme, so the app's font stays.
      titleTextStyle: (base.textTheme.headlineSmall ?? const TextStyle())
          .copyWith(
            color: ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
      contentTextStyle: (base.textTheme.bodyMedium ?? const TextStyle())
          .copyWith(
            color: MoveraDialogTheme.muted,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ink,
        foregroundColor: Colors.white,
        shape: buttonShape,
        textStyle: (base.textTheme.labelLarge ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ink,
        foregroundColor: Colors.white,
        shape: buttonShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: green,
        shape: buttonShape,
        textStyle: (base.textTheme.labelLarge ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? Colors.white : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? green : null,
      ),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? green : null,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? green : null,
      ),
    ),
  );
}

/// A yes/no box in Movera's style; true when [confirm] was tapped.
Future<bool?> showMoveraConfirm(
  BuildContext context, {
  required String title,
  required String body,
  required String cancel,
  required String confirm,
}) => showDialog<bool>(
  context: context,
  builder: (context) => MoveraDialogTheme(
    child: AlertDialog(
      // G8: the box is read by its title; without this Flutter reads the
      // generic "Alert" ("Varning") on Android and web.
      semanticLabel: title,
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => popOwned(context, false),
          child: Text(cancel),
        ),
        FilledButton(
          onPressed: () => popOwned(context, true),
          child: Text(confirm),
        ),
      ],
    ),
  ),
);

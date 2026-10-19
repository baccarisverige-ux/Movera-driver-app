import 'package:flutter/material.dart';
import 'package:movera/constants/appcolors.dart';
import 'package:movera/constants/appfontweight.dart';

import 'custom_text_widget.dart';
import 'responsive_size.dart';

class CustomButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final double borderRadius;
  final double height;
  final double width;
  final Color btncolor;
  final String centerContent;
  final double borderwidth;
  final Color borderColor;
  final Color textColor;
  final double fontSize;
  final Widget icon;
  final Widget loader;
  final bool isLoading;
  final double iconSize;
  const CustomButton({
    super.key,
    this.onPressed,
    this.borderRadius = 12,
    this.height = 56,
    this.width = double.infinity,
    this.btncolor = AppColor.btn,
    required this.centerContent,
    this.borderwidth = 0,
    this.borderColor = Colors.transparent,
    this.textColor = AppColor.whiteText,
    this.fontSize = 16,
    this.icon = const SizedBox(),
    this.loader = const SizedBox(),
    this.isLoading = false,
    this.iconSize = 20,
  });

  /// Grey fill and text for a button that cannot be pressed, so it does
  /// not look like an active one (UI-11).
  static const Color disabledFill = Color(0xFFE4E7E9);
  static const Color disabledText = Color(0xFF8A9297);

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null && !isLoading;
    final fill = !disabled || btncolor.a == 0 ? btncolor : disabledFill;
    final border = !disabled || borderColor.a == 0
        ? borderColor
        : disabledText;
    final text = disabled ? disabledText : textColor;
    return MaterialButton(
      clipBehavior: Clip.none,
      padding: EdgeInsets.zero,
      onPressed: isLoading ? null : onPressed,
      height: ResSize.h * height,
      minWidth: width,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      color: null,
      child: Container(
        constraints: BoxConstraints(minHeight: ResSize.h * height),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        width: width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          color: fill,
          border: Border.all(color: border, width: borderwidth),
        ),
        child: Center(
          heightFactor: 1,
          child: isLoading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [loader],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    icon,
                    Flexible(
                      child: TextWidget(
                        fontSize: fontSize,
                        textAlign: TextAlign.center,
                        text: centerContent,
                        color: text,
                        fontWeight: fwSemiBold,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

/// Shows a bottom sheet pinned to the hittable surface.
///
/// [showModalBottomSheet] lays out in the navigator overlay using the
/// FlutterView MediaQuery (800x600 in widget tests) and Material 3's
/// `Align(heightFactor: 1)` wrapper. Buttons then land below the surface
/// set by [TestWidgetsFlutterBinding.setSurfaceSize].
Future<T?> showMoveraModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double heightFactor = 0.78,
  Color barrierColor = const Color(0x59000000),
  Color backgroundColor = Colors.transparent,
  bool barrierDismissible = true,
  // Size to the content, up to [heightFactor] of the screen.
  bool fitContent = false,
  // With [fitContent]: never shorter than this share of the screen, so a
  // sheet keeps its usual size and only grows when its content needs it.
  double minHeightFactor = 0,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierDismissible ? 'Dismiss' : null,
    barrierColor: barrierColor,
    transitionDuration: Duration.zero,
    pageBuilder: (sheetContext, animation, secondaryAnimation) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final media = MediaQuery.of(context);
          final width = constraints.maxWidth;
          final keyboard = media.viewInsets.bottom.clamp(
            0.0,
            constraints.maxHeight,
          );
          final availableHeight = constraints.maxHeight - keyboard;
          final height = availableHeight * heightFactor;
          return Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: MediaQuery(
              data: media.copyWith(
                size: Size(width, height),
                viewInsets: EdgeInsets.zero,
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: PointerInterceptor(
                  child: ColoredBox(
                    color: backgroundColor,
                    child: fitContent
                        ? ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: width,
                              maxWidth: width,
                              minHeight: math.min(
                                height,
                                availableHeight * minHeightFactor,
                              ),
                              maxHeight: height,
                            ),
                            child: Builder(builder: builder),
                          )
                        : SizedBox(
                            width: width,
                            height: height,
                            child: Builder(builder: builder),
                          ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return child;
    },
  );
}

/// Bottom sheet body that fills the bounded [showMoveraModalSheet] box.
class MoveraModalSheet extends StatelessWidget {
  const MoveraModalSheet({
    super.key,
    required this.child,
    this.heightFactor = 0.78,
    this.color = const Color(0xFFF7F9F9),
    this.radius = 26,
  });

  final Widget child;
  final double heightFactor;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final surface = LayoutViewport.surfaceSize(context);
        final width = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : surface.width;
        final height =
            constraints.maxHeight.isFinite && constraints.maxHeight > 0
            ? constraints.maxHeight
            : surface.height * heightFactor;

        return Material(
          color: color,
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
          ),
          child: SizedBox(
            width: width,
            height: height,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(size: Size(width, height)),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

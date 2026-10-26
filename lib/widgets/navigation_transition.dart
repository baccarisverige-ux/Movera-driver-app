import 'package:flutter/material.dart';

Duration _motionDuration(int milliseconds) =>
    WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations
    ? Duration.zero
    : Duration(milliseconds: milliseconds);

/// Full-screen slide-up route that is *not* a [PageRoute].
///
/// [HeroController] only runs for [PageRoute]s and parks the incoming page
/// [ModalRoute.offstage] until a second frame. Widget tests that pump once
/// after [Navigator.push] would otherwise miss the page with
/// `skipOffstage: true`.
class BottomToTopTransition extends ModalRoute<void> {
  BottomToTopTransition(this.page);

  final Widget page;

  @override
  bool get opaque => true;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => _motionDuration(280);

  @override
  Duration get reverseTransitionDuration => _motionDuration(200);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return page;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.fastLinearToSlowEaseIn,
      reverseCurve: Curves.fastOutSlowIn,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    );
  }
}

/// Active-ride handoff route.
///
/// Google Maps is a platform view on web/iOS Safari. Moving the whole incoming
/// ride page with a route transform can make that platform view briefly detach
/// and re-attach, which looks like the pickup screen disappears and returns.
/// Mount the active ride atomically instead; ride-sheet/map motion continues
/// inside [AcceptRide] itself.
class ActiveRideTransition extends ModalRoute<void> {
  ActiveRideTransition(this.page);

  final Widget page;

  @override
  bool get opaque => true;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => _motionDuration(160);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return page;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

class TopToBottomTransition extends PageRouteBuilder {
  final Widget page;

  TopToBottomTransition(this.page)
    : super(
        pageBuilder: (context, animation, anotherAnimation) => page,
        transitionDuration: _motionDuration(280),
        reverseTransitionDuration: _motionDuration(200),
        transitionsBuilder: (context, animation, anotherAnimation, child) {
          if (MediaQuery.disableAnimationsOf(context)) {
            return child;
          }
          animation = CurvedAnimation(
            curve: Curves.fastLinearToSlowEaseIn,
            parent: animation,
            reverseCurve: Curves.fastOutSlowIn,
          );
          return Align(
            alignment: Alignment.topCenter,
            child: SizeTransition(
              sizeFactor: animation,
              alignment: Alignment.center,
              child: child,
            ),
          );
        },
      );
}

class SwitchTransition extends PageRouteBuilder {
  final Widget page;

  SwitchTransition(this.page)
    : super(
        pageBuilder: (context, animation, anotherAnimation) => page,
        transitionDuration: _motionDuration(280),
        reverseTransitionDuration: _motionDuration(200),
        transitionsBuilder: (context, animation, anotherAnimation, child) {
          if (MediaQuery.disableAnimationsOf(context)) {
            return child;
          }
          animation = CurvedAnimation(
            curve: Curves.fastLinearToSlowEaseIn,
            parent: animation,
            reverseCurve: Curves.fastOutSlowIn,
          );
          return Align(
            alignment: Alignment.center,
            child: SizeTransition(
              axis: Axis.horizontal,
              sizeFactor: animation,
              alignment: Alignment.center,
              child: child,
            ),
          );
        },
      );
}

class LeftToRightTransition extends PageRouteBuilder {
  final Widget page;

  LeftToRightTransition(this.page)
    : super(
        pageBuilder: (context, animation, anotherAnimation) => page,
        transitionDuration: _motionDuration(280),
        reverseTransitionDuration: _motionDuration(200),
        transitionsBuilder: (context, animation, anotherAnimation, child) {
          if (MediaQuery.disableAnimationsOf(context)) {
            return child;
          }
          animation = CurvedAnimation(
            curve: Curves.fastLinearToSlowEaseIn,
            parent: animation,
            reverseCurve: Curves.fastOutSlowIn,
          );
          return Align(
            alignment: Alignment.centerLeft,
            child: SizeTransition(
              axis: Axis.horizontal,
              sizeFactor: animation,
              alignment: Alignment.center,
              child: child,
            ),
          );
        },
      );
}

class RightToLeftTransition extends PageRouteBuilder {
  final Widget page;

  RightToLeftTransition(this.page)
    : super(
        pageBuilder: (context, animation, anotherAnimation) => page,
        transitionDuration: _motionDuration(280),
        reverseTransitionDuration: _motionDuration(200),
        transitionsBuilder: (context, animation, anotherAnimation, child) {
          if (MediaQuery.disableAnimationsOf(context)) {
            return child;
          }
          animation = CurvedAnimation(
            curve: Curves.fastLinearToSlowEaseIn,
            parent: animation,
            reverseCurve: Curves.fastOutSlowIn,
          );
          return Align(
            alignment: Alignment.centerRight,
            child: SizeTransition(
              axis: Axis.horizontal,
              sizeFactor: animation,
              alignment: Alignment.center,
              child: child,
            ),
          );
        },
      );
}

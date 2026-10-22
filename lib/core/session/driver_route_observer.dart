import 'package:flutter/widgets.dart';

/// The app's route observer. Subscribers hear about every modal route,
/// dialogs and bottom sheets included; [pages] only about full screens,
/// and is told after them.
class DriverRouteObserver extends RouteObserver<ModalRoute<void>> {
  /// driver-r4-31: a sheet or a dialog leaves the screen under it visible,
  /// so a screen that pauses itself while covered listens here.
  final pages = _ScreenObserver();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    pages.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    pages.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    pages.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    pages.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

/// driver-r5-28: a full screen is an opaque route, whatever its class.
/// The trip (ActiveRideTransition, BottomToTopTransition) and the side
/// menu's pages are plain [ModalRoute]s, not [PageRoute]s.
class _ScreenObserver extends RouteObserver<ModalRoute<dynamic>> {
  static bool _opaque(Route<dynamic> route) =>
      route is ModalRoute && route.opaque;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_opaque(route)) { super.didPush(route, previousRoute); }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_opaque(route)) { super.didPop(route, previousRoute); }
  }
}

/// A [RouteAware] for [DriverRouteObserver.pages], from two callbacks.
class PageCover with RouteAware {
  PageCover({required this.covered, required this.uncovered});

  /// A full screen was pushed over this route.
  final VoidCallback covered;

  /// The full screen over this route closed.
  final VoidCallback uncovered;

  @override
  void didPushNext() => covered();

  @override
  void didPopNext() => uncovered();
}

final driverRouteObserver = DriverRouteObserver();

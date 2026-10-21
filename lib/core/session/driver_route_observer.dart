import 'package:flutter/widgets.dart';

/// The app's route observer. Subscribers hear about every modal route,
/// dialogs and bottom sheets included; [pages] only about full screens,
/// and is told after them.
class DriverRouteObserver extends RouteObserver<ModalRoute<void>> {
  /// driver-r4-31: a sheet or a dialog leaves the screen under it visible,
  /// so a screen that pauses itself while covered listens here.
  final pages = RouteObserver<PageRoute<dynamic>>();

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

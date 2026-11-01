import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/navigation/navigation_controller.dart';
import 'package:movera/core/routing/route_instruction.dart';

/// G5 live test 2026-10-31: the server sent `eta` (303 s, 1863 m, osrm)
/// but the island said "Route unavailable – try again" because the
/// phone's own route fetch failed. The server ETA wins; the route error
/// is shown only without one.
void main() {
  test('a server ETA hides the phone\'s own route error', () {
    for (final status in [
      NavigationRouteStatus.unavailableRetry,
      NavigationRouteStatus.unavailableCheckLocation,
    ]) {
      expect(
        NavigationRouteStatus.shown(status.text, hasServerEta: true),
        isNull,
      );
      expect(
        NavigationRouteStatus.shown(status.text, hasServerEta: false),
        status.text,
      );
    }
  });

  test('re-test: "Location updating…" / "Route updating…" give way to a '
      'fresh server ETA in the header banner', () {
    for (final status in [
      tr.locationUpdatingEllipsis,
      NavigationRouteStatus.updating.text,
    ]) {
      expect(NavigationRouteStatus.shown(status, hasServerEta: true), isNull);
      expect(NavigationRouteStatus.shown(status, hasServerEta: false), status);
    }
    final banner = NavigationRouteStatus.bannerWithServerEta(
      NavigationBanner(
        primary: tr.navToPickup,
        distanceLabel: tr.locationUpdatingEllipsis,
        status: tr.locationUpdatingEllipsis,
      ),
      '4 min · 1.3 km',
    )!;
    expect(banner.status, isNull);
    expect(banner.distanceLabel, '4 min · 1.3 km');
    expect(banner.primary, tr.navToPickup);
  });

  test('other statuses stay (recalculating, a lost fix)', () {
    final recalculating = NavigationRouteStatus.recalculating.text;
    expect(
      NavigationRouteStatus.shown(recalculating, hasServerEta: true),
      recalculating,
    );
    expect(
      NavigationRouteStatus.shown(
        tr.stopLocationUnavailable,
        hasServerEta: true,
      ),
      tr.stopLocationUnavailable,
    );
    expect(NavigationRouteStatus.shown(null, hasServerEta: true), isNull);
  });
}

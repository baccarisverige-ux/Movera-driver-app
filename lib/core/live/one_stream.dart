import '../dispatch/api_dispatch_repository.dart';
import 'live_driver_config.dart';

/// L20 stream (contract v0.18.122, contract.json#driverOneStream; owner
/// 2026-11-17 "Yes, with switch (Rec.)", Rules audits/load/l20-1-design.md
/// §3): one live connection per driver phone. While the zone's
/// `DriverAppConfig.realtime.oneStream` is on and the driver is online, the
/// offer feed opens `GET /driver/stream` and hands its settings events to
/// [config]; [config] then opens no stream of its own. Off, offline, or a
/// 404 from an older server: the two streams as before. A change of the
/// switch or of the zone opens the online feed again in the right form.
/// The trip stream is not touched.
void linkOneStream({
  required ApiDispatchRepository dispatch,
  required LiveDriverConfig config,
}) {
  dispatch.oneStream = OneStreamLink(
    wanted: () => config.oneStream,
    zoneId: () => config.streamZone,
    configVersion: () => config.streamVersion,
    deliver: config.deliver,
    attached: config.useOneStream,
    opened: config.oneStreamOpened,
  );
  config
    ..onStreamZoneChanged = dispatch.reopen
    ..addListener(() {
      if (dispatch.oneStreamRefused) return;
      if (dispatch.usesOneStream != config.oneStream) dispatch.reopen();
    });
}

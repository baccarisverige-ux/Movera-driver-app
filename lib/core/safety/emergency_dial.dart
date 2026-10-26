enum EmergencyDialResult { opened, unavailable }

Future<EmergencyDialResult> handoffEmergencyDial(
  Future<bool> Function() launch,
) async {
  try {
    return await launch()
        ? EmergencyDialResult.opened
        : EmergencyDialResult.unavailable;
  } catch (_) {
    return EmergencyDialResult.unavailable;
  }
}

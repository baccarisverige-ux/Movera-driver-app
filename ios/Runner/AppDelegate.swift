import Flutter
import UIKit
import GoogleMaps
import DeviceCheck

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let mapsKey = Bundle.main.object(forInfoDictionaryKey: "GoogleMapsApiKey") as? String,
       !mapsKey.isEmpty,
       mapsKey != "$(GOOGLE_MAPS_API_KEY)" {
      GMSServices.provideAPIKey(mapsKey)
    }
    GeneratedPluginRegistrant.register(with: self)
    // driver-29: Ride check recordings stay out of iCloud and Finder backups.
    if let registrar = self.registrar(forPlugin: "MoveraBackupExclusion") {
      let channel = FlutterMethodChannel(
        name: "movera/backup", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "excludeFromBackup",
              let arguments = call.arguments as? [String: Any],
              let path = arguments["path"] as? String else {
          result(FlutterMethodNotImplemented)
          return
        }
        var url = URL(fileURLWithPath: path, isDirectory: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        do {
          try url.setResourceValues(values)
          result(nil)
        } catch {
          result(FlutterError(
            code: "backup", message: error.localizedDescription, details: nil))
        }
      }
    }
    // Audit 2026-11-20 item 2: the screen stays on during an active trip
    // (lib/core/device/screen_awake.dart).
    if let registrar = self.registrar(forPlugin: "MoveraScreenAwake") {
      let screen = FlutterMethodChannel(
        name: "se.movera.driver/screen", binaryMessenger: registrar.messenger())
      screen.setMethodCallHandler { call, result in
        guard call.method == "keepOn" else {
          result(FlutterMethodNotImplemented)
          return
        }
        UIApplication.shared.isIdleTimerDisabled = (call.arguments as? Bool) == true
        result(nil)
      }
    }
    // Contract v0.18.138 (deviceCheck.check, iPhone): Apple App Attest. INACTIVE
    // until the owner's Apple account exists: the Dart side calls this only in
    // a build made with --dart-define=APP_ATTEST=true and the App Attest
    // capability. A new key per request, attested with the app's binding as
    // clientDataHash. Any failure answers nil: the request goes without a check.
    if let registrar = self.registrar(forPlugin: "MoveraDeviceCheck") {
      let channel = FlutterMethodChannel(
        name: "movera/device_check", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "appAttest",
              let arguments = call.arguments as? [String: Any],
              let hashText = arguments["clientDataHash"] as? String,
              let hash = Data(base64Encoded: hashText) else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard #available(iOS 14.0, *), DCAppAttestService.shared.isSupported else {
          result(nil)
          return
        }
        let service = DCAppAttestService.shared
        service.generateKey { keyId, error in
          guard let keyId = keyId, error == nil else {
            DispatchQueue.main.async { result(nil) }
            return
          }
          service.attestKey(keyId, clientDataHash: hash) { attestation, error in
            DispatchQueue.main.async {
              guard let attestation = attestation, error == nil else {
                result(nil)
                return
              }
              result(["keyId": keyId, "attestation": attestation.base64EncodedString()])
            }
          }
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

import Flutter
import UIKit
import GoogleMaps

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
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

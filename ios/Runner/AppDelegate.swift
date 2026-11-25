import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // v0.18.157 (owner 2026-11-24 "Add to admin all kind of crash"): the
    // native crash catcher first, so a crash during start is caught too.
    MoveraCrashCatcher.install()
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
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

// v0.18.157 crash catcher (contract.json#crashCatcher.nativeReason), no third-party SDK:
// an uncaught NSException or a fatal signal writes its name, reason and stack to
// Application Support/movera_native_crash.json; the Dart side reads and deletes it at the
// next launch and sends it as a native_crash report. movera_device.json carries the device
// model and the iOS version. Keep the file names in step with lib/core/observability/crash_files.dart.
private var moveraCrashPath: [CChar] = []
private var moveraSignalBodies: [Int32: [CChar]] = [:]
private var moveraOldActions: [Int32: sigaction] = [:]
private var moveraOldExceptionHandler: (@convention(c) (NSException) -> Void)?

private func moveraSignalHandler(_ sig: Int32) {
  if let body = moveraSignalBodies[sig], !moveraCrashPath.isEmpty {
    moveraCrashPath.withUnsafeBufferPointer { path in
      // O_EXCL: a signal after an uncaught exception never overwrites its file.
      let fd = open(path.baseAddress!, O_WRONLY | O_CREAT | O_EXCL, 0o644)
      if fd >= 0 {
        body.withUnsafeBufferPointer { bytes in _ = write(fd, bytes.baseAddress!, bytes.count - 1) }
        close(fd)
      }
    }
  }
  // Hand the signal on as before (the previous handler, else the default: the app ends).
  if var old = moveraOldActions[sig] {
    sigaction(sig, &old, nil)
  } else {
    signal(sig, SIG_DFL)
  }
  raise(sig)
}

enum MoveraCrashCatcher {
  static func install() {
    let fm = FileManager.default
    guard let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    let file = dir.appendingPathComponent("movera_native_crash.json")
    moveraCrashPath = Array(file.path.utf8CString)
    writeDevice(dir.appendingPathComponent("movera_device.json"))
    moveraOldExceptionHandler = NSGetUncaughtExceptionHandler()
    NSSetUncaughtExceptionHandler { exception in
      let body: [String: String] = [
        "name": exception.name.rawValue,
        "reason": exception.reason ?? "",
        "stack": exception.callStackSymbols.prefix(80).joined(separator: "\n"),
      ]
      if let data = try? JSONSerialization.data(withJSONObject: body) {
        let path = moveraCrashPath.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
        try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
      }
      moveraOldExceptionHandler?(exception)
    }
    let names: [(Int32, String)] = [(SIGABRT, "SIGABRT"), (SIGSEGV, "SIGSEGV"), (SIGBUS, "SIGBUS"), (SIGILL, "SIGILL"), (SIGFPE, "SIGFPE"), (SIGTRAP, "SIGTRAP")]
    for (sig, name) in names {
      moveraSignalBodies[sig] = Array("{\"name\":\"\(name)\",\"reason\":\"signal \(sig)\",\"stack\":\"\"}".utf8CString)
      var action = sigaction()
      action.__sigaction_u.__sa_handler = moveraSignalHandler
      sigemptyset(&action.sa_mask)
      var old = sigaction()
      if sigaction(sig, &action, &old) == 0 { moveraOldActions[sig] = old }
    }
  }

  private static func writeDevice(_ url: URL) {
    var info = utsname()
    uname(&info)
    let model = withUnsafePointer(to: &info.machine) {
      $0.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) { String(cString: $0) }
    }
    let body = ["model": model, "os": "iOS \(UIDevice.current.systemVersion)"]
    if let data = try? JSONSerialization.data(withJSONObject: body) { try? data.write(to: url, options: .atomic) }
  }
}

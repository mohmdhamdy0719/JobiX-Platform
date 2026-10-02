import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "jobix/storage", binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { call, result in
        guard call.method == "excludeFromBackup",
              let path = call.arguments as? String else {
          result(FlutterMethodNotImplemented)
          return
        }
        // Restrict the channel to Application Support, never arbitrary paths.
        guard let root = FileManager.default.urls(
          for: .applicationSupportDirectory, in: .userDomainMask).first,
          path.hasPrefix(root.path + "/jobix/") else {
          result(FlutterError(code: "INVALID_PATH", message: nil, details: nil))
          return
        }
        do {
          var url = URL(fileURLWithPath: path, isDirectory: true)
          var values = URLResourceValues()
          values.isExcludedFromBackup = true
          try url.setResourceValues(values)
          result(nil)
        } catch {
          result(FlutterError(code: "BACKUP_EXCLUSION_FAILED", message: nil, details: nil))
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

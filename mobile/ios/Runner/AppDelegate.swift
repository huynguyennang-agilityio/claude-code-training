import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // "Open settings" on the health gate: the Settings page of this app, where
    // Health access can be turned on again.
    let settings = FlutterMethodChannel(
      name: "stridequest/settings",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    settings.setMethodCallHandler { call, result in
      guard call.method == "open", let url = URL(string: UIApplication.openSettingsURLString) else {
        result(FlutterMethodNotImplemented)
        return
      }
      UIApplication.shared.open(url)
      result(nil)
    }
  }
}

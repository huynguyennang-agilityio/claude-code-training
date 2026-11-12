import Flutter
import HealthKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private lazy var healthStore = HKHealthStore()

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

    // Whether HealthKit would still show its permission dialog for the read
    // types, which is true again after a reinstall: the keychain keeps the
    // app's own count of dialogs, HealthKit forgets the answer.
    let health = FlutterMethodChannel(
      name: "stridequest/health",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    health.setMethodCallHandler { [weak self] call, result in
      guard call.method == "requestStatus" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let identifiers = call.arguments as? [String] else {
        result(FlutterError(code: "bad_args", message: "Expected a list of identifiers", details: nil))
        return
      }
      guard HKHealthStore.isHealthDataAvailable(), let store = self?.healthStore else {
        result("unknown")
        return
      }
      var types = Set<HKObjectType>()
      for identifier in identifiers {
        if let type = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: identifier))
          ?? HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier(rawValue: identifier)) {
          types.insert(type)
        } else {
          result(FlutterError(code: "bad_args", message: "Unknown identifier \(identifier)", details: nil))
          return
        }
      }
      store.getRequestStatusForAuthorization(toShare: [], read: types) { status, error in
        DispatchQueue.main.async {
          if let error = error {
            result(FlutterError(code: "health_error", message: error.localizedDescription, details: nil))
            return
          }
          switch status {
          case .shouldRequest: result("shouldRequest")
          case .unnecessary: result("unnecessary")
          default: result("unknown")
          }
        }
      }
    }
  }
}

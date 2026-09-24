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
    ScreenWakeChannel.register(with: engineBridge.pluginRegistry)
  }
}

/// "Keep the screen on" — SPEC §5.6.
///
///   MethodChannel "ktc.torque/screen"
///     setKeepAwake(Bool) -> nil
///
/// The idle timer is the whole of iOS's part; Dart decides *when* — a live
/// link and the setting on. It lives here rather than in a plugin package so
/// the app's own review covers it (AC-14: nothing on the wire but the store).
enum ScreenWakeChannel {
  static let name = "ktc.torque/screen"

  static func register(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "TorqueScreenWake") else { return }
    let channel = FlutterMethodChannel(name: name, binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "setKeepAwake":
        UIApplication.shared.isIdleTimerDisabled = (call.arguments as? Bool) ?? false
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

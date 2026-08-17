import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Needed by flutter_local_notifications for taps and foreground
    // presentation. Doesn't prompt; permission is requested at the first START.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // App-local plugins aren't in the generated registrant.
    if let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "LiveSessionSurfacePlugin"
    ) {
      LiveSessionSurfacePlugin.register(with: registrar)
    }

    // Must exist before the first frame: `StartFocusSessionIntent` goes
    // through it.
    if let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "QuietModePlugin"
    ) {
      QuietModePlugin.register(with: registrar)
    }

    if let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "GardenSharePlugin"
    ) {
      GardenSharePlugin.register(with: registrar)
    }
  }
}

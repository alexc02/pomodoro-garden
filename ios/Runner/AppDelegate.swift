import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Ticket 06. flutter_local_notifications asks for this: it is what lets the
    // plugin see a notification the user tapped, and what lets it decide how a
    // notification that fires while the app is in front is presented. Setting
    // the delegate does not ask the user for anything — the app requests
    // notification permission at the first START, not at launch. See
    // `lib/src/notifications/local_session_notifications.dart`.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Ticket 08's live session surface. Registered by hand rather than by the
    // generated registrant because it is this app's own code and not a pub
    // package — the same position `LiveSessionSurfacePlugin.kt` is in on
    // Android, where `MainActivity` registers it.
    if let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "LiveSessionSurfacePlugin"
    ) {
      LiveSessionSurfacePlugin.register(with: registrar)
    }

    // Ticket 11's quiet mode, registered by hand for the same reason. It is
    // also what a Shortcut running `StartFocusSessionIntent` reaches Dart
    // through, so it has to exist before the first frame rather than at the
    // first time something asks about a Focus mode.
    if let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "QuietModePlugin"
    ) {
      QuietModePlugin.register(with: registrar)
    }

    // REQ-035's share sheet, registered by hand for the same reason: this app's
    // own code rather than a pub package. See `GardenSharePlugin.swift` for why
    // saving to the photo library needs no permission call here and does need
    // `NSPhotoLibraryAddUsageDescription` in `Info.plist`.
    if let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "GardenSharePlugin"
    ) {
      GardenSharePlugin.register(with: registrar)
    }
  }
}

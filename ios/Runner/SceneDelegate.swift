import Flutter
import UIKit

/// The app's scene, and the route a tap on the live session surface comes in
/// by.
///
/// Tapping a Live Activity opens the URL the widget declared, and an app with a
/// scene manifest — which this one has — is handed URLs here rather than at
/// `UIApplicationDelegate`. Both directions have to be covered, and they are
/// genuinely different moments:
///
/// - **`willConnectTo`** is the app *starting because of* the tap. There is no
///   Dart running yet, so the plugin holds the tap until something asks for it.
/// - **`openURLContexts`** is the app already running. The tap can be delivered
///   the moment it arrives.
class SceneDelegate: FlutterSceneDelegate {

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    for context in connectionOptions.urlContexts {
      LiveSessionSurfacePlugin.shared?.handle(url: context.url, hasStarted: false)
    }
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)

    for context in URLContexts {
      LiveSessionSurfacePlugin.shared?.handle(url: context.url, hasStarted: true)
    }
  }
}

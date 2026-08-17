import Flutter
import UIKit

/// Live Activity taps arrive here as URLs (scene apps don't get them in
/// `UIApplicationDelegate`). `willConnectTo` is a cold launch, so the plugin
/// holds the tap; `openURLContexts` is while running.
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

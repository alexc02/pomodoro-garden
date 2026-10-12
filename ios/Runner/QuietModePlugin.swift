import Flutter
import Foundation

/// Quiet mode channel on iOS; same channel as `QuietModePlugin.kt`.
///
/// No public API can turn a Focus mode on (Focus Status is read-only and
/// `SetFocusFilterIntent` only reports changes), so this reports
/// `byAutomation`: the user builds a Shortcut with Set Focus plus
/// `StartFocusSessionIntent`.
///
/// `begin`/`end` are no-ops. Dart never calls them unless access is `granted`,
/// but answering avoids a `FlutterMethodNotImplemented` error if it does.
final class QuietModePlugin: NSObject {

    static let channelName = "pip_garden/quiet_mode"

    /// For the App Intent, which can't reach the plugin registry. Fine as a
    /// singleton since there's one engine.
    private(set) static var shared: QuietModePlugin?

    /// Static: a Shortcut can launch the app and run the intent before the
    /// plugin is registered. Cleared once read.
    private static var pendingRequest = false

    static func register(with registrar: FlutterPluginRegistrar) {
        shared = QuietModePlugin(messenger: registrar.messenger())
    }

    /// Sent straight to Dart if it's listening, otherwise held (usual on a
    /// cold launch, since the intent runs while Flutter is still starting).
    static func requestSession() {
        if let plugin = shared, plugin.dartIsListening {
            plugin.channel.invokeMethod("sessionRequested", arguments: nil)
        } else {
            pendingRequest = true
        }
    }

    private let channel: FlutterMethodChannel

    /// Set once Dart has asked for the launch request.
    private var dartIsListening = false

    private init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
        super.init()

        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else {
                result(nil)
                return
            }

            switch call.method {
            case "access":
                // Not `denied`: there's nothing for the user to grant.
                result("byAutomation")

            case "requestAccess", "begin", "end":
                result(nil)

            case "takeLaunchRequest":
                result(Self.pendingRequest)
                Self.pendingRequest = false
                self.dartIsListening = true

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}

import Flutter
import Foundation

/// iOS's half of the one quiet-mode port.
///
/// Answers the same channel `QuietModePlugin.kt` answers, and gives a different
/// answer to the first question on it. **No public API can turn a Focus mode
/// on.** Apple's Focus APIs are read-only — Focus Status, and only with the
/// Communication Notifications capability — or reactive: `SetFocusFilterIntent`
/// tells an app that a Focus *changed*, which is the opposite of changing one.
/// Access appears to have tightened further in iOS 26 rather than loosened.
///
/// So this platform reports `byAutomation`: the app cannot silence the phone,
/// but the user can wire it up themselves, and `StartFocusSessionIntent` is the
/// piece they need in order to do it in one step rather than two. Everything
/// that follows from that — a recipe in settings where Android has a switch —
/// is decided in Dart from this one answer, with nothing anywhere asking which
/// phone it is running on.
///
/// `begin` and `end` are answered and do nothing. They are never called: Dart
/// only asks for silence where access is `granted`, and this platform never
/// says so. Answering them anyway is what keeps the port one shape on both
/// sides, so that a call arriving by some route nobody planned is a no-op
/// rather than a `FlutterMethodNotImplemented` reported as a failure.
final class QuietModePlugin: NSObject {

    static let channelName = "pomodoro_garden/quiet_mode"

    /// The registered plugin, for the App Intent to hand a request to.
    ///
    /// An intent runs in the app's process but nowhere near the plugin
    /// registry. There is one Flutter engine and one of these, so this is the
    /// same place `LiveSessionSurfacePlugin.shared` is honest for the same
    /// reason.
    private(set) static var shared: QuietModePlugin?

    /// A session asked for that Dart has not been told about yet.
    ///
    /// Static, because the wait can begin before this class exists: a Shortcut
    /// run against an app that is not running launches it, and the intent can
    /// perform before the engine has registered anything. Consumed on reading,
    /// so one run of the automation is one session.
    private static var pendingRequest = false

    static func register(with registrar: FlutterPluginRegistrar) {
        shared = QuietModePlugin(messenger: registrar.messenger())
    }

    /// The App Intent, run by the user's Shortcut.
    ///
    /// Delivered straight to Dart if there is Dart listening, and held if there
    /// is not — which is the ordinary case for a Shortcut that launched the
    /// app, because the intent performs while Flutter is still starting.
    static func requestSession() {
        if let plugin = shared, plugin.dartIsListening {
            plugin.channel.invokeMethod("sessionRequested", arguments: nil)
        } else {
            pendingRequest = true
        }
    }

    private let channel: FlutterMethodChannel

    /// Whether Dart has asked for the launch request yet, which is also the
    /// moment it becomes possible to call into it.
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
                // `QuietModeAccess.byAutomation`, by name. See the class
                // comment for why this is not `denied`: there is nothing here
                // for the user to grant, and no screen to send them to.
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

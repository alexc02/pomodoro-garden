import ActivityKit
import Flutter
import Foundation

/// Live session channel on iOS, backed by an ActivityKit activity. Same
/// methods and map as `LiveSessionSurfacePlugin.kt`.
///
/// Keeps at most one activity. Always works from the system's
/// `Activity<LiveSessionAttributes>.activities` rather than its own list, so a
/// relaunch after a kill finds what it left behind.
final class LiveSessionSurfacePlugin: NSObject {

    static let channelName = "pip_garden/live_session"

    /// For `SceneDelegate`, which gets the tap URL but can't reach the plugin
    /// registry. One engine, so one instance.
    private(set) static var shared: LiveSessionSurfacePlugin?

    static func register(with registrar: FlutterPluginRegistrar) {
        shared = LiveSessionSurfacePlugin(messenger: registrar.messenger())
    }

    private let channel: FlutterMethodChannel

    /// Set when a surface tap launched the app. Cleared once read.
    private var launchTapPending = false

    private init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
        super.init()

        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else {
                result(nil)
                return
            }

            switch call.method {
            case "show":
                guard let arguments = call.arguments as? [String: Any] else {
                    result(nil)
                    return
                }
                Task {
                    await self.show(arguments)
                    result(nil)
                }

            case "hide":
                Task {
                    await self.hide()
                    result(nil)
                }

            case "takeLaunchTap":
                result(self.launchTapPending)
                self.launchTapPending = false

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    /// Returns whether [url] was a surface tap. `hasStarted` is false on a cold
    /// launch, where the tap is held until Dart asks.
    @discardableResult
    func handle(url: URL, hasStarted: Bool) -> Bool {
        guard LiveSessionDeepLink.matches(url) else { return false }

        if hasStarted {
            channel.invokeMethod("opened", arguments: nil)
        } else {
            launchTapPending = true
        }
        return true
    }

    // MARK: - The activity

    private func show(_ arguments: [String: Any]) async {
        // Requesting one while the user has them disabled is an error.
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let sessionId = arguments["sessionId"] as? String ?? ""
        let state = Self.state(from: arguments)

        let showing = Activity<LiveSessionAttributes>.activities

        if let running = showing.first(where: { $0.attributes.sessionId == sessionId }) {
            // Shouldn't be any others, but clear stale ones just in case.
            await end(showing.filter { $0.id != running.id })
            await running.update(content(state))
            return
        }

        await end(showing)

        // No push updates; the app updates the activity itself.
        _ = try? Activity.request(
            attributes: LiveSessionAttributes(sessionId: sessionId),
            content: content(state),
            pushType: nil
        )
    }

    private func hide() async {
        await end(Activity<LiveSessionAttributes>.activities)
    }

    /// `.immediate`: the default keeps it on the lock screen for up to four
    /// hours, and the completion notification already covers that.
    private func end(_ activities: [Activity<LiveSessionAttributes>]) async {
        for activity in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func content(
        _ state: LiveSessionAttributes.ContentState
    ) -> ActivityContent<LiveSessionAttributes.ContentState> {
        // Stale at the due time, so the system dims it even if the app died.
        ActivityContent(state: state, staleDate: state.endsAt)
    }

    private static func state(
        from arguments: [String: Any]
    ) -> LiveSessionAttributes.ContentState {
        // Epoch millis (UTC), same as Android's `Notification.when`.
        let endsAtMillis = (arguments["endsAt"] as? NSNumber)?.doubleValue ?? 0

        return LiveSessionAttributes.ContentState(
            paused: arguments["paused"] as? Bool ?? false,
            endsAt: Date(timeIntervalSince1970: endsAtMillis / 1000),
            remainingSeconds: (arguments["remainingSeconds"] as? NSNumber)?.intValue ?? 0,
            progress: (arguments["progress"] as? NSNumber)?.doubleValue ?? 0,
            stageIndex: (arguments["stageIndex"] as? NSNumber)?.intValue ?? 0,
            stageLabel: arguments["stageLabel"] as? String ?? "",
            speciesLabel: arguments["speciesLabel"] as? String ?? ""
        )
    }
}

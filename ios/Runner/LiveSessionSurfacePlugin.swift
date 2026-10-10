import ActivityKit
import Flutter
import Foundation

/// iOS's half of the one live-session port.
///
/// Answers the same three methods `LiveSessionSurfacePlugin.kt` answers, on the
/// same channel, against the same map — and turns them into an ActivityKit
/// activity where Android turns them into a foreground service. Nothing above
/// this line knows which of the two it is talking to.
///
/// **There is exactly one activity, and this holds it.** ActivityKit will start
/// as many as it is asked for, and an app that lost track of one would leave a
/// countdown on somebody's lock screen with no session behind it. Every path in
/// here — a new session, a relaunch after the app was killed, a session that
/// was cancelled — ends up asking the same question of
/// `Activity<LiveSessionAttributes>.activities`, which is the system's list
/// rather than one this class keeps.
final class LiveSessionSurfacePlugin: NSObject {

    static let channelName = "pomodoro_garden/live_session"

    /// The registered plugin, for the scene delegate to hand a URL to.
    ///
    /// A tap on the surface arrives as a URL open, which reaches the app
    /// through `UISceneDelegate` — nowhere near the plugin registry. There is
    /// one Flutter engine and one of these, so this is the one place a static
    /// is honest rather than lazy.
    private(set) static var shared: LiveSessionSurfacePlugin?

    static func register(with registrar: FlutterPluginRegistrar) {
        shared = LiveSessionSurfacePlugin(messenger: registrar.messenger())
    }

    private let channel: FlutterMethodChannel

    /// Whether the app was launched by a tap on the surface, and Dart has not
    /// been told yet. Consumed on reading: a launch tap opens the timer once.
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

    /// A URL the app was opened or resumed with. Returns whether it was a tap
    /// on the surface.
    ///
    /// `hasStarted` is false when the app is launching *because* of the tap: the
    /// URL arrives before there is anything in Dart listening, so it waits until
    /// something asks for it.
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
        // The user can turn Live Activities off for this app from Settings, and
        // requesting one when they have is an error rather than a no-op. Nothing
        // about the session depends on the answer, so a refusal is simply
        // nothing showing.
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let sessionId = arguments["sessionId"] as? String ?? ""
        let state = Self.state(from: arguments)

        // The system's list, not one kept here — which is what makes a relaunch
        // after the app was killed find the activity it left behind rather than
        // start a second one over it.
        let showing = Activity<LiveSessionAttributes>.activities

        if let running = showing.first(where: { $0.attributes.sessionId == sessionId }) {
            // Every activity that is not this session's, gone. Reachable only
            // if one was somehow left behind; cheap insurance against a stale
            // countdown outliving the session it belongs to.
            await end(showing.filter { $0.id != running.id })
            await running.update(content(state))
            return
        }

        await end(showing)

        // `pushType: nil` — this app updates its own activity from the
        // foreground and never from a server, so there is no push token to ask
        // for and no notification-service extension behind it.
        _ = try? Activity.request(
            attributes: LiveSessionAttributes(sessionId: sessionId),
            content: content(state),
            pushType: nil
        )
    }

    private func hide() async {
        await end(Activity<LiveSessionAttributes>.activities)
    }

    /// Ends [activities] now.
    ///
    /// `.immediate` rather than the default: the default leaves the activity on
    /// the lock screen for up to four hours after it ends, which is right for a
    /// delivery that has arrived and wrong for a focus session that is over.
    /// The session's completion has already been announced by ticket 06's
    /// notification, and a countdown sitting at zero underneath it would be the
    /// second thing saying so.
    private func end(_ activities: [Activity<LiveSessionAttributes>]) async {
        for activity in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func content(
        _ state: LiveSessionAttributes.ContentState
    ) -> ActivityContent<LiveSessionAttributes.ContentState> {
        // Stale from the instant the session is due: after that the system
        // knows this activity is no longer describing anything, and dims it,
        // even if the app was killed before it could end it.
        ActivityContent(state: state, staleDate: state.endsAt)
    }

    private static func state(
        from arguments: [String: Any]
    ) -> LiveSessionAttributes.ContentState {
        // Milliseconds since the epoch, UTC — the same absolute instant Android
        // hands to `Notification.when`, and the reason neither platform needs
        // this app awake to count down.
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

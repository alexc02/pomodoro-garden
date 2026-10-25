import AppIntents
import Foundation

/// The app's half of REQ-014 on iOS: an action the user can put in a Shortcut,
/// next to the one that turns their Focus on.
///
/// **Why this exists at all.** No app can enable a Focus mode on iOS, so the
/// only route to "my phone goes quiet when a session starts" is the user
/// building it: a Shortcut that runs *Set Focus* and then this. Without this
/// intent that Shortcut would be half a recipe — the Focus would come on and
/// the session would still be waiting to be started by hand, which is two
/// actions where the requirement asked for none.
///
/// **It opens the app rather than running in the background.** The session is
/// the app's to start: it is anchored, written to the database, and joined by a
/// plant, and none of that happens in the intent's process. `openAppWhenRun`
/// launches Flutter, and the request waits in `QuietModePlugin` until there is
/// Dart alive to hear it — which is exactly the shape a tap on the live session
/// surface already has.
///
/// **The phrase is offered but nothing is donated per session.** An `AppShortcut`
/// puts the action in Shortcuts and in Siri's vocabulary the moment the app is
/// installed. Donating an interaction each time a session starts would teach
/// Siri to suggest starting one at habitual times, which is a nudge this app
/// has no business making — PRD §2 sells the absence of exactly that.
struct StartFocusSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Start a focus session"

    /// One string literal rather than anything assembled: `LocalizedStringResource`
    /// is expressible by a string *literal*, and a concatenation is not one.
    static var description = IntentDescription(
        """
        Starts a focus session of the length set in Pip Garden. \
        Put it after Set Focus in a Shortcut, and turning your phone quiet \
        and starting your session become one step.
        """
    )

    /// The session belongs to the app, so the app comes forward to start it.
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        QuietModePlugin.requestSession()
        return .result()
    }
}

/// What puts [StartFocusSessionIntent] in front of the user without their
/// having to go looking for it: the Shortcuts app's list of this app's actions,
/// and a phrase Siri will take.
struct PipGardenShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFocusSessionIntent(),
            phrases: [
                "Start a focus session in \(.applicationName)",
                "Start focusing in \(.applicationName)",
            ],
            shortTitle: "Start a focus session",
            systemImageName: "leaf"
        )
    }
}

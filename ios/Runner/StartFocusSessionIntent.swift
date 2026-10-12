import AppIntents
import Foundation

/// Shortcut action to start a session, meant to go after Set Focus since apps
/// can't enable Focus themselves.
///
/// Opens the app because starting a session needs Flutter; the request waits
/// in `QuietModePlugin` until Dart is listening.
///
/// Nothing is donated per session: that would make Siri suggest sessions at
/// habitual times, and the app shouldn't nudge.
struct StartFocusSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Start a focus session"

    /// Must stay a single literal; `LocalizedStringResource` can't take a
    /// concatenation.
    static var description = IntentDescription(
        """
        Starts a focus session of the length set in Pip Garden. \
        Put it after Set Focus in a Shortcut, and turning your phone quiet \
        and starting your session become one step.
        """
    )

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        QuietModePlugin.requestSession()
        return .result()
    }
}

/// Lists the intent in Shortcuts and gives Siri phrases for it.
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

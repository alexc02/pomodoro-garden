import ActivityKit
import Foundation

/// What a running focus session looks like to iOS.
///
/// Compiled into **both** targets — the app, which starts and updates the
/// activity, and the widget extension, which draws it. That is not a
/// convenience: an `ActivityAttributes` type is matched between the two by its
/// name and its shape, so a second copy that drifted by one field would fail at
/// runtime with an activity that never appears and no compiler complaining.
/// One file, two memberships.
///
/// The fields are the Dart `LiveSession`, one for one. Nothing is computed on
/// this side, and nothing platform-specific is added to it, because Android's
/// notification is built from exactly the same map — see
/// `LiveSessionSurfacePlugin.kt`.
struct LiveSessionAttributes: ActivityAttributes {

    /// The parts that change while the session runs.
    struct ContentState: Codable, Hashable {
        /// Whether the countdown is held.
        ///
        /// A paused session is *drawn* rather than timed: neither this platform
        /// nor Android can hold a running countdown, because both count against
        /// the wall clock, so a held session shows `remainingSeconds` standing
        /// still instead.
        var paused: Bool

        /// The instant the session reaches its planned duration.
        ///
        /// **The one field that makes the countdown free.** `Text(timerInterval:)`
        /// counts to an absolute date, rendered by the system, so the ring on
        /// the lock screen stays right for two hours with nothing of this app
        /// running — which is what REQ-005 requires and what makes an update per
        /// second unnecessary.
        var endsAt: Date

        /// Planned duration minus elapsed, at the instant this was pushed. Only
        /// read while `paused`.
        var remainingSeconds: Int

        /// Elapsed as a fraction of the planned duration, 0 to 1. What the ring
        /// fills to.
        var progress: Double

        /// How grown the plant is, 0 (seed) to 4 (mature) — `GrowthStage.index`
        /// on the Dart side. The number picks the glyph; the label below is
        /// what gets written.
        var stageIndex: Int

        /// "Sprout", "Maturing" — REQ-010's growth stage, in the same words the
        /// app uses on its own screens.
        var stageLabel: String

        /// "Sunflower". What makes the surface about the garden rather than
        /// about the timer.
        var speciesLabel: String
    }

    /// The session being shown. Fixed for the life of the activity, which is
    /// what tells "update the one that is showing" apart from "this is a
    /// different session now".
    var sessionId: String
}

/// Where a tap on the surface goes.
///
/// The app's own scheme rather than a universal link: this URL never leaves the
/// device and is never typed by anyone, it exists so that
/// `LiveSessionSurfacePlugin` can tell "the user came back from their session"
/// apart from an ordinary launch. Declared in `Runner/Info.plist` under
/// `CFBundleURLTypes`.
enum LiveSessionDeepLink {
    static let scheme = "pipgarden"
    static let host = "session"

    static let url = URL(string: "\(scheme)://\(host)")!

    static func matches(_ url: URL) -> Bool {
        url.scheme == scheme && url.host == host
    }
}

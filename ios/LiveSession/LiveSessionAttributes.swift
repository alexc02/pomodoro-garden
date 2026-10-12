import ActivityKit
import Foundation

/// Mirrors the Dart `LiveSession` field for field.
///
/// Compiled into both the app and the widget extension. ActivityKit matches the
/// type by name and shape at runtime, so two drifting copies would fail
/// silently.
struct LiveSessionAttributes: ActivityAttributes {

    /// The parts that change while the session runs.
    struct ContentState: Codable, Hashable {
        /// When paused the widget shows `remainingSeconds` frozen, since the
        /// system timer can't pause.
        var paused: Bool

        /// When the planned duration is reached. `Text(timerInterval:)` counts
        /// down to it, so no per-second updates are needed.
        var endsAt: Date

        /// As of the last push. Only read while `paused`.
        var remainingSeconds: Int

        /// 0 to 1.
        var progress: Double

        /// `GrowthStage.index`: 0 (seed) to 4 (mature). Picks the glyph.
        var stageIndex: Int

        /// e.g. "Sprout", "Maturing".
        var stageLabel: String

        /// e.g. "Sunflower".
        var speciesLabel: String
    }

    /// Fixed per activity; a new id means a new activity.
    var sessionId: String
}

/// Tap URL for the surface. Custom scheme is fine since it never leaves the
/// device. Declared in `Runner/Info.plist` under `CFBundleURLTypes`.
enum LiveSessionDeepLink {
    static let scheme = "pipgarden"
    static let host = "session"

    static let url = URL(string: "\(scheme)://\(host)")!

    static func matches(_ url: URL) -> Bool {
        url.scheme == scheme && url.host == host
    }
}

import ActivityKit
import SwiftUI
import WidgetKit

/// REQ-010's live timer surface: the Dynamic Island and the lock screen.
///
/// **One activity, three presentations, and the fallback is the platform's.**
/// `ActivityConfiguration` is handed a lock-screen view *and* a Dynamic Island
/// view, and iOS picks: an iPhone with an island shows the island
/// presentations, an iPhone without one shows the lock-screen view and nothing
/// else. There is no capability check anywhere in this file or in the app,
/// which is what the ticket's "devices without a Dynamic Island fall back with
/// no visual glitches" comes down to — a branch is the only thing that could
/// glitch, and there is not one.
///
/// **`isStale` is the one thing this draws that the app did not tell it.** The
/// app sets the activity's stale date *to* the instant the session ends, and a
/// suspended app cannot run code to take the activity down at that instant —
/// iOS is not Android, there is no service of ours alive. So the surface is
/// given the ability to know it is finished and say so, rather than sit there
/// counting past zero until the user next opens the app. See ADR 0007.
struct LiveSessionWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveSessionAttributes.self) { context in
            LockScreenSession(state: context.state, isOver: context.isStale)
                .activityBackgroundTint(Color.black.opacity(0.35))
                .activitySystemActionForegroundColor(.primary)
                // On its own, and not only on the island below: on an iPhone
                // without a Dynamic Island this view *is* the whole surface,
                // and a tap on it has to reach the session too. The island's
                // `widgetURL` covers the island's presentations and nothing
                // else.
                .widgetURL(LiveSessionDeepLink.url)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded: the whole of REQ-010's tap state — a progress ring,
                // the time remaining, and the growth stage.
                DynamicIslandExpandedRegion(.leading) {
                    PlantRing(state: context.state, isOver: context.isStale, diameter: 42)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Countdown(state: context.state, isOver: context.isStale)
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 4) {
                        Text(context.state.speciesLabel)
                        Text("·")
                        Text(context.isStale ? "Bloomed" : context.state.stageLabel)
                    }
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
                }
            } compactLeading: {
                // Compact: a tiny ring and the plant, per REQ-010. Small enough
                // that the stage glyph is all that fits inside it.
                PlantRing(state: context.state, isOver: context.isStale, diameter: 20)
            } compactTrailing: {
                Countdown(state: context.state, isOver: context.isStale)
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .monospacedDigit()
                    // Reserves room for the widest countdown this can show, so
                    // the island does not resize itself as the digits change.
                    .frame(maxWidth: 54)
            } minimal: {
                PlantRing(state: context.state, isOver: context.isStale, diameter: 20)
            }
            .widgetURL(LiveSessionDeepLink.url)
        }
    }
}

/// The lock-screen and Notification Centre presentation.
///
/// Also the whole surface on an iPhone with no Dynamic Island, so it carries
/// everything rather than assuming an expanded state exists to carry the rest.
struct LockScreenSession: View {
    let state: LiveSessionAttributes.ContentState
    let isOver: Bool

    var body: some View {
        HStack(spacing: 14) {
            PlantRing(state: state, isOver: isOver, diameter: 52)

            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .font(.system(.headline, design: .rounded))
                Text("\(state.speciesLabel) · \(isOver ? "Bloomed" : state.stageLabel)")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Countdown(state: state, isOver: isOver)
                .font(.system(.title, design: .rounded).weight(.semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// The same three words the app's own timer screen uses, so a user glancing
    /// at a lock screen and a user opening the app read the same thing.
    private var headline: String {
        if isOver { return "Session complete" }
        return state.paused ? "Paused" : "Focusing"
    }
}

/// The time remaining.
///
/// Two renderings, and the difference between them is the whole reason a paused
/// session is a separate case at all. A running session gets
/// `Text(timerInterval:)`, which the system counts down from an absolute date
/// with no process of ours involved. A held session cannot: the interval is
/// against the wall clock and the wall clock does not stop, so what it gets is
/// the number it was pushed, standing still until the user resumes.
struct Countdown: View {
    let state: LiveSessionAttributes.ContentState
    let isOver: Bool

    var body: some View {
        if isOver {
            // Not "0:00". A finished session is a plant, not a timer that ran
            // out, and the completion has already been announced by ticket 06's
            // notification — this is the surface agreeing with it rather than
            // repeating it.
            Image(systemName: "checkmark")
        } else if state.paused {
            Text(held)
        } else {
            Text(timerInterval: interval, countsDown: true)
                .multilineTextAlignment(.trailing)
        }
    }

    /// The span the system counts down over.
    ///
    /// **Clamped, and it is not defensive programming.** A `ClosedRange` traps
    /// when its lower bound is above its upper one, and this view is rendered
    /// with `endsAt` in the past on two ordinary paths: after `staleDate` —
    /// which the app deliberately sets *to* `endsAt` — and on any relaunch
    /// where the app was killed before it could end the activity. Unclamped,
    /// both are a crash in the widget extension.
    private var interval: ClosedRange<Date> {
        let now = Date.now
        return now...max(state.endsAt, now)
    }

    private var held: String {
        let whole = max(state.remainingSeconds, 0)
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }
}

/// The progress ring with the plant inside it: REQ-010's compact state at 20pt
/// and its expanded state at 42.
///
/// One view at both sizes, scaled, so the small one cannot drift from the large
/// one — and so the tiny ring in the island is recognisably the same object as
/// the one on the lock screen.
struct PlantRing: View {
    let state: LiveSessionAttributes.ContentState
    let isOver: Bool
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(.tertiary, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: isOver ? 1 : max(min(state.progress, 1), 0))
                // From the top, clockwise, which is where a ring that means
                // "time" starts everywhere else in this app.
                .rotation(.degrees(-90))
                .stroke(
                    .tint,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                // A held session's ring drops back to the muted colour, so it
                // reads as stopped from across a desk — the same choice the
                // app's own `SessionRing` makes.
                .opacity(state.paused ? 0.45 : 1)

            // A finished session's plant is mature, whatever stage the last
            // push happened to carry — a suspended app cannot send the one that
            // would have said so.
            Image(systemName: Self.glyph(forStage: isOver ? .max : state.stageIndex))
                .font(.system(size: diameter * 0.4))
                .foregroundStyle(.tint)
        }
        .frame(width: diameter, height: diameter)
    }

    private var lineWidth: CGFloat { max(diameter * 0.09, 2) }

    /// The plant, one glyph per growth stage.
    ///
    /// **Placeholder art, in the same spirit as the placeholder plant sprites**
    /// — SF Symbols standing in for the watercolour set, so the surface is
    /// complete and swappable rather than blank. A widget extension is a
    /// separate process and cannot read a Flutter asset, so ticket 23's art
    /// swap reaches this file by way of an app group and a shared image, and
    /// this is the one line it has to replace.
    ///
    /// Keyed by `GrowthStage.index`, and total: an index from a future build
    /// with more stages in it reads as the most grown thing this build knows.
    static func glyph(forStage index: Int) -> String {
        switch index {
        case ..<1: return "circle.fill"
        case 1: return "leaf"
        case 2: return "leaf.fill"
        case 3: return "camera.macro"
        default: return "camera.macro.circle.fill"
        }
    }
}

/// The extension's entry point. One widget in it, and it is not a home-screen
/// widget — an `ActivityConfiguration` is only ever shown for a Live Activity
/// this app started.
@main
struct LiveSessionWidgetBundle: WidgetBundle {
    var body: some Widget {
        LiveSessionWidget()
    }
}

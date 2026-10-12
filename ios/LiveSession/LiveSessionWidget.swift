import ActivityKit
import SwiftUI
import WidgetKit

/// Dynamic Island and lock screen. iOS picks which to show, so there's no
/// Dynamic Island check here.
///
/// The stale date is set to the session's end, so `isStale` means finished.
/// A suspended app can't end the activity on time itself.
struct LiveSessionWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveSessionAttributes.self) { context in
            LockScreenSession(state: context.state, isOver: context.isStale)
                .activityBackgroundTint(Color.black.opacity(0.35))
                .activitySystemActionForegroundColor(.primary)
                // The island's `widgetURL` doesn't cover the lock screen view.
                .widgetURL(LiveSessionDeepLink.url)
        } dynamicIsland: { context in
            DynamicIsland {
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
                PlantRing(state: context.state, isOver: context.isStale, diameter: 20)
            } compactTrailing: {
                Countdown(state: context.state, isOver: context.isStale)
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .monospacedDigit()
                    // Fixed width so the island doesn't resize as digits change.
                    .frame(maxWidth: 54)
            } minimal: {
                PlantRing(state: context.state, isOver: context.isStale, diameter: 20)
            }
            .widgetURL(LiveSessionDeepLink.url)
        }
    }
}

/// Lock screen and Notification Centre. Also the only view on iPhones without
/// a Dynamic Island, so it shows everything.
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

    /// Same wording as the app's timer screen.
    private var headline: String {
        if isOver { return "Session complete" }
        return state.paused ? "Paused" : "Focusing"
    }
}

/// Running: system-driven `Text(timerInterval:)`. Paused: the last pushed
/// value, since the system timer can't pause.
struct Countdown: View {
    let state: LiveSessionAttributes.ContentState
    let isOver: Bool

    var body: some View {
        if isOver {
            Image(systemName: "checkmark")
        } else if state.paused {
            Text(held)
        } else {
            Text(timerInterval: interval, countsDown: true)
                .multilineTextAlignment(.trailing)
        }
    }

    /// Clamped: `ClosedRange` traps if lower > upper, and `endsAt` is in the
    /// past after the stale date or if the app died before ending the activity.
    private var interval: ClosedRange<Date> {
        let now = Date.now
        return now...max(state.endsAt, now)
    }

    private var held: String {
        let whole = max(state.remainingSeconds, 0)
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }
}

/// Progress ring with the plant glyph inside. Used at every size.
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
                // Start at 12 o'clock.
                .rotation(.degrees(-90))
                .stroke(
                    .tint,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                // Muted when paused, like the app's `SessionRing`.
                .opacity(state.paused ? 0.45 : 1)

            // Show mature when over; the last push may predate the final stage.
            Image(systemName: Self.glyph(forStage: isOver ? .max : state.stageIndex))
                .font(.system(size: diameter * 0.4))
                .foregroundStyle(.tint)
        }
        .frame(width: diameter, height: diameter)
    }

    private var lineWidth: CGFloat { max(diameter * 0.09, 2) }

    /// Placeholder SF Symbols per `GrowthStage.index`. The extension can't read
    /// Flutter assets, so real art would need an app group. Unknown higher
    /// indices fall through to mature.
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

/// Live Activity only; no home-screen widget.
@main
struct LiveSessionWidgetBundle: WidgetBundle {
    var body: some Widget {
        LiveSessionWidget()
    }
}

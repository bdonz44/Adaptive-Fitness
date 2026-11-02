import ActivityKit
import SwiftUI
import WidgetKit

@main
struct Hybrid12Widgets: WidgetBundle {
    var body: some Widget {
        RestTimerLiveActivity()
    }
}

private let accent = Color.orange
private let done = Color.green

/// Counts down to the end time on its own; shows "Go" once the time is up.
private struct Countdown: View {
    let state: RestTimerAttributes.ContentState
    let isStale: Bool

    var body: some View {
        if isStale || state.end <= Date() {
            Text("Go").foregroundStyle(done)
        } else {
            Text(timerInterval: state.start...state.end, countsDown: true)
                .monospacedDigit()
        }
    }
}

struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(context.state.label, systemImage: "timer")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                    if !context.isStale {
                        ProgressView(timerInterval: context.state.start...context.state.end, countsDown: true) {
                            EmptyView()
                        } currentValueLabel: {
                            EmptyView()
                        }
                        .tint(accent)
                    }
                }
                Countdown(state: context.state, isStale: context.isStale)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 110, alignment: .trailing)
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.75))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.label, systemImage: "timer")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Countdown(state: context.state, isStale: context.isStale)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.trailing)
                }
            } compactLeading: {
                Image(systemName: "timer").foregroundStyle(accent)
            } compactTrailing: {
                Countdown(state: context.state, isStale: context.isStale)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 44)
            } minimal: {
                Countdown(state: context.state, isStale: context.isStale)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
            }
            .keylineTint(accent)
        }
    }
}

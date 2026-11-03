import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct Hybrid12Widgets: WidgetBundle {
    var body: some Widget {
        RestTimerLiveActivity()
    }
}

private extension RestTimerAttributes.ContentState {
    var accentColor: Color {
        Color(red: Double((accent >> 16) & 0xFF) / 255, green: Double((accent >> 8) & 0xFF) / 255,
              blue: Double(accent & 0xFF) / 255)
    }
}

private let goColor = Color(red: 0.29, green: 0.87, blue: 0.5)

/// Counts down to the end time on its own; shows "Go" once the time is up.
private struct Countdown: View {
    let state: RestTimerAttributes.ContentState
    let isStale: Bool

    var body: some View {
        if isStale || state.end <= Date() {
            Text("Go").foregroundStyle(goColor)
        } else {
            Text(timerInterval: state.start...state.end, countsDown: true)
                .monospacedDigit()
        }
    }
}

private struct RestButtons: View {
    let accent: Color

    var body: some View {
        HStack(spacing: 8) {
            Button(intent: RestAddThirtyIntent()) {
                Text("+30s").font(.subheadline.weight(.bold)).frame(minWidth: 56, minHeight: 36)
            }
            .tint(.gray)
            Button(intent: RestDoneIntent()) {
                Text("Done").font(.subheadline.weight(.heavy)).foregroundStyle(.black).frame(minWidth: 56, minHeight: 36)
            }
            .tint(accent)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
    }
}

/// The three Lock Screen layouts the user can pick.
private struct LockScreenView: View {
    let state: RestTimerAttributes.ContentState
    let isStale: Bool

    var body: some View {
        let accent = state.accentColor
        Group {
            switch state.style {
            case "progress":
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(state.sessionTitle.isEmpty ? state.label : state.sessionTitle).font(.headline)
                        Spacer()
                        if state.setsTotal > 0 {
                            Text("\(state.setsDone) of \(state.setsTotal) sets").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    if state.setsTotal > 0 {
                        HStack(spacing: 3) {
                            ForEach(0..<min(state.setsTotal, 30), id: \.self) { i in
                                Capsule().fill(i < state.setsDone ? accent : Color.gray.opacity(0.5)).frame(height: 8)
                            }
                        }
                    }
                    HStack {
                        Text(state.next.isEmpty ? state.label : "Next: \(state.next)")
                            .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                        Spacer()
                        Countdown(state: state, isStale: isStale)
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundStyle(accent)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90, alignment: .trailing)
                    }
                }
            case "buttons":
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.label).font(.subheadline.weight(.semibold)).foregroundStyle(accent).lineLimit(1)
                        Countdown(state: state, isStale: isStale)
                            .font(.system(size: 40, weight: .heavy, design: .rounded))
                    }
                    Spacer()
                    RestButtons(accent: accent)
                }
            default:
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(state.label, systemImage: "timer")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(accent)
                            .lineLimit(1)
                        if !state.next.isEmpty {
                            Text("Next: \(state.next)").font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                        if !isStale {
                            ProgressView(timerInterval: state.start...state.end, countsDown: true) {
                                EmptyView()
                            } currentValueLabel: {
                                EmptyView()
                            }
                            .tint(accent)
                        }
                    }
                    Countdown(state: state, isStale: isStale)
                        .font(.system(size: 46, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120, alignment: .trailing)
                }
            }
        }
        .padding()
    }
}

struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            LockScreenView(state: context.state, isStale: context.isStale)
                .activityBackgroundTint(Color.black.opacity(0.75))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let accent = context.state.accentColor
            return DynamicIsland {
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
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        if !context.state.next.isEmpty {
                            Text("Next: \(context.state.next)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        RestButtons(accent: accent)
                    }
                }
            } compactLeading: {
                Image(systemName: "timer").foregroundStyle(accent)
            } compactTrailing: {
                Countdown(state: context.state, isStale: context.isStale)
                    .foregroundStyle(accent)
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

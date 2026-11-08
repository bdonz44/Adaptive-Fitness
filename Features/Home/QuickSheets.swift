import SwiftUI
import Hybrid12Engine

/// Home quick action: log a weigh-in.
struct QuickWeightSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        quickSheet("Log weight") {
            if let last = store.weighIns.last {
                Text("Last: \(lb(last.pounds)) lb on \(last.date.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.subheadline).foregroundStyle(Theme.secondary)
            }
            LogField(placeholder: "Weight", unit: "lb") { store.addWeighIn($0); dismiss() }
            Text("Same time, same conditions: first thing in the morning after the bathroom.")
                .font(.caption).foregroundStyle(Theme.secondary)
        }
    }
}

/// Home quick action: log cardio WHOOP didn't track.
struct QuickCardioSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var kind: ManualCardio.Kind = .walk

    var body: some View {
        quickSheet("Log cardio") {
            Text("This week: \(store.cardioThisWeek) of \(Program.cardioGoalMinutes) min").font(.subheadline)
            Picker("Type", selection: $kind) {
                ForEach(ManualCardio.Kind.allCases, id: \.self) { Text($0.name).tag($0) }
            }
            .pickerStyle(.segmented)
            LogField(placeholder: "\(kind.name) minutes", unit: "min") {
                store.logCardio(kind, minutes: Int($0.rounded())); dismiss()
            }
            Text("Only what WHOOP didn't track, or it counts twice.").font(.caption).foregroundStyle(Theme.secondary)
        }
    }
}

/// Home quick action: how much time today (trims the session).
struct QuickTimeSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        quickSheet("Time today") {
            HStack(spacing: 8) {
                choice("Full", nil)
                ForEach(TimeBox.choices, id: \.self) { choice("\($0)", $0) }
            }
            Text(TimeBox.summary(store.session) ?? "About \(TimeBox.minutes(store.session)) min.")
                .font(.subheadline).foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func choice(_ label: String, _ minutes: Int?) -> some View {
        let look = Theme.look
        let on = store.draft.timeBudget == minutes
        return Button { store.setTimeBudget(minutes) } label: {
            Text(label).font(.headline)
                .frame(maxWidth: .infinity, minHeight: 50)
                .foregroundStyle(on ? look.onAccent : look.text)
                .background(on ? look.accent : look.field, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

private func quickSheet<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    NavigationStack {
        VStack(alignment: .leading, spacing: 14) {
            content()
            Spacer()
        }
        .padding()
        .background(Theme.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
    .presentationDetents([.medium])
}

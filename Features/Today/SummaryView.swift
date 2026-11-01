import SwiftUI
import Hybrid12Engine

/// After Finish: every lift's next weight (up, down, same), cardio added, and week progress.
struct SummaryView: View {
    let summary: FinishSummary
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let message = summary.weekMessage {
                    Section {
                        Text(message).font(.headline)
                    }
                }
                Section("Next time") {
                    if summary.changes.isEmpty {
                        Text("No lifts logged.").foregroundStyle(.secondary)
                    }
                    ForEach(summary.changes, id: \.exerciseID) { change in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: icon(change.direction))
                                    .foregroundStyle(color(change.direction))
                                Text(change.name)
                                Spacer()
                                Text(weights(change))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            if let note = change.note {
                                Text(note).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if summary.cardioMinutes > 0 {
                    Section {
                        Text("\(summary.cardioMinutes) cardio minutes added this week")
                    }
                }
            }
            .navigationTitle("\(summary.title) done")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func icon(_ d: ChangeDirection) -> String {
        switch d {
        case .up: return "arrow.up.circle.fill"
        case .down: return "arrow.down.circle.fill"
        case .same: return "equal.circle.fill"
        }
    }

    private func color(_ d: ChangeDirection) -> Color {
        switch d {
        case .up: return Theme.done
        case .down: return .red
        case .same: return .secondary
        }
    }

    private func weights(_ c: LiftChange) -> String {
        guard let to = c.to else { return "" }
        if let from = c.from, from != to { return "\(lb(from)) → \(lb(to)) lb" }
        return "\(lb(to)) lb"
    }
}

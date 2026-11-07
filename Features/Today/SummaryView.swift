import SwiftUI
import Hybrid12Engine

/// After Finish: a celebration, any personal records, every lift's next weight,
/// cardio added, and the week so far.
struct SummaryView: View {
    let summary: FinishSummary
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    @State private var undone = false

    var body: some View {
        let look = Theme.look
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundStyle(look.onAccent)
                        .frame(width: 72, height: 72)
                        .background(look.accent, in: Circle())
                    Text(look.uppercaseTitles ? "\(summary.title) done".uppercased() : "\(summary.title) done")
                        .font(look.title(36))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                    if !statsLine.isEmpty {
                        Text(statsLine).font(.subheadline).foregroundStyle(look.secondary)
                            .multilineTextAlignment(.center)
                    }
                    if let message = summary.weekMessage, !undone {
                        Text(message).font(.headline).multilineTextAlignment(.center).padding(.top, 4)
                    }
                    if let previous = summary.undoState {
                        if undone {
                            Text("Back on week \(previous.week). Your session is saved.")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(look.done)
                        } else {
                            Button {
                                store.undoWeekAdvance(previous)
                                undone = true
                            } label: {
                                Text("Not right? Go back to week \(previous.week)")
                                    .font(.subheadline.weight(.bold))
                                    .padding(.horizontal, 14).frame(minHeight: 44)
                                    .background(look.card, in: Capsule())
                                    .overlay(Capsule().stroke(look.line))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 24)

                ForEach(summary.records) { pr in
                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel(text: "New personal record", color: look.accent)
                        HStack(alignment: .firstTextBaseline) {
                            Text(pr.name).font(.title3.weight(.bold))
                            Spacer()
                            Text("\(lb(pr.weight)) × \(pr.reps)").font(look.number(32))
                        }
                        Text("Estimated max \(lb(pr.e1RM.rounded())) lb, up \(lb(pr.gain.rounded())) on your best")
                            .font(.subheadline).foregroundStyle(look.secondary)
                    }
                    .padding(18)
                    .background(look.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: look.radius))
                    .overlay(RoundedRectangle(cornerRadius: look.radius).stroke(look.accent, lineWidth: 2))
                }

                FinishHeartCard(summary: summary)

                SectionLabel(text: "Next time")
                VStack(spacing: 0) {
                    if summary.changes.isEmpty {
                        Text("No lifts logged.").foregroundStyle(look.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 12)
                    }
                    ForEach(Array(summary.changes.enumerated()), id: \.element.exerciseID) { i, change in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: icon(change.direction)).foregroundStyle(color(change.direction))
                                Text(change.name)
                                Spacer()
                                Text(weights(change)).monospacedDigit().fontWeight(.bold)
                                    .foregroundStyle(change.direction == .up ? look.done : look.text)
                            }
                            if let note = change.note {
                                Text(note).font(.caption).foregroundStyle(look.secondary)
                            }
                        }
                        .padding(.vertical, 12)
                        if i < summary.changes.count - 1 { Divider().overlay(look.line) }
                    }
                    if summary.cardioMinutes > 0 {
                        Divider().overlay(look.line)
                        HStack {
                            Image(systemName: "heart.fill").foregroundStyle(look.accent)
                            Text("Cardio")
                            Spacer()
                            Text("+\(summary.cardioMinutes) min this week").fontWeight(.bold)
                        }
                        .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 16)
                .lookCard()

                if summary.weekDone > 0 {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("This week").font(.subheadline).foregroundStyle(look.secondary)
                            Text("\(summary.weekDone) of 5 sessions").font(.headline)
                        }
                        Spacer()
                        HStack(spacing: 6) {
                            ForEach(0..<5, id: \.self) { i in
                                Circle().fill(i < summary.weekDone ? look.accent : look.field).frame(width: 14, height: 14)
                            }
                        }
                    }
                    .padding(16)
                    .lookCard()
                }

                Button { dismiss() } label: { Text("Done").accentButton() }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
            }
            .padding(20)
        }
        .background(look.background)
        .presentationDragIndicator(.visible)
    }

    private var statsLine: String {
        var parts: [String] = []
        if let m = summary.minutes { parts.append("\(m) min") }
        if summary.setsDone > 0 { parts.append("\(summary.setsDone) sets") }
        if summary.volume > 0 { parts.append("\(summary.volume.formatted(.number.precision(.fractionLength(0)))) lb moved") }
        return parts.joined(separator: " · ")
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
        case .same: return Theme.secondary
        }
    }

    private func weights(_ c: LiftChange) -> String {
        guard let to = c.to else { return "" }
        if let from = c.from, from != to { return "\(lb(from)) → \(lb(to))" }
        return "\(lb(to)) · hold"
    }
}

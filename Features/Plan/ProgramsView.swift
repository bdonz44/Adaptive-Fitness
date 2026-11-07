import SwiftUI
import Hybrid12Engine

/// Plan > Programs: pick the program and how many days a week.
struct ProgramsView: View {
    @Environment(AppStore.self) private var store
    @Environment(RestTimer.self) private var timer
    @State private var days: [ProgramID: Int] = [:]
    @State private var pending: (id: ProgramID, days: Int)?

    var body: some View {
        let look = Theme.look
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Your lifts and history carry over to every program. Each program remembers its own week, so you can switch back.")
                    .font(.subheadline).foregroundStyle(look.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(ProgramID.allCases, id: \.self) { id in
                    card(id)
                }
            }
            .padding()
        }
        .background(look.background)
        .navigationTitle("Programs")
        .confirmationDialog(title, isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
                            titleVisibility: .visible) {
            if let p = pending {
                Button(p.id == store.program.program ? "Switch to \(p.days) days" : "Start \(p.id.name)") {
                    timer.done()
                    store.chooseProgram(p.id, days: p.days)
                    pending = nil
                }
            }
        } message: {
            Text(message)
        }
    }

    private var title: String {
        guard let p = pending else { return "" }
        return p.id == store.program.program ? "\(p.days) days a week?" : "Switch to \(p.id.name)?"
    }

    private var message: String {
        guard let p = pending else { return "" }
        let lost = store.draft.hasWork ? " Today's unfinished session is cleared." : ""
        if p.id == store.program.program {
            return "Same week, \(p.days) sessions instead of \(store.program.days).\(lost)"
        }
        let resume = store.program.resumeWeeks[p.id.rawValue]
        let at = resume.map { "picks up at week \($0)" } ?? "starts at week 1"
        return "\(p.id.name) \(at), \(p.days) days a week. \(store.program.program.name) remembers week \(store.week.week) for when you come back.\(lost)"
    }

    private func card(_ id: ProgramID) -> some View {
        let look = Theme.look
        let current = id == store.program.program
        let chosen = days[id] ?? (current ? store.program.days : id.defaultDays)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(id.name).font(.title3.weight(.heavy))
                Spacer()
                if current {
                    Text("CURRENT").font(.caption.weight(.heavy))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .foregroundStyle(look.onAccent)
                        .background(look.accent, in: Capsule())
                } else if let w = store.program.resumeWeeks[id.rawValue] {
                    Text("Week \(w)").font(.caption.weight(.bold)).foregroundStyle(look.secondary)
                }
            }
            Text(id.blurb).font(.subheadline).foregroundStyle(look.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if id.dayOptions.count > 1 {
                Picker("Days a week", selection: Binding(get: { chosen }, set: { days[id] = $0 })) {
                    ForEach(id.dayOptions, id: \.self) { Text("\($0) days").tag($0) }
                }
                .pickerStyle(.segmented)
            } else {
                Text("\(chosen) days a week").font(.caption).foregroundStyle(look.secondary)
            }
            Text(ProgramLibrary.days(id, days: chosen).map(\.name).joined(separator: " · ").ifEmpty(hybridDays))
                .font(.caption).foregroundStyle(look.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !current || chosen != store.program.days {
                Button { pending = (id, chosen) } label: {
                    Text(current ? "Switch to \(chosen) days" : "Start this program").accentButton()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .lookCard(highlight: current)
    }

    private var hybridDays: String {
        Program.order.map { Program.plan($0).name }.joined(separator: " · ") + " · optional easy run"
    }
}

private extension String {
    func ifEmpty(_ other: String) -> String { isEmpty ? other : self }
}

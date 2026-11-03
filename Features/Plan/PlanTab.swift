import SwiftUI
import Hybrid12Engine

/// The 12-week plan, jump to week and start over.
struct PlanTab: View {
    @Environment(AppStore.self) private var store
    @Environment(RestTimer.self) private var timer
    @Environment(\.openLook) private var openLook
    @State private var jumpTarget: Int?
    @State private var confirmStartOver = false
    @State private var confirmStartOverAgain = false

    var body: some View {
        let week = store.week
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header(week)
                    VStack(spacing: 10) {
                        Button { openLook() } label: {
                            linkRow("Look", detail: "\(Theme.look.name) · Lock Screen · app icon", icon: "paintpalette.fill")
                        }
                        NavigationLink { ProgramsView() } label: {
                            linkRow("Programs", detail: "Hybrid 12 · more coming", icon: "square.stack.3d.up.fill")
                        }
                    }
                    .buttonStyle(.plain)
                    thisWeekCard(week)
                    weeksCard(week)
                    Card(title: "\(week.phase.name) sessions") {
                        ForEach(PlanText.sessions(week.phase, runMinutes: store.program.runMinutes, catalog: store.catalog), id: \.self) { line in
                            Text(line).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Card(title: "Phases") {
                        ForEach(Phase.allCases, id: \.self) { phase in
                            phaseRow(phase, current: phase == week.phase)
                        }
                    }
                    Card(title: "How it works") {
                        Text("Do the five sessions in order, on any days. Finishing all five starts the next week. Weeks 4 and 8 are back-off weeks. After week 12, cycle 2 starts with your weights carried over.")
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Card(title: "Web app data") {
                        Text("Bring over your week, weights, sessions, weigh-ins, waist and cardio from the web app's export file.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        ImportButton()
                    }
                    startOverButton
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle(Theme.look.uppercaseTitles ? "PLAN" : "Plan")
            .confirmationDialog(jumpTarget.map { "Jump to week \($0)?" } ?? "",
                                isPresented: Binding(get: { jumpTarget != nil }, set: { if !$0 { jumpTarget = nil } }),
                                titleVisibility: .visible) {
                Button("Jump to week \(jumpTarget ?? 1)") {
                    if let n = jumpTarget {
                        timer.done()
                        store.jump(toWeekInCycle: n)
                    }
                    jumpTarget = nil
                }
            } message: {
                Text("This week's finished sessions and today's unsaved session are cleared. Your lifts and logs stay.")
            }
        }
    }

    private func linkRow(_ title: String, detail: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Theme.onAccent)
                .frame(width: 40, height: 40)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(Theme.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Theme.secondary)
        }
        .padding(14)
        .lookCard()
        .contentShape(Rectangle())
    }

    private func header(_ week: ProgramWeek) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Week \(week.wk) of 12 · \(week.phase.name)").font(.headline)
            Text("Cycle \(week.cycle) · \(store.program.doneCount) of 5 sessions done this week")
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)
        }
    }

    /// Which sessions count as done this week, and why. Tap to fix a wrong one.
    private func thisWeekCard(_ week: ProgramWeek) -> some View {
        Card(title: "Week \(week.wk) sessions") {
            Text("Tap Mark to fix a session that's wrong.")
                .font(.caption).foregroundStyle(Theme.secondary)
            ForEach(store.weekStatus, id: \.slot) { row in
                HStack(spacing: 10) {
                    Image(systemName: icon(row.status))
                        .foregroundStyle(row.status == .toDo ? Theme.secondary : Theme.done)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(Program.plan(row.slot).name).font(.subheadline.weight(.semibold))
                        Text(statusText(row.status)).font(.caption).foregroundStyle(Theme.secondary)
                    }
                    Spacer()
                    Button(row.status == .toDo ? "Mark done" : "Mark not done") {
                        store.setDone(row.slot, row.status == .toDo)
                    }
                    .font(.caption.weight(.bold))
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func icon(_ s: Program.SlotStatus) -> String {
        switch s {
        case .logged: return "checkmark.circle.fill"
        case .markedDone: return "checkmark.circle"
        case .toDo: return "circle"
        }
    }

    private func statusText(_ s: Program.SlotStatus) -> String {
        switch s {
        case .logged(let d): return "Logged \(d.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))"
        case .markedDone: return "Marked done, nothing logged"
        case .toDo: return "To do"
        }
    }

    private func weeksCard(_ week: ProgramWeek) -> some View {
        Card(title: "This cycle") {
            Text("Tap a week to jump to it.")
                .font(.caption)
                .foregroundStyle(Theme.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(PlanText.cycleWeeks(current: week.week)) { w in
                    Button {
                        if w.status != .current { jumpTarget = w.wk }
                    } label: {
                        weekCell(w)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func weekCell(_ w: PlanText.PlanWeek) -> some View {
        let current = w.status == .current
        return VStack(spacing: 2) {
            HStack(spacing: 3) {
                if w.status == .past {
                    Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundStyle(Theme.done)
                }
                Text("\(w.wk)").font(.title3.weight(.bold)).monospacedDigit()
            }
            Text(w.isDeload ? "Back-off" : w.phase.name)
                .font(.caption2)
                .foregroundStyle(w.isDeload ? Color.blue : Theme.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(current ? Theme.accent.opacity(0.3) : Theme.field, in: RoundedRectangle(cornerRadius: max(Theme.look.radius - 8, 2)))
        .overlay(RoundedRectangle(cornerRadius: max(Theme.look.radius - 8, 2)).stroke(current ? Theme.accent : .clear, lineWidth: 1.5))
        .accessibilityLabel("Week \(w.wk), \(w.isDeload ? "back-off week" : w.phase.name)\(current ? ", current" : "")")
    }

    private func phaseRow(_ phase: Phase, current: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(phase.name).font(.headline)
                Text(PlanText.weeks(phase)).font(.subheadline).foregroundStyle(Theme.secondary)
                Spacer()
                if current {
                    Text("Now").font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
                }
            }
            Text(PlanText.focus(phase)).font(.subheadline)
            Text(PlanText.scheme(phase)).font(.caption).foregroundStyle(Theme.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var startOverButton: some View {
        Button("Start over", role: .destructive) { confirmStartOver = true }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .confirmationDialog("Start over from week 1?", isPresented: $confirmStartOver, titleVisibility: .visible) {
                Button("Start over", role: .destructive) { confirmStartOverAgain = true }
            } message: {
                Text("This erases your weights, sessions, cardio, weigh-ins and waist entries.")
            }
            .alert("Erase everything?", isPresented: $confirmStartOverAgain) {
                Button("Cancel", role: .cancel) {}
                Button("Erase", role: .destructive) {
                    timer.done()
                    store.startOver()
                }
            } message: {
                Text("This can't be undone.")
            }
    }
}

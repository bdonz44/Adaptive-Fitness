import SwiftUI
import UIKit
import Hybrid12Engine

struct TodayView: View {
    @Environment(AppStore.self) private var store
    @Environment(RestTimer.self) private var timer
    @State private var summary: FinishSummary?
    @State private var confirmSkip = false
    @State private var confirmRestart = false
    @State private var banner: String?

    var body: some View {
        let session = store.session
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    WeekHeader()
                    SlotChips()
                    ReadinessPicker()
                    if let banner {
                        Text(banner)
                            .font(.subheadline.weight(.semibold))
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.accent.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
                    }
                    ForEach(session.blocks, id: \.kind) { block in
                        BlockSection(block: block, session: session)
                    }
                    finishButtons(session)
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                if timer.isActive { RestTimerBar() }
            }
            .navigationTitle(session.title)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hideKeyboard() }
                }
            }
            .sheet(item: $summary) { s in
                SummaryView(summary: s)
            }
        }
    }

    @ViewBuilder
    private func finishButtons(_ session: Session) -> some View {
        VStack(spacing: 12) {
            Button {
                hideKeyboard()
                timer.done()
                summary = store.finish()
                banner = nil
            } label: {
                Text("Finish session")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)

            HStack {
                if session.slot != .R {
                    Button("Skip \(session.title)") { confirmSkip = true }
                        .confirmationDialog("Skip \(session.title)? It counts as done with nothing logged.",
                                            isPresented: $confirmSkip, titleVisibility: .visible) {
                            Button("Skip it", role: .destructive) {
                                timer.done()
                                banner = store.skip(session.slot)
                            }
                        }
                }
                Spacer()
                if store.draft.hasWork {
                    Button("Restart") { confirmRestart = true }
                        .confirmationDialog("Clear everything logged in this session?",
                                            isPresented: $confirmRestart, titleVisibility: .visible) {
                            Button("Clear it", role: .destructive) {
                                timer.done()
                                store.restartSession()
                            }
                        }
                }
            }
            .font(.subheadline)

            if store.program.canStartNextWeek {
                Button("Start next week") {
                    timer.done()
                    banner = store.startNextWeek()
                }
                .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Header

struct WeekHeader: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let week = store.week
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Week \(week.wk) of 12 · \(week.phase.name)")
                    .font(.headline)
                if week.cycle > 1 {
                    Text("Cycle \(week.cycle)").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if week.isDeload {
                    Text("Back-off week")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.blue.opacity(0.3), in: Capsule())
                }
            }
            HStack {
                Text("Cardio this week")
                Spacer()
                Text("\(store.cardioThisWeek) of \(Program.cardioGoalMinutes) min")
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            ProgressView(value: min(1, Double(store.cardioThisWeek) / Double(Program.cardioGoalMinutes)))
        }
    }
}

// MARK: - Session chips

struct SlotChips: View {
    @Environment(AppStore.self) private var store
    @Environment(RestTimer.self) private var timer

    var body: some View {
        let next = store.nextSlot
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Program.order + [Slot.R], id: \.self) { slot in
                    chip(slot, isNext: slot == next)
                }
            }
        }
    }

    private func chip(_ slot: Slot, isNext: Bool) -> some View {
        let selected = store.draft.slot == slot
        let done = store.program.isDone(slot)
        let plan = Program.plan(slot)
        return Button {
            if !selected { timer.done() }
            store.select(slot)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if done { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.done) }
                    Text(plan.day.map { "Day \($0)" } ?? "Optional")
                        .font(.caption2.weight(.semibold))
                    if isNext && !done {
                        Text("Next").font(.caption2.weight(.bold)).foregroundStyle(Theme.accent)
                    }
                }
                Text(slot == .R ? "Easy Run" : plan.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selected ? Theme.accent.opacity(0.3) : Theme.card, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Theme.accent : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Readiness

struct ReadinessPicker: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("How do you feel?").font(.caption).foregroundStyle(.secondary)
            Picker("Readiness", selection: Binding(
                get: { store.draft.readiness },
                set: { store.setReadiness($0) }
            )) {
                Text("Great").tag(Readiness.great)
                Text("Normal").tag(Readiness.normal)
                Text("Beat up").tag(Readiness.beat)
            }
            .pickerStyle(.segmented)
            if store.draft.readiness == .beat {
                Text("Short day: no supersets, half the finisher, 10% lighter, no progression.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Blocks

struct BlockSection: View {
    let block: SessionBlock
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(block.title.uppercased())
                .font(.caption.weight(.heavy))
                .foregroundStyle(Theme.accent)
            ForEach(block.items, id: \.key) { item in
                ItemCard(item: item, session: session)
            }
        }
    }
}

func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

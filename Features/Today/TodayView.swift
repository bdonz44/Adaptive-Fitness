import SwiftUI
import UIKit
import Hybrid12Engine

struct TodayView: View {
    @Environment(AppStore.self) private var store
    @Environment(RestTimer.self) private var timer
    @Environment(HoldTimer.self) private var hold
    @State private var summary: FinishSummary?
    @State private var confirmSkip = false
    @State private var confirmRestart = false
    @State private var confirmOpenSets = false
    @State private var banner: String?

    @State private var showFocus = false
    @State private var showRest = false
    @State private var showAddExercise = false

    var body: some View {
        let session = store.session
        let look = Theme.look
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if store.isEmpty { ImportPromptCard() }
                    WeekHeader(title: session.title)
                    WhoopCard()
                    if look.readinessFirst { ReadinessPicker() }
                    SlotChips()
                    if !look.readinessFirst { ReadinessPicker() }
                    if let banner {
                        Text(banner)
                            .font(.subheadline.weight(.semibold))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.accent.opacity(0.2), in: RoundedRectangle(cornerRadius: look.radius))
                    }
                    NowCard(session: session, openFocus: { showFocus = true })
                    if !timer.isActive { CoachCueCard() }
                    ForEach(session.blocks, id: \.kind) { block in
                        BlockSection(block: block, session: session)
                    }
                    Button { showAddExercise = true } label: {
                        Label("Add exercise", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
                    finishButtons(session)
                }
                .padding()
            }
            .background(look.background)
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                if timer.isActive && !showFocus {
                    VStack(spacing: 0) {
                        CoachCueCard(compact: true).padding(.horizontal).padding(.bottom, 8)
                        RestTimerBar(expand: { showRest = true })
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFocus = true
                    } label: {
                        Label("Focus mode", systemImage: "scope")
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hideKeyboard() }
                }
            }
            .toolbarBackground(look.background, for: .navigationBar)
            .sheet(isPresented: $showAddExercise) {
                AddExerciseSheet(session: session)
            }
            .sheet(item: $summary) { s in
                SummaryView(summary: s)
            }
            .fullScreenCover(isPresented: $showFocus) {
                FocusView()
            }
            .fullScreenCover(isPresented: Binding(get: { hold.isActive && !showFocus }, set: { if !$0 { hold.cancel() } })) {
                HoldTimerView()
            }
            .fullScreenCover(isPresented: $showRest) {
                RestView(close: { showRest = false })
            }
            .onChange(of: timer.isActive) { _, active in
                if !active { showRest = false }
            }
        }
    }

    private func finishNow() {
        timer.done()
        summary = store.finish()
        banner = nil
    }

    @ViewBuilder
    private func finishButtons(_ session: Session) -> some View {
        VStack(spacing: 12) {
            Button {
                hideKeyboard()
                if store.sessionStats.setsOpen > 0 {
                    confirmOpenSets = true
                } else {
                    finishNow()
                }
            } label: {
                Text(Theme.look.uppercaseTitles ? "FINISH SESSION" : "Finish session")
            }
            .buttonStyle(.plain)
            .accentButton()
            .confirmationDialog("\(store.sessionStats.setsOpen) sets aren't ticked. Log them as done at the planned weight and reps?",
                                isPresented: $confirmOpenSets, titleVisibility: .visible) {
                Button("Yes, log them as done") {
                    store.markEverythingDone()
                    finishNow()
                }
                Button("Only what I ticked") { finishNow() }
            } message: {
                Text("Skipped exercises stay skipped.")
            }

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
    let title: String

    var body: some View {
        let week = store.week
        let look = Theme.look
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SectionLabel(text: "Week \(week.wk) / 12 · \(week.phase.name)" + (week.cycle > 1 ? " · Cycle \(week.cycle)" : ""))
                Spacer()
                if week.isDeload {
                    Text("Back-off week")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.blue.opacity(0.3), in: Capsule())
                }
            }
            Text(look.uppercaseTitles ? title.uppercased() : title)
                .font(look.title(42))
                .foregroundStyle(look.text)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            // One segment per session this week: done, today, still to do.
            HStack(spacing: 6) {
                ForEach(Program.order, id: \.self) { slot in
                    Capsule()
                        .fill(store.program.isDone(slot) ? look.accent
                              : slot == store.draft.slot ? look.text : look.field)
                        .frame(height: 6)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("\(store.program.doneCount) of 5 sessions done this week")
            HStack {
                Text("\(store.program.doneCount) of 5 done")
                Spacer()
                Text("Cardio \(store.cardioThisWeek) / \(Program.cardioGoalMinutes) min").monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(look.secondary)
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
            .background(selected ? Theme.accent.opacity(0.25) : Theme.card, in: RoundedRectangle(cornerRadius: max(Theme.look.radius - 6, 2)))
            .overlay(RoundedRectangle(cornerRadius: max(Theme.look.radius - 6, 2)).stroke(selected ? Theme.accent : Theme.line, lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Readiness

struct ReadinessPicker: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("How do you feel?").font(.caption).foregroundStyle(Theme.secondary)
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
                    .foregroundStyle(Theme.secondary)
            }
        }
        .padding(Theme.look.readinessFirst ? 16 : 0)
        .background(Theme.look.readinessFirst ? Theme.card : .clear, in: RoundedRectangle(cornerRadius: Theme.look.radius))
    }
}

// MARK: - Blocks

struct BlockSection: View {
    let block: SessionBlock
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: block.title, color: Theme.accent)
            ForEach(block.items, id: \.key) { item in
                ItemCard(item: item, session: session)
            }
        }
    }
}

func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

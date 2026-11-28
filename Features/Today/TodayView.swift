import SwiftUI
import UIKit
import Hybrid12Engine

struct TodayView: View {
    @Environment(AppStore.self) private var store
    @Environment(HeartRateMonitor.self) private var heart
    @Environment(RestTimer.self) private var timer
    @Environment(HoldTimer.self) private var hold
    @State private var summary: FinishSummary?
    @State private var confirmSkip = false
    @State private var confirmRestart = false
    @State private var confirmNextWeek = false
    @State private var confirmOpenSets = false
    @State private var banner: String?

    @State private var showFocus = false
    @State private var showRest = false
    @State private var showAddExercise = false
    @State private var showBuild = false
    @State private var askCoach = false

    var body: some View {
        let session = store.session
        let look = Theme.look
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if store.isEmpty { ImportPromptCard() }
                    WeekHeader(title: session.title)
                    if let plan = session.reEntry { ReEntryBanner(plan: plan) }
                    if store.draft.custom != nil {
                        HStack {
                            Label("Your own workout: an extra, it doesn't count toward the week", systemImage: "square.and.pencil")
                                .font(.subheadline.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            Button("Back to the plan") { timer.done(); store.leaveCustom() }.font(.subheadline.weight(.bold))
                        }
                        .padding(12)
                        .background(look.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: max(look.radius - 4, 2)))
                    }
                    WhoopCard()
                    if look.readinessFirst { ReadinessPicker() }
                    SlotChips()
                    if !look.readinessFirst { ReadinessPicker() }
                    if store.adaptive.timeBox { TimeTodayPicker(session: session) }
                    AdaptiveNotes()
                    if let banner {
                        Text(banner)
                            .font(.subheadline.weight(.semibold))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.accent.opacity(0.2), in: RoundedRectangle(cornerRadius: look.radius))
                    }
                    if store.draft.startedAt == nil { WorkoutClock() }
                    NowCard(session: session, openFocus: { showFocus = true })
                    if !timer.isActive { CoachCueCard() }
                    ForEach(session.blocks, id: \.kind) { block in
                        BlockSection(block: block, session: session)
                    }
                    Button { showAddExercise = true } label: {
                        Label("Add exercises", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
                    Button { showBuild = true } label: {
                        Label("Build your own workout", systemImage: "square.and.pencil")
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
            // Workout time and heart rate stay pinned at the top while you scroll.
            .safeAreaInset(edge: .top, spacing: 0) { WorkoutStatusBar() }
            .safeAreaInset(edge: .bottom) {
                if timer.isActive && !showFocus {
                    VStack(spacing: 0) {
                        CoachCueCard(compact: true).padding(.horizontal).padding(.bottom, 8)
                        RestTimerBar(expand: { showRest = true })
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { askCoach = true } label: {
                        Label("Ask the coach", systemImage: "bubble.left.and.text.bubble.right")
                    }
                }
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
            .sheet(isPresented: $askCoach) { CoachChatView() }
            .sheet(isPresented: $showBuild) { CustomWorkoutView() }
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
        // A fast double tap must not log the session twice (the summary sheet is still opening).
        guard summary == nil else { return }
        timer.done()
        summary = store.finish(heart: { [heart] start, end in heart.summary(from: start, to: end) },
                               recovery: { [heart] ends in Fitness.recovery(heart.samples, workEnds: ends) })
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
                Button("Start next week") { confirmNextWeek = true }
                    .font(.subheadline.weight(.semibold))
                    .confirmationDialog(store.draft.hasAnyInput
                                        ? "Start next week? What's logged in today's session is cleared, and this can't be undone."
                                        : "Start next week? This week's open sessions are left undone.",
                                        isPresented: $confirmNextWeek, titleVisibility: .visible) {
                        Button("Start next week", role: .destructive) {
                            timer.done()
                            banner = store.startNextWeek()
                        }
                    }
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
                SectionLabel(text: "Week \(week.wk) / 12 · \(store.program.program.phaseName(week.phase))" + (week.cycle > 1 ? " · Cycle \(week.cycle)" : ""))
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
                ForEach(store.program.order, id: \.self) { slot in
                    Capsule()
                        .fill(store.program.isDone(slot) ? look.accent
                              : slot == store.draft.slot ? look.text : look.field)
                        .frame(height: 6)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("\(store.program.doneCount) of \(store.program.order.count) sessions done this week")
            HStack {
                Text("\(store.program.doneCount) of \(store.program.order.count) done")
                Spacer()
                if let p = store.nutritionAdvice?.proteinGrams {
                    Text("Protein \(store.proteinToday)/\(p) g").monospacedDigit()
                    Spacer()
                }
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
    /// A day picked while today's session has logged work: asks first.
    @State private var pendingSlot: Slot?

    var body: some View {
        let next = store.nextSlot
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(slots, id: \.self) { slot in
                    chip(slot, isNext: slot == next)
                }
            }
        }
        .confirmationDialog("Switch sessions? Everything logged in \(store.session.title) is cleared.",
                            isPresented: Binding(get: { pendingSlot != nil }, set: { if !$0 { pendingSlot = nil } }),
                            titleVisibility: .visible) {
            Button("Switch and clear", role: .destructive) {
                if let slot = pendingSlot {
                    timer.done()
                    store.select(slot)
                }
                pendingSlot = nil
            }
        }
    }

    /// The week's sessions, plus Hybrid 12's optional easy run.
    private var slots: [Slot] {
        store.program.order + (store.program.program == .hybrid12 ? [Slot.R] : [])
    }

    private func chip(_ slot: Slot, isNext: Bool) -> some View {
        let selected = store.draft.slot == slot && store.draft.custom == nil
        let done = store.program.isDone(slot)
        let day = store.program.order.firstIndex(of: slot).map { $0 + 1 }
        return Button {
            guard !selected else { return }
            if store.draft.hasAnyInput {
                pendingSlot = slot
            } else {
                timer.done()
                store.select(slot)
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if done { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.done) }
                    Text(day.map { "Day \($0)" } ?? "Optional")
                        .font(.caption2.weight(.semibold))
                    if isNext && !done {
                        Text("Next").font(.caption2.weight(.bold)).foregroundStyle(Theme.accent)
                    }
                }
                Text(slot == .R ? "Easy Run" : store.slotName(slot))
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

/// Adaptive 4: back after missed days.
struct ReEntryBanner: View {
    @Environment(AppStore.self) private var store
    @Environment(RestTimer.self) private var timer
    let plan: ReEntry.Plan
    @State private var confirmPhase = false

    var body: some View {
        let look = Theme.look
        let phaseStart = store.week.phase.rawValue * 4 + 1
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.uturn.backward.circle.fill").font(.title2).foregroundStyle(look.accent)
                Text("Welcome back").font(.headline)
            }
            Text(ReEntry.message(plan)).font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            if plan.offerPhaseRestart && store.week.wk != phaseStart {
                Button { confirmPhase = true } label: {
                    Text("Restart \(store.program.program.phaseName(store.week.phase)) at week \(phaseStart)")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(look.field, in: RoundedRectangle(cornerRadius: max(look.radius - 6, 2)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(look.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: look.radius))
        .overlay(RoundedRectangle(cornerRadius: look.radius).stroke(look.accent, lineWidth: 1.5))
        .confirmationDialog("Restart the phase at week \(phaseStart)?", isPresented: $confirmPhase, titleVisibility: .visible) {
            Button("Restart at week \(phaseStart)") {
                timer.done()
                store.restartPhase()
            }
        } message: {
            Text("After \(plan.daysOff) days off, redoing the phase rebuilds your base. Your weights and history stay.")
        }
    }
}

/// Adaptive 2: "Time today" trims the session to fit.
struct TimeTodayPicker: View {
    @Environment(AppStore.self) private var store
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Time today").font(.caption).foregroundStyle(Theme.secondary)
            Picker("Time today", selection: Binding(
                get: { store.draft.timeBudget ?? 0 },
                set: { store.setTimeBudget($0 == 0 ? nil : $0) }
            )) {
                Text("Full").tag(0)
                ForEach(TimeBox.choices, id: \.self) { Text("\($0) min").tag($0) }
            }
            .pickerStyle(.segmented)
            Text(TimeBox.summary(session) ?? "About \(TimeBox.minutes(session)) min.")
                .font(.caption)
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
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

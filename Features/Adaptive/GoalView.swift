import SwiftUI
import Hybrid12Engine

/// Plan > Goal: a target and a date. The app chains the right programs and says if you're on track.
struct GoalView: View {
    @Environment(AppStore.self) private var store
    @State private var kind: Goal.Kind = .vo2Max
    @State private var target: Double?
    @State private var liftID = "squat"
    @State private var deadline = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    @State private var editing = false

    static let lifts: [(id: String, name: String)] = [("squat", "Squat"), ("bench", "Bench"), ("deadlift", "Deadlift"), ("ohp", "Overhead press")]

    var body: some View {
        let look = Theme.look
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let goal = store.goal, !editing {
                    current(goal)
                } else {
                    form
                }
            }
            .padding()
        }
        .background(look.background)
        .navigationTitle("Goal")
    }

    private func current(_ goal: Goal) -> some View {
        let look = Theme.look
        let liftName = Self.lifts.first { $0.id == goal.liftID }?.name
        return VStack(alignment: .leading, spacing: 16) {
            Card(title: "Your goal") {
                Text(goal.title(liftName: liftName)).font(.title2.weight(.heavy))
                if let s = store.goalStatus {
                    Label(s.text, systemImage: s.done ? "trophy.fill" : s.onTrack ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(s.onTrack ? Theme.done : Color(hex: 0xF59E0B))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(goal.kind == .vo2Max ? "Log a VO2 max (Progress > Fitness) to track this."
                                              : "Log a weigh-in or the lift to track this.")
                        .font(.subheadline).foregroundStyle(look.secondary)
                }
            }
            Card(title: "The plan") {
                Text("12-week blocks until your date. Switch when each block ends (the app reminds you from week 10).")
                    .font(.caption).foregroundStyle(look.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(Array(store.goalPlan.enumerated()), id: \.offset) { i, block in
                    HStack {
                        Text(i == 0 && block.program == store.program.program ? "Now" : block.starts.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.subheadline.monospacedDigit()).frame(width: 64, alignment: .leading)
                        Text(block.program.name).font(.headline)
                        Spacer()
                    }
                }
            }
            HStack {
                Button("Change goal") { load(goal); editing = true }
                Spacer()
                Button("Clear goal", role: .destructive) { store.goal = nil }
            }
            .font(.subheadline.weight(.semibold))
        }
    }

    private var form: some View {
        let look = Theme.look
        let now = store.goalValue(kind, liftID: kind == .lift ? liftID : nil)
        return VStack(alignment: .leading, spacing: 16) {
            Text("Set a target and a date. The app picks the programs to get there and checks every week whether you're on track.")
                .font(.subheadline).foregroundStyle(look.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Picker("Goal", selection: $kind) {
                ForEach(Goal.Kind.allCases, id: \.self) { Text($0.name).tag($0) }
            }
            .pickerStyle(.segmented)
            if kind == .lift {
                Picker("Lift", selection: $liftID) {
                    ForEach(Self.lifts, id: \.id) { Text($0.name).tag($0.id) }
                }
                .pickerStyle(.segmented)
            }
            Card(title: "Target") {
                HStack {
                    NumberField(placeholder: placeholder, value: target) { target = $0 }
                    Text(kind == .vo2Max ? "ml/kg/min" : "lb").font(.subheadline).foregroundStyle(look.secondary)
                    Spacer()
                }
                Text(now.map { "Now: \(lb($0))\(kind == .vo2Max ? "" : " lb")\(kind == .lift ? " estimated max" : "")" }
                     ?? (kind == .vo2Max ? "No VO2 max yet: log one on Progress > Fitness." : "No data yet."))
                    .font(.caption).foregroundStyle(look.secondary)
                if kind == .vo2Max, let age = store.age {
                    let n = Fitness.norms(age: age)
                    Text("For men \(age): average about \(lb(n.average)), good \(lb(n.good)).")
                        .font(.caption).foregroundStyle(look.secondary)
                }
            }
            Card(title: "By") {
                DatePicker("Date", selection: $deadline, in: Date().addingTimeInterval(28 * 86400)..., displayedComponents: .date)
                    .labelsHidden()
            }
            Button {
                guard let target, target > 0 else { return }
                store.goal = Goal(kind: kind, target: target, liftID: kind == .lift ? liftID : nil,
                                  start: Date(), deadline: deadline, startValue: now)
                editing = false
            } label: { Text("Save goal").accentButton(height: 56) }
                .buttonStyle(.plain)
                .disabled((target ?? 0) <= 0)
            if editing {
                Button("Cancel") { editing = false }.font(.subheadline)
            }
        }
    }

    private var placeholder: String {
        switch kind {
        case .vo2Max: return "45"
        case .bodyweight: return "185"
        case .lift: return "315"
        }
    }

    private func load(_ g: Goal) {
        kind = g.kind
        target = g.target
        liftID = g.liftID ?? "squat"
        deadline = g.deadline
    }
}

/// Plan and Programs, from week 10 of a block: what to run next and why.
struct NextBlockCard: View {
    @Environment(AppStore.self) private var store
    @Environment(RestTimer.self) private var timer
    @State private var confirm = false

    var body: some View {
        if let next = store.nextBlock {
            let look = Theme.look
            let wk = (store.program.programWeek.week - 1) % 12 + 1
            Card(title: wk >= 12 ? "Block done: what's next" : "Next block (after week 12)") {
                Text(next.program.name).font(.title3.weight(.heavy))
                Text(next.reason).font(.subheadline).foregroundStyle(look.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if next.program != store.program.program {
                    Button(wk >= 12 ? "Start \(next.program.name)" : "Start it now") { confirm = true }
                        .font(.subheadline.weight(.bold))
                        .confirmationDialog("Start \(next.program.name)?", isPresented: $confirm, titleVisibility: .visible) {
                            Button("Start \(next.program.name)") {
                                timer.done()
                                store.chooseProgram(next.program, days: store.program.days)
                            }
                        } message: {
                            Text("\(store.program.program.name) remembers where you are, so you can come back.")
                        }
                }
            }
        }
    }
}

import SwiftUI
import Hybrid12Engine

/// Build your own workout: saved workouts to start, and an editor for new ones.
struct CustomWorkoutView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var editing: CustomWorkout?
    @State private var confirmStart: CustomWorkout?

    var body: some View {
        let look = Theme.look
        NavigationStack {
            List {
                Section {
                    Button {
                        editing = CustomWorkout(name: "", items: [])
                    } label: {
                        Label("New workout", systemImage: "plus.circle.fill").font(.headline)
                    }
                } footer: {
                    Text("Pick the exercises, sets, reps and rest. It's logged and progressed like any session, as an extra: it never counts as one of the program's days.")
                }
                if !store.customWorkouts.isEmpty {
                    Section("My workouts") {
                        ForEach(store.customWorkouts) { w in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(w.name.isEmpty ? "Your workout" : w.name).font(.headline)
                                    Text(w.items.compactMap { store.catalog.exercise($0.exerciseID)?.name }.joined(separator: ", "))
                                        .font(.caption).foregroundStyle(look.secondary).lineLimit(2)
                                }
                                Spacer()
                                Button("Start") { start(w) }
                                    .buttonStyle(.borderedProminent).tint(look.accent)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { editing = w }
                            .swipeActions { Button("Delete", role: .destructive) { store.deleteCustom(w) } }
                        }
                    }
                }
            }
            .navigationTitle("Build your own")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .sheet(item: $editing) { w in
                CustomWorkoutEditor(workout: w) { saved, startNow in
                    store.saveCustom(saved)
                    editing = nil
                    if startNow { start(saved) }
                }
            }
            .confirmationDialog("Start \(confirmStart?.name ?? "")? What's logged in today's session is cleared.",
                                isPresented: Binding(get: { confirmStart != nil }, set: { if !$0 { confirmStart = nil } }),
                                titleVisibility: .visible) {
                Button("Start", role: .destructive) {
                    if let w = confirmStart { store.startCustom(w); dismiss() }
                    confirmStart = nil
                }
            }
        }
    }

    private func start(_ w: CustomWorkout) {
        if store.draft.hasAnyInput { confirmStart = w } else { store.startCustom(w); dismiss() }
    }
}

/// Name, exercises, and sets × reps and rest for each.
struct CustomWorkoutEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var workout: CustomWorkout
    let done: (CustomWorkout, Bool) -> Void
    @State private var picking = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Name (e.g. Arms + Abs)", text: $workout.name)
                }
                Section("Exercises") {
                    ForEach(Array(workout.items.enumerated()), id: \.offset) { i, item in
                        if let ex = store.catalog.exercise(item.exerciseID) {
                            row(i, ex)
                        }
                    }
                    .onDelete { workout.items.remove(atOffsets: $0) }
                    .onMove { workout.items.move(fromOffsets: $0, toOffset: $1) }
                    Button { picking = true } label: { Label("Add exercises", systemImage: "plus") }
                }
                Section {
                    Button("Save and start") { done(workout, true) }.bold().disabled(workout.items.isEmpty)
                    Button("Save") { done(workout, false) }.disabled(workout.items.isEmpty)
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle(workout.name.isEmpty ? "New workout" : workout.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .sheet(isPresented: $picking) {
                ExercisePicker(exclude: Set(workout.items.map(\.exerciseID))) { ids in
                    for id in ids {
                        if let ex = store.catalog.exercise(id) { workout.items.append(CustomWorkout.defaults(for: ex)) }
                    }
                }
            }
        }
    }

    private func row(_ i: Int, _ ex: Exercise) -> some View {
        let item = workout.items[i]
        let unit = ex.unit == .sec ? " sec" : ex.unit == .yd ? " yd" : ""
        return VStack(alignment: .leading, spacing: 8) {
            Text(ex.name).font(.headline)
            HStack {
                Stepper("\(item.sets) sets", value: Binding(get: { workout.items[i].sets },
                                                             set: { workout.items[i].sets = min(10, max(1, $0)) }), in: 1...10)
                    .fixedSize()
                Spacer()
                Menu {
                    ForEach(Array(CustomWorkout.repChoices(ex.unit).enumerated()), id: \.offset) { _, c in
                        Button(c.low == c.high ? "\(c.low)\(unit)" : "\(c.low)-\(c.high)\(unit)") {
                            workout.items[i].low = c.low
                            workout.items[i].high = c.high
                        }
                    }
                } label: {
                    Text(item.low == item.high ? "× \(item.low)\(unit)" : "× \(item.low)-\(item.high)\(unit)").bold()
                }
            }
            Menu {
                ForEach(CustomWorkout.restChoices, id: \.self) { r in
                    Button(r < 60 ? "\(r) sec rest" : "\(r / 60):\(String(format: "%02d", r % 60)) rest") { workout.items[i].rest = r }
                }
            } label: {
                Text("Rest \(item.rest < 60 ? "\(item.rest) sec" : "\(item.rest / 60):\(String(format: "%02d", item.rest % 60))")")
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Pick exercises you have the gear for, grouped like Add exercises.
struct ExercisePicker: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let exclude: Set<String>
    let picked: ([String]) -> Void
    @State private var search = ""
    @State private var chosen: [String] = []

    private var groups: [(title: String, exercises: [Exercise])] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        func keep(_ e: Exercise) -> Bool {
            store.gear.has(e) && !exclude.contains(e.id) && (q.isEmpty || e.name.lowercased().contains(q))
        }
        var out: [(String, [Exercise])] = []
        let mains = store.catalog.mainLifts.filter(keep)
        if !mains.isEmpty { out.append(("Main lifts", mains)) }
        var order: [String] = []
        for e in store.catalog.accessories where !order.contains(e.category) { order.append(e.category) }
        for c in order {
            let list = store.catalog.accessories(in: c).filter(keep).sorted { $0.name < $1.name }
            if !list.isEmpty { out.append((AddExerciseSheet.title(c), list)) }
        }
        return out
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groups, id: \.title) { g in
                    Section(g.title) {
                        ForEach(g.exercises, id: \.id) { ex in
                            Button {
                                if let i = chosen.firstIndex(of: ex.id) { chosen.remove(at: i) } else { chosen.append(ex.id) }
                            } label: {
                                HStack {
                                    Text(ex.name).foregroundStyle(Theme.text)
                                    Spacer()
                                    if let n = chosen.firstIndex(of: ex.id) {
                                        Text("\(n + 1)").font(.caption.weight(.heavy)).foregroundStyle(Theme.onAccent)
                                            .frame(width: 24, height: 24).background(Theme.accent, in: Circle())
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $search)
            .navigationTitle("Add exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(chosen.isEmpty ? "Add" : "Add \(chosen.count)") { picked(chosen); dismiss() }.disabled(chosen.isEmpty)
                }
            }
        }
    }
}

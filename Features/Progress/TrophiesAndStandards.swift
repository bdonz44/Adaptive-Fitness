import SwiftUI
import Hybrid12Engine

/// Progress: milestones reached and the next ones up.
struct TrophiesCard: View {
    @Environment(AppStore.self) private var store
    @State private var showAll = false

    var body: some View {
        let look = Theme.look
        let all = store.milestones
        let done = all.filter(\.achieved)
        let next = all.filter { !$0.achieved }.sorted { $0.fraction > $1.fraction }.prefix(3)
        Card(title: "Milestones · \(done.count) of \(all.count)") {
            if !done.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(done.reversed()) { m in
                            Label(m.title, systemImage: "trophy.fill")
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .foregroundStyle(look.onAccent)
                                .background(look.accent, in: Capsule())
                        }
                    }
                }
            }
            Text("Next up").font(.caption.weight(.heavy)).foregroundStyle(look.secondary)
            ForEach(Array(next)) { m in progressRow(m) }
            Button("All milestones") { showAll = true }.font(.subheadline)
        }
        .sheet(isPresented: $showAll) {
            NavigationStack {
                List(all) { m in
                    HStack {
                        Image(systemName: m.achieved ? "trophy.fill" : "trophy").foregroundStyle(m.achieved ? look.accent : look.secondary)
                        VStack(alignment: .leading) {
                            Text(m.title).font(.subheadline.weight(.semibold))
                            Text(m.detail).font(.caption).foregroundStyle(look.secondary)
                        }
                        Spacer()
                        if !m.achieved { Text("\(Int((m.fraction * 100).rounded()))%").font(.caption).monospacedDigit() }
                    }
                }
                .navigationTitle("Milestones")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showAll = false } } }
            }
        }
    }

    private func progressRow(_ m: Milestone) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(m.title).font(.subheadline.weight(.semibold))
                Spacer()
                Text(m.kind == .plates || m.kind == .club || m.kind == .bodyweight
                     ? "\(lb(m.progress.rounded())) / \(lb(m.target))" : "\(Int(m.progress)) / \(Int(m.target))")
                    .font(.caption).monospacedDigit().foregroundStyle(Theme.secondary)
            }
            ProgressView(value: m.fraction).tint(Theme.accent)
        }
    }
}

/// Progress: where each big lift stands for your bodyweight and age (the age updates on its own).
struct StandardsCard: View {
    @Environment(AppStore.self) private var store
    @State private var picking = false
    @State private var picked = Calendar.current.date(from: DateComponents(year: 1981, month: 1, day: 1)) ?? Date()

    var body: some View {
        let look = Theme.look
        Card(title: store.age.map { "Strength standards · age \($0)" } ?? "Strength standards") {
            if store.age == nil || picking {
                Text("Your birthday sets the age adjustment, and it updates every year on its own.")
                    .font(.subheadline).foregroundStyle(look.secondary)
                DatePicker("Birthday", selection: $picked, in: ...Date(), displayedComponents: .date)
                Button("Save birthday") { store.birthDate = picked; picking = false }.buttonStyle(.borderedProminent)
            } else if let age = store.age, let bw = store.weighIns.last?.pounds {
                ForEach(StrengthStandards.lifts, id: \.self) { id in
                    if let max = Suggestions.best1RM(store.lifts[id]) {
                        let s = StrengthStandards.standing(id, e1RM: max, bodyweight: bw, age: age)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(store.catalog.exercise(id)?.name ?? id).font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(s.tier ?? "Not yet Beginner").font(.subheadline.weight(.heavy)).foregroundStyle(look.accent)
                            }
                            Text("Est. max \(lb(Suggestions.round5(max))) lb · \(String(format: "%.2f", s.ratio))× bodyweight"
                                 + (s.next.map { n in s.nextWeight.map { " · \(n) at \(lb($0))" } ?? "" } ?? " · top tier"))
                                .font(.caption).foregroundStyle(look.secondary)
                            let tiers = StrengthStandards.weights(id, bodyweight: bw, age: age)
                            ProgressView(value: min(max, tiers.last ?? max), total: tiers.last ?? max).tint(look.accent)
                        }
                    }
                }
                Text("At \(lb(bw)) lb and age \(age). Tiers ease with age (about 6% at 45, 14% at 50). A guide from common strength-standard tables, not a test.")
                    .font(.caption2).foregroundStyle(look.secondary).fixedSize(horizontal: false, vertical: true)
                Button("Change birthday") { picked = store.birthDate ?? picked; picking = true }.font(.caption)
            } else {
                Text("Log a weigh-in and finish a few main lifts to see where you stand.")
                    .font(.subheadline).foregroundStyle(look.secondary)
            }
        }
    }
}

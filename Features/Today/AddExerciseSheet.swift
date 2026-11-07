import SwiftUI
import Hybrid12Engine

/// "Add exercise": every exercise in the library, grouped, with search.
/// Picking one adds it to today's Extras.
struct AddExerciseSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let session: Session
    @State private var search = ""

    private var groups: [(title: String, exercises: [Exercise])] {
        let inSession = Set(session.items.compactMap(\.exerciseID))
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        func keep(_ e: Exercise) -> Bool {
            !inSession.contains(e.id) && (query.isEmpty || e.name.lowercased().contains(query)
                                          || e.category.lowercased().contains(query))
        }
        var result: [(String, [Exercise])] = []
        let mains = store.catalog.mainLifts.filter(keep)
        if !mains.isEmpty { result.append(("Main lifts", mains)) }
        var order: [String] = []
        for e in store.catalog.accessories where !order.contains(e.category) { order.append(e.category) }
        for category in order {
            let list = store.catalog.accessories(in: category).filter(keep).sorted { $0.name < $1.name }
            if !list.isEmpty { result.append((Self.title(category), list)) }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groups, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.exercises, id: \.id) { e in
                            Button {
                                store.addExtra(e.id)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(e.name).font(.body.weight(.semibold)).foregroundStyle(Theme.text)
                                    Text(Self.equipment(e.eq)).font(.caption).foregroundStyle(Theme.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Search exercises")
            .navigationTitle("Add exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    static let names = ["bicep": "Biceps", "tricep": "Triceps", "delt": "Shoulders", "chest": "Chest",
                        "row": "Back", "quad": "Legs", "hinge": "Hinge", "core": "Core", "full": "Full body",
                        "main": "Big lifts"]

    /// "bicep" -> "Biceps"; unknown "rearDelt" -> "Rear Delt"
    static func title(_ category: String) -> String {
        if let name = names[category] { return name }
        var out = ""
        for ch in category {
            if ch.isUppercase { out.append(" ") }
            out.append(ch)
        }
        return out.replacingOccurrences(of: "_", with: " ").capitalized
    }

    static func equipment(_ eq: Equipment) -> String {
        switch eq {
        case .bb: return "Barbell"
        case .db: return "Dumbbells"
        case .kb: return "Kettlebell"
        case .bw: return "Bodyweight"
        }
    }
}

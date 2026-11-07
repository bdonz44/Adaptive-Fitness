import SwiftUI
import Hybrid12Engine

/// Log food: tap protein quick adds, or type protein and calories. Targets live at the bottom.
struct FoodLogSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var protein = ""
    @State private var calories = ""

    var body: some View {
        let look = Theme.look
        let advice = store.nutritionAdvice
        let pTarget = advice?.proteinGrams
        let cTarget = advice?.calorieTarget
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Progress
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Today").font(.caption.weight(.heavy)).foregroundStyle(look.accent)
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(store.proteinToday)").font(look.number(52)).monospacedDigit()
                            Text(pTarget.map { "/ \($0) g protein" } ?? "g protein").font(.title3).foregroundStyle(look.secondary)
                        }
                        if let t = pTarget {
                            ProgressView(value: Double(min(store.proteinToday, t)), total: Double(max(t, 1))).tint(look.accent)
                            Text(store.proteinToday >= t ? "Protein done. That's how muscle stays while the fat goes."
                                 : "\(t - store.proteinToday) g to go.")
                                .font(.subheadline.weight(.semibold))
                        }
                        Text(Nutrition.progressText(store.caloriesToday, of: cTarget, unit: "cal") + (cTarget == nil ? " logged" : ""))
                            .font(.subheadline).foregroundStyle(look.secondary)
                    }
                    .padding(16)
                    .lookCard(highlight: true)

                    // Quick add
                    Text("Add protein").font(.headline)
                    HStack(spacing: 8) {
                        ForEach(Nutrition.quickProtein, id: \.self) { g in
                            Button { store.logFood(protein: g) } label: {
                                Text("+\(g) g")
                                    .font(.headline).monospacedDigit()
                                    .frame(maxWidth: .infinity, minHeight: 52)
                                    .foregroundStyle(look.onAccent)
                                    .background(look.accent, in: RoundedRectangle(cornerRadius: max(look.radius - 6, 2)))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Add \(g) grams of protein")
                        }
                    }

                    // Custom
                    Text("Or type it").font(.headline)
                    HStack(spacing: 8) {
                        field("Protein", text: $protein, unit: "g")
                        field("Calories", text: $calories, unit: "cal")
                        Button("Add") {
                            store.logFood(protein: Int(protein) ?? 0, calories: Int(calories) ?? 0)
                            protein = ""; calories = ""
                            hideKeyboard()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled((Int(protein) ?? 0) <= 0 && (Int(calories) ?? 0) <= 0)
                    }

                    // Today's entries
                    if !store.foodToday.isEmpty {
                        Card(title: "Logged today") {
                            ForEach(store.foodToday) { e in
                                HStack {
                                    Text(e.date.formatted(date: .omitted, time: .shortened)).foregroundStyle(look.secondary)
                                    Text([e.protein > 0 ? "\(e.protein) g protein" : nil, e.calories > 0 ? "\(e.calories) cal" : nil]
                                        .compactMap { $0 }.joined(separator: " · "))
                                    Spacer()
                                    Button { store.removeFood(e) } label: { Image(systemName: "xmark.circle.fill") }
                                        .buttonStyle(.plain).foregroundStyle(look.secondary)
                                        .accessibilityLabel("Remove entry")
                                }
                                .font(.subheadline)
                            }
                        }
                    }

                    // Targets
                    NutritionTargets()
                }
                .padding()
            }
            .background(look.background)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func field(_ placeholder: String, text: Binding<String>, unit: String) -> some View {
        HStack(spacing: 4) {
            TextField(placeholder, text: text)
                .keyboardType(.numberPad)
                .monospacedDigit()
            Text(unit).font(.caption).foregroundStyle(Theme.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 10)
        .background(Theme.field, in: RoundedRectangle(cornerRadius: 10))
    }
}

/// Goal weight (sets the protein target) and usual calories (turns the calorie call into a number).
struct NutritionTargets: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let look = Theme.look
        Card(title: "Targets") {
            Text("These set your numbers. They are not food.").font(.caption).foregroundStyle(look.secondary)
            row("Goal weight", now: store.nutritionSettings.goalWeight.map { "\(lb($0)) lb → \(Int($0.rounded())) g protein a day" } ?? "Not set",
                placeholder: "Goal weight", unit: "lb") { store.nutritionSettings.goalWeight = $0 }
            row("Usual calories a day", now: store.nutritionSettings.currentCalories.map { "\($0) cal" } ?? "Optional",
                placeholder: "Usual calories", unit: "cal") { store.nutritionSettings.currentCalories = Int($0.rounded()) }
        }
    }

    private func row(_ title: String, now: String, placeholder: String, unit: String, set: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Text(now).font(.subheadline).foregroundStyle(Theme.secondary)
            }
            LogField(placeholder: placeholder, unit: unit, onLog: set)
        }
    }
}

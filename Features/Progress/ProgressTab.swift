import SwiftUI
import Charts
import Hybrid12Engine

/// Coach check, cardio, bodyweight, waist, working weights and recent sessions.
struct ProgressTab: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    WeeklyReviewButton()
                    CoachCard()
                    InsightsCard()
                    FitnessCard()
                    CardioCard()
                    NutritionCard()
                    HardMinutesCard()
                    MuscleSetsCard()
                    BodyweightCard()
                    WaistCard()
                    MeasurementsCard()
                    WorkingWeightsCard()
                    StandardsCard()
                    TrophiesCard()
                    RecentSessionsCard()
                }
                .padding()
            }
            .background(Theme.background)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Theme.look.uppercaseTitles ? "PROGRESS" : "Progress")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hideKeyboard() }
                }
            }
        }
    }
}

// MARK: - Shared pieces

struct Card<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: title, color: Theme.accent)
            VStack(alignment: .leading, spacing: 12) { content }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .lookCard()
        }
    }
}

/// A number box and a Log button. Clears after logging.
struct LogField: View {
    let placeholder: String
    let unit: String
    let onLog: (Double) -> Void
    @State private var text = ""

    private var value: Double? { typedNumber(text).flatMap { $0 > 0 ? $0 : nil } }

    var body: some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
                .monospacedDigit()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Theme.field, in: RoundedRectangle(cornerRadius: 10))
            Text(unit).foregroundStyle(Theme.secondary)
            Button("Log") {
                guard let value, value > 0 else { return }
                onLog(value)
                text = ""
                hideKeyboard()
            }
            .buttonStyle(.borderedProminent)
            .disabled((value ?? 0) <= 0)
        }
    }
}

struct TrendChart: View {
    let points: [(date: Date, value: Double)]
    let unit: String

    var body: some View {
        let values = points.map(\.value)
        let low = (values.min() ?? 0) - 2
        let high = (values.max() ?? 0) + 2
        Chart(points, id: \.date) { p in
            LineMark(x: .value("Date", p.date), y: .value(unit, p.value))
                .foregroundStyle(Theme.accent)
            PointMark(x: .value("Date", p.date), y: .value(unit, p.value))
                .foregroundStyle(Theme.accent)
                .symbolSize(20)
        }
        .chartYScale(domain: low...high)
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in
            AxisGridLine(); AxisValueLabel(format: .dateTime.month(.abbreviated).day())
        } }
        .frame(height: 140)
    }
}

struct Sparkline: View {
    let values: [Double]

    var body: some View {
        Chart(Array(values.enumerated()), id: \.offset) { i, v in
            LineMark(x: .value("Session", i), y: .value("Weight", v))
                .foregroundStyle(Theme.accent)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: (values.min() ?? 0)...max((values.max() ?? 1), (values.min() ?? 0) + 1))
        .frame(width: 64, height: 24)
    }
}

/// Latest value, change since first, a chart, and the last few entries with Remove.
struct MeasureSummary: View {
    let points: [(date: Date, value: Double)]
    let unit: String
    let onRemove: (Int) -> Void

    var body: some View {
        if let trend = Tracking.trend(points.map(\.value)) {
            HStack(alignment: .firstTextBaseline) {
                Text(lb(trend.latest)).font(.title.weight(.bold)).monospacedDigit()
                Text(unit).foregroundStyle(Theme.secondary)
                Spacer()
                if let change = trend.changeSinceFirst {
                    Text("\(Tracking.changeText(change, unit: unit)) since first")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondary)
                }
            }
            if points.count >= 2 {
                TrendChart(points: points, unit: unit)
            }
            let recent = Array(points.enumerated().suffix(Tracking.weighInListLimit).reversed())
            VStack(spacing: 0) {
                ForEach(recent, id: \.offset) { index, p in
                    HStack {
                        Text(p.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                            .foregroundStyle(Theme.secondary)
                        Spacer()
                        Text("\(lb(p.value)) \(unit)").monospacedDigit()
                        Button("Remove", role: .destructive) { onRemove(index) }
                            .font(.caption)
                            .buttonStyle(.borderless)
                            .padding(.leading, 8)
                    }
                    .font(.subheadline)
                    .padding(.vertical, 6)
                }
            }
        }
    }
}

// MARK: - Sections

struct CoachCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Card(title: "Coach check") {
            ForEach(Array(store.coachNotes().enumerated()), id: \.offset) { _, note in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: icon(note.kind))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 22)
                    Text(note.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func icon(_ kind: CoachNote.Kind) -> String {
        switch kind {
        case .weight: return "scalemass"
        case .cardio: return "figure.run"
        case .strength: return "dumbbell"
        }
    }
}

struct CardioCard: View {
    @Environment(AppStore.self) private var store
    @State private var kind: ManualCardio.Kind = .run

    var body: some View {
        let goal = Program.cardioGoalMinutes
        let minutes = store.cardioThisWeek
        Card(title: "Cardio") {
            HStack {
                Text("This week")
                Spacer()
                Text("\(minutes) of \(goal) min").monospacedDigit().foregroundStyle(Theme.secondary)
            }
            ProgressView(value: min(1, Double(minutes) / Double(goal)))
            if store.whoopCardioThisWeek > 0 {
                Text("Includes \(store.whoopCardioThisWeek) min from WHOOP (\(store.whoopCardioSports.joined(separator: ", "))).")
                    .font(.caption)
                    .foregroundStyle(Theme.secondary)
            }
            ForEach(store.manualCardioThisWeek) { entry in
                HStack {
                    Label("\(entry.kind.name) · \(entry.minutes) min", systemImage: entry.kind.icon).font(.subheadline)
                    Spacer()
                    Text(entry.date.formatted(.dateTime.weekday(.abbreviated))).font(.caption).foregroundStyle(Theme.secondary)
                    Button { store.removeCardio(entry) } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(Theme.secondary)
                        .accessibilityLabel("Remove \(entry.kind.name) \(entry.minutes) minutes")
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Picker("Type", selection: $kind) {
                    ForEach(ManualCardio.Kind.allCases, id: \.self) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                LogField(placeholder: "\(kind.name) minutes", unit: "min") { store.logCardio(kind, minutes: Int($0.rounded())) }
                Text("Only log what WHOOP didn't track, or it counts twice.")
                    .font(.caption2).foregroundStyle(Theme.secondary)
            }
            if store.program.week > 1 {
                let last = store.cardioByWeek[store.program.week - 1] ?? 0
                Text("Last week: \(last) min")
                    .font(.caption)
                    .foregroundStyle(Theme.secondary)
            }
        }
    }
}

/// Minutes at 80%+ of max heart rate per week: the work that raises VO2 max.
struct HardMinutesCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let weeks = store.hardMinutesByWeek
        if !weeks.isEmpty {
            Card(title: "Zone 4-5 minutes") {
                Chart(Array(weeks.enumerated()), id: \.offset) { _, w in
                    BarMark(x: .value("Week", w.label), y: .value("Minutes", w.minutes))
                        .foregroundStyle(Theme.accent)
                        .annotation(position: .top) {
                            Text("\(Int(w.minutes.rounded()))").font(.caption2).foregroundStyle(Theme.secondary)
                        }
                }
                .frame(height: 150)
                Text("Time at 80%+ of max heart rate, from WHOOP or live heart rate. This is the work that raises VO2 max; 4×4 days add about 16 minutes each.")
                    .font(.caption).foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Adaptive 6: today's protein against the target, the calorie call, and the food log (hidden when switched off).
struct NutritionCard: View {
    @Environment(AppStore.self) private var store
    @State private var logging = false

    var body: some View {
        if let a = store.nutritionAdvice {
            let look = Theme.look
            Card(title: "Nutrition") {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Nutrition.progressText(store.proteinToday, of: a.proteinGrams, unit: "g"))
                            .font(look.number(32)).monospacedDigit()
                        Text("Protein eaten today").font(.caption).foregroundStyle(look.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(a.calorieChange == 0 ? "Hold" : (a.calorieChange > 0 ? "+\(a.calorieChange)" : "\(a.calorieChange)"))
                            .font(look.number(32)).monospacedDigit()
                            .foregroundStyle(a.calorieChange < 0 ? look.accent : (a.calorieChange > 0 ? look.done : look.text))
                        Text(a.calorieTarget.map { "Aim for \($0) cal a day" } ?? "Calorie change a day").font(.caption).foregroundStyle(look.secondary)
                    }
                }
                Text(a.headline).font(.headline)
                Text(a.detail).font(.subheadline).foregroundStyle(look.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let r = a.ratePerWeek {
                    Text("Trend: \(r <= 0 ? "losing" : "gaining") \(String(format: "%.1f", abs(r))) lb a week (last 28 days).")
                        .font(.caption).foregroundStyle(look.secondary)
                }
                Button { logging = true } label: { Label("Log food", systemImage: "plus.circle.fill").accentButton(height: 50) }
                    .buttonStyle(.plain)
                if store.nutritionSettings.goalWeight == nil {
                    Text("Set your goal weight in Log food → Targets so protein matches your goal.")
                        .font(.caption).foregroundStyle(look.accent)
                }
            }
            .sheet(isPresented: $logging) { FoodLogSheet() }
        }
    }
}

struct BodyweightCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let entries = store.weighIns
        Card(title: "Bodyweight") {
            if entries.isEmpty {
                Text("Weigh in once or twice a week, at the same time of day.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
            }
            MeasureSummary(points: entries.map { ($0.date, $0.pounds) }, unit: "lb") { index in
                store.removeWeighIn(entries[index])
            }
            LogField(placeholder: "Today's weight", unit: "lb") { store.addWeighIn($0) }
        }
    }
}

struct WaistCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let entries = store.waist
        Card(title: "Waist") {
            if Tracking.showsWaistTarget(entryCount: entries.count) {
                Text("Measure at the belly button once a week. The heart-health target is under \(lb(Tracking.waistTarget)) in.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
            }
            MeasureSummary(points: entries.map { ($0.date, $0.inches) }, unit: "in") { index in
                store.removeWaist(entries[index])
            }
            LogField(placeholder: "Waist", unit: "in") { store.addWaist($0) }
        }
    }
}

struct WorkingWeightsCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let rows = store.workingWeights
        Card(title: "Working weights") {
            if rows.isEmpty {
                Text("Finish a session and your lifts show up here.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
            }
            ForEach(rows) { row in
                NavigationLink { LiftHistoryView(exerciseID: row.id) } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.name)
                            .font(row.isMain ? .body.weight(.semibold) : .body)
                        if let max = row.estimatedMax {
                            Text("Est. max \(lb(max)) lb")
                                .font(.caption)
                                .foregroundStyle(Theme.secondary)
                        }
                        if let f = store.forecast(row.id) {
                            Text("\(lb(f.target)) by \(f.date.formatted(.dateTime.month(.abbreviated).day()))")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    Spacer()
                    if row.history.count >= 2 {
                        Sparkline(values: row.history)
                    }
                    Text("\(lb(row.weight)) lb")
                        .monospacedDigit()
                        .frame(minWidth: 60, alignment: .trailing)
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.secondary)
                }
                .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct RecentSessionsCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Card(title: "Recent sessions") {
            if store.recentLogs.isEmpty {
                Text("Nothing logged yet.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
            }
            ForEach(store.recentLogs) { log in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(log.title)
                        Text(log.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                            .font(.caption)
                            .foregroundStyle(Theme.secondary)
                        if let h = log.heart {
                            Label(h.line, systemImage: "heart.fill")
                                .font(.caption)
                                .foregroundStyle(Theme.secondary)
                        }
                    }
                    Spacer()
                    Text("Week \(store.displayWeek(log.week))")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondary)
                }
            }
        }
    }
}

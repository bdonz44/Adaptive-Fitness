import Charts
import SwiftUI
import Hybrid12Engine

/// Every session of one lift: estimated max over time, best set ever, best weight at each rep count.
struct LiftHistoryView: View {
    @Environment(AppStore.self) private var store
    let exerciseID: String

    var body: some View {
        let look = Theme.look
        let rec = store.lifts[exerciseID]
        let stats = LiftStats(rec)
        let name = store.catalog.exercise(exerciseID)?.name ?? exerciseID
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(look.uppercaseTitles ? name.uppercased() : name).font(look.title(34)).minimumScaleFactor(0.6)
                if stats.sessions.isEmpty {
                    Text("No sessions logged yet. Finish a workout with this lift and its history starts here.")
                        .font(.subheadline).foregroundStyle(look.secondary)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        tile(rec?.workingWeight.map { "\(lb($0))" } ?? "--", "Working weight")
                        tile(stats.best.map { "\(lb(Suggestions.round5($0.e1RM)))" } ?? "--", "Best estimated max")
                        tile(stats.best.map { "\(lb($0.weight)) × \($0.reps)" } ?? "--", "Best set")
                        tile("\(stats.sessions.count)", "Sessions")
                    }
                    if stats.sessions.count >= 2 {
                        Card(title: "Estimated max") {
                            Chart(Array(stats.sessions.enumerated()), id: \.offset) { _, p in
                                LineMark(x: .value("Date", p.date), y: .value("Max", p.e1RM))
                                    .foregroundStyle(look.accent).interpolationMethod(.catmullRom)
                                PointMark(x: .value("Date", p.date), y: .value("Max", p.e1RM))
                                    .foregroundStyle(look.accent).symbolSize(20)
                            }
                            .chartYScale(domain: .automatic(includesZero: false))
                            .frame(height: 180)
                            if let p = HomeInsights.projection(stats.sessions.map { ($0.date, $0.e1RM) }, now: Date()) {
                                Text("On pace for \(lb(p.target)) by \(p.date.formatted(.dateTime.month(.abbreviated).day())).")
                                    .font(.subheadline.weight(.semibold)).foregroundStyle(look.accent)
                            }
                        }
                    }
                    if !stats.repBests.isEmpty {
                        Card(title: "Best top set at each rep count") {
                            ForEach(stats.repBests, id: \.reps) { r in
                                HStack {
                                    Text("\(r.reps) rep\(r.reps == 1 ? "" : "s")").frame(width: 60, alignment: .leading)
                                    Text("\(lb(r.weight)) lb").fontWeight(.bold).monospacedDigit()
                                    Spacer()
                                    Text(r.date.formatted(.dateTime.month(.abbreviated).day().year(.twoDigits)))
                                        .font(.caption).foregroundStyle(look.secondary)
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                    Card(title: "Sessions") {
                        ForEach(Array(stats.sessions.reversed().enumerated()), id: \.offset) { i, p in
                            HStack {
                                Text(p.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                                    .foregroundStyle(look.secondary)
                                Spacer()
                                Text("\(lb(p.weight)) × \(p.reps)").monospacedDigit().fontWeight(p == stats.best ? .heavy : .regular)
                                if p == stats.best { Image(systemName: "trophy.fill").foregroundStyle(look.accent) }
                            }
                            .font(.subheadline)
                        }
                    }
                }
            }
            .padding()
        }
        .background(look.background)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tile(_ value: String, _ label: String) -> some View {
        let look = Theme.look
        return VStack(alignment: .leading, spacing: 4) {
            Text(value).font(look.number(26)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
            Text(label).font(.caption).foregroundStyle(look.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .lookCard()
    }
}

/// A small chart button that opens a lift's history.
struct HistoryButton: View {
    let exerciseID: String
    @State private var show = false

    var body: some View {
        Button { show = true } label: {
            Image(systemName: "chart.line.uptrend.xyaxis").font(.subheadline).frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.accent)
        .accessibilityLabel("Lift history")
        .sheet(isPresented: $show) {
            NavigationStack {
                LiftHistoryView(exerciseID: exerciseID)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { show = false } } }
            }
        }
    }
}

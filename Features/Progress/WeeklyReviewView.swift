import SwiftUI
import Hybrid12Engine

/// The Sunday review: the last 7 days on one screen, and what's next.
struct WeeklyReviewView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let look = Theme.look
        let r = store.weeklyReview()
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("\(r.start.formatted(.dateTime.month(.abbreviated).day())) – \(r.end.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(.subheadline).foregroundStyle(look.secondary)
                    Text(r.verdict).font(look.title(30)).fixedSize(horizontal: false, vertical: true)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        tile("\(r.sessions.count) / \(r.sessionsPlanned)", "Sessions",
                             good: r.sessions.count >= r.sessionsPlanned)
                        tile("\(r.cardioMinutes) / \(Program.cardioGoalMinutes)", "Cardio minutes",
                             good: r.cardioMinutes >= Program.cardioGoalMinutes)
                        tile("\(Int(r.hardMinutes.rounded()))", "Zone 4-5 minutes", good: r.hardMinutes >= 30)
                        tile(r.strain.map { String(format: "%.1f", $0) } ?? "--", "WHOOP strain (sessions)", good: nil)
                    }

                    if !r.sessions.isEmpty {
                        Card(title: "Sessions") {
                            ForEach(Array(r.sessions.enumerated()), id: \.offset) { _, s in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(s.title).font(.subheadline.weight(.semibold))
                                        Spacer()
                                        Text(s.date.formatted(.dateTime.weekday(.abbreviated)))
                                            .font(.caption).foregroundStyle(look.secondary)
                                    }
                                    if let h = s.heart {
                                        Text(h.line).font(.caption).foregroundStyle(look.secondary)
                                    }
                                }
                            }
                        }
                    }

                    if !r.records.isEmpty {
                        Card(title: "Personal records") {
                            ForEach(Array(r.records.enumerated()), id: \.offset) { _, p in
                                HStack {
                                    Text(p.name)
                                    Spacer()
                                    Text("\(lb(p.weight)) × \(p.reps)").fontWeight(.bold).monospacedDigit()
                                }
                            }
                        }
                    }

                    Card(title: "Went up") {
                        if r.liftsUp.isEmpty {
                            Text("Nothing went up this week. Hit the top of the range and it will.")
                                .font(.subheadline).foregroundStyle(look.secondary)
                        }
                        ForEach(Array(r.liftsUp.enumerated()), id: \.offset) { _, l in
                            HStack {
                                Image(systemName: "arrow.up.circle.fill").foregroundStyle(look.done)
                                Text(l.name)
                                Spacer()
                                Text("\(lb(l.from)) → \(lb(l.to))").fontWeight(.bold).monospacedDigit()
                            }
                        }
                    }

                    if r.weightChange != nil || r.waistChange != nil {
                        Card(title: "Body") {
                            if let c = r.weightChange, let w = r.latestWeight {
                                HStack {
                                    Text("Weight")
                                    Spacer()
                                    Text("\(lb(w)) lb (\(signed(c)) lb)").monospacedDigit()
                                }
                            }
                            if let c = r.waistChange {
                                HStack {
                                    Text("Waist")
                                    Spacer()
                                    Text("\(signed(c)) in").monospacedDigit()
                                }
                            }
                        }
                    }

                    Card(title: "Next") {
                        Text(r.nextWeek).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding()
            }
            .background(look.background)
            .navigationTitle("Weekly review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func signed(_ x: Double) -> String {
        x == 0 ? "no change" : (x > 0 ? "+" : "−") + lb(abs((x * 10).rounded() / 10))
    }

    private func tile(_ value: String, _ label: String, good: Bool?) -> some View {
        let look = Theme.look
        return VStack(alignment: .leading, spacing: 4) {
            Text(value).font(look.number(30)).monospacedDigit()
                .foregroundStyle(good == true ? look.done : look.text)
            Text(label).font(.caption).foregroundStyle(look.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .lookCard()
    }
}

/// Progress tab: open the review any time.
struct WeeklyReviewButton: View {
    @State private var show = false

    var body: some View {
        Button { show = true } label: {
            Label("This week's review", systemImage: "calendar.badge.checkmark").accentButton(height: 52)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $show) { WeeklyReviewView() }
    }
}

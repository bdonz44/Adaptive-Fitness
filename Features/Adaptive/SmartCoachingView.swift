import SwiftUI
import Hybrid12Engine

/// Plan > Smart coaching: one switch per adaptive feature.
struct SmartCoachingView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        let look = Theme.look
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Extra rules on top of the program. Each one can be turned off, and the program's own rules take over.")
                    .font(.subheadline).foregroundStyle(look.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Card(title: "Effort counts") {
                    Toggle(isOn: $store.adaptive.effortProgression) {
                        Text("Use Easy / Solid / Grinder").font(.headline)
                    }
                    Text("After your last set, tap how it felt. Next time:")
                        .font(.subheadline).foregroundStyle(look.secondary)
                    VStack(alignment: .leading, spacing: 6) {
                        rule("Easy at the top of the range", "double jump")
                        rule("Solid at the top", "normal jump")
                        rule("Grinder at the top", "same weight")
                        rule("Easy but short of the top", "normal jump anyway")
                        rule("Missed reps", "the usual miss rules")
                    }
                    Text("Reps you had left also count toward your estimated max, so new weights start closer to right.")
                        .font(.caption).foregroundStyle(look.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Card(title: "Coming back") {
                    Toggle(isOn: $store.adaptive.reEntry) {
                        Text("Ramp back after missed days").font(.headline)
                    }
                    Text("Weeks only move when you finish sessions, never by the calendar. Time off makes the first sessions back lighter:")
                        .font(.subheadline).foregroundStyle(look.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 6) {
                        rule("7-13 days off", "90%, 1 session")
                        rule("14-27 days off", "85%, 2 sessions, week restarts")
                        rule("28+ days off", "80%, 2 sessions, option to redo the phase")
                    }
                    Text("No weight increases on those sessions.")
                        .font(.caption).foregroundStyle(look.secondary)
                }

                Card(title: "Nutrition") {
                    Toggle(isOn: $store.adaptive.nutrition) {
                        Text("Protein and calorie numbers").font(.headline)
                    }
                    Text("Protein: 1 g per lb of your goal weight, every day. Calories, from your weigh-in trend: flat for 2 weeks above goal, cut 300 a day; losing more than 1% a week, add 200; otherwise hold. Log food and set your goal weight from the protein tile on Home or Progress > Nutrition > Log food. Off hides every nutrition number.")
                        .font(.subheadline).foregroundStyle(look.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Card(title: "Sunday review") {
                    Toggle(isOn: $store.adaptive.weeklyReview) {
                        Text("Weekly review notification").font(.headline)
                    }
                    Text("Sunday at 6:41 pm: sessions done, cardio, zone 4-5 minutes, WHOOP strain, what went up, PRs, weight and waist change, and what's next. Open it any time from the Progress tab.")
                        .font(.subheadline).foregroundStyle(look.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Card(title: "Time today") {
                    Toggle(isOn: $store.adaptive.timeBox) {
                        Text("Fit the workout to my time").font(.headline)
                    }
                    Text("Pick 20, 30, 45 or 60 minutes on Today. The workout is cut in this order until it fits:")
                        .font(.subheadline).foregroundStyle(look.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(["The finisher", "The third superset pair", "One set off each accessory",
                                       "The second superset pair", "Main lift sets, never below 2",
                                       "Engine rounds, never below half"].enumerated()), id: \.offset) { i, step in
                            Text("\(i + 1). \(step)").font(.subheadline)
                        }
                    }
                    Text("Anything you've already logged, and exercises you added, stay put.")
                        .font(.caption).foregroundStyle(look.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding()
        }
        .background(look.background)
        .navigationTitle("Smart coaching")
    }

    private func rule(_ when: String, _ then: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(when).font(.subheadline)
            Spacer(minLength: 8)
            Text(then).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.look.accent)
        }
    }
}

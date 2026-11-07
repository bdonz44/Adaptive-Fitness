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

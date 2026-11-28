import SwiftUI
import Charts
import Hybrid12Engine

/// Progress > Fitness: VO2 max (Apple Health or a 12-minute test) and heart-rate recovery.
struct FitnessCard: View {
    @Environment(AppStore.self) private var store
    @State private var showTest = false
    @State private var connecting = false

    var body: some View {
        let look = Theme.look
        let readings = store.vo2Readings
        let recovery = store.recoveryLogs
        Card(title: "Fitness") {
            // VO2 max
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("VO2 MAX").font(.caption.weight(.heavy)).foregroundStyle(look.secondary)
                    if let v = store.latestVO2 {
                        Text(String(format: "%.1f", v.value)).font(look.number(40))
                        Text("\(v.source) · \(v.date.formatted(.dateTime.month(.abbreviated).day()))")
                            .font(.caption).foregroundStyle(look.secondary)
                    } else {
                        Text("No reading yet").font(.headline)
                    }
                }
                Spacer()
                if let c = Fitness.change(readings.map { (date: $0.date, value: $0.value) }, days: 120, now: Date()) {
                    Text(String(format: "%+.1f", c)).font(.title3.weight(.bold))
                        .foregroundStyle(c >= 0 ? Theme.done : Color(hex: 0xEF4444))
                }
            }
            if readings.count >= 2 {
                Chart(readings) { r in
                    LineMark(x: .value("Date", r.date), y: .value("VO2 max", r.value))
                    PointMark(x: .value("Date", r.date), y: .value("VO2 max", r.value))
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 120)
                .foregroundStyle(look.accent)
            }
            if let age = store.age {
                let n = Fitness.norms(age: age)
                Text("Men your age: average about \(lb(n.average)), good \(lb(n.good)).")
                    .font(.caption).foregroundStyle(look.secondary)
                if let fa = store.fitnessAge {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("FITNESS AGE").font(.caption.weight(.heavy)).foregroundStyle(look.secondary)
                        Text("\(fa)").font(look.number(32)).foregroundStyle(fa <= age ? Theme.done : look.text)
                        Text(fa < age ? "\(age - fa) years younger than you are" : fa == age ? "right on your age" : "\(fa - age) years older: room to gain")
                            .font(.caption).foregroundStyle(look.secondary)
                    }
                    Text("From your VO2 max against age norms, nudged by your strength and heart-rate recovery.")
                        .font(.caption2).foregroundStyle(look.secondary)
                }
            } else {
                Text("Add your birthday (Progress > Strength standards) for your fitness age.")
                    .font(.caption).foregroundStyle(look.secondary)
            }
            HStack {
                Button("Log a 12-minute test") { showTest = true }
                Spacer()
                if !store.healthVO2Connected {
                    Button(connecting ? "Reading…" : "Read from Apple Health") {
                        connecting = true
                        Task {
                            await store.refreshHealthVO2(force: true) {
                                await HealthService.shared.vo2Max(since: Date().addingTimeInterval(-365 * 86400))
                            }
                            connecting = false
                        }
                    }
                    .disabled(connecting)
                }
            }
            .font(.subheadline.weight(.semibold))
            if store.healthVO2Connected && !readings.contains(where: { $0.source != "12-minute test" }) {
                Text("Apple Health has no VO2 max yet. If WHOOP shares it with Health, it shows here; otherwise the 12-minute test works.")
                    .font(.caption).foregroundStyle(look.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            // Heart-rate recovery
            VStack(alignment: .leading, spacing: 2) {
                Text("HEART-RATE RECOVERY").font(.caption.weight(.heavy)).foregroundStyle(look.secondary)
                if let last = store.latestRecovery {
                    HStack(alignment: .firstTextBaseline) {
                        Text("−\(last.bpm) bpm").font(look.number(32))
                        Text("in a minute").font(.subheadline).foregroundStyle(look.secondary)
                    }
                    Text(Fitness.recoveryVerdict(last.bpm)).font(.caption).foregroundStyle(look.secondary)
                } else {
                    Text("Measured after interval sessions with the round timer and your strap connected. Higher is fitter, and it moves within weeks.")
                        .font(.caption).foregroundStyle(look.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if recovery.count >= 2 {
                Chart(Array(recovery.suffix(20).enumerated()), id: \.offset) { _, r in
                    LineMark(x: .value("Date", r.date), y: .value("Drop", r.bpm))
                    PointMark(x: .value("Date", r.date), y: .value("Drop", r.bpm))
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 100)
                .foregroundStyle(Theme.done)
            }
        }
        .sheet(isPresented: $showTest) { CooperTestSheet() }
    }
}

/// The 12-minute test: run as far as you can in 12 minutes, type the distance.
struct CooperTestSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var miles: Double?
    @State private var error: String?

    var body: some View {
        let look = Theme.look
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Warm up 10 minutes. Then run as far as you can in exactly 12 minutes: treadmill at 1% incline, a track or a flat road. Even pace, last 2 minutes all out.")
                    .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Text("Distance").font(.headline)
                    NumberField(placeholder: "1.50", value: miles) { miles = $0 }
                    Text("miles").foregroundStyle(look.secondary)
                }
                if let m = miles, let v = Fitness.cooper(miles: m) {
                    Text("VO2 max about \(String(format: "%.1f", v))").font(.title3.weight(.bold))
                }
                if let error { Text(error).font(.caption).foregroundStyle(.red) }
                Button {
                    if let m = miles, store.logCooper(miles: m) { dismiss() } else {
                        error = "That distance doesn't look right (0.6 to 3.1 miles)."
                    }
                } label: { Text("Save").accentButton(height: 56) }
                    .buttonStyle(.plain)
                Spacer()
            }
            .padding()
            .background(look.background)
            .navigationTitle("12-minute test")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

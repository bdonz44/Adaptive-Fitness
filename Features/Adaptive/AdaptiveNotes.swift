import SwiftUI
import Hybrid12Engine

/// Today: why the session changed (red recovery, sore spots, muscle balancing) and the sore-spot check-in.
struct AdaptiveNotes: View {
    @Environment(AppStore.self) private var store
    @State private var showSore = false

    var body: some View {
        let look = Theme.look
        let day = store.dayNote
        let balance = store.balanceNotes
        let pain = store.painNotes
        let spots = store.soreSpots
        VStack(alignment: .leading, spacing: 10) {
            if day != nil || !balance.isEmpty || !spots.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    if let day {
                        Label(day, systemImage: "heart.text.square.fill")
                            .font(.subheadline.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !spots.isEmpty {
                        Label("Training around: " + spots.map { $0.area.name.lowercased() }.joined(separator: ", "),
                              systemImage: "bandage.fill")
                            .font(.subheadline.weight(.semibold))
                        ForEach(pain, id: \.self) { line in
                            Text("· " + line).font(.footnote).foregroundStyle(look.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    ForEach(balance, id: \.self) { line in
                        Label(line, systemImage: "scalemass.fill")
                            .font(.footnote)
                            .foregroundStyle(look.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(look.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: max(look.radius - 4, 2)))
            }
            if let spot = store.soreToCheck {
                SoreCheckIn(spot: spot)
            }
            Button { showSore = true } label: {
                Label(spots.isEmpty ? "Something hurts?" : "Sore spots", systemImage: "bandage")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .sheet(isPresented: $showSore) { SoreSpotSheet() }
    }
}

/// Every 3 days: how's the sore spot?
struct SoreCheckIn: View {
    @Environment(AppStore.self) private var store
    let spot: SoreSpot
    @State private var worse = false

    var body: some View {
        let look = Theme.look
        VStack(alignment: .leading, spacing: 8) {
            Text("How's your \(spot.area.name.lowercased())?").font(.headline)
            HStack {
                Button("Better") { store.checkSore(spot.area, .better) }
                Button("Same") { store.checkSore(spot.area, .same) }
                Button("Worse") { worse = true; store.checkSore(spot.area, .worse) }
            }
            .buttonStyle(.bordered)
            if worse {
                Text("Still training around it. If it's sharp, swelling, waking you up or keeps getting worse, get it checked by a doctor or physio.")
                    .font(.caption).foregroundStyle(look.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookCard()
    }
}

/// Pick what hurts. Every session then swaps out lifts that load it until you say it's better.
struct SoreSpotSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let look = Theme.look
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Tap what hurts. Until you say it's better, every session swaps lifts that load it for ones that don't (or takes them out), keeps training everything else, and checks in every 3 days. The coach knows too.")
                        .font(.subheadline).foregroundStyle(look.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(BodyArea.allCases, id: \.self) { area in
                            let on = store.soreSpots.contains { $0.area == area }
                            Button { store.toggleSore(area) } label: {
                                HStack {
                                    Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                    Text(area.name).font(.headline)
                                    Spacer()
                                }
                                .padding(14)
                                .foregroundStyle(on ? look.onAccent : look.text)
                                .background(on ? look.accent : look.card, in: RoundedRectangle(cornerRadius: max(look.radius - 6, 4)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text("Sharp pain, swelling, numbness or pain that wakes you up: see a doctor or physio. This is for training around a niggle, not an injury.")
                        .font(.caption).foregroundStyle(look.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
            }
            .background(look.background)
            .navigationTitle("Sore spots")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

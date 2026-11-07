import SwiftUI
import Hybrid12Engine

/// Plan > Equipment: what you own. Weights snap to it, the bell button cycles your bells,
/// and exercises needing gear you don't have are swapped out or hidden.
struct EquipmentView: View {
    @Environment(AppStore.self) private var store

    static let dumbbellChoices: [Double] = Array(stride(from: 5.0, through: 100, by: 5)) + [2.5, 7.5, 12.5].sorted()
    static let bellChoices: [Double] = [10, 15, 18, 20, 25, 26, 30, 35, 40, 44, 45, 50, 53, 55, 60, 62, 70]

    var body: some View {
        @Bindable var store = store
        let look = Theme.look
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Tell the app what you own. Suggested weights snap to it, the bell button cycles your bells, and anything needing gear you don't have gets swapped for something you can do.")
                    .font(.subheadline).foregroundStyle(look.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Card(title: "Barbell") {
                    Toggle("Barbell and plates", isOn: $store.gear.barbell).font(.headline)
                    if store.gear.barbell {
                        Picker("Smallest plate", selection: $store.gear.smallestPlate) {
                            Text("1.25 lb").tag(1.25)
                            Text("2.5 lb").tag(2.5)
                            Text("5 lb").tag(5.0)
                        }
                        Text("Barbell weights move in steps of \(lb(store.gear.smallestPlate * 2)) lb.")
                            .font(.caption).foregroundStyle(look.secondary)
                        HStack {
                            Text("Heaviest you can load")
                            Spacer()
                            Text(store.gear.barbellMax.map { "\(lb($0)) lb" } ?? "No limit").monospacedDigit()
                            Stepper("", onIncrement: {
                                store.gear.barbellMax = store.gear.barbellMax.map { $0 + 10 }
                            }, onDecrement: {
                                store.gear.barbellMax = max(95, (store.gear.barbellMax ?? 405) - 10)
                            })
                            .labelsHidden()
                        }
                        if store.gear.barbellMax != nil {
                            Button("No limit") { store.gear.barbellMax = nil }.font(.caption)
                        }
                    }
                }

                Card(title: "Dumbbells") {
                    Text("Tap the pairs you own.").font(.caption).foregroundStyle(look.secondary)
                    chips(Self.dumbbellChoices.sorted(), selected: store.gear.dumbbells) { w in
                        toggle(w, in: &store.gear.dumbbells)
                    }
                }

                Card(title: "Kettlebells") {
                    Text("Tap the bells you own (lb).").font(.caption).foregroundStyle(look.secondary)
                    chips(Self.bellChoices, selected: store.gear.kettlebells) { w in
                        toggle(w, in: &store.gear.kettlebells)
                    }
                }

                Card(title: "Everything else") {
                    Toggle("Flat or incline bench", isOn: $store.gear.bench)
                    Toggle("TRX straps", isOn: $store.gear.trx)
                    Toggle("Pull-up bar", isOn: $store.gear.pullupBar)
                    Toggle("Heavy bag", isOn: $store.gear.bag)
                    Toggle("Treadmill", isOn: $store.gear.treadmill)
                    if !store.gear.bag || !store.gear.treadmill {
                        Text("Bag and treadmill conditioning stays in the plan: shadowbox instead of the bag, run or hike hills instead of the treadmill.")
                            .font(.caption).foregroundStyle(look.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if store.gear != .standard {
                    Button("Back to the standard home gym") { store.gear = .standard }
                        .font(.footnote).frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .background(look.background)
        .navigationTitle("Equipment")
    }

    private func toggle(_ w: Double, in list: inout [Double]) {
        if let i = list.firstIndex(of: w) { list.remove(at: i) } else { list.append(w); list.sort() }
    }

    private func chips(_ values: [Double], selected: [Double], tap: @escaping (Double) -> Void) -> some View {
        let look = Theme.look
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
            ForEach(values, id: \.self) { w in
                let on = selected.contains(w)
                Button { tap(w) } label: {
                    Text(lb(w))
                        .font(.subheadline.weight(.bold)).monospacedDigit()
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .foregroundStyle(on ? look.onAccent : look.text)
                        .background(on ? look.accent : look.field, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(lb(w)) pounds")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

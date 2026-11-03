import SwiftUI
import Hybrid12Engine

/// The set you're on, big, with one button to log it. Below it the full list stays.
struct NowCard: View {
    @Environment(AppStore.self) private var store
    @Environment(RestTimer.self) private var timer
    let session: Session
    let openFocus: () -> Void

    var body: some View {
        let look = Theme.look
        if let open = store.nextOpenSet, let item = session.item(open.key) {
            let weight = store.weight(for: item, set: open.set, in: session)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionLabel(text: "Now · \(kindName(item))", color: look.accent)
                    Spacer()
                    Text("Set \(open.set + 1) of \(item.sets)").font(.subheadline).foregroundStyle(look.secondary)
                }
                Text(item.name).font(.system(size: 22, weight: .bold, design: look.bodyDesign))
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let weight, item.equipment != .bw {
                        Text(lb(weight)).font(look.number(84)).minimumScaleFactor(0.5).lineLimit(1)
                        Text("lb × \(target(item))").font(.title3.weight(.semibold)).foregroundStyle(look.secondary)
                    } else {
                        Text(target(item)).font(look.number(64))
                        Text(unitWord(item.unit)).font(.title3.weight(.semibold)).foregroundStyle(look.secondary)
                    }
                }
                if item.equipment == .bb, let weight {
                    Text("Per side: \(Plates.text(weight))").font(.subheadline).foregroundStyle(look.secondary)
                }
                SetProgress(done: doneCount(item), total: item.sets)
                HStack(spacing: 10) {
                    Button {
                        SetTick.toggle(item, set: open.set, in: session, store: store, timer: timer)
                    } label: {
                        Text(look.uppercaseTitles ? "DONE · \(item.high) \(unitWord(item.unit).uppercased())"
                                                  : "Done · \(item.high) \(unitWord(item.unit))")
                            .accentButton()
                    }
                    .buttonStyle(.plain)
                    Button(action: openFocus) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.title3.weight(.bold))
                            .frame(width: 56, height: 56)
                            .background(look.field, in: RoundedRectangle(cornerRadius: max(look.radius - 4, 2)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open focus mode")
                }
                Text("Did different reps or weight? Change it in the list below.")
                    .font(.caption)
                    .foregroundStyle(look.secondary)
            }
            .padding(18)
            .lookCard(highlight: look.outlined)
        } else if store.draft.hasWork {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill").font(.title).foregroundStyle(look.done)
                Text("Lifts done. Log the cardio below, then Finish.").font(.headline)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lookCard()
        }
    }

    private func doneCount(_ item: SessionItem) -> Int {
        store.entry(item.key).sets.prefix(item.sets).filter(\.isDone).count
    }

    private func target(_ item: SessionItem) -> String {
        "\(item.high)"
    }

    private func kindName(_ item: SessionItem) -> String {
        switch item.kind {
        case .main: return "Main lift"
        default: return item.tag.isEmpty ? "Accessory" : "Superset \(item.tag)"
        }
    }
}

/// One bar per set: filled when done.
struct SetProgress: View {
    let done: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(total, 1), id: \.self) { i in
                Capsule().fill(i < done ? Theme.accent : Theme.field).frame(height: 8)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(done) of \(total) sets done")
    }
}

/// Bar end with plates drawn to scale-ish, largest nearest the sleeve start.
struct PlateBar: View {
    let total: Double

    var body: some View {
        let plates = Plates.perSide(total)
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2).fill(Theme.secondary.opacity(0.6)).frame(width: 46, height: 10)
            ForEach(Array(plates.enumerated()), id: \.offset) { _, p in
                RoundedRectangle(cornerRadius: 3)
                    .fill(color(p))
                    .frame(width: p >= 25 ? 16 : 11, height: height(p))
            }
            RoundedRectangle(cornerRadius: 2).fill(Theme.secondary.opacity(0.6)).frame(width: 14, height: 10)
            Text(plates.isEmpty ? "Empty bar" : Plates.text(total))
                .font(.subheadline.weight(.semibold))
                .padding(.leading, 10)
        }
        .frame(height: 80)
        .accessibilityElement()
        .accessibilityLabel("Plates per side: \(Plates.text(total))")
    }

    private func height(_ p: Double) -> CGFloat {
        switch p {
        case 45: return 76
        case 35: return 66
        case 25: return 56
        case 10: return 42
        case 5: return 34
        default: return 26
        }
    }

    private func color(_ p: Double) -> Color {
        switch p {
        case 45: return Color(hex: 0x2563EB)
        case 35: return Color(hex: 0xEAB308)
        case 25: return Color(hex: 0x16A34A)
        case 10: return Color(hex: 0xE4E4E7)
        case 5: return Color(hex: 0xDC2626)
        default: return Color(hex: 0x71717A)
        }
    }
}

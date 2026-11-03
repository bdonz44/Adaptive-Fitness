import SwiftUI
import Hybrid12Engine

/// The coach's call after a set, with a button when it suggests a new weight.
struct CoachCueCard: View {
    @Environment(AppStore.self) private var store
    var compact = false

    var body: some View {
        if let (_, cue) = store.coachCue {
            let look = Theme.look
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: icon(cue.tone))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(color(cue.tone))
                VStack(alignment: .leading, spacing: 2) {
                    if !compact { SectionLabel(text: "Coach", color: color(cue.tone)) }
                    Text(cue.text)
                        .font(.system(size: compact ? 15 : 17, weight: .semibold, design: look.bodyDesign))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if let w = cue.newWeight {
                    Button { store.applyCoachWeight() } label: {
                        Text("Use \(lb(w))")
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(look.onAccent)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .background(look.accent, in: RoundedRectangle(cornerRadius: max(look.radius - 8, 2)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(compact ? 12 : 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color(cue.tone).opacity(0.14), in: RoundedRectangle(cornerRadius: look.radius))
            .overlay(RoundedRectangle(cornerRadius: look.radius).stroke(color(cue.tone).opacity(0.6), lineWidth: 1))
        }
    }

    private func icon(_ tone: CoachCues.Cue.Tone) -> String {
        switch tone {
        case .push: return "flame.fill"
        case .steady: return "target"
        case .ease: return "arrow.down.circle.fill"
        case .done: return "checkmark.seal.fill"
        }
    }

    private func color(_ tone: CoachCues.Cue.Tone) -> Color {
        switch tone {
        case .push: return Theme.accent
        case .steady: return Color(hex: 0x60A5FA)
        case .ease: return Color(hex: 0xFBBF24)
        case .done: return Theme.done
        }
    }
}

/// Easy / Solid / Grinder: how the set felt. Feeds the coach (and is saved as RIR).
struct EffortPicker: View {
    @Binding var effort: CoachCues.Effort?

    var body: some View {
        let look = Theme.look
        HStack(spacing: 8) {
            ForEach(CoachCues.Effort.allCases, id: \.self) { e in
                let selected = effort == e
                Button { effort = selected ? nil : e } label: {
                    Text(name(e))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(selected ? look.onAccent : look.text)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(selected ? look.accent : look.card, in: RoundedRectangle(cornerRadius: max(look.radius - 8, 2)))
                        .overlay(RoundedRectangle(cornerRadius: max(look.radius - 8, 2)).stroke(selected ? .clear : look.line))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private func name(_ e: CoachCues.Effort) -> String {
        switch e {
        case .easy: return "Easy"
        case .solid: return "Solid"
        case .grind: return "Grinder"
        }
    }
}

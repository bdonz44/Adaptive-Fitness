import SwiftUI
import Hybrid12Engine

/// The coach's call after a set, with a button when it suggests a new weight.
struct CoachCueCard: View {
    @Environment(AppStore.self) private var store
    var compact = false

    var body: some View {
        if let (_, cue) = store.coachCue {
            let look = Theme.look
            let style = CoachStyle(cue.tone)
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: style.icon)
                    .font(.system(size: compact ? 24 : 30, weight: .heavy))
                VStack(alignment: .leading, spacing: 3) {
                    Text("COACH").font(.system(size: 12, weight: .black)).tracking(1.5).opacity(0.85)
                    Text(cue.text)
                        .font(.system(size: compact ? 18 : 21, weight: .heavy, design: look.bodyDesign))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if let undo = store.adjustUndo, undo.key == store.coachCue?.key {
                    Button { store.undoAdjust() } label: {
                        Text("Undo")
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(style.fill)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 48)
                            .background(style.text, in: RoundedRectangle(cornerRadius: max(look.radius - 8, 4)))
                    }
                    .buttonStyle(.plain)
                } else if let w = cue.newWeight {
                    Button { store.applyCoachWeight() } label: {
                        Text("Use \(lb(w))")
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(style.fill)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 48)
                            .background(style.text, in: RoundedRectangle(cornerRadius: max(look.radius - 8, 4)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .foregroundStyle(style.text)
            .padding(compact ? 14 : 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(style.fill, in: RoundedRectangle(cornerRadius: look.radius))
            .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
            .sensoryFeedback(.impact(weight: .heavy), trigger: cue.text)
            .accessibilityElement(children: .combine)
        }
    }
}

/// Solid, high-contrast colors for each kind of call.
struct CoachStyle {
    let fill: Color
    let text: Color
    let icon: String

    init(_ tone: CoachCues.Cue.Tone) {
        switch tone {
        case .push: fill = Theme.accent; text = Theme.onAccent; icon = "flame.fill"
        case .steady: fill = Color(hex: 0x2563EB); text = .white; icon = "target"
        case .ease: fill = Color(hex: 0xF59E0B); text = .black; icon = "arrow.down.circle.fill"
        case .done: fill = Color(hex: 0x16A34A); text = .white; icon = "checkmark.seal.fill"
        }
    }
}

/// The coach's target or last-set push, as a bold callout (Now card and Focus).
struct CoachCallout: View {
    let text: String

    var body: some View {
        let look = Theme.look
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "flame.fill").font(.system(size: 20, weight: .heavy))
            Text(text)
                .font(.system(size: 17, weight: .heavy, design: look.bodyDesign))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(look.onAccent)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(look.accent, in: RoundedRectangle(cornerRadius: max(look.radius - 6, 4)))
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

import SwiftUI
import Hybrid12Engine

/// Front and back figures with each muscle colored by this week's hard sets.
/// Grey: under 3. Blue: under 10. Green: 10-20 (the growth range). Orange: over 20.
struct BodyMap: View {
    let sets: [Muscle: Double]
    var compact = false
    @State private var selected: Muscle?

    /// One drawn part, in a 100 × 200 box. `muscle` nil = not tracked (head, forearms, shins).
    private struct Part {
        enum Shape { case ellipse, rounded(CGFloat), polygon([CGPoint]) }
        let rect: CGRect
        let shape: Shape
        let muscle: Muscle?
    }

    private static func e(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ m: Muscle?) -> Part {
        Part(rect: CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h), shape: .ellipse, muscle: m)
    }
    private static func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: CGFloat, _ m: Muscle?) -> Part {
        Part(rect: CGRect(x: x, y: y, width: w, height: h), shape: .rounded(c), muscle: m)
    }
    /// Both sides of the body.
    private static func pair(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ m: Muscle?) -> [Part] {
        [e(x, y, w, h, m), e(100 - x, y, w, h, m)]
    }

    private static func poly(_ pts: [(CGFloat, CGFloat)], _ m: Muscle?) -> Part {
        Part(rect: CGRect(x: 0, y: 0, width: 100, height: 200), shape: .polygon(pts.map { CGPoint(x: $0.0, y: $0.1) }), muscle: m)
    }

    private static let shared: [Part] = [
        e(50, 13, 17, 21, nil),                                                        // head
        r(45, 21, 10, 9, 3, nil),                                                      // neck
        poly([(31, 29), (69, 29), (63, 80), (37, 80)], nil),                           // V torso
        poly([(37, 78), (63, 78), (67, 98), (33, 98)], nil),                           // pelvis
    ] + pair(21, 81, 9, 25, nil)                                                       // forearms

    private static let front: [Part] = shared
      + pair(42.5, 166, 11, 40, nil)                                                   // shins
      + pair(29, 36, 18, 16, .shoulders)
      + pair(41, 42, 19, 15, .chest)
      + pair(24, 56, 11, 26, .biceps)
      + [r(41, 50, 18, 31, 6, .core)]
      + pair(42, 121, 17, 48, .quads)

    private static let back: [Part] = shared
      + pair(42.5, 163, 12, 34, nil)                                                   // calves
      + [poly([(34, 30), (66, 30), (64, 48), (58, 75), (42, 75), (36, 48)], .back),
         r(43, 74, 14, 8, 3, .core)]                                                   // lower back
      + pair(29, 36, 18, 16, .shoulders)
      + pair(24, 56, 11, 26, .triceps)
      + pair(43, 91, 16, 16, .glutes)
      + pair(42.5, 124, 15, 42, .hamstrings)

    static func color(_ n: Double, _ look: Look) -> Color {
        if n < 3 { return look.field.opacity(0.9) }
        if n < MuscleMap.low { return Color(hex: 0x60A5FA) }
        if n <= MuscleMap.high { return Color(hex: 0x22C55E) }
        return look.accent
    }

    var body: some View {
        let look = Theme.look
        VStack(spacing: 10) {
            HStack(spacing: compact ? 10 : 18) {
                figure(Self.front, label: "Front")
                figure(Self.back, label: "Back")
            }
            .frame(height: compact ? 170 : 260)
            if !compact {
                if let m = selected {
                    let n = sets[m] ?? 0
                    Text("\(m.name): \(n == n.rounded() ? "\(Int(n))" : String(format: "%.1f", n)) sets this week · "
                         + (n < MuscleMap.low ? "under the 10-set growth range" : n <= MuscleMap.high ? "in the growth range" : "over 20, plenty"))
                        .font(.subheadline.weight(.semibold))
                } else {
                    Text("Tap a muscle to see its sets.").font(.caption).foregroundStyle(look.secondary)
                }
            }
            legend
        }
    }

    private func figure(_ parts: [Part], label: String) -> some View {
        let look = Theme.look
        return VStack(spacing: 4) {
            GeometryReader { g in
                let scale = min(g.size.width / 100, g.size.height / 200)
                let dx = (g.size.width - 100 * scale) / 2
                ZStack(alignment: .topLeading) {
                    ForEach(Array(parts.enumerated()), id: \.offset) { _, p in
                        let fill = p.muscle.map { Self.color(sets[$0] ?? 0, look) } ?? look.field.opacity(0.55)
                        shape(p, scale: scale)
                            .fill(fill)
                            .overlay(shape(p, scale: scale).stroke(p.muscle != nil && p.muscle == selected ? look.text : .clear,
                                                                   lineWidth: 2))
                            .offset(x: dx)
                            .contentShape(shape(p, scale: scale).offset(x: dx))
                            .onTapGesture { if let m = p.muscle { selected = selected == m ? nil : m } }
                    }
                }
            }
            Text(label).font(.caption2.weight(.semibold)).foregroundStyle(look.secondary)
        }
        .accessibilityElement()
        .accessibilityLabel("\(label) body map: " + Muscle.allCases.map { "\($0.name) \(Int((sets[$0] ?? 0).rounded()))" }.joined(separator: ", "))
    }

    private func shape(_ p: Part, scale s: CGFloat) -> Path {
        let rect = CGRect(x: p.rect.minX * s, y: p.rect.minY * s, width: p.rect.width * s, height: p.rect.height * s)
        switch p.shape {
        case .ellipse: return Path(ellipseIn: rect)
        case .rounded(let c): return Path(roundedRect: rect, cornerRadius: c * s)
        case .polygon(let pts):
            var path = Path()
            path.addLines(pts.map { CGPoint(x: $0.x * s, y: $0.y * s) })
            path.closeSubpath()
            return path
        }
    }

    private var legend: some View {
        let look = Theme.look
        return HStack(spacing: 12) {
            swatch(Self.color(0, look), "0-2")
            swatch(Self.color(5, look), "Under 10")
            swatch(Self.color(15, look), "10-20")
            swatch(Self.color(25, look), "20+")
        }
        .font(.caption2)
    }

    private func swatch(_ c: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3).fill(c).frame(width: 12, height: 12)
            Text(label).foregroundStyle(Theme.secondary)
        }
    }
}

import SwiftUI
import UIKit

/// The six looks from the design canvas. Each is a set of colors, fonts and shapes;
/// every screen reads them through `Theme`.
enum Look: String, CaseIterable, Identifiable {
    case iron, chalk, pulse, field, arcade, calm

    var id: String { rawValue }
    static let storageKey = "look"

    static var current: Look {
        Look(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .iron
    }

    var name: String {
        switch self {
        case .iron: return "Iron"
        case .chalk: return "Chalk"
        case .pulse: return "Pulse"
        case .field: return "Field"
        case .arcade: return "Arcade"
        case .calm: return "Calm"
        }
    }

    var blurb: String {
        switch self {
        case .iron: return "Black and orange, big bold numbers"
        case .chalk: return "Light paper, serif, like a training notebook"
        case .pulse: return "Navy and green, readiness first"
        case .field: return "Olive and khaki, tactical"
        case .arcade: return "Neon on black, loud"
        case .calm: return "Clean and simple, Apple-style"
        }
    }

    var scheme: ColorScheme { self == .chalk || self == .calm ? .light : .dark }

    // MARK: Colors

    var background: Color {
        switch self {
        case .iron: return Color(hex: 0x0B0B0C)
        case .chalk: return Color(hex: 0xF6F3EC)
        case .pulse: return Color(hex: 0x0A1220)
        case .field: return Color(hex: 0x1E2219)
        case .arcade: return Color(hex: 0x07070A)
        case .calm: return Color(hex: 0xF2F2F7)
        }
    }

    var card: Color {
        switch self {
        case .iron: return Color(hex: 0x18181B)
        case .chalk: return Color(hex: 0xEFEAE0)
        case .pulse: return Color(hex: 0x111C2E)
        case .field: return Color(hex: 0x2A3022)
        case .arcade: return Color(hex: 0x13131A)
        case .calm: return Color(hex: 0xFFFFFF)
        }
    }

    /// Number fields and secondary buttons.
    var field: Color {
        switch self {
        case .iron: return Color(hex: 0x27272A)
        case .chalk: return Color(hex: 0xE4DED2)
        case .pulse: return Color(hex: 0x1A273C)
        case .field: return Color(hex: 0x3A4132)
        case .arcade: return Color(hex: 0x1E1E28)
        case .calm: return Color(hex: 0xE9E9EE)
        }
    }

    var line: Color {
        switch self {
        case .iron: return Color(hex: 0x27272A)
        case .chalk: return Color(hex: 0xD6D3D1)
        case .pulse: return Color(hex: 0x24324A)
        case .field: return Color(hex: 0x4A5240)
        case .arcade: return Color(hex: 0x26263A)
        case .calm: return Color(hex: 0xE5E5EA)
        }
    }

    var text: Color {
        switch self {
        case .chalk: return Color(hex: 0x1C1B19)
        case .calm: return Color(hex: 0x111114)
        case .field: return Color(hex: 0xE9E5D6)
        case .pulse: return Color(hex: 0xE6EDF7)
        default: return Color(hex: 0xF4F4F5)
        }
    }

    var secondary: Color {
        switch self {
        case .iron: return Color(hex: 0xA1A1AA)
        case .chalk: return Color(hex: 0x57534E)
        case .pulse: return Color(hex: 0x93A4BD)
        case .field: return Color(hex: 0xA8A48F)
        case .arcade: return Color(hex: 0xA1A1B5)
        case .calm: return Color(hex: 0x6B6B73)
        }
    }

    var accent: Color { Color(hex: accentHex) }

    var accentHex: UInt32 {
        switch self {
        case .iron: return 0xFF7A1A
        case .chalk: return 0xC2410C
        case .pulse: return 0x34D399
        case .field: return 0xD4C35A
        case .arcade: return 0xC6FF3D
        case .calm: return 0x0A64D6
        }
    }

    /// Text on an accent-filled button.
    var onAccent: Color {
        switch self {
        case .chalk, .calm: return .white
        default: return background
        }
    }

    var done: Color {
        switch self {
        case .chalk: return Color(hex: 0x15803D)
        case .calm: return Color(hex: 0x248A3D)
        case .field: return Color(hex: 0x9BC27A)
        default: return Color(hex: 0x4ADE80)
        }
    }

    // MARK: Shapes and type

    var radius: CGFloat {
        switch self {
        case .field: return 2
        case .chalk: return 12
        case .arcade: return 22
        default: return 18
        }
    }

    /// Field and Chalk outline their cards instead of filling them.
    var outlined: Bool { self == .field || self == .chalk }
    var uppercaseTitles: Bool { self == .iron || self == .field || self == .arcade }
    var bodyDesign: Font.Design { self == .field ? .monospaced : self == .pulse ? .rounded : .default }
    /// Pulse puts the readiness card first.
    var readinessFirst: Bool { self == .pulse }

    func title(_ size: CGFloat) -> Font {
        switch self {
        case .iron: return .system(size: size, weight: .heavy).width(.compressed)
        case .chalk: return .system(size: size, weight: .bold, design: .serif)
        case .pulse: return .system(size: size, weight: .bold, design: .rounded)
        case .field: return .system(size: size, weight: .bold).width(.condensed)
        case .arcade: return .system(size: size, weight: .black).width(.expanded)
        case .calm: return .system(size: size, weight: .heavy)
        }
    }

    func number(_ size: CGFloat) -> Font {
        switch self {
        case .iron: return .system(size: size, weight: .heavy).width(.compressed)
        case .chalk: return .system(size: size, weight: .semibold, design: .monospaced)
        case .pulse: return .system(size: size, weight: .bold, design: .rounded)
        case .field: return .system(size: size, weight: .bold).width(.condensed)
        case .arcade: return .system(size: size, weight: .black)
        case .calm: return .system(size: size, weight: .bold, design: .rounded)
        }
    }

    /// Small labels above sections ("UP NEXT").
    var label: Font { .system(size: 12, weight: .bold, design: bodyDesign) }

    func uiTitleFont(_ size: CGFloat) -> UIFont {
        let base: UIFont
        switch self {
        case .iron: base = .systemFont(ofSize: size, weight: .heavy, width: .compressed)
        case .field: base = .systemFont(ofSize: size, weight: .bold, width: .condensed)
        case .arcade: base = .systemFont(ofSize: size, weight: .black, width: .expanded)
        default: base = .systemFont(ofSize: size, weight: .heavy)
        }
        let design: UIFontDescriptor.SystemDesign? = self == .chalk ? .serif : self == .pulse ? .rounded : nil
        if let design, let d = base.fontDescriptor.withDesign(design) { return UIFont(descriptor: d, size: size) }
        return base
    }

    /// Alternate app icon asset name; nil = the original icon.
    var iconName: String { "AppIcon-\(name)" }
}

/// What every screen reads. Changing the look rebuilds the screens (see RootTabView).
enum Theme {
    static var look: Look { Look.current }
    static var accent: Color { look.accent }
    static var card: Color { look.card }
    static var field: Color { look.field }
    static var done: Color { look.done }
    static var background: Color { look.background }
    static var text: Color { look.text }
    static var secondary: Color { look.secondary }
    static var line: Color { look.line }
    static var onAccent: Color { look.onAccent }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// Section title in the look's style ("UP NEXT").
struct SectionLabel: View {
    let text: String
    var color: Color = Theme.secondary

    var body: some View {
        Text(text.uppercased())
            .font(Theme.look.label)
            .tracking(1.2)
            .foregroundStyle(color)
    }
}

/// Card background in the look's style.
struct CardBackground: ViewModifier {
    var highlight: Bool = false

    func body(content: Content) -> some View {
        let look = Theme.look
        let shape = RoundedRectangle(cornerRadius: look.radius, style: .continuous)
        content
            .background(look.outlined && !highlight ? Color.clear : look.card, in: shape)
            .overlay(shape.stroke(highlight ? look.accent : (look.outlined ? look.line : .clear),
                                  lineWidth: highlight ? 2 : 1))
    }
}

extension View {
    func lookCard(highlight: Bool = false) -> some View { modifier(CardBackground(highlight: highlight)) }

    /// Big filled button in the accent color.
    func accentButton(height: CGFloat = 56) -> some View {
        self.font(.system(size: 18, weight: .heavy, design: Theme.look.bodyDesign))
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: max(Theme.look.radius - 4, 2), style: .continuous))
    }
}

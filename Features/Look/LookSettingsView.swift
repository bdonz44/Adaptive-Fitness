import SwiftUI
import UIKit

/// Pick a look, a Lock Screen style and an app icon.
struct LookSettingsView: View {
    @AppStorage(Look.storageKey) private var lookName = Look.iron.rawValue
    @AppStorage(LockStyle.storageKey) private var lockName = LockStyle.big.rawValue
    @State private var iconName: String? = UIApplication.shared.alternateIconName
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let look = Look(rawValue: lookName) ?? .iron
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SectionLabel(text: "Look", color: look.accent)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(Look.allCases) { option in
                            Button { choose(option) } label: { LookTile(option: option, selected: option == look) }
                                .buttonStyle(.plain)
                        }
                    }

                    SectionLabel(text: "Lock Screen timer", color: look.accent)
                    VStack(spacing: 10) {
                        ForEach(LockStyle.allCases) { style in
                            Button {
                                lockName = style.rawValue
                                RestTimer.shared.refreshLockScreen()
                            } label: {
                                optionRow(style.name, detail: style.blurb, selected: style.rawValue == lockName, look: look)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    SectionLabel(text: "App icon", color: look.accent)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 14) {
                        iconButton(nil, label: "Original", look: look)
                        ForEach(Look.allCases) { option in
                            iconButton(option.iconName, label: option.name, look: look)
                        }
                    }
                    Text("iPhone shows a short message when the icon changes.")
                        .font(.caption)
                        .foregroundStyle(look.secondary)
                }
                .padding()
            }
            .background(look.background)
            .navigationTitle("Look")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .preferredColorScheme(look.scheme)
        .tint(look.accent)
    }

    private func choose(_ option: Look) {
        RootTabView.styleBars(option)
        lookName = option.rawValue
        RestTimer.shared.refreshLockScreen()
    }

    private func optionRow(_ title: String, detail: String, selected: Bool, look: Look) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(look.text)
                Text(detail).font(.subheadline).foregroundStyle(look.secondary)
            }
            Spacer()
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(selected ? look.accent : look.secondary)
        }
        .padding(14)
        .background(look.card, in: RoundedRectangle(cornerRadius: look.radius))
        .overlay(RoundedRectangle(cornerRadius: look.radius).stroke(selected ? look.accent : look.line, lineWidth: selected ? 2 : 1))
    }

    private func iconButton(_ name: String?, label: String, look: Look) -> some View {
        let selected = iconName == name
        return Button {
            guard UIApplication.shared.supportsAlternateIcons, !selected else { return }
            UIApplication.shared.setAlternateIconName(name) { error in
                if error == nil { iconName = name }
            }
        } label: {
            VStack(spacing: 6) {
                Image(name.map { "Preview-\($0)" } ?? "Preview-Original")
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(selected ? look.accent : .clear, lineWidth: 3))
                Text(label).font(.caption).foregroundStyle(selected ? look.accent : look.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) icon\(selected ? ", selected" : "")")
    }
}

/// A small preview of a look: its background, card, accent and title font.
struct LookTile: View {
    let option: Look
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(option.uppercaseTitles ? option.name.uppercased() : option.name)
                .font(option.title(26))
                .foregroundStyle(option.text)
            HStack(spacing: 5) {
                Capsule().fill(option.accent).frame(height: 6)
                Capsule().fill(option.accent).frame(height: 6)
                Capsule().fill(option.field).frame(height: 6)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("235").font(option.number(30)).foregroundStyle(option.text)
                Text("lb").font(.caption).foregroundStyle(option.secondary)
            }
            Text("Done")
                .font(.caption.weight(.heavy))
                .foregroundStyle(option.onAccent)
                .frame(maxWidth: .infinity, minHeight: 26)
                .background(option.accent, in: RoundedRectangle(cornerRadius: max(option.radius - 10, 2)))
            Text(option.blurb).font(.caption2).foregroundStyle(option.secondary).lineLimit(2, reservesSpace: true)
        }
        .padding(12)
        .background(option.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? option.accent : Color.gray.opacity(0.35), lineWidth: selected ? 3 : 1))
        .accessibilityElement()
        .accessibilityLabel("\(option.name): \(option.blurb)\(selected ? ", selected" : "")")
    }
}

/// Programs. Hybrid 12 is the only one built so far; the rest are planned.
struct ProgramsView: View {
    private struct Template: Identifiable {
        let id: String
        let name: String
        let detail: String
        let length: String
    }

    private let templates = [
        Template(id: "strong3", name: "Strong 3", detail: "3 days · 45 min · squat, bench, deadlift focus", length: "8 wk"),
        Template(id: "engine", name: "Engine Builder", detail: "4 days · runs plus 2 short lifts · first 10K", length: "10 wk"),
        Template(id: "keep", name: "Keep It", detail: "3 days · hold your strength after a cut", length: "ongoing"),
        Template(id: "joint", name: "Joint Friendly", detail: "4 days · trap bar, landmine, sleds · easy on the low back", length: "12 wk"),
        Template(id: "trip", name: "Road Trip", detail: "Any days · dumbbells or bodyweight only", length: "1-2 wk"),
    ]

    var body: some View {
        let look = Theme.look
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your lifts and history carry over to any program.")
                    .font(.subheadline).foregroundStyle(look.secondary)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Hybrid 12").font(.title3.weight(.heavy))
                        Spacer()
                        Text("CURRENT").font(.caption.weight(.heavy))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .foregroundStyle(look.onAccent)
                            .background(look.accent, in: Capsule())
                    }
                    Text("5 days · strength plus conditioning · lose fat, keep muscle")
                        .font(.subheadline).foregroundStyle(look.secondary)
                }
                .padding(16)
                .lookCard(highlight: true)

                SectionLabel(text: "Coming soon").padding(.top, 8)
                ForEach(templates) { t in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(t.name).font(.headline)
                            Text(t.detail).font(.subheadline).foregroundStyle(look.secondary)
                        }
                        Spacer()
                        Text(t.length).font(.caption).foregroundStyle(look.secondary)
                    }
                    .padding(14)
                    .lookCard()
                    .opacity(0.75)
                }
                Text("These programs still need their weeks and rules written. Tell Claude which one you want first.")
                    .font(.caption).foregroundStyle(look.secondary).padding(.top, 4)
            }
            .padding()
        }
        .background(look.background)
        .navigationTitle("Programs")
    }
}

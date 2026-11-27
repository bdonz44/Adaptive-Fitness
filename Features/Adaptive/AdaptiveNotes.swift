import SwiftUI
import Hybrid12Engine

/// Today: why the session changed (red recovery moved a hard day, muscle balancing added sets).
struct AdaptiveNotes: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let look = Theme.look
        let day = store.dayNote
        let balance = store.balanceNotes
        if day != nil || !balance.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                if let day {
                    Label(day, systemImage: "heart.text.square.fill")
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
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
    }
}

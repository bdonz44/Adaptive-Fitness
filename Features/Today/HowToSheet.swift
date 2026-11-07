import SwiftUI
import Hybrid12Engine

/// How to do an exercise: setup, the movement, what to avoid, and a form video search.
struct HowToSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let exerciseID: String

    var body: some View {
        let look = Theme.look
        let ex = store.catalog.exercise(exerciseID)
        let how = store.catalog.howTo(exerciseID)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let ex {
                        Text(look.uppercaseTitles ? ex.name.uppercased() : ex.name)
                            .font(look.title(34)).minimumScaleFactor(0.6)
                        Text(ex.category == Catalog.trxCategory ? "TRX straps" : AddExerciseSheet.equipment(ex.eq)
                             + (ex.side ? " · each side" : ""))
                            .font(.subheadline).foregroundStyle(look.secondary)
                        CoachCallout(text: ex.cue)
                    }
                    if let how {
                        step("1", "Set up", how.setup)
                        step("2", "The movement", how.movement)
                        step("!", "Avoid", how.mistake, warn: true)
                    }
                    if let ex, let url = Catalog.formVideoURL(for: ex.name) {
                        Button { openURL(url) } label: {
                            Label("Watch form videos", systemImage: "play.rectangle.fill").accentButton()
                        }
                        .buttonStyle(.plain)
                        Text("Opens YouTube with the best form videos for \(ex.name).")
                            .font(.caption).foregroundStyle(look.secondary)
                    }
                }
                .padding()
            }
            .background(look.background)
            .navigationTitle("How to")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func step(_ mark: String, _ title: String, _ text: String, warn: Bool = false) -> some View {
        let look = Theme.look
        return HStack(alignment: .top, spacing: 12) {
            Text(mark)
                .font(.headline.weight(.heavy))
                .frame(width: 30, height: 30)
                .foregroundStyle(warn ? .white : look.onAccent)
                .background(warn ? Color(hex: 0xDC2626) : look.accent, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(text).font(.body).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .lookCard()
    }
}

/// A small "how to" button for an exercise.
struct HowToButton: View {
    let exerciseID: String
    @State private var show = false

    var body: some View {
        Button { show = true } label: {
            Image(systemName: "questionmark.circle").font(.title3)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.accent)
        .accessibilityLabel("How to do this exercise")
        .sheet(isPresented: $show) { HowToSheet(exerciseID: exerciseID) }
    }
}

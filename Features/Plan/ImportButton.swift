import SwiftUI
import UniformTypeIdentifiers
import Hybrid12Engine

/// Picks the web app's `hybrid12-data.json` from Files, shows what's in it, and imports after a confirm.
struct ImportButton: View {
    @Environment(AppStore.self) private var store
    @Environment(RestTimer.self) private var timer
    var prominent = false

    @State private var picking = false
    @State private var pending: Importer.Result?
    @State private var message: String?

    var body: some View {
        Group {
            if prominent {
                Button { picking = true } label: {
                    Label("Import from web app", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button { picking = true } label: {
                    Label("Import from web app", systemImage: "square.and.arrow.down")
                }
            }
        }
        .fileImporter(isPresented: $picking, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): read(url)
            case .failure(let error): message = error.localizedDescription
            }
        }
        .alert("Import from the web app?", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })) {
            Button("Cancel", role: .cancel) { pending = nil }
            Button(store.isEmpty ? "Import" : "Replace and import", role: store.isEmpty ? nil : .destructive) {
                if let r = pending {
                    timer.done()
                    store.importWebData(r)
                    message = "Imported \(r.summary). You're on week \(ProgramWeek(r.program.week).wk)."
                }
                pending = nil
            }
        } message: {
            if let r = pending {
                Text("This file has \(r.summary), and puts you on week \(ProgramWeek(r.program.week).wk) with \(r.program.doneCount) of 5 sessions done."
                     + (store.isEmpty ? "" : " It replaces everything in the app now."))
            }
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        }
    }

    private func read(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            pending = try Importer.parse(Data(contentsOf: url), catalog: store.catalog)
        } catch {
            message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

/// Shown on Today while the app is empty.
struct ImportPromptCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Moving from the web app?").font(.headline)
            Text("Export your data from the web app and save hybrid12-data.json to Files. Then import it here to bring over your week, weights and history.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ImportButton(prominent: true)
        }
        .padding()
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }
}

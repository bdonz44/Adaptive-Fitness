import SwiftUI
import Hybrid12Engine

/// Ask the coach (Apple Intelligence). Opened from Home and Today.
struct CoachChatView: View {
    @Environment(AppStore.self) private var store
    @Environment(WhoopService.self) private var whoop
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if #available(iOS 26.0, *) {
                    CoachChat(store: store, whoop: whoop)
                } else {
                    Text("Ask the coach needs iOS 26 or later with Apple Intelligence.").padding()
                }
            }
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

@available(iOS 26.0, *)
private struct CoachChat: View {
    @State private var coach: AICoach
    @State private var text = ""
    @State private var showNotes = false
    @FocusState private var typing: Bool

    init(store: AppStore, whoop: WhoopService) {
        _coach = State(initialValue: AICoach(store: store, whoop: whoop))
    }

    static let starters = [
        "My shoulder is cranky. What do I swap today?",
        "I only have 30 minutes.",
        "Why is my bench stuck?",
        "What should I eat today?",
        "Add something for my arms.",
    ]

    var body: some View {
        let look = Theme.look
        VStack(spacing: 0) {
            if let reason = coach.unavailableReason {
                VStack(spacing: 12) {
                    Image(systemName: "apple.intelligence").font(.system(size: 44)).foregroundStyle(look.accent)
                    Text(reason).multilineTextAlignment(.center)
                }
                .padding(30)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            if coach.messages.isEmpty { intro }
                            ForEach(coach.messages) { m in bubble(m).id(m.id) }
                            if coach.isResponding && (coach.messages.last?.text.isEmpty ?? true) {
                                ProgressView().padding(.leading, 6)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: coach.messages.last?.text) { _, _ in
                        if let id = coach.messages.last?.id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } }
                    }
                }
                inputBar
            }
        }
        .background(look.background)
        .sheet(isPresented: $showNotes) { CoachNotesView() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showNotes = true } label: { Label("What the coach remembers", systemImage: "note.text") }
            }
            if !coach.messages.isEmpty {
                ToolbarItem(placement: .cancellationAction) { Button("New chat") { coach.reset() }.disabled(coach.isResponding) }
            }
        }
    }

    private var intro: some View {
        let look = Theme.look
        return VStack(alignment: .leading, spacing: 10) {
            Text("Ask your coach").font(look.title(30))
            Text("It knows your program, today's session, your lifts, WHOOP, food and gear, and it can change today's workout: swap, add, skip, or fit it to your time.")
                .font(.subheadline).foregroundStyle(look.secondary).fixedSize(horizontal: false, vertical: true)
            Text(coach.usesCloud ? "Apple Intelligence · Private Cloud Compute · free" : "Apple Intelligence · on your iPhone · free and private")
                .font(.caption).foregroundStyle(look.secondary)
            ForEach(Self.starters, id: \.self) { s in
                Button { Task { await coach.send(s) } } label: {
                    Text(s).font(.subheadline).multilineTextAlignment(.leading)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(look.card, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(look.line))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func bubble(_ m: AICoach.Message) -> some View {
        let look = Theme.look
        let mine = m.role == .you
        return HStack {
            if mine { Spacer(minLength: 40) }
            Text(m.text.isEmpty ? " " : m.text)
                .font(.body)
                .foregroundStyle(mine ? look.onAccent : look.text)
                .padding(12)
                .background(mine ? look.accent : look.card, in: RoundedRectangle(cornerRadius: 16))
                .textSelection(.enabled)
            if !mine { Spacer(minLength: 40) }
        }
    }

    private var inputBar: some View {
        let look = Theme.look
        return HStack(spacing: 8) {
            TextField("Ask the coach…", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .focused($typing)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(look.field, in: RoundedRectangle(cornerRadius: 18))
            Button {
                let t = text
                text = ""
                Task { await coach.send(t) }
            } label: {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 34)).foregroundStyle(look.accent)
            }
            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || coach.isResponding)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal).padding(.vertical, 8)
        .background(look.background)
    }
}

/// What the coach remembers between chats. Swipe to delete.
struct CoachNotesView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if store.coachNotes.isEmpty {
                    Text("Nothing yet. Tell the coach about a sore spot, what you like or your schedule, and it remembers.")
                        .font(.subheadline).foregroundStyle(Theme.secondary)
                }
                ForEach(store.coachNotes.reversed()) { note in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(note.text)
                        Text(note.date.formatted(.dateTime.month(.abbreviated).day())).font(.caption).foregroundStyle(Theme.secondary)
                    }
                    .swipeActions { Button("Forget", role: .destructive) { store.forget(note) } }
                }
            }
            .navigationTitle("Coach remembers")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

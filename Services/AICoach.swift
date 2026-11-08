import Foundation
import FoundationModels
import Observation
import Hybrid12Engine

/// "Ask the coach": Apple Intelligence, free. Uses Apple's Private Cloud Compute model when it's
/// available (bigger, still private), otherwise the model on the phone. It can change today's session.
@available(iOS 26.0, *)
@MainActor
@Observable
final class AICoach {
    struct Message: Identifiable, Equatable {
        enum Role { case you, coach, action }
        let id = UUID()
        let role: Role
        var text: String
    }

    private(set) var messages: [Message] = []
    private(set) var isResponding = false
    @ObservationIgnored private var session: LanguageModelSession?
    /// Set when the cloud model failed once: stay on the phone's model.
    @ObservationIgnored private var onDeviceOnly = false
    @ObservationIgnored private let store: AppStore
    @ObservationIgnored private let whoop: WhoopService

    init(store: AppStore, whoop: WhoopService) {
        self.store = store
        self.whoop = whoop
    }

    /// Nil when the coach can be used; otherwise what to tell the user.
    var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available: return nil
        case .unavailable(.deviceNotEligible): return "This iPhone doesn't support Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled): return "Turn on Apple Intelligence in Settings > Apple Intelligence & Siri, then come back."
        case .unavailable(.modelNotReady): return "Apple Intelligence is still downloading its model. Keep the phone on Wi-Fi and charging, then try again."
        case .unavailable: return "Apple Intelligence isn't available right now."
        }
    }

    var usesCloud: Bool {
        if onDeviceOnly { return false }
        if #available(iOS 27.0, *) { return PrivateCloudComputeLanguageModel().isAvailable }
        return false
    }

    func reset() {
        session = nil
        messages = []
    }

    func send(_ text: String) async {
        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isResponding else { return }
        messages.append(Message(role: .you, text: prompt))
        isResponding = true
        defer { isResponding = false }
        do {
            try await answer(prompt)
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            // Long chat: start fresh with today's context and ask again.
            session = nil
            do { try await answer(prompt) } catch { fail(error) }
        } catch {
            if usesCloud, !onDeviceOnly {
                // The cloud model refused or failed: fall back to the model on the phone.
                onDeviceOnly = true
                session = nil
                if let last = messages.last, last.role == .coach { messages.removeLast() }
                do { try await answer(prompt) } catch { fail(error) }
            } else {
                fail(error)
            }
        }
    }

    private func answer(_ prompt: String) async throws {
        let s = session ?? makeSession()
        session = s
        messages.append(Message(role: .coach, text: ""))
        let index = messages.count - 1
        for try await snap in s.streamResponse(to: prompt) {
            messages[index].text = snap.content
        }
        store.saveCoachChanges()
    }

    private func fail(_ error: Error) {
        if let last = messages.last, last.role == .coach, last.text.isEmpty { messages.removeLast() }
        let text: String
        if case LanguageModelSession.GenerationError.guardrailViolation = error {
            text = "I can't help with that one. Ask me about training, recovery or food."
        } else {
            text = "Coach hit a snag: \(error.localizedDescription)"
        }
        messages.append(Message(role: .coach, text: text))
    }

    private func makeSession() -> LanguageModelSession {
        let instructions = """
        You are Brandon's strength coach inside his Hybrid 12 app. Be direct, demanding and encouraging, \
        like a coach who wants him to grind. Keep answers short: 2-5 sentences or a few bullets. Use the facts \
        below; never invent weights or history. Give specific numbers (sets, reps, weights, minutes, grams). \
        When he asks to change today's workout, use the tools: swapExercise, addExercise, skipExercise, setTimeToday, \
        then say what changed. Only swap to exercises his gear allows. For pain: no heroics, swap to something \
        pain-free, and tell him to see a doctor if it's sharp, keeps coming back, or he hurt something. You are not a doctor.

        FACTS
        \(store.coachContext(whoop: whoop.today))
        """
        let tools: [any Tool] = [SwapTool(coach: CoachLink(store)), AddTool(coach: CoachLink(store)),
                                 SkipTool(coach: CoachLink(store)), TimeTool(coach: CoachLink(store))]
        if #available(iOS 27.0, *), !onDeviceOnly {
            let cloud = PrivateCloudComputeLanguageModel()
            if cloud.isAvailable {
                return LanguageModelSession(model: cloud, tools: tools, instructions: instructions)
            }
        }
        return LanguageModelSession(tools: tools, instructions: instructions)
    }
}

/// Lets the tools reach the store on the main actor.
struct CoachLink: @unchecked Sendable {
    let store: AppStore
    init(_ store: AppStore) { self.store = store }
    func run(_ work: @escaping @MainActor (AppStore) -> String) async -> String {
        await MainActor.run { work(store) }
    }
}

@available(iOS 26.0, *)
struct SwapTool: Tool {
    let name = "swapExercise"
    let description = "Replace an exercise in today's session with another exercise."
    let coach: CoachLink
    @Generable struct Arguments {
        @Guide(description: "The exercise in today's session to replace, e.g. Bench Press")
        var exercise: String
        @Guide(description: "The exercise to do instead, e.g. Floor Press")
        var replacement: String
    }
    func call(arguments: Arguments) async throws -> String {
        await coach.run { $0.coachSwap(arguments.exercise, to: arguments.replacement) }
    }
}

@available(iOS 26.0, *)
struct AddTool: Tool {
    let name = "addExercise"
    let description = "Add an exercise to the end of today's session."
    let coach: CoachLink
    @Generable struct Arguments {
        @Guide(description: "The exercise to add, e.g. TRX Chest Fly")
        var exercise: String
    }
    func call(arguments: Arguments) async throws -> String {
        await coach.run { $0.coachAdd(arguments.exercise) }
    }
}

@available(iOS 26.0, *)
struct SkipTool: Tool {
    let name = "skipExercise"
    let description = "Skip an exercise in today's session."
    let coach: CoachLink
    @Generable struct Arguments {
        @Guide(description: "The exercise in today's session to skip")
        var exercise: String
        @Guide(description: "Why: Pain, No time, No equipment, or Other")
        var reason: String
    }
    func call(arguments: Arguments) async throws -> String {
        await coach.run { $0.coachSkip(arguments.exercise, reason: arguments.reason) }
    }
}

@available(iOS 26.0, *)
struct TimeTool: Tool {
    let name = "setTimeToday"
    let description = "Fit today's session into the minutes available (20, 30, 45 or 60; 75 or more means the full session)."
    let coach: CoachLink
    @Generable struct Arguments {
        @Guide(description: "Minutes available today")
        var minutes: Int
    }
    func call(arguments: Arguments) async throws -> String {
        await coach.run { $0.coachTime(arguments.minutes) }
    }
}

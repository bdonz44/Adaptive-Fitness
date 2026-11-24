import AVFoundation
import Foundation
import Observation
import UIKit
import UserNotifications
import Hybrid12Engine

/// Runs a round timer (heavy bag, intervals, EMOM). Sounds mix with your music and play
/// with the silent switch on; backup notifications fire if the app is closed.
@Observable
final class RoundTimer {
    private(set) var settings = RoundPlan.Settings(rounds: 1, work: 60, rest: 0)
    private(set) var phases: [RoundPlan.Phase] = []
    private(set) var itemKey: String?
    private(set) var name = ""
    private(set) var isRunning = false
    private(set) var isPaused = false
    /// Seconds run before the current stretch (pauses and skips add here).
    private var banked: TimeInterval = 0
    private var resumedAt = Date()

    @ObservationIgnored private var players: [String: AVAudioPlayer] = [:]
    private static let notePrefix = "round-timer-"

    func elapsed(at date: Date) -> TimeInterval {
        isPaused || !isRunning ? banked : banked + date.timeIntervalSince(resumedAt)
    }

    func position(at date: Date) -> RoundPlan.Position {
        RoundPlan.position(phases, elapsed: elapsed(at: date))
    }

    // MARK: Saved settings (per workout name)

    /// Keyed by the workout's planned work/rest too, so a change to the plan
    /// (for example adding the rest it was missing) isn't hidden by an old save.
    private static func key(for item: SessionItem) -> String {
        let d = RoundPlan.defaults(for: item)
        return "roundTimer.\(item.name).\(d.work)-\(d.rest)"
    }

    static func saved(for item: SessionItem) -> RoundPlan.Settings {
        let defaults = RoundPlan.defaults(for: item)
        guard let data = UserDefaults.standard.data(forKey: key(for: item)),
              let saved = try? JSONDecoder().decode(RoundPlan.Settings.self, from: data) else { return defaults }
        // Work and rest are remembered; rounds follow the plan for the week.
        return RoundPlan.Settings(rounds: defaults.rounds, work: saved.work, rest: saved.rest)
    }

    static func save(_ s: RoundPlan.Settings, for item: SessionItem) {
        if let data = try? JSONEncoder().encode(s) { UserDefaults.standard.set(data, forKey: key(for: item)) }
    }

    // MARK: Control

    func start(_ s: RoundPlan.Settings, item: SessionItem) {
        settings = s
        phases = RoundPlan.phases(s)
        itemKey = item.key
        name = item.name
        banked = 0
        resumedAt = Date()
        isRunning = true
        isPaused = false
        UIApplication.shared.isIdleTimerDisabled = true
        prepareAudio()
        play("clack")
        scheduleBackups()
    }

    func pause() {
        guard isRunning, !isPaused else { return }
        banked = elapsed(at: Date())
        isPaused = true
        cancelBackups()
    }

    func resume() {
        guard isRunning, isPaused else { return }
        resumedAt = Date()
        isPaused = false
        scheduleBackups()
    }

    /// Jumps to the start of the next phase (skip the rest, or end a round early).
    func skip() {
        let now = Date()
        let starts = RoundPlan.phaseStarts(phases)
        guard let i = position(at: now).phase, i + 1 < starts.count else { return }
        banked = TimeInterval(starts[i + 1])
        resumedAt = now
        // While paused nothing is scheduled; resume() schedules from the new position.
        if !isPaused { scheduleBackups() }
    }

    func stop() {
        isRunning = false
        isPaused = false
        itemKey = nil
        UIApplication.shared.isIdleTimerDisabled = false
        cancelBackups()
    }

    // MARK: Sound

    private func prepareAudio() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        for name in ["bell-start", "bell-end", "clack"] where players[name] == nil {
            if let url = Bundle.main.url(forResource: name, withExtension: "wav") {
                players[name] = try? AVAudioPlayer(contentsOf: url)
                players[name]?.prepareToPlay()
            }
        }
    }

    func play(_ name: String) {
        try? AVAudioSession.sharedInstance().setActive(true)
        players[name]?.currentTime = 0
        players[name]?.play()
    }

    // MARK: Backup notifications (app closed or phone locked)

    private func scheduleBackups() {
        cancelBackups()
        let center = UNUserNotificationCenter.current()
        let starts = RoundPlan.phaseStarts(phases)
        let now = elapsed(at: Date())
        var requests: [UNNotificationRequest] = []
        for (i, phase) in phases.enumerated() where i > 0 {
            let at = TimeInterval(starts[i]) - now
            guard at > 1 else { continue }
            requests.append(note(i, at: at, title: phase.kind == .work ? "Round \(phase.round)" : "Rest",
                                 body: phase.kind == .work ? "Work! \(name)" : "Breathe. Next round soon.",
                                 sound: phase.kind == .work ? "bell-start.wav" : "bell-end.wav"))
        }
        let end = TimeInterval(settings.totalSeconds) - now
        // The "Done" note goes first so a long plan never pushes it past iOS's 64-alert limit
        // (shared with the rest timer, nudges and the weekly review).
        if end > 1 { requests.insert(note(999, at: end, title: "Done", body: "\(name) finished. Log it.", sound: "bell-end.wav"), at: 0) }
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            for r in requests.prefix(55) { center.add(r) }
        }
    }

    private func note(_ i: Int, at: TimeInterval, title: String, body: String, sound: String) -> UNNotificationRequest {
        let c = UNMutableNotificationContent()
        c.title = title
        c.body = body
        c.sound = UNNotificationSound(named: UNNotificationSoundName(sound))
        return UNNotificationRequest(identifier: Self.notePrefix + "\(i)", content: c,
                                     trigger: UNTimeIntervalNotificationTrigger(timeInterval: at, repeats: false))
    }

    private func cancelBackups() { Self.cancelLeftovers() }

    /// The timer lives only in memory: after the app was closed or crashed, its bells must stop too.
    static func cancelLeftovers() {
        let ids = (0...1000).map { notePrefix + "\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
}

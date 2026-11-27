import Foundation
import Hybrid12Engine

/// What the AI coach knows, and what it may change. Kept short: the on-device model's
/// whole conversation has to fit in about 4,000 tokens.
extension AppStore {
    func coachContext(whoop: WhoopToday?, now: Date = Date()) -> String {
        let s = session
        var lines: [String] = []
        lines.append("Today: \(now.formatted(date: .complete, time: .shortened)).")
        lines.append("Athlete: Brandon\(age.map { ", \($0)" } ?? ""), home gym. Goal: stronger, leaner, higher VO2 max.")
        lines.append("Program: \(program.program.name), \(program.days) days a week, week \(week.wk) of 12, \(program.program.phaseName(week.phase))\(week.isDeload ? " (back-off week)" : ""). \(program.doneCount) of \(program.order.count) sessions done this week.")
        var today = "Today's session (\(s.title)\(draft.startedAt != nil ? ", in progress" : "")):"
        for item in s.items {
            if item.isLift {
                let w = suggestion(for: item, in: s).weight.map { " at \(lb($0)) lb" } ?? ""
                let done = entry(item.key).sets.filter(\.isDone).count
                today += " \(item.name) \(item.sets)×\(item.low == item.high ? "\(item.high)" : "\(item.low)-\(item.high)")\(w)\(done > 0 ? " (\(done) done)" : "");"
            } else if item.isCardio {
                today += " \(item.name) \(item.rounds ?? 0) \(item.unit == .min ? "min" : "rounds");"
            }
        }
        lines.append(today)
        if let t = whoop, let r = t.recovery {
            lines.append("WHOOP today: recovery \(r)%\(t.sleepHours.map { String(format: ", slept %.1f h", $0) } ?? "")\(t.hrv.map { ", HRV \(Int($0)) ms" } ?? "")\(t.strain.map { String(format: ", strain %.1f", $0) } ?? "").")
        }
        let mains = catalog.mainLifts.compactMap { ex -> String? in
            guard let rec = lifts[ex.id], let w = rec.workingWeight else { return nil }
            let best = Suggestions.best1RM(rec).map { ", est. max \(lb(Suggestions.round5($0)))" } ?? ""
            return "\(ex.name) \(lb(w))\(best)\((rec.breaker ?? 0) > 0 ? " (plateau breaker)" : "")"
        }
        if !mains.isEmpty { lines.append("Working weights: " + mains.joined(separator: "; ") + ".") }
        let recent = recentLogs.prefix(5).map { "\($0.title) \($0.date.formatted(.dateTime.weekday(.abbreviated)))" }
        if !recent.isEmpty { lines.append("Recent sessions: " + recent.joined(separator: ", ") + ".") }
        lines.append("Cardio this week: \(cardioThisWeek) of \(Program.cardioGoalMinutes) min. Zone 4-5 this week: \(Int(hardMinutesThisWeek.rounded())) min.")
        if let n = nutritionAdvice {
            lines.append("Nutrition: protein \(proteinToday) of \(n.proteinGrams ?? 0) g today. \(n.headline)")
        }
        if let w = weighIns.last { lines.append("Bodyweight \(lb(w.pounds)) lb\(nutritionSettings.goalWeight.map { ", goal \(lb($0))" } ?? "").") }
        let short = MuscleMap.short(muscleSets()).prefix(3).map(\.name)
        if !short.isEmpty { lines.append("Under 10 sets this week: " + short.joined(separator: ", ") + ".") }
        if let i = insights.first { lines.append("Pattern: \(i.headline).") }
        lines.append("Gear: " + gearSummary + ".")
        if let memory = coachMemoryLine { lines.append(memory) }
        if let g = goal { lines.append("Goal: \(g.title(liftName: g.liftID.flatMap { catalog.exercise($0)?.name }))." + (goalStatus.map { " " + $0.text } ?? "")) }
        if let day = dayNote { lines.append(day) }
        return lines.joined(separator: "\n")
    }

    var gearSummary: String {
        var g: [String] = []
        if gear.barbell { g.append("barbell" + (gear.barbellMax.map { " up to \(lb($0)) lb" } ?? "")) }
        if let top = gear.dumbbells.last { g.append("dumbbells \(lb(gear.dumbbells.first ?? top))-\(lb(top)) lb") }
        if !gear.kettlebells.isEmpty { g.append("kettlebells " + gear.kettlebells.map { lb($0) }.joined(separator: "/") + " lb") }
        if gear.bench { g.append("bench") }
        if gear.trx { g.append("TRX") }
        if gear.pullupBar { g.append("pull-up bar") }
        if gear.bag { g.append("heavy bag") }
        if gear.treadmill { g.append("treadmill") }
        return g.joined(separator: ", ")
    }

    /// Nothing to do: each action already saved the draft. Kept as a hook for the chat.
    func saveCoachChanges() {}

    // MARK: Actions the coach can take (each returns what happened, for the coach to say)

    /// "Session now: Back Squat 2×6-8, Romanian Deadlift 3×10-15, ..." after a change.
    private var sessionNow: String {
        " Session now: " + session.items.map { i in
            i.isLift ? "\(i.name) \(i.sets)×\(i.low == i.high ? "\(i.high)" : "\(i.low)-\(i.high)")"
                     : "\(i.name) \(i.rounds ?? 0) \(i.unit == .min ? "min" : "rounds")"
        }.joined(separator: ", ") + "."
    }

    func coachSwap(_ name: String, to replacement: String) -> String {
        let s = session
        guard let item = CoachActions.item(name, in: s), item.isLift else { return "No exercise called \(name) in today's session." }
        let used = Set(s.items.compactMap(\.exerciseID))
        let original = item.exerciseID.flatMap(catalog.exercise)
        let options = original.map { CoachActions.alternatives(for: $0, catalog: catalog, gear: gear, excluding: used) } ?? []
        let optionText = options.isEmpty ? "" : " Same-muscle options: " + options.map(\.name).joined(separator: ", ") + "."
        guard let ex = CoachActions.exercise(replacement, catalog: catalog, gear: gear, excluding: used) else {
            return "Couldn't find \(replacement) among exercises the gear allows." + optionText
        }
        if entry(item.key).hasCompletedWork {
            return "Not swapped: \(item.name) already has sets logged today. Skip it or add \(ex.name) instead."
        }
        if let original, !CoachActions.sameMuscles(original, ex) {
            return "Not swapped: \(ex.name) trains different muscles than \(item.name)." + optionText
        }
        if item.isExtra {
            removeExtra(item)
            addExtras([ex.id])
        } else {
            draftSwap(item.key, to: ex.id)
        }
        return "Swapped \(item.name) for \(ex.name) in today's session." + sessionNow
    }

    func coachAdd(_ name: String) -> String {
        guard let ex = CoachActions.exercise(name, catalog: catalog, gear: gear,
                                             excluding: Set(session.items.compactMap(\.exerciseID))) else {
            return "Couldn't find \(name) among exercises the gear allows, or it's already in today's session."
        }
        addExtras([ex.id])
        return "Added \(ex.name) to today's session." + sessionNow
    }

    func coachSkip(_ name: String, reason: String) -> String {
        guard let item = CoachActions.item(name, in: session) else { return "No exercise called \(name) in today's session." }
        let r = ["Pain", "No time", "No equipment", "Other"].first { reason.lowercased().contains($0.lowercased()) } ?? "Other"
        skip(item, reason: r)
        return "Skipped \(item.name) today (\(r))." + sessionNow
    }

    func coachTime(_ minutes: Int) -> String {
        let pick = TimeBox.choices.min { abs($0 - minutes) < abs($1 - minutes) } ?? 45
        setTimeBudget(minutes >= 60 + 15 ? nil : pick)
        return "Time today set to \(minutes >= 75 ? "full" : "\(pick) min"). " + (TimeBox.summary(session) ?? "") + sessionNow
    }
}

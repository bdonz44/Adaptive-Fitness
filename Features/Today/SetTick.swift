import Foundation
import Hybrid12Engine

/// Ticking a work set, shared by the set rows, the Now card and focus mode.
enum SetTick {
    /// Ticks (or unticks) a set. Ticking fills a blank weight with the suggestion,
    /// stores `reps` when given, and starts the rest (or the superset transition).
    static func toggle(_ item: SessionItem, set index: Int, in session: Session, store: AppStore,
                       timer: RestTimer, reps: Int? = nil, weight: Double? = nil,
                       effort: CoachCues.Effort? = nil) {
        let current = store.entry(item.key)
        let wasTicked = index < current.sets.count && current.sets[index].ticked
        let ticking = !wasTicked || reps != nil
        let suggested = store.suggestion(for: item, in: session).weight
        store.update(item.key, sets: item.sets) { e in
            e.sets[index].ticked = ticking
            if let reps { e.sets[index].reps = reps }
            if let weight { e.sets[index].weight = weight }
            if ticking, e.sets[index].weight == nil, item.equipment != .bw, let w = suggested {
                e.sets[index].weight = w
            }
        }
        guard ticking else { store.clearCoachCue(); return }
        store.carryForward(item, from: index)
        store.coachAfterSet(item, set: index, effort: effort, in: session)
        startRest(after: item, in: session, timer: timer)
    }

    static func startRest(after item: SessionItem, in session: Session, timer: RestTimer) {
        if item.startsPair,
           let partner = session.items.first(where: { $0.pair == item.pair && $0.position == 1 }) {
            timer.start(seconds: RestTimer.transitionSeconds, label: "Transition to \(partner.name)")
        } else {
            timer.start(seconds: item.restSeconds, label: "Rest")
        }
    }
}

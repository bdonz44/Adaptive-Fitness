import SwiftUI
import Hybrid12Engine

/// One set at a time: huge weight, a reps stepper, the plates, and Done.
/// While resting it shows the full-screen timer.
struct FocusView: View {
    @Environment(AppStore.self) private var store
    @Environment(RestTimer.self) private var timer
    @Environment(\.dismiss) private var dismiss
    @State private var reps: Int?
    @State private var weight: Double?
    @State private var shownKey = ""
    @State private var effort: CoachCues.Effort?

    var body: some View {
        let look = Theme.look
        let session = store.session
        Group {
            if timer.isActive {
                RestView(close: { dismiss() })
            } else if let open = store.nextOpenSet, let item = session.item(open.key) {
                setScreen(item, open: open, session: session)
            } else {
                doneScreen
            }
        }
        .background(look.background)
    }

    private func setScreen(_ item: SessionItem, open: SessionInsights.OpenSet, session: Session) -> some View {
        let look = Theme.look
        let key = "\(open.key)#\(open.set)"
        let shownWeight = weight ?? store.weight(for: item, set: open.set, in: session)
        let shownReps = reps ?? store.entry(item.key).sets[safe: open.set]?.reps ?? item.high
        let position = (session.items.filter(\.isLift).firstIndex { $0.key == item.key } ?? 0) + 1
        return VStack(alignment: .leading, spacing: 18) {
            HStack {
                Button { dismiss() } label: {
                    Text("All exercises").font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14).frame(height: 44)
                        .background(look.card, in: RoundedRectangle(cornerRadius: max(look.radius - 6, 2)))
                }
                .buttonStyle(.plain)
                Spacer()
                Text("Exercise \(position) of \(session.items.filter(\.isLift).count)")
                    .font(.subheadline).foregroundStyle(look.secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(text: "\(item.kind == .main ? "Main lift" : "Accessory") · Set \(open.set + 1) of \(item.sets)",
                             color: look.accent)
                Text(look.uppercaseTitles ? item.name.uppercased() : item.name)
                    .font(look.title(44)).lineLimit(2).minimumScaleFactor(0.6)
                if let line = coachLine(item, set: open.set, session: session) {
                    Label(line, systemImage: "flame.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(look.accent)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if item.equipment != .bw, let w = shownWeight {
                HStack(spacing: 14) {
                    if item.equipment != .kb { stepButton("−5", label: "5 pounds less") { weight = max(0, w - 5) } }
                    VStack(spacing: 0) {
                        Text(lb(w)).font(look.number(130)).minimumScaleFactor(0.5).lineLimit(1)
                        Text("pounds").font(.title3.weight(.semibold)).foregroundStyle(look.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    if item.equipment == .kb {
                        stepButton("Bell", label: "Next bell") { weight = Suggestions.nextBellInCycle(w) }
                    } else {
                        stepButton("+5", label: "5 pounds more") { weight = w + 5 }
                    }
                }
            }

            HStack(spacing: 14) {
                stepButton("−", label: "One less") { reps = max(0, shownReps - 1) }
                VStack(spacing: 0) {
                    Text("\(shownReps)").font(look.number(60))
                    Text("\(unitWord(item.unit)) · target \(item.low == item.high ? "\(item.high)" : "\(item.low)-\(item.high)")")
                        .font(.subheadline).foregroundStyle(look.secondary)
                }
                .frame(maxWidth: .infinity)
                stepButton("+", label: "One more") { reps = shownReps + 1 }
            }

            if item.equipment == .bb, let w = shownWeight {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Plates on each side").font(.caption).foregroundStyle(look.secondary)
                    PlateBar(total: w)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lookCard()
            }

            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 6) {
                Text("How did it feel?").font(.caption).foregroundStyle(look.secondary)
                EffortPicker(effort: $effort)
            }
            Button {
                SetTick.toggle(item, set: open.set, in: session, store: store, timer: timer,
                               reps: shownReps, weight: item.equipment == .bw ? nil : shownWeight, effort: effort)
                reps = nil
                weight = nil
                effort = nil
            } label: {
                Text(doneLabel(item)).accentButton(height: 64)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .onAppear { shownKey = key }
        .onChange(of: key) { _, newKey in
            if newKey != shownKey { reps = nil; weight = nil; shownKey = newKey }
        }
    }

    private func coachLine(_ item: SessionItem, set: Int, session: Session) -> String? {
        if set == item.sets - 1, let push = CoachCues.lastSetPush(item: item, lightDay: session.isLightDay) { return push }
        if set == 0 { return store.coachTarget(for: item, in: session) }
        return nil
    }

    private var doneScreen: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "checkmark.seal.fill").font(.system(size: 64)).foregroundStyle(Theme.done)
            Text("Lifts done").font(Theme.look.title(40))
            Text("Log the cardio and finisher in the list, then Finish.")
                .multilineTextAlignment(.center).foregroundStyle(Theme.secondary)
            Spacer()
            Button { dismiss() } label: { Text("Back to the list").accentButton() }
                .buttonStyle(.plain)
        }
        .padding(20)
    }

    private func doneLabel(_ item: SessionItem) -> String {
        if item.startsPair { return "Done · go to the next exercise" }
        return item.restSeconds > 0 ? "Done · start \(RestTimer.clock(TimeInterval(item.restSeconds))) rest" : "Done"
    }

    private func stepButton(_ title: String, label: String, action: @escaping () -> Void) -> some View {
        let look = Theme.look
        return Button(action: action) {
            Text(title).font(.title2.weight(.bold))
                .frame(width: 64, height: 64)
                .background(look.card, in: RoundedRectangle(cornerRadius: max(look.radius - 4, 2)))
                .overlay(RoundedRectangle(cornerRadius: max(look.radius - 4, 2)).stroke(look.line))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

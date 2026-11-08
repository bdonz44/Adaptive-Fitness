import Charts
import SwiftUI
import Hybrid12Engine

/// Opens every time: am I ready, what am I doing today, am I winning. Then one button to go.
struct HomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(WhoopService.self) private var whoop
    let go: () -> Void
    @State private var logFood = false
    @State private var quick: QuickAction?
    @State private var askCoach = false

    enum QuickAction: String, Identifiable { case weight, cardio, time; var id: String { rawValue } }

    var body: some View {
        let look = Theme.look
        let session = store.session
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    greeting
                    brief(session)
                    quickActions
                    ReadinessRing()
                    missionCard(session)
                    weekStrip
                    scoreboard
                    coachLine
                    muscleLine
                    InsightsCard(limit: 2)
                    heatmap
                    liftTrends
                    sinceStart
                }
                .padding()
            }
            .background(look.background)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { store.refreshWidget(recovery: whoop.today?.recovery) }
            .sheet(isPresented: $askCoach) { CoachChatView() }
            .sheet(isPresented: $logFood) { FoodLogSheet() }
            .sheet(item: $quick) { action in
                switch action {
                case .weight: QuickWeightSheet()
                case .cardio: QuickCardioSheet()
                case .time: QuickTimeSheet()
                }
            }
        }
    }

    // MARK: Greeting

    private var greeting: some View {
        let look = Theme.look
        let hour = Calendar.current.component(.hour, from: Date())
        let line = hour < 12 ? "Let's work, Brandon." : hour < 17 ? "Still time. Let's go, Brandon." : "Finish strong, Brandon."
        return VStack(alignment: .leading, spacing: 2) {
            Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased())
                .font(.caption.weight(.heavy)).tracking(1.5).foregroundStyle(look.accent)
            Text(line).font(look.title(34)).minimumScaleFactor(0.6).lineLimit(2)
        }
        .padding(.top, 8)
    }

    // MARK: Mission

    @ViewBuilder
    private func missionCard(_ session: Session) -> some View {
        let look = Theme.look
        let week = store.week
        let program = store.program
        let day = (program.order.firstIndex(of: session.slot) ?? 0) + 1
        let main = session.items.first { $0.kind == .main } ?? session.items.first(where: \.isLift)
        VStack(alignment: .leading, spacing: 12) {
            if store.loggedToday && store.draft.startedAt == nil {
                SectionLabel(text: "Today", color: look.accent)
                Text(look.uppercaseTitles ? "DONE TODAY" : "Done today").font(look.title(40))
                Text("Recover like it's part of the program: walk 30 minutes\(store.nutritionAdvice?.proteinGrams.map { ", hit \($0) g protein" } ?? ""), sleep 7+ hours.")
                    .font(.subheadline).foregroundStyle(look.secondary).fixedSize(horizontal: false, vertical: true)
                Text("Next up: \(store.slotName(store.nextSlot))").font(.headline)
            } else {
                SectionLabel(text: store.draft.startedAt == nil ? "Today's mission" : "In progress", color: look.accent)
                Text(look.uppercaseTitles ? session.title.uppercased() : session.title)
                    .font(look.title(44)).minimumScaleFactor(0.5).lineLimit(2)
                Text("Day \(day) of \(program.order.count) · Week \(week.wk) · \(program.program.phaseName(week.phase)) · about \(TimeBox.minutes(session)) min")
                    .font(.subheadline).foregroundStyle(look.secondary)
                if let main, let id = main.exerciseID {
                    let w = store.suggestion(for: main, in: session).weight
                    let last = store.lifts[id]?.history.last
                    VStack(alignment: .leading, spacing: 4) {
                        Text(w.map { "\(main.name) \(lb($0)) × \(main.high)" } ?? "\(main.name) \(main.sets) × \(main.high)")
                            .font(.title3.weight(.bold))
                        if let pr = HomeInsights.prChase(item: main, weight: w, record: store.lifts[id]) {
                            Label(pr, systemImage: "trophy.fill").font(.subheadline.weight(.semibold)).foregroundStyle(look.accent)
                        } else if let l = last, let lw = l.weight, let lr = l.reps {
                            Text("Last time \(lb(lw)) × \(lr). Beat it.").font(.subheadline).foregroundStyle(look.secondary)
                        }
                    }
                }
                Button {
                    store.startWorkout()
                    go()
                } label: {
                    Label(store.draft.startedAt == nil ? "START WORKOUT" : "BACK TO IT", systemImage: "play.fill")
                        .font(.system(size: 22, weight: .black, design: look.bodyDesign))
                        .foregroundStyle(look.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .background(look.accent, in: RoundedRectangle(cornerRadius: max(look.radius - 2, 2)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookCard(highlight: true)
    }

    // MARK: Week

    private var weekStrip: some View {
        let look = Theme.look
        let program = store.program
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(program.doneCount) of \(program.order.count) this week").font(.subheadline.weight(.semibold))
                Spacer()
                if store.streak > 0 {
                    Text("🔥 \(store.streak) week\(store.streak == 1 ? "" : "s") in a row").font(.subheadline.weight(.bold))
                }
            }
            HStack(spacing: 6) {
                ForEach(program.order, id: \.self) { slot in
                    VStack(spacing: 4) {
                        Capsule()
                            .fill(program.isDone(slot) ? look.accent : slot == store.draft.slot ? look.text : look.field)
                            .frame(height: 10)
                        let n = (program.order.firstIndex(of: slot) ?? 0) + 1
                        Text(program.isDone(slot) ? "Day \(n) ✓" : "Day \(n)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(slot == store.draft.slot && !program.isDone(slot) ? look.text : look.secondary)
                            .lineLimit(1)
                    }
                }
            }
            ProgressView(value: Double(store.week.wk - 1) + Double(program.doneCount) / Double(max(1, program.order.count)), total: 12)
                .tint(look.accent)
            let finish = HomeInsights.finishLine(week: store.week, doneThisWeek: program.doneCount, perWeek: program.order.count,
                                                 recentLogDates: store.logs.filter { $0.slot != .R }.map(\.date), now: Date())
            Text("\(program.program.name) · week \(store.week.wk) of 12 · \(finish.left) sessions to go"
                 + (finish.date.map { " · done around \($0.formatted(.dateTime.month(.abbreviated).day()))" } ?? ""))
                .font(.caption).foregroundStyle(look.secondary)
        }
        .padding(16)
        .lookCard()
    }

    // MARK: Scoreboard

    private struct Tile: Identifiable {
        let id: String
        let value: String
        let label: String
        let icon: String
        var good = false
        var tap: (() -> Void)? = nil
    }

    /// Always four tiles (no gaps): the first four that have something to show.
    private var tiles: [Tile] {
        var out: [Tile] = [
            Tile(id: "zone", value: "\(Int(store.hardMinutesThisWeek.rounded()))", label: "Zone 4-5 min this week", icon: "heart.fill"),
            Tile(id: "cardio", value: "\(store.cardioThisWeek)/\(Program.cardioGoalMinutes)", label: "Cardio min this week",
                 icon: "figure.run", good: store.cardioThisWeek >= Program.cardioGoalMinutes),
        ]
        if let p = store.nutritionAdvice?.proteinGrams {
            out.append(Tile(id: "protein", value: "\(store.proteinToday)/\(p) g", label: "Protein eaten · tap to log",
                            icon: "fork.knife", good: store.proteinToday >= p, tap: { logFood = true }))
        }
        if let strain = whoop.today?.strain {
            out.append(Tile(id: "strain", value: String(format: "%.1f", strain), label: "WHOOP strain today", icon: "bolt.fill"))
        }
        if let last = store.weighIns.last {
            let weekAgo = store.weighIns.last { $0.date <= last.date.addingTimeInterval(-6 * 86400) }
            let change = weekAgo.map { " (\(Tracking.changeText(last.pounds - $0.pounds, unit: "lb")))" } ?? ""
            out.append(Tile(id: "weight", value: "\(lb(last.pounds))", label: "Bodyweight lb" + change + " · tap to log",
                            icon: "scalemass.fill", tap: { quick = .weight }))
        }
        out.append(Tile(id: "sessions", value: "\(store.sessionsLoggedTotal)", label: "Sessions logged all time", icon: "checkmark.seal.fill"))
        out.append(Tile(id: "streak", value: "\(store.streak)", label: "Full weeks in a row", icon: "flame.fill"))
        return Array(out.prefix(4))
    }

    private var scoreboard: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(tiles) { t in
                if let tap = t.tap {
                    Button(action: tap) { tile(t.value, t.label, icon: t.icon, good: t.good) }.buttonStyle(.plain)
                } else {
                    tile(t.value, t.label, icon: t.icon, good: t.good)
                }
            }
        }
    }

    private func tile(_ value: String, _ label: String, icon: String, good: Bool = false) -> some View {
        let look = Theme.look
        return VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon).foregroundStyle(look.accent)
            Text(value).font(look.number(30)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
                .foregroundStyle(good ? look.done : look.text)
            Text(label).font(.caption).foregroundStyle(look.secondary).lineLimit(2, reservesSpace: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .lookCard()
    }

    // MARK: Coach and progress

    @ViewBuilder
    private var coachLine: some View {
        let since = HomeInsights.daysSince(store.logs.filter { $0.slot != .R }.map(\.date), now: Date())
        VStack(spacing: 8) {
            if let since, since >= 2, !store.loggedToday {
                CoachCallout(text: "\(since) days since you trained. Today. No negotiating.")
            } else {
                CoachCallout(text: HomeInsights.lineOfTheDay(store.homeFacts, date: Date()))
            }
            Button { askCoach = true } label: {
                Label("Ask the coach", systemImage: "bubble.left.and.text.bubble.right.fill")
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.bordered).tint(Theme.accent)
        }
    }

    // MARK: Brief and quick actions

    private func brief(_ session: Session) -> some View {
        let main = session.items.first { $0.kind == .main }
        let w = main.flatMap { store.suggestion(for: $0, in: session).weight }
        let line = main.map { m in w.map { "\(m.name) \(lb($0)) × \(m.high)" } ?? m.name }
        let pr = main.flatMap { m in HomeInsights.prChase(item: m, weight: w, record: store.lifts[m.exerciseID ?? ""]) } != nil
        let t = whoop.today
        return Text(HomeInsights.brief(recovery: t?.recovery, sleepHours: t?.sleepHours, title: session.title, mainLine: line,
                                       isPR: pr, minutes: TimeBox.minutes(session), doneToday: store.loggedToday))
            .font(.headline)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var quickActions: some View {
        let look = Theme.look
        return HStack(spacing: 8) {
            quickButton("Weight", icon: "scalemass.fill") { quick = .weight }
            if store.adaptive.nutrition { quickButton("Food", icon: "fork.knife") { logFood = true } }
            quickButton("Cardio", icon: "figure.run") { quick = .cardio }
            if store.adaptive.timeBox { quickButton("Time", icon: "timer") { quick = .time } }
        }
        .foregroundStyle(look.text)
    }

    private func quickButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        let look = Theme.look
        return Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.title3).foregroundStyle(look.accent)
                Text(title).font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(look.card, in: RoundedRectangle(cornerRadius: max(look.radius - 6, 2)))
            .overlay(RoundedRectangle(cornerRadius: max(look.radius - 6, 2)).stroke(look.line))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log \(title.lowercased())")
    }

    @ViewBuilder
    private var muscleLine: some View {
        let short = MuscleMap.short(store.muscleSets()).prefix(3)
        if !short.isEmpty && store.logs.count >= 3 {
            let look = Theme.look
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "figure.strengthtraining.traditional").foregroundStyle(look.accent).font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Under 10 sets this week").font(.caption.weight(.heavy)).foregroundStyle(look.accent)
                    Text(short.map(\.name).joined(separator: ", ") + ". Add a few sets with Add exercises.")
                        .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lookCard()
        }
    }

    // MARK: Heatmap and lift trends

    /// Training calendar: one row per week (this week on top), Monday to Sunday.
    private var heatmap: some View {
        let look = Theme.look
        let weeks = HomeInsights.trainingCalendar(store.logs.map(\.date), now: Date(), weeks: 8)
        let full = weeks.dropFirst()
        let avg = full.isEmpty ? 0 : Double(full.map(\.count).reduce(0, +)) / Double(full.count)
        let best = weeks.map(\.count).max() ?? 0
        let todayIndex = (Calendar.current.component(.weekday, from: Date()) + 5) % 7   // Monday = 0
        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Training days", color: look.accent)
            Text("Each row is a week, Monday to Sunday. Filled = you trained that day.")
                .font(.caption).foregroundStyle(look.secondary)
            HStack(spacing: 6) {
                Text("").frame(width: 70, alignment: .leading)
                ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, d in
                    Text(d).font(.caption2.weight(.bold)).foregroundStyle(look.secondary).frame(maxWidth: .infinity)
                }
                Text("").frame(width: 22)
            }
            ForEach(Array(weeks.enumerated()), id: \.offset) { row, week in
                HStack(spacing: 6) {
                    Text(row == 0 ? "This week" : row == 1 ? "Last week" : week.start.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.caption.weight(row == 0 ? .bold : .regular))
                        .foregroundStyle(row == 0 ? look.text : look.secondary)
                        .frame(width: 70, alignment: .leading)
                    ForEach(0..<7, id: \.self) { d in
                        let mark = week.days[d]
                        RoundedRectangle(cornerRadius: 5)
                            .fill(mark == .trained ? look.accent : mark == .future ? Color.clear : look.field)
                            .overlay(RoundedRectangle(cornerRadius: 5)
                                .stroke(row == 0 && d == todayIndex ? look.text : (mark == .future ? look.line : .clear),
                                        lineWidth: row == 0 && d == todayIndex ? 2 : 1))
                            .frame(maxWidth: .infinity)
                            .frame(height: 22)
                    }
                    Text("\(week.count)").font(.caption.weight(.bold)).monospacedDigit()
                        .foregroundStyle(week.count >= store.program.order.count ? look.done : look.text)
                        .frame(width: 22, alignment: .trailing)
                }
                .accessibilityElement()
                .accessibilityLabel("\(row == 0 ? "This week" : "Week of \(week.start.formatted(date: .abbreviated, time: .omitted))"): \(week.count) days trained")
            }
            Text("Average \(String(format: "%.1f", avg)) days a week · best week \(best)")
                .font(.caption.weight(.semibold)).foregroundStyle(look.secondary)
        }
        .padding(16)
        .lookCard()
    }

    @ViewBuilder
    private var liftTrends: some View {
        let ids = ["squat", "bench", "deadlift"].filter { HomeInsights.e1RMSeries(store.lifts[$0]).count >= 2 }
        if !ids.isEmpty {
            let look = Theme.look
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "Estimated max", color: look.accent)
                ForEach(ids, id: \.self) { id in
                    let series = HomeInsights.e1RMSeries(store.lifts[id])
                    let name = store.catalog.exercise(id)?.name ?? id
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name).font(.subheadline.weight(.semibold))
                            Text("\(lb(Suggestions.round5(series.map(\.e1RM).max() ?? 0))) lb").font(look.number(24)).monospacedDigit()
                            if let p = HomeInsights.projection(series, now: Date()) {
                                Text("On pace for \(lb(p.target)) by \(p.date.formatted(.dateTime.month(.abbreviated).day()))")
                                    .font(.caption.weight(.semibold)).foregroundStyle(look.accent)
                            }
                        }
                        .frame(width: 150, alignment: .leading)
                        Chart(Array(series.suffix(12).enumerated()), id: \.offset) { _, p in
                            LineMark(x: .value("Date", p.date), y: .value("Max", p.e1RM))
                                .foregroundStyle(look.accent)
                                .interpolationMethod(.catmullRom)
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 50)
                    }
                }
            }
            .padding(16)
            .lookCard()
        }
    }

    @ViewBuilder
    private var sinceStart: some View {
        let lines = HomeInsights.sinceStart(lifts: store.lifts, weighIns: store.weighIns, waist: store.waist, catalog: store.catalog)
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "Since you started", color: Theme.accent)
                Text(lines.joined(separator: " · ")).font(.headline)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lookCard()
        }
    }
}

/// WHOOP on Home: recovery ring, sleep, HRV, resting heart rate, strain, and the last 7 days.
/// Not connected: a card to connect.
struct ReadinessRing: View {
    @Environment(WhoopService.self) private var whoop
    @Environment(AppStore.self) private var store
    @State private var connecting = false

    static func color(_ r: Int) -> Color {
        let zone = WhoopReadiness.zone(r)
        return zone == .green ? Color(hex: 0x22C55E) : zone == .yellow ? Color(hex: 0xFACC15) : Color(hex: 0xEF4444)
    }

    var body: some View {
        let look = Theme.look
        Group {
            if !whoop.isConnected {
                Button { connecting = true } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "heart.text.square.fill").font(.system(size: 34)).foregroundStyle(look.accent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Connect WHOOP").font(.headline)
                            Text(whoop.isConfigured ? "See recovery, sleep, HRV and strain here, and let recovery set how hard you go."
                                 : "This build doesn't have the WHOOP keys. Install the newest TestFlight build.")
                                .font(.subheadline).foregroundStyle(look.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").foregroundStyle(look.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lookCard(highlight: true)
                }
                .buttonStyle(.plain)
            } else if let t = whoop.today, let r = t.recovery {
                connected(t, r)
            } else {
                HStack {
                    ProgressView()
                    Text(whoop.isSyncing ? "Getting today's WHOOP numbers…" : "No WHOOP recovery yet today. Open WHOOP to sync, then come back.")
                        .font(.subheadline).foregroundStyle(look.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lookCard()
            }
        }
        .sheet(isPresented: $connecting) { NavigationStack { WhoopSettingsView() } }
    }

    private func connected(_ t: WhoopToday, _ r: Int) -> some View {
        let look = Theme.look
        let color = Self.color(r)
        let zone = WhoopReadiness.zone(r)
        let week = Array(store.whoopDays.suffix(7))
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 18) {
                ZStack {
                    Circle().stroke(look.field, lineWidth: 12)
                    Circle().trim(from: 0, to: CGFloat(r) / 100)
                        .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(r)%").font(look.number(30)).monospacedDigit()
                        Text("recovery").font(.caption2).foregroundStyle(look.secondary)
                    }
                }
                .frame(width: 110, height: 110)
                VStack(alignment: .leading, spacing: 6) {
                    Text(zone == .green ? "Green. Go heavy." : zone == .yellow ? "Yellow. Hit your numbers." : "Red. Get it done, no heroics.")
                        .font(.headline).foregroundStyle(color)
                    if let line = WhoopReadiness.coachLine(t) {
                        Text(line).font(.caption).foregroundStyle(look.secondary).lineLimit(3)
                    }
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                stat(t.sleepHours.map { h in let m = Int((h * 60).rounded()); return "\(m / 60):\(String(format: "%02d", m % 60))" } ?? "--",
                     "Sleep", t.sleepPerformance.map { "\($0)%" })
                stat(t.hrv.map { "\(Int($0.rounded()))" } ?? "--", "HRV ms", nil)
                stat(t.restingHR.map(String.init) ?? "--", "RHR", nil)
                stat(t.strain.map { String(format: "%.1f", $0) } ?? "--", "Strain", nil)
            }
            if week.count >= 3 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Last 7 days").font(.caption.weight(.heavy)).foregroundStyle(look.secondary)
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(Array(week.enumerated()), id: \.offset) { _, d in
                            VStack(spacing: 3) {
                                Text(d.recovery.map { "\($0)" } ?? "").font(.system(size: 10, weight: .bold)).monospacedDigit()
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(d.recovery.map(Self.color) ?? look.field)
                                    .frame(height: CGFloat(max(6, d.recovery ?? 6)) * 0.6)
                                Text(d.sleepHours.map { String(format: "%.1fh", $0) } ?? "")
                                    .font(.system(size: 9)).foregroundStyle(look.secondary).monospacedDigit()
                                Text(d.date.formatted(.dateTime.weekday(.narrow))).font(.caption2.weight(.semibold))
                                    .foregroundStyle(look.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 100, alignment: .bottom)
                    Text("Bars: recovery %. Below: hours slept.").font(.caption2).foregroundStyle(look.secondary)
                }
            }
            if !WhoopReadiness.isCurrent(t, now: Date()) {
                Text("From \(t.fetchedAt.formatted(.relative(presentation: .named))). Open WHOOP to sync, then come back.")
                    .font(.caption).foregroundStyle(look.secondary)
            }
        }
        .padding(16)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: look.radius))
        .overlay(RoundedRectangle(cornerRadius: look.radius).stroke(color.opacity(0.5), lineWidth: 1))
    }

    private func stat(_ value: String, _ label: String, _ sub: String?) -> some View {
        let look = Theme.look
        return VStack(spacing: 2) {
            Text(value).font(look.number(22)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
            Text(label).font(.caption2).foregroundStyle(look.secondary)
            if let sub { Text(sub).font(.caption2.weight(.semibold)).foregroundStyle(look.secondary) }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(look.field, in: RoundedRectangle(cornerRadius: 10))
    }
}

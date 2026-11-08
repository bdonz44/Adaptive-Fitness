import SwiftUI
import WidgetKit

struct TodayEntry: TimelineEntry {
    let date: Date
    let snap: WidgetSnapshot
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry { TodayEntry(date: Date(), snap: .placeholder) }
    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(TodayEntry(date: Date(), snap: WidgetSnapshot.read() ?? .placeholder))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let entry = TodayEntry(date: Date(), snap: WidgetSnapshot.read() ?? .placeholder)
        // The app reloads it on every change; this is a fallback.
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600))))
    }
}

private let accent = Color(red: 0.98, green: 0.45, blue: 0.09)

private func recoveryColor(_ r: Int) -> Color {
    r >= 67 ? Color(red: 0.13, green: 0.77, blue: 0.37) : r >= 34 ? Color(red: 0.98, green: 0.8, blue: 0.08) : Color(red: 0.94, green: 0.27, blue: 0.27)
}

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    var body: some View {
        let s = entry.snap
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(s.doneToday ? "Done today" : s.title).font(.headline).lineLimit(1)
                Text("\(s.done)/\(s.total) this week" + (s.streak > 0 ? " · 🔥\(s.streak)" : "")).font(.caption)
                if let p = s.proteinTarget { Text("Protein \(s.proteinEaten ?? 0)/\(p) g").font(.caption) }
            }
        case .accessoryCircular:
            Gauge(value: Double(s.done), in: 0...Double(max(s.total, 1))) { Text("Wk") } currentValueLabel: { Text("\(s.done)") }
                .gaugeStyle(.accessoryCircularCapacity)
        case .systemMedium:
            HStack(spacing: 14) {
                main(s)
                VStack(alignment: .leading, spacing: 8) {
                    if let r = s.recovery {
                        stat("\(r)%", "Recovery", color: recoveryColor(r))
                    }
                    if let p = s.proteinTarget {
                        stat("\(s.proteinEaten ?? 0)/\(p)", "Protein g", color: (s.proteinEaten ?? 0) >= p ? .green : .primary)
                    }
                    if s.streak > 0 { stat("🔥 \(s.streak)", "Weeks in a row", color: .primary) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        default:
            main(s)
        }
    }

    private func main(_ s: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(s.doneToday ? "DONE TODAY" : "TODAY").font(.caption2.weight(.heavy)).foregroundStyle(accent)
            Text(s.doneToday ? "Recover" : s.title).font(.headline.weight(.heavy)).lineLimit(2).minimumScaleFactor(0.7)
            Text(s.subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 2)
            HStack(spacing: 3) {
                ForEach(0..<max(s.total, 1), id: \.self) { i in
                    Capsule().fill(i < s.done ? accent : Color.secondary.opacity(0.3)).frame(height: 6)
                }
            }
            Text("\(s.done) of \(s.total) this week").font(.caption2.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stat(_ value: String, _ label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.headline.weight(.bold)).foregroundStyle(color).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HybridToday", provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today")
        .description("Today's session, the week, streak, recovery and protein.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

import SwiftUI
import Hybrid12Engine

/// Progress > Chest and arms.
struct MeasurementsCard: View {
    @Environment(ProgressStore.self) private var progress

    var body: some View {
        Card(title: "Chest and arms") {
            ForEach(BodyPart.allCases, id: \.self) { part in
                let points = progress.points(part)
                VStack(alignment: .leading, spacing: 8) {
                    Text(part.name).font(.headline)
                    Text(part.how).font(.caption).foregroundStyle(Theme.secondary)
                    MeasureSummary(points: points.map { ($0.date, $0.inches) }, unit: "in") { index in
                        progress.removeMeasurement(points[index])
                    }
                    LogField(placeholder: part == .chest ? "Chest" : "Arm", unit: "in") { progress.addMeasurement($0, part: part) }
                }
                if part != BodyPart.allCases.last { Divider() }
            }
        }
    }
}

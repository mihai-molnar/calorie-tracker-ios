import SwiftUI
import Charts

struct WeightChartView: View {
    let entries: [DailyLogEntry]

    private var yDomain: ClosedRange<Double> {
        let weights = entries.compactMap(\.weightKg)
        guard let min = weights.min(), let max = weights.max() else {
            return 0...100
        }
        let padding = Swift.max((max - min) * 0.5, 1.0)
        return (min - padding)...(max + padding)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weight Trend")
                .font(.headline)

            if entries.isEmpty {
                Text("No weight data yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(entries) { entry in
                    if let weight = entry.weightKg {
                        LineMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", weight)
                        )
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", weight)
                        )
                        .foregroundStyle(.blue)
                    }
                }
                .frame(height: 200)
                .chartYScale(domain: yDomain)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }
}

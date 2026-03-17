import SwiftUI
import Charts

struct CalorieChartView: View {
    let entries: [DailyLogEntry]
    let dailyTarget: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Calories")
                .font(.headline)

            if entries.isEmpty {
                Text("No calorie data yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            } else {
                Chart {
                    ForEach(entries) { entry in
                        BarMark(
                            x: .value("Date", entry.date),
                            y: .value("Calories", entry.totalCalories)
                        )
                        .foregroundStyle(entry.totalCalories > dailyTarget ? .red : .blue)
                    }

                    RuleMark(y: .value("Target", dailyTarget))
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Target")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                }
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }
}

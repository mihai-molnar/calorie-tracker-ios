import SwiftUI
import Charts

struct CalorieChartView: View {
    let entries: [DailyLogEntry]
    let dailyTarget: Int
    let isLoadingMore: Bool
    let onLoadMore: () -> Void

    private let pointWidth: CGFloat = 25

    private var chartWidth: CGFloat {
        CGFloat(entries.count) * pointWidth
    }

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
                scrollableChart
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    private var scrollableChart: some View {
        HStack(spacing: 0) {
            // Fixed Y-axis
            Chart {
                ForEach(entries) { entry in
                    if let date = entry.parsedDate {
                        BarMark(
                            x: .value("Date", date, unit: .day),
                            y: .value("Calories", entry.totalCalories)
                        )
                        .opacity(0)
                    }
                }
                RuleMark(y: .value("Target", dailyTarget))
                    .opacity(0)
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(width: 50, height: 200)

            // Scrollable chart
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        if isLoadingMore {
                            ProgressView()
                                .frame(width: 40)
                        }

                        Chart {
                            ForEach(entries) { entry in
                                if let date = entry.parsedDate {
                                    BarMark(
                                        x: .value("Date", date, unit: .day),
                                        y: .value("Calories", entry.totalCalories)
                                    )
                                    .foregroundStyle(entry.totalCalories > dailyTarget ? .red : .blue)
                                }
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
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day, count: 3)) { value in
                                if let date = value.as(Date.self) {
                                    let day = Calendar.current.component(.day, from: date)
                                    if day == 1 {
                                        AxisValueLabel {
                                            VStack(spacing: 2) {
                                                Text(date, format: .dateTime.month(.abbreviated))
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                                Text("\(day)")
                                                    .font(.caption2)
                                            }
                                        }
                                    } else {
                                        AxisValueLabel {
                                            Text("\(day)")
                                                .font(.caption2)
                                        }
                                    }
                                    AxisGridLine()
                                    AxisTick()
                                }
                            }
                        }
                        .chartYAxis(.hidden)
                        .frame(width: max(chartWidth, 300), height: 200)
                        .id("calorieChart")
                    }
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onChange(of: geo.frame(in: .named("calorieScroll")).minX) { _, newValue in
                                    if newValue > -100 {
                                        onLoadMore()
                                    }
                                }
                        }
                    )
                }
                .coordinateSpace(name: "calorieScroll")
                .onAppear {
                    proxy.scrollTo("calorieChart", anchor: .trailing)
                }
            }
        }
        .frame(height: 200)
    }
}

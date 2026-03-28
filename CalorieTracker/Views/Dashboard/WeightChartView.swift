import SwiftUI
import Charts

struct WeightChartView: View {
    let entries: [DailyLogEntry]
    let isLoadingMore: Bool
    let onLoadMore: () -> Void

    private let pointWidth: CGFloat = 25

    private var chartWidth: CGFloat {
        CGFloat(entries.count) * pointWidth
    }

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
                scrollableChart
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    private var scrollableChart: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    if isLoadingMore {
                        ProgressView()
                            .frame(width: 40)
                    }

                    Chart(entries) { entry in
                        if let weight = entry.weightKg, let date = entry.parsedDate {
                            LineMark(
                                x: .value("Date", date, unit: .day),
                                y: .value("Weight", weight)
                            )
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("Date", date, unit: .day),
                                y: .value("Weight", weight)
                            )
                            .foregroundStyle(.blue)
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
                    .chartYScale(domain: yDomain)
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .frame(width: max(chartWidth, 300), height: 200)
                    .id("weightChart")
                }
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onChange(of: geo.frame(in: .named("weightScroll")).minX) { _, newValue in
                                if newValue > -100 {
                                    onLoadMore()
                                }
                            }
                    }
                )
            }
            .coordinateSpace(name: "weightScroll")
            .frame(height: 200)
            .onAppear {
                proxy.scrollTo("weightChart", anchor: .trailing)
            }
        }
    }
}

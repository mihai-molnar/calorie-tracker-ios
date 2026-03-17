import SwiftUI

struct SummaryCardView: View {
    let today: TodaySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today")
                .font(.headline)

            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(today.totalCalories)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("consumed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(today.caloriesRemaining)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(today.caloriesRemaining >= 0 ? .green : .red)
                    Text("remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    if let weight = today.weightKg {
                        Text(weight.formatted(.number.precision(.fractionLength(1))))
                            .font(.title)
                            .fontWeight(.bold)
                        Text("kg")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("--")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("no weigh-in")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }
}

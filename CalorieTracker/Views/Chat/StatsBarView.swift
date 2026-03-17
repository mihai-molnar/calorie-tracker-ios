import SwiftUI

struct StatsBarView: View {
    let totalCalories: Int
    let dailyCalorieTarget: Int
    let weightKg: Double?
    let progress: Double

    var body: some View {
        HStack(spacing: 16) {
            ProgressRingView(progress: progress, lineWidth: 6, size: 44)
                .overlay {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 10, weight: .semibold))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(totalCalories) / \(dailyCalorieTarget) kcal")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("\(max(0, dailyCalorieTarget - totalCalories)) remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let weight = weightKg {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(weight.formatted(.number.precision(.fractionLength(1))))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("kg")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }
}

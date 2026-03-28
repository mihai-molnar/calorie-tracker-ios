import SwiftUI

struct StatsBarView: View {
    let totalCalories: Int
    let dailyCalorieTarget: Int
    let weightKg: Double?
    let progress: Double
    @Binding var dataApplied: Bool

    @State private var popScale: CGFloat = 1.0

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
                    .scaleEffect(popScale)
                Text("\(max(0, dailyCalorieTarget - totalCalories)) remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .scaleEffect(popScale)
            }

            Spacer()

            if let weight = weightKg {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(weight.formatted(.number.precision(.fractionLength(1))))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .scaleEffect(popScale)
                    Text("kg")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .onChange(of: dataApplied) {
            if dataApplied {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                    popScale = 1.3
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                        popScale = 1.0
                    }
                    dataApplied = false
                }
            }
        }
    }
}

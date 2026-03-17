import SwiftUI

struct TargetWeightStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var targetText = ""

    var body: some View {
        VStack(spacing: 24) {
            Text("What's your target weight?")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Must be less than your current weight (\(viewModel.weightKg.formatted(.number.precision(.fractionLength(0...1)))) kg)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TextField("75", text: $targetText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .frame(width: 120)
                    .onChange(of: targetText) { _, newValue in
                        if let val = Double(newValue) {
                            viewModel.targetWeightKg = val
                        }
                    }
                Text("kg")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            if viewModel.targetWeightKg >= viewModel.weightKg && !targetText.isEmpty {
                Text("Target weight must be less than current weight")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .onAppear {
            targetText = viewModel.targetWeightKg.formatted(.number.precision(.fractionLength(0...1)))
        }
    }
}

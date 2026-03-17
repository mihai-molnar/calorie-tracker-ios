import SwiftUI

struct WeightStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var weightText = ""

    var body: some View {
        VStack(spacing: 24) {
            Text("What's your current weight?")
                .font(.title2)
                .fontWeight(.semibold)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TextField("80", text: $weightText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .frame(width: 120)
                    .onChange(of: weightText) { _, newValue in
                        if let val = Double(newValue) {
                            viewModel.weightKg = val
                        }
                    }
                Text("kg")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            weightText = viewModel.weightKg.formatted(.number.precision(.fractionLength(0...1)))
        }
    }
}

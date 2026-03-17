import SwiftUI

struct ReviewStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var overrideText = ""
    @State private var isOverriding = false

    private var calculatedTarget: Int {
        let bmr: Double
        switch viewModel.gender {
        case .male:
            bmr = 10 * viewModel.weightKg + 6.25 * viewModel.heightCm - 5 * Double(viewModel.age) + 5
        case .female:
            bmr = 10 * viewModel.weightKg + 6.25 * viewModel.heightCm - 5 * Double(viewModel.age) - 161
        case .other:
            let male = 10 * viewModel.weightKg + 6.25 * viewModel.heightCm - 5 * Double(viewModel.age) + 5
            let female = 10 * viewModel.weightKg + 6.25 * viewModel.heightCm - 5 * Double(viewModel.age) - 161
            bmr = (male + female) / 2
        }

        let multiplier: Double
        switch viewModel.activityLevel {
        case .sedentary: multiplier = 1.2
        case .light: multiplier = 1.375
        case .moderate: multiplier = 1.55
        case .active: multiplier = 1.725
        case .veryActive: multiplier = 1.9
        }

        let tdee = bmr * multiplier
        let target = max(1200, Int(tdee - 500))
        return target
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Your Daily Target")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                Text("\(viewModel.calorieTargetOverride ?? calculatedTarget)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                Text("kcal / day")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                HStack {
                    Text("Gender")
                    Spacer()
                    Text(viewModel.gender.rawValue.capitalized)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Age")
                    Spacer()
                    Text("\(viewModel.age)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Height")
                    Spacer()
                    Text("\(Int(viewModel.heightCm)) cm")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Weight")
                    Spacer()
                    Text("\(viewModel.weightKg.formatted(.number.precision(.fractionLength(0...1)))) kg")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Target")
                    Spacer()
                    Text("\(viewModel.targetWeightKg.formatted(.number.precision(.fractionLength(0...1)))) kg")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Activity")
                    Spacer()
                    Text(viewModel.activityLevel.displayName)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
            .padding(.horizontal)

            if isOverriding {
                HStack {
                    TextField("Custom target", text: $overrideText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: overrideText) { _, newValue in
                            viewModel.calorieTargetOverride = Int(newValue)
                        }
                    Button("Reset") {
                        isOverriding = false
                        viewModel.calorieTargetOverride = nil
                        overrideText = ""
                    }
                    .font(.caption)
                }
                .padding(.horizontal)
            } else {
                Button("Adjust target manually") {
                    isOverriding = true
                    overrideText = "\(calculatedTarget)"
                }
                .font(.footnote)
            }
        }
    }
}

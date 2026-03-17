import SwiftUI

struct GenderStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text("What's your gender?")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Used to calculate your daily calorie target")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Gender", selection: $viewModel.gender) {
                ForEach(Gender.allCases, id: \.self) { gender in
                    Text(gender.rawValue.capitalized).tag(gender)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
        }
    }
}

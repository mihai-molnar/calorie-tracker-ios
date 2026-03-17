import SwiftUI

struct HeightStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text("What's your height?")
                .font(.title2)
                .fontWeight(.semibold)

            Text("\(Int(viewModel.heightCm)) cm")
                .font(.system(size: 48, weight: .bold, design: .rounded))

            Slider(value: $viewModel.heightCm, in: 100...250, step: 1)
                .padding(.horizontal)
        }
    }
}

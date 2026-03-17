import SwiftUI

struct AgeStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text("How old are you?")
                .font(.title2)
                .fontWeight(.semibold)

            Picker("Age", selection: $viewModel.age) {
                ForEach(10...100, id: \.self) { age in
                    Text("\(age) years").tag(age)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 150)
        }
    }
}

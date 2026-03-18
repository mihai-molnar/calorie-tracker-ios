import SwiftUI

struct OnboardingContainerView: View {
    @State var viewModel: OnboardingViewModel

    init(authManager: AuthManager) {
        self._viewModel = State(initialValue: OnboardingViewModel(authManager: authManager))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            ProgressView(value: viewModel.progress)
                .padding(.horizontal)
                .padding(.top, 8)

            Text("Step \(viewModel.currentStep + 1) of \(viewModel.totalSteps)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Spacer()

            // Current step content
            Group {
                switch viewModel.currentStep {
                case 0: GenderStepView(viewModel: viewModel)
                case 1: AgeStepView(viewModel: viewModel)
                case 2: HeightStepView(viewModel: viewModel)
                case 3: WeightStepView(viewModel: viewModel)
                case 4: ActivityStepView(viewModel: viewModel)
                case 5: TargetWeightStepView(viewModel: viewModel)
                case 6: ReviewStepView(viewModel: viewModel)
                default: EmptyView()
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.currentStep)

            Spacer()

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            // Navigation buttons
            HStack(spacing: 16) {
                if viewModel.currentStep > 0 {
                    Button("Back") {
                        viewModel.previousStep()
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                if viewModel.currentStep == viewModel.totalSteps - 1 {
                    Button {
                        Task { await viewModel.submit() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("Get Started")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canAdvance || viewModel.isLoading)
                } else {
                    Button("Next") {
                        viewModel.nextStep()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canAdvance)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }
}

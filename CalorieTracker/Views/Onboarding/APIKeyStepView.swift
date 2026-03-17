import SwiftUI

struct APIKeyStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text("OpenAI API Key")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Your key is encrypted and stored securely on the server. It's used to power the AI chat.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack {
                SecureField("sk-...", text: $viewModel.apiKey)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Button {
                    if let clip = UIPasteboard.general.string {
                        viewModel.apiKey = clip
                    }
                } label: {
                    Image(systemName: "doc.on.clipboard")
                }
            }
            .padding(.horizontal)
        }
    }
}

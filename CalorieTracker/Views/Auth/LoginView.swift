import SwiftUI

struct LoginView: View {
    @State private var viewModel: AuthViewModel
    var onNavigateToRegister: () -> Void

    init(authManager: AuthManager, onNavigateToRegister: @escaping () -> Void) {
        self._viewModel = State(initialValue: AuthViewModel(authManager: authManager))
        self.onNavigateToRegister = onNavigateToRegister
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("CalTracker")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Track your calories with AI")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 14) {
                StyledTextField(placeholder: "Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                StyledTextField(placeholder: "Password", text: $viewModel.password, isSecure: true)
                    .textContentType(.password)
            }
            .padding(.horizontal)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Button {
                Task { await viewModel.login() }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                } else {
                    Text("Sign In")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
            }
            .buttonStyle(.borderedProminent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disabled(!viewModel.isValid || viewModel.isLoading)
            .padding(.horizontal)

            Button("Don't have an account? Sign Up") {
                onNavigateToRegister()
            }
            .font(.footnote)

            Spacer()
        }
        .padding()
    }
}

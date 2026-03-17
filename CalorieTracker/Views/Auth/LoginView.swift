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

            VStack(spacing: 16) {
                TextField("Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .textFieldStyle(.roundedBorder)

                SecureField("Password", text: $viewModel.password)
                    .textContentType(.password)
                    .textFieldStyle(.roundedBorder)
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
                } else {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
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

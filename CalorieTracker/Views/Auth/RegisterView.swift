import SwiftUI

struct RegisterView: View {
    @State private var viewModel: AuthViewModel
    var onNavigateToLogin: () -> Void

    init(authManager: AuthManager, onNavigateToLogin: @escaping () -> Void) {
        self._viewModel = State(initialValue: AuthViewModel(authManager: authManager))
        self.onNavigateToLogin = onNavigateToLogin
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Create Account")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Start tracking your calories")
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
                    .textContentType(.newPassword)
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
                Task { await viewModel.register() }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Create Account")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.isValid || viewModel.isLoading)
            .padding(.horizontal)

            Button("Already have an account? Sign In") {
                onNavigateToLogin()
            }
            .font(.footnote)

            Spacer()
        }
        .padding()
    }
}

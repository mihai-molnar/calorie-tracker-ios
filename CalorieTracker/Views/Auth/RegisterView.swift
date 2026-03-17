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

            VStack(spacing: 14) {
                StyledTextField(placeholder: "Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                StyledTextField(placeholder: "Password", text: $viewModel.password, isSecure: true)
                    .textContentType(.newPassword)
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
                        .padding(.vertical, 6)
                } else {
                    Text("Create Account")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
            }
            .buttonStyle(.borderedProminent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
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

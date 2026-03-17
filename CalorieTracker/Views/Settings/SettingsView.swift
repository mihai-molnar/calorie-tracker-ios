import SwiftUI

struct SettingsView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    Form {
                        Section("OpenAI API Key") {
                            SecureField("New API key", text: Binding(
                                get: { vm.apiKey },
                                set: { vm.apiKey = $0 }
                            ))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                            Button {
                                Task { await vm.saveApiKey() }
                            } label: {
                                if vm.isLoading {
                                    ProgressView()
                                } else {
                                    Text("Update Key")
                                }
                            }
                            .disabled(!vm.canSaveApiKey)

                            if let success = vm.successMessage {
                                Text(success)
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }

                            if let error = vm.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }

                        if let target = vm.dailyCalorieTarget {
                            Section("Daily Calorie Target") {
                                Text("\(target) kcal")
                            }
                        }

                        Section {
                            Button("Log Out", role: .destructive) {
                                vm.logout()
                            }
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Settings")
        }
        .task {
            let vm = SettingsViewModel(authManager: authManager)
            self.viewModel = vm
            await vm.loadSettings()
        }
    }
}

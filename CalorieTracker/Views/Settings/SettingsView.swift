import SwiftUI

struct SettingsView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    Form {
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

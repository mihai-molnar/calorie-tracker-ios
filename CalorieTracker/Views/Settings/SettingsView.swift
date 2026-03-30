import SwiftUI

struct SettingsView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    Form {
                        Section("Daily Calorie Target") {
                            if vm.isLoading {
                                ShimmerView(width: 80, height: 16)
                            } else if let target = vm.dailyCalorieTarget {
                                Text("\(target) kcal")
                            }
                        }

                        Section("How to Use") {
                            TutorialView()
                                .listRowInsets(EdgeInsets())
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

import SwiftUI

struct DashboardView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: DashboardViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    if vm.isLoading && vm.today == nil {
                        ProgressView()
                    } else if let today = vm.today {
                        ScrollView {
                            VStack(spacing: 16) {
                                SummaryCardView(today: today)

                                WeightChartView(entries: vm.weightEntries(from: vm.allEntries).reversed())

                                CalorieChartView(
                                    entries: Array(vm.allEntries.prefix(30).reversed()),
                                    dailyTarget: today.dailyCalorieTarget
                                )
                            }
                            .padding()
                        }
                    } else if let error = vm.errorMessage {
                        ContentUnavailableView {
                            Label("Error", systemImage: "exclamationmark.triangle")
                        } description: {
                            Text(error)
                        } actions: {
                            Button("Retry") {
                                Task { await vm.loadDashboard() }
                            }
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Dashboard")
        }
        .task {
            let vm = DashboardViewModel(authManager: authManager)
            self.viewModel = vm
            await vm.loadDashboard()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active, let vm = viewModel {
                Task { await vm.loadDashboard() }
            }
        }
    }
}

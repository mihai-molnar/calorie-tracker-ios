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
                    } else if vm.today != nil {
                        ScrollView {
                            VStack(spacing: 16) {
                                SummaryCardView(today: vm.today!)

                                WeightChartView(
                                    entries: vm.weightEntries(from: vm.allEntries).reversed(),
                                    isLoadingMore: vm.isLoadingMore,
                                    onLoadMore: { Task { await vm.loadMore() } }
                                )

                                CalorieChartView(
                                    entries: vm.allEntries.reversed(),
                                    dailyTarget: vm.today!.dailyCalorieTarget,
                                    isLoadingMore: vm.isLoadingMore,
                                    onLoadMore: { Task { await vm.loadMore() } }
                                )
                            }
                            .padding()
                        }
                        .refreshable {
                            await vm.loadDashboard()
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
        .onAppear {
            if let vm = viewModel, vm.today != nil {
                Task { await vm.refreshLatest() }
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active, let vm = viewModel, vm.today != nil {
                Task { await vm.refreshLatest() }
            }
        }
    }
}

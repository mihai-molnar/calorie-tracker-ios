import SwiftUI

struct DashboardView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var viewModel: DashboardViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    if vm.isLoading && vm.data == nil {
                        ProgressView()
                    } else if let data = vm.data {
                        ScrollView {
                            VStack(spacing: 16) {
                                SummaryCardView(today: data.today)

                                // 7-day average
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("7-Day Average")
                                            .font(.headline)
                                        Text("\(vm.calculateSevenDayAverage(from: data.history)) kcal")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                    }
                                    Spacer()
                                }
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))

                                WeightChartView(entries: vm.weightEntries(from: data.history).reversed())

                                CalorieChartView(
                                    entries: Array(data.history.prefix(30).reversed()),
                                    dailyTarget: data.today.dailyCalorieTarget
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
    }
}

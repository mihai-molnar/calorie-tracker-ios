import SwiftUI

@main
struct CalorieTrackerApp: App {
    @State private var authManager = AuthManager()
    @State private var showingRegister = false

    var body: some Scene {
        WindowGroup {
            Group {
                switch authManager.state {
                case .unauthenticated:
                    NavigationStack {
                        if showingRegister {
                            RegisterView(authManager: authManager) {
                                showingRegister = false
                            }
                        } else {
                            LoginView(authManager: authManager) {
                                showingRegister = true
                            }
                        }
                    }

                case .loading:
                    ProgressView("Loading...")
                        .task { await checkOnboardingStatus() }

                case .needsOnboarding:
                    OnboardingContainerView(authManager: authManager)

                case .onboarded:
                    TabView {
                        ChatView()
                            .tabItem {
                                Label("Chat", systemImage: "message")
                            }
                        DashboardView()
                            .tabItem {
                                Label("Dashboard", systemImage: "chart.bar")
                            }
                        SettingsView()
                            .tabItem {
                                Label("Settings", systemImage: "gear")
                            }
                    }
                }
            }
            .environment(authManager)
        }
    }

    private func checkOnboardingStatus() async {
        guard let token = authManager.token else {
            authManager.logout()
            return
        }
        do {
            let _: DashboardResponse = try await APIClient(authManager: authManager).get(path: "/dashboard", token: token)
            authManager.markOnboarded()
        } catch let error as APIError where error.isUnauthorized {
            authManager.handleUnauthorized()
        } catch {
            // Dashboard failed (likely no profile) — needs onboarding
            authManager.markNeedsOnboarding()
        }
    }
}

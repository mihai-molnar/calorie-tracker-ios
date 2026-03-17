import SwiftUI

@main
struct CalorieTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "fork.knife.circle.fill")
                .imageScale(.large)
                .foregroundStyle(.tint)
                .font(.system(size: 60))
            Text("Calorie Tracker")
                .font(.largeTitle)
                .fontWeight(.bold)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}

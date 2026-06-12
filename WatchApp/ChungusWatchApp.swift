import SwiftUI

@main
struct ChungusWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
    }
}

struct WatchRootView: View {
    @State private var hasActiveWorkout = false

    var body: some View {
        NavigationStack {
            if hasActiveWorkout {
                ActiveWorkoutView()
            } else {
                WatchHomeView(hasActiveWorkout: $hasActiveWorkout)
            }
        }
    }
}

struct WatchHomeView: View {
    @Binding var hasActiveWorkout: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Chungus")
                    .font(.title3.bold())
                    .foregroundStyle(.orange)

                Button {
                    hasActiveWorkout = true
                } label: {
                    Label("Start Workout", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                NavigationLink {
                    WatchHistoryView()
                } label: {
                    Label("History", systemImage: "clock")
                }
            }
            .padding()
        }
        .navigationTitle("Chungus")
    }
}

struct WatchHistoryView: View {
    var body: some View {
        List {
            Text("Recent workouts will appear here")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .navigationTitle("History")
    }
}

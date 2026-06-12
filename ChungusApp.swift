import SwiftUI
import SwiftData

@main
struct ChungusApp: App {

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [
            UserProfile.self,
            WorkoutPlan.self,
            WorkoutTemplate.self,
            ExerciseTemplate.self,
            WorkoutSession.self,
            ExerciseSession.self,
            SetRecord.self
        ])
    }
}

/// Root view that decides between onboarding and dashboard
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    var body: some View {
        if profiles.isEmpty {
            OnboardingView()
        } else {
            MainTabView()
        }
    }
}

/// Main tab bar after onboarding
struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Workouts", systemImage: "dumbbell.fill")
                }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(.orange)
    }
}

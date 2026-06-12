import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class DashboardViewModel {

    var upcomingWorkouts: [WorkoutTemplate] = []
    var recentSessions: [WorkoutSession] = []
    var isLoading = false
    var activePlan: WorkoutPlan?

    func loadData(context: ModelContext) {
        isLoading = true

        // Fetch active plan
        let planDescriptor = FetchDescriptor<WorkoutPlan>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        if let plan = try? context.fetch(planDescriptor).first {
            activePlan = plan
            upcomingWorkouts = plan.workouts
                .sorted { $0.order < $1.order }
        }

        // Fetch recent sessions (last 10)
        var sessionDescriptor = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        sessionDescriptor.fetchLimit = 10

        recentSessions = (try? context.fetch(sessionDescriptor)) ?? []

        isLoading = false
    }

    /// Get the last session for a specific workout template
    func lastSession(for template: WorkoutTemplate) -> WorkoutSession? {
        recentSessions.first { $0.templateId == template.id }
    }

    /// Stats for the dashboard header
    var totalWorkoutsCompleted: Int {
        recentSessions.filter { $0.isComplete }.count
    }

    var currentStreak: Int {
        // Simple streak calculation: consecutive days with workouts
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        let workoutDates = Set(recentSessions.map {
            calendar.startOfDay(for: $0.startedAt)
        })

        while workoutDates.contains(checkDate) {
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }

        return streak
    }
}

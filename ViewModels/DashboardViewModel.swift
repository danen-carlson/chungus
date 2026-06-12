import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class DashboardViewModel {

    var upcomingWorkouts: [WorkoutTemplate] = []
    var recentSessions: [WorkoutSession] = []
    var isLoading = false
    var isGenerating = false
    var generationError: String?
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

    /// Generate a workout plan (fallback for when onboarding saved profile but plan generation failed)
    func generatePlan(context: ModelContext) async {
        isGenerating = true
        generationError = nil

        // Fetch user profile
        var profileDescriptor = FetchDescriptor<UserProfile>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        profileDescriptor.fetchLimit = 1

        guard let profile = try? context.fetch(profileDescriptor).first else {
            generationError = "No profile found. Please restart the app."
            isGenerating = false
            return
        }

        do {
            let generator = WorkoutGenerator()
            let profileSummary = profile.promptSummary
            print("[Chungus] Retrying plan generation for: \(profileSummary)")
            let generatedPlan = try await generator.generateInitialPlan(profileSummary: profileSummary)
            print("[Chungus] Plan received: \(generatedPlan.splitType) with \(generatedPlan.workouts.count) workouts")

            let plan = WorkoutPlan(splitType: generatedPlan.splitType)

            for (index, genWorkout) in generatedPlan.workouts.enumerated() {
                let template = WorkoutTemplate(
                    name: genWorkout.name,
                    targetMuscles: genWorkout.targetMuscles,
                    estimatedDurationMin: genWorkout.estimatedDurationMin,
                    order: index
                )

                for (exIndex, genEx) in genWorkout.exercises.enumerated() {
                    let exercise = ExerciseTemplate(
                        name: genEx.name,
                        muscleGroup: genEx.muscleGroup,
                        sets: genEx.sets,
                        repRange: genEx.repRange,
                        targetWeightLbs: genEx.targetWeightLbs,
                        restSeconds: genEx.restSeconds,
                        tips: genEx.tips,
                        alternatives: genEx.alternatives ?? [],
                        order: exIndex
                    )
                    template.exercises.append(exercise)
                }

                plan.workouts.append(template)
            }

            context.insert(plan)
            try context.save()

            // Reload dashboard data
            loadData(context: context)
            print("[Chungus] Plan saved — dashboard reloaded")

        } catch {
            print("[Chungus] ❌ Plan generation failed: \(error)")
            generationError = error.localizedDescription
        }

        isGenerating = false
    }
}

import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class RebuildPlanViewModel {

    // Step tracking
    var currentStep: Int = 0
    var totalSteps: Int = 4
    var isGenerating = false
    var generationError: String?

    // Pre-filled profile data
    var age: Int = 25
    var sex: String = "Prefer not to say"
    var heightFeet: Int = 5
    var heightInches: Int = 10
    var weightLbs: Double = 170
    var yearsTraining: Double = 0
    var daysAvailable: Int = 4
    var sportsPlayed: String = ""
    var specificExercises: String = ""
    var goal: String = "Hypertrophy"
    var equipmentAccess: String = "Full Gym"
    var equipmentPreference: Set<String> = ["Free weights"]
    var timeConstraintMin: Int? = nil
    var additionalNotes: String = ""

    // Gateway connection
    var gatewayConnected: Bool = false

    // History summary
    var historySummary: String = "No recent workout history found."

    var canProceed: Bool {
        switch currentStep {
        case 0: return age >= 13 && weightLbs > 0
        case 1: return daysAvailable >= 1 && daysAvailable <= 7
        case 2: return true
        case 3: return gatewayConnected
        default: return false
        }
    }

    var progress: Double {
        Double(currentStep + 1) / Double(totalSteps)
    }

    func nextStep() {
        guard currentStep < totalSteps - 1 else { return }
        currentStep += 1
    }

    func previousStep() {
        guard currentStep > 0 else { return }
        currentStep -= 1
    }

    /// Load existing profile and build history summary
    func loadExistingData(context: ModelContext) {
        // Fetch latest profile
        var profileDescriptor = FetchDescriptor<UserProfile>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        profileDescriptor.fetchLimit = 1

        if let profile = try? context.fetch(profileDescriptor).first {
            age = profile.age
            sex = profile.sex
            heightFeet = profile.heightFeet
            heightInches = profile.heightInches
            weightLbs = profile.weightLbs
            yearsTraining = profile.yearsTraining
            daysAvailable = profile.daysAvailable
            sportsPlayed = profile.sportsPlayed.joined(separator: ", ")
            specificExercises = profile.specificExercises.joined(separator: ", ")
            goal = profile.goal
            equipmentAccess = profile.equipmentAccess
            equipmentPreference = Set(profile.equipmentPreference)
            timeConstraintMin = profile.timeConstraintMin
            additionalNotes = profile.additionalNotes
        }

        // Build history summary from recent sessions
        buildHistorySummary(context: context)
    }

    private func buildHistorySummary(context: ModelContext) {
        var sessionDescriptor = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        sessionDescriptor.fetchLimit = 10

        guard let sessions = try? context.fetch(sessionDescriptor), !sessions.isEmpty else {
            historySummary = "No recent workout history. Estimate weights based on training experience."
            return
        }

        // Extract top weights per exercise name
        var exerciseWeights: [String: [Double]] = [:]

        for session in sessions {
            for exSession in session.exercises {
                if let topWeight = exSession.topSetWeight, topWeight > 0 {
                    // Normalize exercise name (remove variations)
                    let normalizedName = normalizeExerciseName(exSession.name)
                    if exerciseWeights[normalizedName] == nil {
                        exerciseWeights[normalizedName] = []
                    }
                    exerciseWeights[normalizedName]?.append(topWeight)
                }
            }
        }

        if exerciseWeights.isEmpty {
            historySummary = "No weight data found in recent sessions. Estimate based on training experience."
            return
        }

        // Build summary string
        var summaryParts: [String] = []
        for (exName, weights) in exerciseWeights.sorted(by: { $0.key < $1.key }).prefix(15) {
            let avgWeight = weights.reduce(0, +) / Double(weights.count)
            let maxWeight = weights.max() ?? avgWeight
            summaryParts.append("- \(exName): recently used \(Int(avgWeight))-\(Int(maxWeight)) lbs")
        }

        historySummary = summaryParts.joined(separator: "\n")
    }

    private func normalizeExerciseName(_ name: String) -> String {
        // Remove common variations to group similar exercises
        return name
            .replacingOccurrences(of: " - .*", with: "", options: .regularExpression)
            .replacingOccurrences(of: " \\(.*\\)", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// Build UserProfile from current data
    func buildProfile() -> UserProfile {
        let sports = sportsPlayed
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let exercises = specificExercises
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return UserProfile(
            age: age,
            sex: sex,
            heightFeet: heightFeet,
            heightInches: heightInches,
            weightLbs: weightLbs,
            timeConstraintMin: timeConstraintMin,
            daysAvailable: daysAvailable,
            sportsPlayed: sports,
            yearsTraining: yearsTraining,
            specificExercises: exercises,
            goal: goal,
            equipmentAccess: equipmentAccess,
            equipmentPreference: Array(equipmentPreference),
            additionalNotes: additionalNotes
        )
    }

    /// Delete old plan, save updated profile, and generate new plan
    func completeRebuild(context: ModelContext) async {
        isGenerating = true
        generationError = nil

        let profile = buildProfile()
        let profileSummary = profile.promptSummary

        do {
            // Delete existing active plan
            var planDescriptor = FetchDescriptor<WorkoutPlan>(
                predicate: #Predicate { $0.isActive == true }
            )
            if let oldPlan = try? context.fetch(planDescriptor).first {
                context.delete(oldPlan)
            }

            // Generate new plan with history
            let generator = WorkoutGenerator()
            print("[Chungus] Rebuilding plan with history...")
            let generatedPlan = try await generator.regeneratePlan(
                profileSummary: profileSummary,
                historySummary: historySummary
            )
            print("[Chungus] New plan received: \(generatedPlan.splitType) with \(generatedPlan.workouts.count) workouts")

            // Convert to SwiftData models
            let plan = WorkoutPlan(splitType: generatedPlan.splitType)

            for (index, genWorkout) in generatedPlan.workouts.enumerated() {
                let template = WorkoutTemplate(
                    name: genWorkout.name,
                    targetMuscles: genWorkout.targetMuscles,
                    estimatedDurationMin: genWorkout.estimatedDurationMin,
                    order: index
                )

                for (exIndex, genEx) in genWorkout.exercises.enumerated() {
                    let resolvedImageUrl = genEx.imageUrl.map { url -> String in
                        if url.hasPrefix("http") { return url }
                        return "https://fitness.hankbot.online\(url)"
                    }

                    let exercise = ExerciseTemplate(
                        name: genEx.name,
                        muscleGroup: genEx.muscleGroup,
                        sets: genEx.sets,
                        repRange: genEx.repRange,
                        targetWeightLbs: genEx.targetWeightLbs,
                        restSeconds: genEx.restSeconds,
                        tips: genEx.tips,
                        imageUrl: resolvedImageUrl,
                        alternatives: genEx.alternatives ?? [],
                        order: exIndex
                    )
                    template.exercises.append(exercise)
                }

                plan.workouts.append(template)
            }

            // Update profile and insert new plan
            profile.updatedAt = Date()
            context.insert(profile)
            context.insert(plan)
            try context.save()
            print("[Chungus] Profile updated + New Plan saved to SwiftData")

        } catch {
            print("[Chungus] ❌ Rebuild failed: \(error)")
            generationError = error.localizedDescription
        }

        isGenerating = false
    }
}

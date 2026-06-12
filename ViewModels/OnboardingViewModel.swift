import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class OnboardingViewModel {

    // Step tracking
    var currentStep: Int = 0
    var totalSteps: Int = 4
    var isGenerating = false
    var generationError: String?

    // Step 1: Basics
    var age: Int = 25
    var sex: String = "Prefer not to say"
    var heightFeet: Int = 5
    var heightInches: Int = 10
    var weightLbs: Double = 170

    // Step 2: Training
    var yearsTraining: Double = 0
    var daysAvailable: Int = 4
    var sportsPlayed: String = ""
    var specificExercises: String = ""

    // Step 3: Goals & Equipment
    var goal: String = "Hypertrophy"
    var equipmentAccess: String = "Full Gym"
    var equipmentPreference: Set<String> = ["Free weights"]
    var timeConstraintMin: Int? = nil
    var additionalNotes: String = ""

    // Step 4: API Key
    var geminiAPIKey: String = ""

    var canProceed: Bool {
        switch currentStep {
        case 0: return age >= 13 && weightLbs > 0
        case 1: return daysAvailable >= 1 && daysAvailable <= 7
        case 2: return true
        case 3: return !geminiAPIKey.trimmingCharacters(in: .whitespaces).isEmpty
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

    /// Build UserProfile from collected data
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

    /// Save profile and generate initial workout plan
    func completeSetup(context: ModelContext) async {
        isGenerating = true
        generationError = nil

        // Save API key
        KeychainService.geminiAPIKey = geminiAPIKey.trimmingCharacters(in: .whitespaces)

        // Build and save profile
        let profile = buildProfile()
        context.insert(profile)

        do {
            try context.save()

            // Generate initial plan
            let generator = WorkoutGenerator()
            let generatedPlan = try await generator.generateInitialPlan(for: profile)

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

        } catch {
            generationError = error.localizedDescription
        }

        isGenerating = false
    }
}

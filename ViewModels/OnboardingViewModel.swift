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

    // Step 4: Server connectivity
    var gatewayConnected: Bool = false

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

        // Build profile (don't insert yet — wait until plan is generated)
        let profile = buildProfile()
        let profileSummary = profile.promptSummary
        print("[Chungus] Profile: \(profileSummary)")

        do {
            // Generate initial plan via Gateway (RAG + Venice AI)
            // This way if generation fails, user stays on onboarding and can retry
            let generator = WorkoutGenerator()
            print("[Chungus] Calling Gateway to generate plan...")
            let generatedPlan = try await generator.generateInitialPlan(profileSummary: profileSummary)
            print("[Chungus] Plan received: \(generatedPlan.splitType) with \(generatedPlan.workouts.count) workouts")

            // Convert to SwiftData models
            let plan = WorkoutPlan(splitType: generatedPlan.splitType)

            for (index, genWorkout) in generatedPlan.workouts.enumerated() {
                let template = WorkoutTemplate(
                    name: genWorkout.name,
                    targetMuscles: genWorkout.targetMuscles,
                    estimatedDurationMin: genWorkout.estimatedDurationMin,
                    order: index
                )
                print("[Chungus]   Workout \(index + 1): \(genWorkout.name) (\(genWorkout.exercises.count) exercises)")

                for (exIndex, genEx) in genWorkout.exercises.enumerated() {
                    // Resolve relative image URL to full URL
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

            // NOW insert everything and save atomically
            // This triggers the @Query in RootView to switch to Dashboard
            context.insert(profile)
            context.insert(plan)
            try context.save()
            print("[Chungus] Profile + Plan saved to SwiftData — setup complete!")

        } catch {
            print("[Chungus] ❌ Setup failed: \(error)")
            generationError = error.localizedDescription
        }

        isGenerating = false
    }
}
